#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $(basename "$0") [-v]" >&2
    echo "  -v  verbose: print session events to stdout (default when tty)" >&2
    exit 1
}

VERBOSE=0
while getopts "v" opt; do
    case $opt in
        v) VERBOSE=1 ;;
        *) usage ;;
    esac
done

# Auto-enable verbose when running interactively
[ -t 1 ] && VERBOSE=1

log() { [ "$VERBOSE" -eq 1 ] && echo "$@" || true; }

tee_output() {
    if [ "$VERBOSE" -eq 1 ]; then
        tee "$1"
    else
        cat > "$1"
    fi
}

pick_tool() {
    command -v "$1" || command -v "${1}-bpfcc" || { echo "Tool $1 not found" >&2; exit 1; }
}

OPENSNOOP=$(pick_tool opensnoop)
TCPCONNECT=$(pick_tool tcpconnect)
TCPLIFE=$(pick_tool tcplife)
EXECSNOOP=$(pick_tool execsnoop)

LOG_DIR="${LOG_DIR:-$HOME/clouseau-logs}"
POLL_INTERVAL="${POLL_INTERVAL:-5}"

mkdir -p "$LOG_DIR"

# Use sudo only when not already root
if [ "$EUID" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

trap '$SUDO kill $(jobs -p) 2>/dev/null; exit' INT TERM

# Track which PIDs are already being monitored
declare -A TRACKED

# Pattern for the real Claude CLI binary; stored in a variable so that
# pgrep's own command line does not contain the literal path.
CLAUDE_PATTERN='.local/share/claude/versions/'

run_session() {
    local pid=$1
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local session_dir="$LOG_DIR/session_${ts}_pid${pid}"
    mkdir -p "$session_dir"

    log "[$(date)] Claude detected (PID $pid) — logging to $session_dir"

    # What files is it touching?
    $SUDO "$OPENSNOOP" -p "$pid" | tee_output "$session_dir/opensnoop.log" &
    local open_pid=$!

    # Network connections (new + closed with duration/bytes)
    $SUDO "$TCPCONNECT" -p "$pid" | tee_output "$session_dir/tcpconnect.log" &
    local tcp_pid=$!
    $SUDO "$TCPLIFE" -p "$pid" | tee_output "$session_dir/tcplife.log" &
    local tcplife_pid=$!

    # Any subprocesses it spawns
    $SUDO "$EXECSNOOP" -P "$pid" | tee_output "$session_dir/execsnoop.log" &
    local exec_pid=$!

    # Wait for Claude to exit
    while kill -0 "$pid" 2>/dev/null; do
        sleep 2
    done

    log "[$(date)] Claude (PID $pid) exited — stopping tracers"
    $SUDO kill "$open_pid" "$tcp_pid" "$tcplife_pid" "$exec_pid" 2>/dev/null
    wait "$open_pid" "$tcp_pid" "$tcplife_pid" "$exec_pid" 2>/dev/null
    unset TRACKED[$pid]
}

log "[$(date)] Clouseau daemon started (log dir: $LOG_DIR)"

while true; do
    while IFS= read -r pid; do
        if [ -n "$pid" ] && [ -z "${TRACKED[$pid]:-}" ]; then
            # Verify this is actually a Claude binary, not a transient shell
            exe=$(readlink "/proc/$pid/exe" 2>/dev/null || true)
            [[ "$exe" == *"$CLAUDE_PATTERN"* ]] || continue
            TRACKED[$pid]=1
            run_session "$pid" &
        fi
    done < <(pgrep -f "$CLAUDE_PATTERN")
    sleep "$POLL_INTERVAL"
done

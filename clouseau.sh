#!/bin/bash

pick_tool() {
    command -v "$1" || command -v "${1}-bpfcc" || { echo "Tool $1 not found" >&2; exit 1; }
}

OPENSNOOP=$(pick_tool opensnoop)
TCPCONNECT=$(pick_tool tcpconnect)
EXECSNOOP=$(pick_tool execsnoop)

LOG_DIR="${LOG_DIR:-$HOME/clouseau-logs}"
POLL_INTERVAL="${POLL_INTERVAL:-5}"

mkdir -p "$LOG_DIR"

# Use sudo only when not already root
if [ "$EUID" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

trap '$SUDO kill $(jobs -p) 2>/dev/null; exit' INT TERM

run_session() {
    local pid=$1
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local session_dir="$LOG_DIR/session_${ts}_pid${pid}"
    mkdir -p "$session_dir"

    echo "[$(date)] Claude detected (PID $pid) — logging to $session_dir"

    # What files is it touching?
    $SUDO "$OPENSNOOP" -p "$pid" | tee "$session_dir/opensnoop.log" &
    local open_pid=$!

    # Network connections
    $SUDO "$TCPCONNECT" -p "$pid" | tee "$session_dir/tcpconnect.log" &
    local tcp_pid=$!

    # Any subprocesses it spawns
    $SUDO "$EXECSNOOP" -P "$pid" | tee "$session_dir/execsnoop.log" &
    local exec_pid=$!

    # Wait for Claude to exit
    while kill -0 "$pid" 2>/dev/null; do
        sleep 2
    done

    echo "[$(date)] Claude (PID $pid) exited — stopping tracers"
    $SUDO kill "$open_pid" "$tcp_pid" "$exec_pid" 2>/dev/null
    wait "$open_pid" "$tcp_pid" "$exec_pid" 2>/dev/null
}

echo "[$(date)] Clouseau daemon started (log dir: $LOG_DIR)"

while true; do
    CLAUDE_PID=$(pgrep -f "claude" | head -1)
    if [ -n "$CLAUDE_PID" ]; then
        run_session "$CLAUDE_PID"
    fi
    sleep "$POLL_INTERVAL"
done

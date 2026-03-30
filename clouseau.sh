pick_tool() {
    command -v "$1" || command -v "${1}-bpfcc" || { echo "Tool $1 not found" >&2; exit 1; }
}

OPENSNOOP=$(pick_tool opensnoop)
TCPCONNECT=$(pick_tool tcpconnect)
EXECSNOOP=$(pick_tool execsnoop)

CLAUDE_PID=$(pgrep -f "claude")

# What files is it touching?
sudo "$OPENSNOOP" -p "$CLAUDE_PID"

# Network connections
sudo "$TCPCONNECT" -p "$CLAUDE_PID"

# Any subprocesses it spawns
sudo "$EXECSNOOP"

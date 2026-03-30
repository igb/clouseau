# clouseau

A monitor for Claude: what files is it accessing, what network connections is it making, and what processes it is spawning.

Uses Linux eBPF tracing tools to attach to Claude CLI processes and log activity per session.

## What it tracks

- **File access** — via `opensnoop`: every file Claude opens
- **Network connections** — via `tcpconnect`: outbound connections as they are made
- **Connection lifecycle** — via `tcplife`: connection duration and bytes transferred
- **Subprocess execution** — via `execsnoop`: every process Claude spawns

Each Claude session gets its own timestamped directory under `LOG_DIR`.

## Installation (Debian/Ubuntu)

Download the `.deb` from the [latest release](../../releases/latest) and install:

```sh
sudo apt-get install ./clouseau_*.deb
```

This installs:

| Path | Description |
|------|-------------|
| `/usr/bin/clouseau` | The monitor script |
| `/etc/default/clouseau` | Configuration (LOG_DIR, POLL_INTERVAL) |
| `/lib/systemd/system/clouseau.service` | systemd service unit |

### Dependencies

The package depends on `bpfcc-tools` and `procps`, which will be pulled in automatically.

### Running as a service

```sh
sudo systemctl enable --now clouseau
```

Logs go to `/var/log/clouseau/` by default and are also available via journald:

```sh
journalctl -u clouseau -f
```

## Manual / command line usage

```
Usage: clouseau [-v]
  -v  verbose: print session events to stdout (default when tty)
```

Run directly (requires root or sudo for eBPF tools):

```sh
sudo clouseau          # daemon mode, quiet
sudo clouseau -v       # daemon mode, print events to stdout
```

Clouseau polls for a running `claude` process every `POLL_INTERVAL` seconds (default: 5). When found, it attaches all tracers to that PID and logs until the process exits.

## Configuration

Edit `/etc/default/clouseau` to override defaults:

```sh
LOG_DIR=/var/log/clouseau   # where session logs are written
POLL_INTERVAL=5             # seconds between polls for a claude process
```

These variables can also be set in the environment when running manually:

```sh
LOG_DIR=~/my-logs POLL_INTERVAL=2 sudo -E clouseau -v
```

## Log output

Each session produces a directory at `$LOG_DIR/session_<timestamp>_pid<N>/` containing:

| File | Contents |
|------|----------|
| `opensnoop.log` | Files opened by Claude |
| `tcpconnect.log` | Outbound TCP connections |
| `tcplife.log` | Connection duration and bytes |
| `execsnoop.log` | Subprocesses spawned by Claude |

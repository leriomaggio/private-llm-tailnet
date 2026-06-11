#!/usr/bin/env bash
# Stop the background mlx_lm.server, if one is running.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

if [[ ! -f "$PID_FILE" ]]; then
    echo "No PID file at $PID_FILE; nothing to stop."
    exit 0
fi

PID="$(cat "$PID_FILE")"
if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo "Stopped model server (pid $PID)."
else
    echo "Process $PID not running; cleaning up stale PID file."
fi
rm -f "$PID_FILE"

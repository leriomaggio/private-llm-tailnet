#!/usr/bin/env bash
# Start mlx_lm.server in the background and wait until it answers.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Model server already running (pid $(cat "$PID_FILE"))."
    exit 0
fi

echo "Starting mlx_lm.server with $MODEL on port $PORT ..."
cd "$REPO_ROOT"
nohup uv run mlx_lm.server \
    --model "$MODEL" \
    --port "$PORT" \
    --log-level INFO \
    >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"

# First run downloads the model, so be patient before giving up.
for _ in $(seq 1 120); do
    if curl -fsS -m 2 "http://localhost:$PORT/v1/models" >/dev/null 2>&1; then
        echo "Server is up at http://localhost:$PORT (pid $(cat "$PID_FILE"))."
        echo "Logs: $LOG_FILE"
        exit 0
    fi
    if ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Server process exited early. Last log lines:" >&2
        tail -20 "$LOG_FILE" >&2
        rm -f "$PID_FILE"
        exit 1
    fi
    sleep 2
done

echo "Server did not answer within 4 minutes. Check $LOG_FILE" >&2
exit 1

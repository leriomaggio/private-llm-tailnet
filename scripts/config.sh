#!/usr/bin/env bash
# Shared configuration for the helper scripts. Every value can be overridden
# from the environment, e.g. `MODEL=mlx-community/Mistral-7B-Instruct-v0.3-4bit make serve`.

MODEL="${MODEL:-mlx-community/Llama-3.2-3B-Instruct-4bit}"
PORT="${PORT:-8080}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="${RUN_DIR:-$REPO_ROOT/.run}"
PID_FILE="$RUN_DIR/mlx-server.pid"
LOG_FILE="$RUN_DIR/mlx-server.log"

# The macOS GUI app bundles its own CLI; fall back to it when no standalone
# `tailscale` binary is on the PATH.
if command -v tailscale >/dev/null 2>&1; then
    TAILSCALE="tailscale"
else
    TAILSCALE="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

mkdir -p "$RUN_DIR"

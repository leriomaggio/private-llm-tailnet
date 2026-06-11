#!/usr/bin/env bash
# Remove the tailscale serve configuration created by serve-tailnet.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

"$TAILSCALE" serve reset
echo "Serve configuration cleared."
"$TAILSCALE" serve status

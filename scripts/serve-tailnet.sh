#!/usr/bin/env bash
# Expose the model server and the chat client on the tailnet over HTTPS.
#
# Layout on https://<machine>.<tailnet>.ts.net:
#   /        -> proxied to the local mlx_lm.server (so /v1/* reaches the API)
#   /chat    -> the static chat client, served by tailscale itself
#
# This uses `tailscale serve`, which is tailnet-only. It deliberately never
# uses `tailscale funnel`, which would expose the same services to the public
# internet.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

if ! "$TAILSCALE" status >/dev/null 2>&1; then
    echo "Tailscale is not connected. Log in first (menu bar icon or 'tailscale login')." >&2
    exit 1
fi

"$TAILSCALE" serve --bg "http://localhost:$PORT"
"$TAILSCALE" serve --bg --set-path=/chat "$REPO_ROOT/client/chat.html"

echo
"$TAILSCALE" serve status
echo
HOSTNAME_FQDN="$("$TAILSCALE" status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')"
echo "Chat client: https://$HOSTNAME_FQDN/chat"
echo "API:         https://$HOSTNAME_FQDN/v1/chat/completions"

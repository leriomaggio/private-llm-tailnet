# A private LLM on your own tailnet

This repository turns a Mac with Apple silicon into a personal, private LLM
service: a local model served from the Mac, reachable from your phone or any
other of your devices, anywhere in the world, over an encrypted connection
that never touches the public internet.

There is no cloud API in the loop, no account with a model provider, no
public endpoint to secure, and no login screen to build. The network itself
is the security boundary: only devices in your private Tailscale network
(your tailnet) can even see that the service exists.

The whole demo is three small parts:

1. **A model server**: [`mlx_lm.server`](https://github.com/ml-explore/mlx-lm),
   Apple-silicon-native, exposing an OpenAI-compatible chat-completions API
   on localhost.
2. **Tailscale serve**: gives that localhost server a stable HTTPS URL,
   visible only inside your tailnet.
3. **A chat client**: one self-contained HTML file, no build step, served
   over the same URL, so your phone needs nothing installed beyond the
   Tailscale app and a browser.

After one-time setup, the entire thing starts with `make serve`.

## Why bother, when chat apps exist

Partly because the model and the conversation never leave hardware you own,
which matters if you want to experiment with prompts over private notes,
contracts, or health questions. Partly because small open-weight models have
become genuinely useful and run well on consumer Apple silicon. And partly
because it is a compact, honest demonstration of an idea that is bigger than
this demo: identity-based private networking removes most of the work that
normally sits between "service running on my machine" and "service I can use
from anywhere, safely".

The conventional route to remote access involves a public reverse proxy, TLS
certificates, an authentication layer, rate limiting, and the standing anxiety
of an open port. Here, all of that collapses into the question "is this device
in my tailnet or not".

## Architecture

```
        iPhone, anywhere                              Mac, at home
  ┌─────────────────────────┐                ┌────────────────────────────────┐
  │ Tailscale app (VPN on)  │                │ tailscaled                     │
  │                         │   WireGuard    │  ┌──────────────────────────┐  │
  │ Safari:                 │    tunnel      │  │ tailscale serve          │  │
  │  https://mac-name       │ ─────────────► │  │  TLS for *.ts.net        │  │
  │   .tailnet.ts.net/chat  │  end-to-end    │  │  /     → proxy :8080     │  │
  │                         │  encrypted     │  │  /chat → chat.html       │  │
  └─────────────────────────┘                │  └────────────┬─────────────┘  │
                                             │               │ loopback only  │
       not reachable from                    │  ┌────────────▼─────────────┐  │
       the public internet                   │  │ mlx_lm.server :8080      │  │
                                             │  │ OpenAI-compatible API    │  │
                                             │  └──────────────────────────┘  │
                                             └────────────────────────────────┘
```

Three things are worth understanding about this picture, because they carry
the security story.

**WireGuard does the heavy lifting.** Tailscale builds a mesh of WireGuard
tunnels between your devices. Each device has a cryptographic identity tied
to your login, and traffic between two devices is encrypted end to end,
whether they sit on the same Wi-Fi or on opposite sides of the planet. Your
phone on mobile data reaches the Mac through that tunnel, not through any
public address.

**`tailscale serve` adds a clean HTTPS front door.** The model server binds
to `127.0.0.1` and never listens on a routable interface. `tailscale serve`
terminates TLS (with a real certificate for your machine's
`mac-name.tailnet.ts.net` name, so browsers are happy) and proxies requests
to localhost. It only accepts connections arriving over the tailnet.

**The trust boundary is the tailnet, not the app.** There is deliberately no
password or API key in front of the model. Anything that can reach the
endpoint has already authenticated, as a device you enrolled, with keys
managed by Tailscale. Adding an app-level login here would protect against
exactly nobody who is not already inside your network. This is the part of
the design that does not survive contact with `tailscale funnel`, which is
why funnel must never be used for this; see
[the security note below](#serve-not-funnel).

## Prerequisites

- A Mac with Apple silicon (this was built on an M3 Pro with 36 GB of RAM;
  the default 3B model is comfortable on far less).
- [Tailscale](https://tailscale.com/download) installed and logged in on the
  Mac and on the devices you want to chat from, all in the same tailnet.
- MagicDNS and HTTPS certificates enabled for the tailnet. Both live in the
  [admin console](https://login.tailscale.com/admin/dns) under DNS: MagicDNS
  has a toggle, and HTTPS certificates an "Enable HTTPS" button.
- [uv](https://docs.astral.sh/uv/) for Python environment management. The
  project pins Python 3.12 (`mlx-lm` does not yet support 3.14); uv downloads
  it automatically if needed.
- `make` (ships with the Xcode command line tools).

Verify the Tailscale side before anything else:

```sh
tailscale status        # should list your devices, not "Logged out."
tailscale dns status    # should show MagicDNS enabled
```

If `tailscale` is not on your PATH, the macOS app bundles the same CLI at
`/Applications/Tailscale.app/Contents/MacOS/Tailscale`. The helper scripts in
this repository try both.

## Step 1: run the model locally

```sh
git clone https://github.com/leriomaggio/private-llm-tailnet.git
cd private-llm-tailnet
make setup    # uv sync: installs mlx-lm into .venv
make start    # starts mlx_lm.server on http://localhost:8080
```

`make start` launches the server in the background, with logs and a PID file
under `.run/`. On first run it downloads the default model,
[`mlx-community/Llama-3.2-3B-Instruct-4bit`](https://huggingface.co/mlx-community/Llama-3.2-3B-Instruct-4bit)
(about 1.8 GB), into the Hugging Face cache; the script waits until the API
answers. One behaviour worth knowing: the server starts responding to
`/v1/models` while weights are still downloading, but a chat completion
request will simply block until the model is ready. Patience, not panic.

Verify with curl:

```sh
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "Say hello."}], "max_tokens": 50}'
```

You should get back a JSON chat completion with the model's reply. The API is
OpenAI-compatible, so anything that speaks that dialect (SDKs, other clients)
works against it unchanged.

The model is a variable, not a commitment. Any MLX-converted model from the
[mlx-community](https://huggingface.co/mlx-community) organisation works:

```sh
MODEL=mlx-community/Mistral-7B-Instruct-v0.3-4bit make start
```

## Step 2: expose it on the tailnet

```sh
make serve
```

This runs the model server if it is not already up, then configures
`tailscale serve` with two mounts on your machine's HTTPS hostname:

- `/` proxies to `http://localhost:8080`, so the API surface
  (`/v1/chat/completions`, `/v1/models`) keeps its natural paths;
- `/chat` serves `client/chat.html` as a static file, directly from
  tailscaled, with no separate web server involved.

The script prints the resulting URLs, which look like:

```
Chat client: https://mac-name.tailnet.ts.net/chat
API:         https://mac-name.tailnet.ts.net/v1/chat/completions
```

The first HTTPS request can take a few seconds longer while Tailscale obtains
a Let's Encrypt certificate for the machine's name. `tailscale serve status`
shows the active configuration at any time, and `make unserve` clears it
(serve configuration persists across reboots until you reset it, which is
easy to forget).

> **Status note.** Everything up to here is verified on the machine this was
> built on. The serve layer and the phone path below are written from the
> Tailscale documentation and will be re-verified end to end; this note
> disappears when that is done.

## Step 3: use it from your phone

On the phone: install Tailscale, log in to the same tailnet, make sure the
VPN toggle is on. Then open `https://mac-name.tailnet.ts.net/chat` in the
browser and start typing. It works the same on home Wi-Fi and on mobile data,
because in both cases the traffic rides the WireGuard tunnel to the Mac.

The client is a single HTML file with no dependencies. It streams tokens as
the model produces them, keeps the conversation in memory (nothing is stored
anywhere), and defaults its API endpoint to the origin it was served from,
which is exactly right when it is served by the same `tailscale serve`
hostname as the API. The settings panel lets you point it at a different
endpoint or model; settings persist in the URL hash, so a bookmark captures
them and nothing is written to browser storage.

## Serve, not funnel

Tailscale has two superficially similar commands and the entire security
model of this project lives in the difference between them.

`tailscale serve` publishes a service **to your tailnet only**. The TLS
endpoint is reachable exclusively over the WireGuard mesh, by devices you
have enrolled. From the public internet, nothing is listening.

`tailscale funnel` publishes a service **to the public internet**, routed
through Tailscale's infrastructure. It exists for the cases where you
genuinely want strangers to reach your machine: a webhook receiver, a quick
demo for a colleague without Tailscale.

For a personal LLM the distinction is not subtle. This setup has no
authentication of its own, on purpose, because the tailnet provides it.
Swap `serve` for `funnel` and that reasoning inverts: you would be offering
free, anonymous compute, plus your conversation contents, to anyone who finds
the URL. One word in one command is the whole boundary, which is exactly why
it deserves this prominent a warning. Nothing in this repository uses funnel,
and `make serve` never will.

## Alternative: Ollama instead of MLX

If you already run [Ollama](https://ollama.com), you can keep it and skip the
MLX setup entirely; it exposes the same OpenAI-compatible API surface.

```sh
ollama pull llama3.2:3b
OLLAMA_ORIGINS="https://mac-name.tailnet.ts.net" ollama serve
PORT=11434 ./scripts/serve-tailnet.sh
```

The `OLLAMA_ORIGINS` variable is the one piece of friction worth flagging:
Ollama validates the `Host` and `Origin` headers of incoming requests and, by
default, rejects browser requests that do not look like they came from
localhost. Behind the `tailscale serve` proxy, requests arrive with your
`ts.net` hostname in those headers, so Ollama must be told to accept that
origin (use `OLLAMA_ORIGINS="*"` if you would rather not pin the name). If
you see 403 responses from the API while curl against
`http://localhost:11434` works fine, this is almost certainly the cause.

> **Status note.** The Ollama path is documented from Ollama's own
> documentation and known community reports; it has not yet been exercised on
> this machine. TODO: verify and record the exact failure mode in NOTES.md.

## Make targets

```
make setup     install Python dependencies (uv sync)
make start     start the model server on localhost
make stop      stop the model server
make serve     start the model server and expose it on the tailnet
make unserve   clear the tailscale serve configuration
make down      stop the server and clear serve config
make status    show server and serve state
make logs      tail the model server log
```

`MODEL` and `PORT` are honoured by all of them, for example
`MODEL=mlx-community/Mistral-7B-Instruct-v0.3-4bit PORT=8081 make serve`.

## Troubleshooting

**`tailscale status` says "Logged out."** The daemon is running but the node
is not authenticated. Log in from the Tailscale menu bar icon, or
`tailscale login`. This happened on the machine this was built on, with the
app running and the system extension loaded, so it is not a hypothetical.

**Chat completions hang on first use.** Almost always the model download:
weights fetch on the first request for a given model, and the request blocks
until they are in. `make logs` shows the download progress.

**`https://mac-name.tailnet.ts.net` does not resolve.** Check MagicDNS is
enabled (`tailscale dns status`, or the DNS page of the admin console) and
that you are using the full name including the tailnet domain,
`tailscale status --json | grep DNSName` prints it.

**Certificate errors in the browser.** HTTPS certificates must be enabled
once per tailnet, in the admin console under DNS. The first request after
`make serve` can also be slow while the certificate is issued; reload once
rather than assuming failure.

**The phone cannot reach the Mac.** Confirm the Tailscale VPN toggle is on,
and that both devices appear in `tailscale status`. The Mac must be awake;
a sleeping laptop serves no completions (see next steps below).

**Port 8080 is taken.** `PORT=8081 make serve`.

**`uv sync` fails on Python version.** The project pins 3.12 in
`.python-version` because `mlx-lm` does not support 3.14 yet; uv normally
downloads the pinned interpreter automatically.

## Next steps

The natural evolution, kept out of scope here, is moving the model server to
an always-on machine (a Mac mini in a cupboard is the classic choice) so the
service does not depend on a laptop lid being open. Nothing about the setup
changes except the machine name in the URL. Tailscale-side improvements worth
exploring: an ACL that restricts which of your devices may reach the model
port, and [Tailscale SSH](https://tailscale.com/kb/1193/tailscale-ssh) for
administering the host from the same phone that chats with it.

## Licence

[MIT](LICENSE), Valerio Maggio.

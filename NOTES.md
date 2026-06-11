# Developer experience log

A running, unpolished record of building this project: friction points,
pleasant surprises and documentation gaps, in the order they happened.
Raw material for a future write-up, not marketing copy.

Format per entry: date, what I was doing, what happened, what I expected.

---

## 2026-06-11 — Project setup

**Tailscale CLI vs the macOS app.** First friction before writing a line of
code: `tailscale status` on the Mac reported "Logged out" even though the
Tailscale app was installed, running, and the system extension loaded. There
are two CLI entry points on macOS (a standalone binary in `/usr/local/bin`
and one bundled inside `Tailscale.app`), and it was not obvious which daemon
either talks to. In this case both agreed the node was logged out; the fix
was simply logging in again from the menu bar. Worth a clearer error, or a
hint in the CLI output about the GUI app's state.

**Python version pinning.** `mlx-lm` does not yet support Python 3.14 (my
pyenv default), so the project pins 3.12 via `.python-version`. `uv` handled
this without drama: one line in the file, `uv sync`, done. Pleasant surprise.

**Model download visibility.** `mlx_lm.server` starts answering
`/v1/models` while the weights are still downloading, but a chat completion
request just blocks silently until the download finishes. Fine once you know,
confusing the first time. The Hugging Face progress bar also renders poorly
when the server log goes to a file.

<!-- TODO(valerio): replace or extend the entries below; these are placeholders -->

## YYYY-MM-DD — First end-to-end run on the tailnet

*Placeholder: what `tailscale serve` setup felt like, whether the path-mount
behaviour matched expectations, anything surprising in the admin console.*

## YYYY-MM-DD — First use from the phone

*Placeholder: latency on mobile data, certificate behaviour in iOS Safari,
keyboard/safe-area quirks in the chat client.*

## YYYY-MM-DD — Ollama alternative path

*Placeholder: the `OLLAMA_ORIGINS` Host-header friction in practice, how the
error manifests, what fixed it.*

## Doc gaps noticed along the way

*Placeholder: list of places where Tailscale or MLX docs left questions open.*

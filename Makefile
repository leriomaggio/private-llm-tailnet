# Private LLM over Tailscale. `make serve` brings the whole demo up.
# Override defaults per invocation, e.g.:
#   MODEL=mlx-community/Mistral-7B-Instruct-v0.3-4bit make serve

.PHONY: setup start stop serve unserve down status logs

setup:            ## Install Python dependencies with uv
	uv sync

start:            ## Start the local model server
	./scripts/start-model.sh

stop:             ## Stop the local model server
	./scripts/stop-model.sh

serve: start      ## Start the model server and expose it on the tailnet
	./scripts/serve-tailnet.sh

unserve:          ## Clear the tailscale serve config (model server keeps running)
	./scripts/unserve-tailnet.sh

down: stop unserve ## Stop everything

status:           ## Show model server and tailscale serve state
	@if [ -f .run/mlx-server.pid ] && kill -0 $$(cat .run/mlx-server.pid) 2>/dev/null; then \
		echo "Model server: running (pid $$(cat .run/mlx-server.pid))"; \
	else \
		echo "Model server: not running"; \
	fi
	@tailscale serve status 2>/dev/null || /Applications/Tailscale.app/Contents/MacOS/Tailscale serve status

logs:             ## Tail the model server log
	tail -f .run/mlx-server.log

#!/usr/bin/env bash
set -euo pipefail

pids=()

stop() {
  if ((${#pids[@]})); then
    kill -s TERM "${pids[@]}" 2>/dev/null || true
    wait "${pids[@]}" 2>/dev/null || true
  fi
  exit "$1"
}

fail() {
  kill "${pids[@]}" 2>/dev/null || true
  exit 1
}

alive() {
  local pid
  for pid in "${pids[@]}"; do
    kill -0 "$pid" 2>/dev/null || return 1
  done
}

poll() {
  until python3 -c 'import os, sys, urllib.request; t = os.environ.get("SHIM_TOKEN"); r = urllib.request.Request(sys.argv[1], headers={"Authorization": "Bearer " + t} if t else {}); sys.exit(urllib.request.urlopen(r, timeout=5).status != 200)' "$1" 2>/dev/null; do
    alive || fail
    sleep 5 &
    wait "$!"
  done
}

trap 'stop 143' TERM
trap 'stop 130' INT

rm -f /tmp/openjev-ready

python3 -c '
import os, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        if os.path.exists("/tmp/openjev-ready"):
            self.send_response(200)
            self.send_header("Content-Length", "0")
        else:
            self.send_response(204)
        self.end_headers()

    do_HEAD = do_GET

    def log_message(self, *args):
        pass

ThreadingHTTPServer(("0.0.0.0", int(sys.argv[1])), H).serve_forever()
' "$PORT_HEALTH" &
pids+=("$!")

vllm serve "$MODEL_NAME" --host 127.0.0.1 --port 8000 --served-model-name qwen --enable-prefix-caching --max-model-len 16384 --gpu-memory-utilization 0.90 --limit-mm-per-prompt '{"image":1}' --trust-remote-code --max-num-seqs 256 --max-logprobs 64 --gdn-prefill-backend triton &
pids+=("$!")

poll http://127.0.0.1:8000/health

PYTHONPATH=/app/deps python3 /app/shim.py --host 0.0.0.0 --port "$PORT" &
pids+=("$!")

poll "http://127.0.0.1:$PORT/v1/version"
touch /tmp/openjev-ready

if alive; then
  wait -n || true
fi
fail

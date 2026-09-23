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

trap 'stop 143' TERM
trap 'stop 130' INT

vllm serve "$MODEL_NAME" --host 127.0.0.1 --port 8000 --served-model-name qwen --enable-prefix-caching --max-model-len 16384 --gpu-memory-utilization 0.90 --limit-mm-per-prompt '{"image":1}' --trust-remote-code --max-num-seqs 256 --max-logprobs 64 --gdn-prefill-backend triton &
vllm_pid=$!
pids+=("$vllm_pid")

until python3 -c 'import sys, urllib.request; sys.exit(urllib.request.urlopen("http://127.0.0.1:8000/health", timeout=5).status != 200)' 2>/dev/null; do
  kill -0 "$vllm_pid" 2>/dev/null || exit 1
  sleep 5 &
  wait "$!"
done

python3 /app/shim.py --host 0.0.0.0 --port "$PORT" &
pids+=("$!")

if kill -0 "$vllm_pid" 2>/dev/null; then
  wait -n || true
fi
kill "${pids[@]}" 2>/dev/null || true
exit 1

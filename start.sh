#!/usr/bin/env bash
set -euo pipefail

python3 /app/shim.py --host 0.0.0.0 --port "$PORT" &
shim_pid=$!

vllm serve "$MODEL_NAME" --host 127.0.0.1 --port 8000 --served-model-name qwen --enable-prefix-caching --max-model-len 16384 --gpu-memory-utilization 0.90 --limit-mm-per-prompt '{"image":1}' --trust-remote-code --max-num-seqs 256 --max-logprobs 64 --gdn-prefill-backend triton &
vllm_pid=$!

wait -n || true
kill "$shim_pid" "$vllm_pid" 2>/dev/null || true
exit 1

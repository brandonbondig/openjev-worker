# openjev-worker

This image runs OpenJev's helper (`shim.py`, unmodified) next to vLLM 0.29.0 on one GPU worker, so the worker answers `POST /v1/systemone` like the reference serving box in the model's SERVE.md. It is built for a RunPod load-balancer endpoint and published as `ghcr.io/brandonbondig/openjev-worker`.

`start.sh` starts the helper, then vLLM, and exits with status 1 as soon as either process stops, so the container restarts instead of half-serving. vLLM runs with SERVE.md's flags:

```
vllm serve "$MODEL_NAME" --host 127.0.0.1 --port 8000 --served-model-name qwen --enable-prefix-caching --max-model-len 16384 --gpu-memory-utilization 0.90 --limit-mm-per-prompt '{"image":1}' --trust-remote-code --max-num-seqs 256 --max-logprobs 64 --gdn-prefill-backend triton
```

The helper runs as `python3 /app/shim.py --host 0.0.0.0 --port "$PORT"` with SERVE.md's knobs as image defaults: `VLLM=http://127.0.0.1:8000/v1`, `TOKENIZER=openjev/openjev-FP8`, `READOUT_T=0.85`, `READOUT_NOUL_T=1.829074`, `READOUT_NOUL_BIAS=0`, `READOUT_TARGETED=1`, `READOUT_INSTR_STYLE=pyrepr` and `SHIM_STAGGER=1`. Its client libraries are pinned to SERVE.md's versions, openai 3.16.2 and httpx 0.28.1, and the build fails unless the helper's sha256 is `81a22f1b1b8912a465059207ef9f60b7c6c16b4de6372305d867efbe38a1987a`.

There are two deviations from SERVE.md. The model is the FP8 checkpoint `openjev/openjev-FP8`, so `--quantization fp8` is dropped; SERVE.md instead applies online FP8 quantization to the bfloat16 weights. The helper's tokenizer uses the transformers version that ships in the vLLM 0.29.0 image instead of transformers 5.17.0.

## Running it

Every variable can be overridden at deploy time. `MODEL_NAME` is the Hugging Face model vLLM serves (default `openjev/openjev-FP8`); keep `TOKENIZER` in step with it. `SHIM_TOKEN` is optional: when it is set, every helper route requires `Authorization: Bearer <token>`, and on RunPod it can stay unset because the load balancer authenticates the public ingress. `HF_TOKEN`, if present, is used by both processes for Hugging Face downloads. `PORT` is the helper's port (default 3000). The readout knobs `READOUT_T`, `READOUT_NOUL_T`, `READOUT_NOUL_BIAS`, `READOUT_TARGETED`, `READOUT_INSTR_STYLE` and `SHIM_STAGGER` carry SERVE.md's measured values, and the model card's numbers only hold with them unchanged.

Port 3000 is the helper and the only exposed port. Port 8000 is vLLM, bound to loopback and reachable only from inside the container.

On a machine with an 80 GB or larger GPU:

```
docker run --gpus all -p 3000:3000 -e SHIM_TOKEN=... ghcr.io/brandonbondig/openjev-worker:latest
```

## Licence

The helper (`shim.py`) and `NOTICE` are Apache License 2.0, as are this repository's own files (see `LICENSE`). The OpenJev weights are CC BY-NC 4.0 and are not in the image; vLLM downloads them from Hugging Face at start-up.

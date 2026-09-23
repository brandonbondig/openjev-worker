#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/brandonbondig/openjev-worker}"
BASE="${BASE:-vllm/vllm-openai@sha256:082ca6f035279109041ffd3fe0695cb568b29bc580b35c4f297a66a08b216c1b}"
TAG="${TAG:-$(git rev-parse --short HEAD)}"

STAGE="$(mktemp -d)"
mkdir -p "$STAGE/app"
cp shim.py start.sh NOTICE "$STAGE/app/"
chmod +x "$STAGE/app/start.sh"
echo "81a22f1b1b8912a465059207ef9f60b7c6c16b4de6372305d867efbe38a1987a  $STAGE/app/shim.py" | sha256sum -c -

pip install --no-cache-dir --target "$STAGE/app/deps" --python-version 3.12 --platform manylinux2014_x86_64 --implementation cp --abi cp312 --only-binary=:all: "openai==3.16.2" "httpx==0.28.1"

tar -C "$STAGE" -cf "$STAGE/layer.tar" app

crane append -b "$BASE" -f "$STAGE/layer.tar" -t "$IMAGE:$TAG"

crane mutate "$IMAGE:$TAG" \
  --entrypoint /app/start.sh \
  --cmd "" \
  --workdir /vllm-workspace \
  --exposed-ports 3000 \
  --label org.opencontainers.image.source=https://github.com/brandonbondig/openjev-worker \
  --env MODEL_NAME=openjev/openjev-FP8 \
  --env VLLM=http://127.0.0.1:8000/v1 \
  --env TOKENIZER=openjev/openjev-FP8 \
  --env READOUT_T=0.85 \
  --env READOUT_NOUL_T=1.829074 \
  --env READOUT_NOUL_BIAS=0 \
  --env READOUT_TARGETED=1 \
  --env READOUT_INSTR_STYLE=pyrepr \
  --env SHIM_STAGGER=1 \
  --env PORT=3000 \
  -t "$IMAGE:$TAG"

crane tag "$IMAGE:$TAG" latest
crane digest "$IMAGE:$TAG"

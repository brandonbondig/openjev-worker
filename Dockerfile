FROM vllm/vllm-openai:v0.29.0

RUN pip install --no-cache-dir "openai==3.16.2" "httpx==0.28.1"

COPY shim.py start.sh NOTICE /app/

RUN chmod +x /app/start.sh

RUN echo "81a22f1b1b8912a465059207ef9f60b7c6c16b4de6372305d867efbe38a1987a  /app/shim.py" | sha256sum -c -

ENV MODEL_NAME=openjev/openjev-FP8 \
    VLLM=http://127.0.0.1:8000/v1 \
    TOKENIZER=openjev/openjev-FP8 \
    READOUT_T=0.85 \
    READOUT_NOUL_T=1.829074 \
    READOUT_NOUL_BIAS=0 \
    READOUT_TARGETED=1 \
    READOUT_INSTR_STYLE=pyrepr \
    SHIM_STAGGER=1 \
    PORT=3000

EXPOSE 3000

ENTRYPOINT ["/app/start.sh"]

#!/bin/bash
set -e

MODEL_PATH="${MODEL_PATH:-/app/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf}"
THREADS="${THREADS:-4}"
CTX_SIZE="${CTX_SIZE:-2048}"
N_PREDICT="${N_PREDICT:-4096}"
TEMPERATURE="${TEMPERATURE:-0.8}"
PORT="${PORT:-8080}"
MODE="${1:-server}"

case "$MODE" in
  server)
    exec python3 /app/run_inference_server.py \
      -m "$MODEL_PATH" \
      -t "$THREADS" \
      -c "$CTX_SIZE" \
      -n "$N_PREDICT" \
      --temperature "$TEMPERATURE" \
      --host 0.0.0.0 \
      --port "$PORT"
    ;;
  cli)
    shift
    exec python3 /app/run_inference.py \
      -m "$MODEL_PATH" \
      -t "$THREADS" \
      -c "$CTX_SIZE" \
      --temperature "$TEMPERATURE" \
      "$@"
    ;;
  *)
    exec "$@"
    ;;
esac

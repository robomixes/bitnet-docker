# BitNet Docker — Run Microsoft's 1-Bit LLM in One Command

A fully self-contained Docker setup for running [Microsoft's BitNet](https://github.com/microsoft/BitNet) locally. No compilers, no Python environments, no manual setup — just Docker.

The container clones BitNet, compiles it from source, downloads the model, and packages everything into a portable image. One command to build, one command to run.

---

## Prerequisites

Only one thing needed:

- [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) installed and running

## Quick Start

```bash
git clone https://github.com/robomixes/bitnet-docker.git
cd bitnet-docker
docker compose build
docker compose up -d
```

The first build takes ~15-20 minutes (compiles BitNet + downloads the 1.1 GB model). After that, starts instantly.

## Quick Commands

**Start the server:**
```bash
docker compose up -d
```

**Check if it's running:**
```bash
curl http://localhost:8080/health
# Returns: {"status":"ok"}
```

**Open the web UI:**

Visit [http://localhost:8080](http://localhost:8080) in your browser — it has a built-in chat interface.

**Send a prompt via API:**
```bash
curl http://localhost:8080/completion -H "Content-Type: application/json" -d '{"prompt": "What is machine learning?", "n_predict": 100}'
```

**Run CLI mode (one-off prompt):**
```bash
docker compose run --rm bitnet cli -p "Hello, how are you?" -n 100
```

**Stop the server:**
```bash
docker compose down
```

## Take It Anywhere (Fully Offline)

Export the image to a file:

```bash
docker save bitnet-llm:2b-4t -o bitnet-portable.tar
```

Load it on any other machine with Docker:

```bash
docker load -i bitnet-portable.tar
docker compose up -d
```

No internet required after export.

## Configuration

Adjust settings via environment variables in `docker-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `THREADS` | `4` | CPU threads for inference |
| `CTX_SIZE` | `2048` | Context window size |
| `N_PREDICT` | `4096` | Max tokens to generate |
| `TEMPERATURE` | `0.8` | Sampling temperature |

## What's Inside

| Property | Value |
|----------|-------|
| Base image | Ubuntu 22.04 |
| Compiler | Clang 18 (installed during build) |
| Model | BitNet b1.58-2B-4T (2.4B parameters) |
| Model format | GGUF (i2_s quantization) |
| Image size | ~2.4 GB |
| Port | 8080 |
| Inference speed | ~28 tokens/sec |

## How It Works

The Dockerfile uses a **multi-stage build**:

1. **Builder stage** — Clones BitNet from GitHub, installs Clang 18, generates optimized x86 kernels, compiles the inference engine, and downloads the pre-built GGUF model from HuggingFace
2. **Runtime stage** — Copies only the compiled binaries and the model into a minimal Ubuntu image (~2.4 GB total)

The entrypoint supports two modes:
- `server` (default) — Starts an HTTP server on port 8080 with a web UI
- `cli` — Runs a single prompt from the command line

## What is BitNet?

BitNet is Microsoft's open-source framework for running **1.58-bit large language models** on standard hardware. Each model weight is either -1, 0, or 1, which dramatically reduces memory and computation:

- **~10x less memory** than standard models of the same size
- **55-82% less energy** consumption
- **Fast CPU inference** — no GPU required
- **100% offline** — no cloud, no API calls, no data leaving your machine

## Limitations

- **Inference only** — no fine-tuning or training on your own data
- **No RAG support** — cannot use your own documents for context
- **CPU only** — no GPU acceleration (by design)
- **Small model** — 2B parameters, suitable for basic Q&A and text generation
- **Limited model selection** — only two official models available (2B and 4B)

For features like RAG, fine-tuning, or larger models, consider tools like [Ollama](https://ollama.com/), [LM Studio](https://lmstudio.ai/), or [PrivateGPT](https://github.com/zylon-ai/private-gpt).

## License

BitNet is released under the [MIT License](https://github.com/microsoft/BitNet/blob/main/LICENSE) by Microsoft.

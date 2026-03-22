# ============================================
# Stage 1: Build BitNet from source
# ============================================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    clang \
    cmake \
    build-essential \
    python3 \
    python3-pip \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy source code
COPY 3rdparty/ 3rdparty/
COPY src/ src/
COPY include/ include/
COPY utils/ utils/
COPY preset_kernels/ preset_kernels/
COPY gpu/ gpu/
COPY CMakeLists.txt .
COPY requirements.txt .
COPY setup_env.py .
COPY run_inference.py .
COPY run_inference_server.py .

# Install gguf Python package (needed for codegen)
RUN pip3 install --no-cache-dir 3rdparty/llama.cpp/gguf-py

# Generate x86_64 TL2 kernels for BitNet-b1.58-2B-4T
RUN python3 utils/codegen_tl2.py \
    --model bitnet_b1_58-3B \
    --BM 160,320,320 \
    --BK 96,96,96 \
    --bm 32,32,32

# CMake configure and build
RUN cmake -B build \
    -DBITNET_X86_TL2=OFF \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    && cmake --build build --config Release

# ============================================
# Stage 2: Minimal runtime image
# ============================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled binaries from builder
COPY --from=builder /build/build/bin/ ./build/bin/
# Copy shared libraries (libllama.so, libggml.so, etc.)
COPY --from=builder /build/build/3rdparty/llama.cpp/src/libllama.so ./build/bin/
COPY --from=builder /build/build/3rdparty/llama.cpp/ggml/src/libggml.so ./build/bin/

# Copy Python scripts
COPY run_inference.py run_inference_server.py ./

# Copy the pre-built GGUF model
COPY models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf \
     ./models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf

# Copy entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set library path in case of shared libs
ENV LD_LIBRARY_PATH=/app/build/bin
ENV MODEL_PATH=/app/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf

EXPOSE 8080

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]

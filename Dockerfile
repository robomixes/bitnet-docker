# ============================================
# Stage 1: Build BitNet from source
# ============================================
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    build-essential \
    python3 \
    python3-pip \
    git \
    wget \
    software-properties-common \
    gnupg \
    && wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc \
    && echo "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-18 main" > /etc/apt/sources.list.d/llvm.list \
    && apt-get update && apt-get install -y --no-install-recommends clang-18 \
    && ln -s /usr/bin/clang-18 /usr/bin/clang && ln -s /usr/bin/clang++-18 /usr/bin/clang++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone BitNet and its submodules
RUN git clone --recursive https://github.com/microsoft/BitNet.git .

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

# Download the model
RUN pip3 install --no-cache-dir huggingface_hub && \
    python3 -c "from huggingface_hub import snapshot_download; snapshot_download('microsoft/BitNet-b1.58-2B-4T', local_dir='models/BitNet-b1.58-2B-4T')"

# Convert model to GGUF format
RUN python3 -m pip install --no-cache-dir -r requirements.txt && \
    python3 utils/convert-hf-to-gguf-bitnet.py models/BitNet-b1.58-2B-4T --outtype f32 && \
    ./build/bin/llama-quantize models/BitNet-b1.58-2B-4T/ggml-model-f32.gguf \
    models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf I2_S 1

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
# Copy shared libraries (libllama.so, libggml.so)
COPY --from=builder /build/build/3rdparty/llama.cpp/src/libllama.so ./build/bin/
COPY --from=builder /build/build/3rdparty/llama.cpp/ggml/src/libggml.so ./build/bin/

# Copy Python scripts
COPY --from=builder /build/run_inference.py /build/run_inference_server.py ./

# Copy the GGUF model
COPY --from=builder /build/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf \
     ./models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf

# Copy entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set library path
ENV LD_LIBRARY_PATH=/app/build/bin
ENV MODEL_PATH=/app/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf

EXPOSE 8080

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]

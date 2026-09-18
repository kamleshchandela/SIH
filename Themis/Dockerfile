# Multi-stage Docker build for Themis Legal Metrology Compliance Engine
# Stage 1: Build binary with cached Rust dependencies
FROM rust:slim-bookworm AS builder

WORKDIR /usr/src/themis

# Install build prerequisites for C++ & OpenMP (required for ONNX Runtime linking)
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy cargo manifest and lockfile
COPY themis/Cargo.toml themis/Cargo.lock ./

# Create dummy src to cache dependencies
RUN mkdir src && touch src/lib.rs && echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Copy real source code
COPY themis/src ./src

# Build production binary with strip and thin LTO
RUN touch src/main.rs && cargo build --release

# Stage 2: Minimal runtime image
FROM debian:bookworm-slim AS runner

WORKDIR /app

# Install runtime dependencies: OpenMP, SSL certificates, curl for healthchecks
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-privileged system user
RUN useradd -u 10001 -m themisuser

# Copy stripped binary from builder
COPY --from=builder /usr/src/themis/target/release/themis /app/themis

# Copy ONNX OCR models
COPY themis/models /app/models

# Create storage directories and set permissions
RUN mkdir -p /app/data && chown -R themisuser:themisuser /app

# Default models volume mount
VOLUME ["/app/models", "/app/data"]

USER themisuser

# Default configuration
ENV PORT=8080
ENV THEMIS_DETERMINISTIC=1
ENV RUST_LOG="themis=info,ort=error"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/api/v1/health || exit 1

ENTRYPOINT ["/app/themis"]
CMD ["--models-dir", "/app/models"]

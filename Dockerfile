# ==============================================================================
# Soup Runtime for Akamai Connected Cloud (Linode Dedicated GPUs)
# Optimized for NVIDIA RTX 4000 Ada Generation (20GB) & L40S (48GB) [Ada Lovelace sm_89]
# ==============================================================================

FROM nvidia/cuda:12.8.2-runtime-ubuntu24.04

# Environment Configuration
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:${PATH}" \
    TORCH_CUDA_ARCH_LIST="8.9;9.0" \
    CUDA_DEVICE_ORDER=PCI_BUS_ID \
    HF_HOME=/mnt/soup-storage/cache/huggingface \
    SOUP_CACHE_DIR=/mnt/soup-storage/cache/soup

# Install OS prerequisites & Python 3.12
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-dev \
    python3-venv \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Setup virtual environment and verify Python version (3.11-3.13 supported by soup-cli)
RUN python3 -m venv "${VIRTUAL_ENV}" \
    && python -c "import sys; assert (3, 11) <= sys.version_info[:2] < (3, 14), 'soup-cli requires Python 3.11-3.13'"

WORKDIR /workspace

# Install Soup CLI with full training, serving, data, and evaluation stacks
ARG SOUP_VERSION=0.77.1
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir "soup-cli[train,serve,data,eval]==${SOUP_VERSION}"

# Validate installation and binary accessibility
RUN command -v soup \
    && soup --version

# Entrypoint configuration
ENTRYPOINT ["soup"]
CMD ["--help"]

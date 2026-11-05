#!/usr/bin/env bash
# ==============================================================================
# Soup on Akamai Connected Cloud (Linode) - 1-Click Bootstrap Script
# Target: Ubuntu 24.04 LTS / 22.04 LTS on Akamai GPU Instances (RTX 4000 Ada / L40S)
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo " [Soup] Initializing Akamai Linode GPU Environment Bootstrap"
echo "============================================================"

# Ensure root execution
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root (use sudo)." >&2
   exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "==> Step 1: Updating system packages and kernel headers..."
apt-get update -y
apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    ca-certificates \
    lsb-release \
    git \
    linux-headers-"$(uname -r)"

echo "==> Step 2: Checking / Installing NVIDIA Drivers..."
if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA driver already detected:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
else
    echo "Installing NVIDIA 550 Server Driver..."
    apt-get install -y --no-install-recommends nvidia-driver-550-server
    echo "NVIDIA driver installed. (Note: A system reboot may be required if modules fail to load)."
fi

echo "==> Step 3: Installing Docker Engine..."
if ! command -v docker &> /dev/null; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    echo "Docker installed successfully."
else
    echo "Docker already installed."
fi

echo "==> Step 4: Installing NVIDIA Container Toolkit..."
if ! dpkg -s nvidia-container-toolkit &> /dev/null; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg --yes
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    apt-get update -y
    apt-get install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
    echo "NVIDIA Container Toolkit configured and Docker restarted."
else
    echo "NVIDIA Container Toolkit already installed."
fi

echo "==> Step 5: Setting up persistent storage directories..."
mkdir -p /mnt/soup-storage/cache/huggingface
mkdir -p /mnt/soup-storage/data
mkdir -p /mnt/soup-storage/checkpoints
chmod -R 777 /mnt/soup-storage

echo "==> Step 6: Validating Docker GPU Pass-through..."
if docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi > /dev/null 2>&1; then
    echo "SUCCESS: Docker GPU pass-through is active and functional!"
    docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    echo "Warning: Direct GPU check failed. A quick reboot ('sudo reboot') may be required to initialize NVIDIA kernel modules."
fi

echo "============================================================"
echo " [Soup] Akamai Linode GPU Host is ready for Soup!"
echo " Run: docker compose up -d"
echo "============================================================"

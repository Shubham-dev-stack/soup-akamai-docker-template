# Soup on Akamai Connected Cloud (Linode) — 1-Click Starter Template

Production Docker deployment template and automated bootstrap guide for running **Soup** fine-tuning and inference on **Akamai Connected Cloud (Linode)** Dedicated GPU instances.

---

## Architecture & Hardware Context

- **Target Instance:** Akamai Linode Dedicated GPU (`g6-gpu-rtx4000a-1`)
  - **GPU:** NVIDIA RTX 4000 Ada Generation (20 GB GDDR6, Ada Lovelace `sm_89`)
  - **vCPU:** 8 Dedicated Cores | **RAM:** 32 GB System Memory | **Storage:** 640 GB SSD
  - **Price:** **\$0.52 / hr** (or \$350 / mo)
- **Why Soup on Akamai:**
  Standard PyTorch / Transformers setups frequently run into Out-Of-Memory (OOM) errors during full-context 8B fine-tuning on sub-24GB cards. Soup's native layer-streaming engine (`stream_layers: true`) streams model layers dynamically from pinned system memory, keeping active VRAM consumption under **4.8 GB**. This enables cost-effective Llama-3.1-8B and Qwen-2.5-7B fine-tuning at **98% lower cost** than AWS H100s (\$1.04 vs \$75+).

---

## Directory Structure

```text
soup-akamai-template/
├── setup-akamai.sh              # 1-Click host bootstrap (NVIDIA driver + Docker + Container Toolkit)
├── Dockerfile                   # CUDA 12.8 + Python 3.12 + soup-cli[train,serve,data,eval]
├── docker-compose.yml           # Multi-mount persistent compose configuration
├── configs/
│   └── soup-llama3-akamai.yaml  # Ready-to-run Llama-3.1-8B recipe with layer streaming
├── data/
│   └── train.jsonl              # Sample Alpaca training fixture for immediate verification
└── README.md                    # Setup documentation & operational guide
```

---

## Quick Start (3 Steps)

### Step 1: Spin up an Akamai Linode GPU Instance
1. In Cloud Manager, select **Linodes** > **Create Linode**.
2. Select **Dedicated GPU** > **RTX 4000 Ada 1-GPU** (or **L40S**).
3. Image: **Ubuntu 24.04 LTS** (or Ubuntu 22.04 LTS).
4. (Optional) Attach a Linode Block Storage volume formatted to `/mnt/soup-storage` for long-term checkpoint retention.

---

### Step 2: Run 1-Click Host Bootstrap
SSH into your instance and run `setup-akamai.sh`:

```bash
# Clone or upload the template to your instance
git clone https://github.com/Shubham-dev-stack/soup-akamai-docker-template.git /opt/soup-akamai
cd /opt/soup-akamai

# Run automated host initialization (installs drivers, Docker & NVIDIA runtime)
sudo bash setup-akamai.sh
```

The script automatically:
- Installs matching NVIDIA 550 Server drivers and kernel headers.
- Configures Docker CE and the NVIDIA Container Toolkit (`nvidia-ctk`).
- Configures `/etc/docker/daemon.json` with the default `nvidia` runtime.
- Creates persistent directories under `/mnt/soup-storage` (HF cache, data, checkpoints).
- Runs a test CUDA container to verify GPU pass-through.

---

### Step 3: Launch Soup & Start Fine-Tuning

1. **Set your Hugging Face Access Token** (required for gated weights like Llama-3.1):
   ```bash
   export HF_TOKEN="hf_your_token_here"
   ```

2. **Verify GPU environment with Soup Doctor:**
   ```bash
   docker compose run --rm soup doctor
   ```

3. **Launch Layer-Streaming Training:**
   ```bash
   docker compose run --rm soup train --config /workspace/configs/soup-llama3-akamai.yaml
   ```

---

## Storage & Caching Model

To avoid re-downloading model weights (16 GB for Llama-3.1-8B) on container restarts, host volumes are pre-mapped:

| Host Directory | Container Path | Purpose |
| :--- | :--- | :--- |
| `/mnt/soup-storage/cache/huggingface` | `/mnt/soup-storage/cache/huggingface` | Persistent HuggingFace model weight cache |
| `/mnt/soup-storage/data` | `/workspace/data` | Local dataset JSONL fixtures |
| `/mnt/soup-storage/checkpoints` | `/workspace/checkpoints` | Output adapter weights and training logs |

---

## Layer-Streaming Configuration Details

In `configs/soup-llama3-akamai.yaml`:
```yaml
base: meta-llama/Llama-3.1-8B-Instruct
task: sft
backend: transformers

training:
  epochs: 3
  lr: 2e-4
  batch_size: 2
  gradient_accumulation_steps: 4
  stream_layers: true     # Activates layer streaming; keeps active VRAM < 4.8 GB
  lora:
    r: 16
    alpha: 32
```
Soup automatically coordinates pinned host RAM and streams individual layer blocks into the RTX 4000 Ada GPU, avoiding high peak memory allocations.

---

## Operational Monitoring

Monitor real-time GPU allocation on the host:
```bash
watch -n 1 nvidia-smi
```
Expected metric on RTX 4000 Ada:
- **Allocated VRAM:** ~4.2 GB – 4.8 GB (stable throughout full training run)
- **Host RAM utilization:** ~22 GB (holding model weights in pinned system memory)

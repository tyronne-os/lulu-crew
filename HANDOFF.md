# Beryl Engine – Handoff Document (generated 2026-10-29)

## Project Overview
Beryl Engine for Digital Humans – a local, self-hosted AI companion platform built on OpenCode v1, running in WSL on a Windows 11 laptop with 8 GB RAM / AMD Radeon iGPU.

## Current State
- **OpenCode v1.19.5** running in WSL (port 4096 via auth-proxy → 4097 upstream)
- **Ngrok tunnels**: web→4097, hall→4097, gpu→11434
- **/api/health → 200** (4 companions, 137 reflections, 10 models, router online)
- **Chrome auth-popup fix active** – no more sign-in popups
- **GitHub repo**: `https://github.com/tyronne-os/lulu-crew` (private, pushed)

## Models Currently Registered (local-staff)
| Model | Size | Backend | Uncensored? |
|-------|------|---------|-------------|
| local-staff/smoke-0.5b | 0.5B | llamacpp | No |
| local-staff/smoke-360m | 360M | llamacpp | No |
| local-staff/coder-1.5b | 1.5B | llamacpp | No |
| local-staff/coder-3b | 3B | llamacpp | No |
| local-staff/coder-14b | 14B | llamacpp | No (incomplete) |
| local-staff/realvis-xl-v5 | 3.5B | comfyui | N/A |
| local-staff/sdxl-base | 3.5B | comfyui | N/A |

## Models to Pull (Uncensored Brand Stack)

### Amanda – Small Conversational NSFW RP (GGUF, CPU/Kaggle)
```
Qwen3.5-text-9B-NSFW-RolePlay-Q4_K_M.gguf   → mradermacher/Qwen3.5-text-9B-NSFW-RP-RolePlay-GGUF
Huihui-Qwen3.5-9B-abliterated-GGUF           → huihui-ai/Huihui-Qwen3.5-9B-abliterated-GGUF
```

### Brand – Large Quality (GGUF, Azure V100 / Kaggle T4)
```
Qwen3.8-27B-Uncensored-GGUF                  → JonathanColetti/Qwen3.8-27B-Uncensored-GGUF
Huihui-Qwen3.6-35B-A3B-Uncensored-GGUF       → huihui-ai/Huihui-Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive
```

### Coder – Kick-Ass Lulu IDE Build (GGUF, Azure V100)
```
Qwen2.5-Coder-32B-Instruct-GGUF Q4_K_M       → bartowski/Qwen2.5-Coder-32B-Instruct-GGUF
Qwen2.5-Coder-14B-Instruct-GGUF Q4_K_M       → mradermacher/Qwen2.5-Coder-14B-Instruct-GGUF
```

### Diffusion – Max Realism for OnlyFans Pages
```
FLUX.1-dev                                     → black-forest-labs/FLUX.1-dev (12B)
Wan2.2-I2V-14B                                 → Wan-AI/Wan2.2-I2V-14B (image-to-video)
Stable Video Diffusion-XT                      → stabilityai/stable-video-diffusion-xt
```

### Voice – Uncensored Streaming (Grok-like)
```
Kokoro-82M ONNX                                → hexgrad/Kokoro-82M (already downloaded)
Qwen3-TTS-12Hz-1.7B-VoiceDesign              → Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign
Qwen3-Omni-30B-A3B-Instruct                  → Qwen/Qwen3-Omni-30B-A3B-Instruct (speech-to-speech realtime)
```

## Azure GPU Setup ($200 Credit)

### VM Specification
- **VM**: `Standard_NC6s_v3` (1x NVIDIA V100 16GB) – best $/hour value
- **Image**: Ubuntu 22.04
- **Location**: eastus
- **Estimated**: ~65 hours on $200 credit

### Deployment
```bash
# 1. Create resource group and VM
az group create --name lulu-rg --location eastus
az vm create \
  --resource-group lulu-rg \
  --name lulu-gpu-01 \
  --image Ubuntu2204 \
  --size Standard_NC6s_v3 \
  --admin-username trell \
  --ssh-key-values ~/.ssh/id_rsa.pub \
  --location eastus

# 2. Open required ports
for p in 80 443 8080 11434 4096 6006; do
  az vm open-port --port $p --resource-group lulu-rg --name lulu-gpu-01
done

# 3. Get VM IP
az vm show --resource-group lulu-rg --name lulu-gpu-01 -d --query publicIps -o tsv

# 4. SSH and run setup
ssh trell@<AZURE-IP> 'bash -s' < scripts/azure-vm-setup.sh
```

### GPU Rotation Strategy
| Backend | Models | Purpose |
|---------|--------|---------|
| Local (laptop CPU) | smoke-0.5b, smoke-360m | Fast CPU chat |
| Azure V100 16GB | Amanda 9B NSFW RP, Coder 32B | Conversational + IDE |
| Kaggle T4 via ngrok | Brand 35B, FLUX.1-dev | Quality + diffusion |
| HF free GPU | Overflow | When Azure/Kaggle full |

## Multi-GPU Router Integration
Update `~/.config/systemd/user/local-staff.service.d/env.conf`:
```
Environment=AZURE_GPU_URL=http://<AZURE-IP>:11434
Environment=KAGGLE_GPU_URL=http://<KAGGLE-NGROK>.ngrok-free.dev
Environment=HF_GPU_URL=https://<HF-SPACE>.hf.space
```

Then restart: `systemctl --user restart local-staff.service`

## Immediate Commands
```bash
# 1. Pull uncensored models (run locally or on Azure)
bash scripts/pull-models.sh

# 2. Create and configure Azure VM
bash scripts/azure-vm-setup.sh

# 3. Restart local-staff with new backend URLs
systemctl --user restart local-staff.service

# 4. Test Amanda model
curl http://127.0.0.1:8090/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"amanda-nsfw-9b","messages":[{"role":"user","content":"test"}]}'
```

## Not Building End-to-End Yet
Focus on: pull models → test Amanda → generate brand assets → set up Azure IDE → rotate GPUs. Build Lulu end-to-end after the model stack is proven.

## OneDrive 2TB Model Storage + Advanced Neocortex Memory
OneDrive path: `C:\Users\chant\OneDrive\` (rj spencer-jacques)

### Directory Structure
```
OneDrive/MahoganyHall/
├── Models/                    # All HF models synced here
│   ├── gguf/                  # GGUF language models (Amanda, Brand, Coder)
│   ├── checkpoints/           # Diffusion checkpoints (RealVis, FLUX, SD3.5)
│   ├── lora/                  # Trained LoRAs for brand consistency
│   ├── voice/                 # TTS voices (Kokoro ONNX, Piper)
│   ├── video/                 # Grok video frames for I2V training
│   └── diffusion/             # Diffusion model weights
├── Beryl Engine/
│   ├── 01-Portrait-Creator/   # Portrait generation pipeline
│   ├── 02-Voice-Suite/        # Voice agent pipeline
│   ├── 03-Beryl-Neurons/      # Neocortex neuron storage
│   ├── 04-Beryl-Nexus/        # Nexus integration
│   └── 05-Analytics-Pipeline/
│       └── experience-ledger/ # Per-staff JSONL experience logs
└── Hall/
    └── data/mahogany.db       # SQLite with neocortex tables
```

### Neocortex Tables (in mahogany.db)
| Table | Purpose |
|-------|---------|
| neocortex_likes | What she loves (hierarchical, weighted tree) |
| neocortex_dislikes | What she dislikes (separate branch, no polarity contamination) |
| neocortex_expression | Middle trunk: how she expresses (vocal/non-verbal/ritual) |
| neocortex_episodes | Episodic narrative memory (ENE) |
| neocortex_assessments | Member assessment scores & traits |
| neocortex_strategies | Conversion/retention strategy plans |
| neocortex_lifecycles | Her own life log between chats (human development) |

### Scripts
- `scripts/onedrive-models-organize.sh` - Syncs local models to OneDrive, creates directory structure, initializes neocortex tables

### Experience Ledger
Each staff member has a JSONL ledger at:
`OneDrive/MahoganyHall/Beryl Engine/05-Analytics-Pipeline/experience-ledger/<staff_id>.jsonl`

Replayable, append-only log of every experience for evolution cycles.
#!/bin/bash
# =============================================================================
# Azure VM Setup for Beryl Engine Lulu Build
# Target: Standard_NC6s_v3 (1x V100 16GB)
# =============================================================================
set -euo pipefail

echo "=== Updating system ==="
apt-get update && apt-get upgrade -y

echo "=== Installing NVIDIA drivers ==="
ubuntu-drivers install --gpgpu -y

echo "=== Installing Docker ==="
apt-get install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Installing NVIDIA Container Toolkit ==="
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/$(. /etc/os-release; echo $ID$VERSION_ID)/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
apt-get update
apt-get install -y nvidia-container-toolkit
systemctl restart docker

echo "=== Installing code-server (IDE) ==="
curl -fsSL https://code-server.dev/install.sh | sh
systemctl enable --now code-server@trell

echo "=== Installing Ollama ==="
curl -fsSL https://ollama.com/install.sh | sh
systemctl enable --now ollama

echo "=== Pulling uncensored models to Ollama ==="
ollama pull qwen2.5-coder:32b-instruct-q4_K_M || true
ollama pull qwen2.5-coder:14b-instruct-q4_K_M || true

echo "=== Installing llama.cpp ==="
git clone https://github.com/ggerganov/llama.cpp ~/llama.cpp 2>/dev/null || true
cd ~/llama.cpp && make -j$(nproc) LLAMA_CUDA=1 2>/dev/null || true

echo "=== Installing ComfyUI ==="
git clone https://github.com/comfyanonymous/ComfyUI ~/ComfyUI 2>/dev/null || true
cd ~/ComfyUI && pip install -r requirements.txt 2>/dev/null || true

echo "=== Downloading FLUX.1-dev ==="
mkdir -p ~/ComfyUI/models/checkpoints
cd ~/ComfyUI/models/checkpoints
wget -q https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors || true

echo "=== Setup complete ==="
echo "SSH: ssh trell@$(curl -s ifconfig.me)"
echo "code-server: https://$(curl -s ifconfig.me):8080"
echo "Ollama: http://$(curl -s ifconfig.me):11434"
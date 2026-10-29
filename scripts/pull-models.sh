#!/bin/bash
# =============================================================================
# Pull Uncensored Models for Beryl Engine / Lulu Build
# Run on Azure V100 or Kaggle T4
# =============================================================================
set -euo pipefail

MODEL_DIR="${HOME}/.local/share/local-staff/models"
mkdir -p "$MODEL_DIR"

echo "=== Amanda NSFW RP 9B (GGUF) ==="
# Primary: Qwen3.5-text-9B-NSFW-RP
wget -q --show-progress -O "$MODEL_DIR/Qwen3.5-text-9B-NSFW-RolePlay-Q4_K_M.gguf" \
  "https://huggingface.co/mradermacher/Qwen3.5-text-9B-NSFW-RP-RolePlay-GGUF/resolve/main/Qwen3.5-text-9B-NSFW-RP-RolePlay-Q4_K_M.gguf" || \
  wget -q --show-progress -O "$MODEL_DIR/Qwen3.5-text-9B-NSFW-RolePlay-Q4_K_M.gguf" \
  "https://huggingface.co/huihui-ai/Huihui-Qwen3.5-9B-abliterated-GGUF/resolve/main/Huihui-Qwen3.5-9B-abliterated-Q4_K_M.gguf"

echo "=== Brand Quality 35B (GGUF) ==="
wget -q --show-progress -O "$MODEL_DIR/Qwen3.6-35B-A3B-Uncensored-Q4_K_M.gguf" \
  "https://huggingface.co/huihui-ai/Huihui-Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive/resolve/main/Qwen3.6-35B-A3B-Uncensored-Q4_K_M.gguf" || \
  wget -q --show-progress -O "$MODEL_DIR/Qwen3.8-27B-Uncensored-Q4_K_M.gguf" \
  "https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF/resolve/main/Qwen3.8-27B-Uncensored-Q4_K_M.gguf"

echo "=== Coder 32B (GGUF) ==="
wget -q --show-progress -O "$MODEL_DIR/Qwen2.5-Coder-32B-Instruct-Q4_K_M.gguf" \
  "https://huggingface.co/bartowski/Qwen2.5-Coder-32B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-32B-Instruct-Q4_K_M.gguf"

echo "=== Coder 14B (GGUF) ==="
wget -q --show-progress -O "$MODEL_DIR/Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf" \
  "https://huggingface.co/mradermacher/Qwen2.5-Coder-14B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf"

echo "=== Model pull complete ==="
ls -lh "$MODEL_DIR"/*.gguf
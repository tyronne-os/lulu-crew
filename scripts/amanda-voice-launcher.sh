#!/bin/bash
# =============================================================================
# Amanda Streaming Voice Agent Launcher
# Run locally: bash scripts/amanda-voice-launcher.sh
# =============================================================================
set -euo pipefail

HALL=/mnt/c/Users/chant/OneDrive/MahoganyHall
VENV=/home/trell/.local/share/mahogany-hall/venv

cd "$HALL"

echo "=== Checking llama.cpp router (port 8090) ==="
if ! curl -s -m 3 http://127.0.0.1:8090/v1/models > /dev/null 2>&1; then
  echo "Starting llama.cpp router..."
  bash scripts/local-staff-router.sh &  # if you have one
  sleep 5
fi

echo "=== Checking Amanda model registered ==="
# Amanda model should be in beryl_staff + local-staff-models.json
# Pull if missing
if [ ! -f "$HOME/.local/share/local-staff/models/Qwen3.5-text-9B-NSFW-RolePlay-Q4_K_M.gguf" ]; then
  echo "Amanda GGUF not found locally. Pulling..."
  bash scripts/pull-models.sh || true
fi

echo "=== Starting Amanda Voice Agent (port 8101) ==="
"$VENV/bin/python" scripts/amanda-voice-agent.py &
AMANDA_PID=$!
sleep 3

echo "=== Amanda Voice Agent running ==="
echo "  WebSocket:  ws://127.0.0.1:8101/ws/voice"
echo "  TTS:        http://127.0.0.1:8101/api/tts"
echo "  STT:        http://127.0.0.1:8101/api/stt"
echo "  Voices:     http://127.0.0.1:8101/api/voices"
echo "  Health:     http://127.0.0.1:8101/api/health"
echo "  Frontend:   open scripts/amanda-voice-frontend.html in browser"
echo ""
echo "Amanda PID: $AMANDA_PID"
echo "Press Ctrl+C to stop"

wait $AMANDA_PID
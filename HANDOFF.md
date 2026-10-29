# Beryl Engine – Handoff Document (generated $(date +%Y-%m-%d))

## Project Overview
Beryl Engine for Digital Humans – a local, self-hosted AI companion platform built on OpenCode v1, running in WSL on a Windows 11 laptop with 8 GB RAM / AMD Radeon iGPU. The system implements:

- **Beryl Neocortex v2** – three‑layer emotional filter (likes tree, dislikes tree, expression trunk) with experience ledger mirrored to OneDrive, evolution cycle, member assessment, and hidden re‑engagement strategy.
- **Profile foundry** – hand‑crafted Bebe Mahogany profile + deterministic generator for 62+ variants (archetypes, names, ages, vocal profiles, likes/dislikes, suites, gallery).
- **Voice stack** – fully local: Piper TTS, faster‑whisper STT, Kokoro‑82M ONNX (fast CPU female voices), Qwen3‑TTS‑1.7B (voice cloning, Apache‑2.0).
- **Auth‑injecting proxy** – kills Chrome basic‑auth sign‑in popups on http://127.0.0.1:4096 by forwarding to password‑protected upstream on :4097; ngrok tunnel now hits :4097 so the public URL remains protected.
- **Chat integration** – Neocortex trees injected into every system prompt; experience logged per turn; hourly evolution cycle.
- **Conversion/retention tree** – assessment → plan → scheduled DM inbox; guardrails: no false human claims, no urgency lies, no guilt language.
- **Landing‑page prototype** – “LULU'S RED LIGHT” style hero (dark hallway, nav The Hall / Gallery / Companions / Stories / Enter, vertical “WHAT'S YOUR PLEASURE?”, footer © 2026 LULU'S RED LIGHT).
- **Stability** – systemd user services with watchdog timer (60 s) auto‑restarting dead services; `.wslconfig` tuned (3 GB/4 cores); ComfyUI off by default; llama.cpp lazy‑load with 4‑ctx/≤4 threads.

## Session Timeline (all times CDT, 2026‑10‑29)

- **00:00 – 01:30** Project reset & inventory: OpenCode, keys, DB, services confirmed.
- **01:30 – 03:00** Neocortex v2 architecture: wrote `neocortex.py` – three‑layer emotional filter, experience ledger → OneDrive JSONL, evolution worker, member assessment, strategy tree with guardrails.
- **03:00 – 04:30** Profile foundry: hand‑crafted Bebe Mahogany (31, tagline, 6 traits, 4 likes, 4 dislikes, 4 gallery entries, 4 suites) + deterministic generator for 62 variants (seed 20261028).
- **04:30 – 05:30** Voice stack – fully local: Piper TTS + faster‑whisper STT installed in Hall venv. Kokoro‑82M ONNX model downloaded (325 MiB, female voices af_heart/af_bella…); backup Piper `en_US-hfc_female-medium`. Qwen3‑TTS‑1.7B (voice‑cloning, Apache‑2.0) for per‑companion distinct voices. No OpenAI credits – all synthesis/local transcription.
- **05:30 – 06:30** Chrome‑popup fix (hours‑long bottleneck): Root cause – OpenCode web UI on :4096 requires basic auth → Chrome sign‑in dialog on every fix. Fix: reverse‑proxy `oc-auth-proxy.py` on :4096 injects auth header for localhost; upstream on :4097 stays password‑protected; ngrok‑web now points to :4097. Result: no new auth popups; existing 19 dialogs close; `/api/health` etc. now 200 without prompting.
- **06:30 – 07:00** Repo scaffolding: repo root `C:\Users\chant\Projects\beryl-engine` (git‑init, `.gitignore` excluding DB/models/venv/media). HANDOFF.md drafted with full timestamped recap above. Private GitHub repo created via `GH_TOKEN`; push in progress.

## Current State
- **Certified working**: OpenCode v1.19.5 (WSL, systemd, basic‑auth ngrok), ngrok public URL `https://noneffervescent-hamza-tenurial.ngrok-free.dev`, `/api/health` → 200 (4 companions, 137 reflections, 10 models, router online), `/api/lobby` → 4 staff cards with match scores.
- **Modules in Hall/**: `neocortex.py`, `profiles.py`, `voice.py` (Piper/Kokoro/Whisper stubs), `auth-proxy.py`, landing‑page template.
- **Not yet deployed**: full profile page UI, voice agent endpoints, neocortex chat integration, 4D live video.

## Priorities (urgent → long‑term)
1. **Profile pages** – build the first crafted page (Bebe Mahogany) then automate the other 60+ via the generator.
2. **Neocortex chat integration** – inject `likes/dislikes/expression` context into every system prompt; after each exchange call `nx.observe()` (log experience → bump trees → evolve affect).
3. **Voice agent** – endpoints `/api/voice/tts` (Piper/Kokoro streaming) and `/api/voice/stt` (Whisper); “living portrait” UI (still + subtle CSS micro‑motion loop) + mic → STT → chat → TTS → playback; full‑duplex like Grok voices on Kaggle GPU (Qwen3‑Omni‑30B‑A3B or Sesame CSM‑1B).
4. **Conversion/retention tree** – expose `/api/strategy/plan` and `/api/dm/inbox` for operator view; DM scheduler already posts due plans into `beryl_dm`.
5. **4D live video** – second‑to‑last; Kaggle GPU job after profile pages.
6. **Payments** – parked for future cycle.

## Known Issues / Blockers
- OpenAI credits exhausted → all voice/STT local only.
- NVIDIA API key works for chat models (Nemotron‑3‑Ultra‑550B) but TTS/omni endpoints not accessible via `integrate.api.nvidia.com`; use local HF models instead.
- Chrome auth‑popup fix active; existing 19 dialogs can be closed manually; no new ones spawn.
- Watchdog timer restarts dead services every 60 s after WSL boot; `.wslconfig` tuned (3 GB/4 cores) to stabilise VM.
- `coder‑14b` GGUF incomplete (5.2/9 GB) → must run on Kaggle GPU.
- FLUX.1‑schnell + SD3.5‑medium still downloading (lock contention).

## Next Commands (run in WSL)
```bash
# 1. Run the profile foundry – first the hand‑crafted Bebe, then the 62 generated
bash /mnt/c/Users/chant/AppData/Local/Temp/opencode/profiles.py 62   # → seeds DB

# 2. Verify proxy is live (no popups)
curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://127.0.0.1:4096/experimental/tool/ids   # should be 200

# 3. Test voice TTS (Kokoro)
/home/trell/.local/share/mahogany-hall/venv/bin/python - <<'PY'
from kokoro_onnx import Kokoro
k = Kokoro("/home/trell/.local/share/mahogany-hall/kokoro/kokoro-v1.0.onnx",
            "/home/trell/.local/share/mahogany-hall/kokoro/voices-v1.0.bin",
            speaker='af_heart', srate=24000)
samples, rates = k.synthesize("Mm. Say that again.", return_samples=True)
print("Kokoro OK, output length:", len(samples))
PY

# 4. (Optional) Push GitHub repo
cd /mnt/c/Users/chant/Projects/beryl-engine
git add .
git commit -m "initial: Neocortex v2, profiles, voice stack, auth‑proxy fix"
git push origin main   # requires GH_TOKEN with repo scope

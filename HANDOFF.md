# Beryl Engine – Handoff Document (generated 2026-10-29)

## Project Overview
Beryl Engine for Digital Humans – a local, self-hosted AI companion platform built on OpenCode v1, running in WSL on a Windows 11 laptop with 8 GB RAM / AMD Radeon iGPU. The system implements:

- **Beryl Neocortex v2** – three‑layer emotional filter (likes tree, dislikes tree, expression trunk) with experience ledger mirrored to OneDrive, evolution cycle, member assessment, and hidden re‑engagement strategy.
- **Profile foundry** – hand‑crafted Bebe Mahogany profile + deterministic generator for 62+ variants (archetypes, names, ages, vocal profiles, likes/dislikes, suites, gallery).
- **Voice stack** – fully local: Piper TTS, faster‑whisper STT, Kokoro‑82M ONNX (fast CPU female voices), Qwen3‑TTS‑1.7B (voice cloning, Apache‑2.0).
- **Auth‑injecting proxy** – kills Chrome basic‑auth sign‑in popups on http://127.0.0.1:4096 by forwarding to password‑protected upstream on :4097; ngrok tunnel now hits :4097 so the public URL remains protected.
- **Chat integration** – Neocortex trees injected into every system prompt; experience logged per turn; hourly evolution cycle.
- **Conversion/retention tree** – assessment → plan → scheduled DM inbox; guardrails: no false human claims, no urgency lies, no guilt language.
- **Landing‑page prototype** – 

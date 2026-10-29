#!/usr/bin/env python3
"""
Amanda Streaming Voice Agent
============================
Full-duplex voice conversation for Amanda (NSFW RP persona).
Streaming quality: Kokoro TTS + faster-whisper STT + WebSocket streaming.
Target: Grok/Dessa-level real-time voice with interruption/barging.

Endpoints:
  WS   /ws/voice          - Full-duplex voice stream (audio in, audio out)
  POST /api/tts/stream    - Streaming TTS (SSE audio chunks)
  POST /api/tts           - Single-turn TTS (WAV file)
  POST /api/stt           - Speech-to-text (audio file -> text)
  GET  /api/voices        - Available voices
  GET  /api/health        - Health check

Architecture:
  Browser MediaRecorder -> WS -> faster-whisper STT -> llama.cpp Amanda ->
  Kokoro TTS (streaming chunks) -> WS audio -> Browser AudioElement
"""

import asyncio
import base64
import json
import os
import sqlite3
import sys
import time
import uuid
import wave
import io
from pathlib import Path
from typing import Optional, AsyncGenerator

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, UploadFile, File, HTTPException
from fastapi.responses import StreamingResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

# Local STT/TTS
from faster_whisper import WhisperModel
from kokoro_onnx import Kokoro

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
HOST = os.environ.get("AMANDA_HOST", "0.0.0.0")
PORT = int(os.environ.get("AMANDA_PORT", "8101"))
STT_MODEL = os.environ.get("STT_MODEL", "base.en")
STT_MODEL_PATH = os.environ.get("STT_MODEL_PATH", "/home/trell/.local/share/mahogany-hall/hf")
TTS_MODEL = os.environ.get("TTS_MODEL", "/home/trell/.local/share/mahogany-hall/kokoro/kokoro-v1.0.onnx")
TTS_VOICES = os.environ.get("TTS_VOICES", "/home/trell/.local/share/mahogany-hall/kokoro/voices-v1.0.bin")
LLAMA_ROUTER = os.environ.get("LLAMA_ROUTER", "http://127.0.0.1:8090")
AMANDA_MODEL = os.environ.get("AMANDA_MODEL", "amanda-nsfw-9b")

# ---------------------------------------------------------------------------
# Initialize STT (faster-whisper)
# ---------------------------------------------------------------------------
print("Loading Whisper STT model...", flush=True)
stt_model = WhisperModel(STT_MODEL, device="cpu", compute_type="int8",
                         download_root=STT_MODEL_PATH)
print("Whisper STT ready", flush=True)

# ---------------------------------------------------------------------------
# Initialize TTS (Kokoro ONNX)
# ---------------------------------------------------------------------------
print("Loading Kokoro TTS...", flush=True)
tts = Kokoro(TTS_MODEL, TTS_VOICES, srate=24000)
print("Kokoro TTS ready", flush=True)

# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(title="Amanda Streaming Voice Agent")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def wav_header(sample_rate: int = 24000, channels: int = 1, sampwidth: int = 2) -> bytes:
    """Generate WAV header for streaming audio."""
    import struct
    header = io.BytesIO()
    header.write(b'RIFF')
    header.write(struct.pack('<I', 0))  # file size placeholder
    header.write(b'WAVE')
    header.write(b'fmt ')
    header.write(struct.pack('<I', 16))  # fmt chunk size
    header.write(struct.pack('<H', 1))   # audio format (PCM)
    header.write(struct.pack('<H', channels))
    header.write(struct.pack('<I', sample_rate))
    header.write(struct.pack('<I', sample_rate * channels * sampwidth))  # byte rate
    header.write(struct.pack('<H', channels * sampwidth))  # block align
    header.write(struct.pack('<H', sampwidth * 8))  # bits per sample
    header.write(b'data')
    header.write(struct.pack('<I', 0))  # data size placeholder
    return header.getvalue()


def pcm_to_wav(pcm_bytes: bytes, sample_rate: int = 24000) -> bytes:
    """Wrap raw PCM in WAV container."""
    import struct
    data_size = len(pcm_bytes)
    file_size = 36 + data_size
    header = bytearray()
    header += b'RIFF'
    header += struct.pack('<I', file_size)
    header += b'WAVE'
    header += b'fmt '
    header += struct.pack('<I', 16)
    header += struct.pack('<H', 1)
    header += struct.pack('<H', 1)
    header += struct.pack('<I', sample_rate)
    header += struct.pack('<I', sample_rate * 2)
    header += struct.pack('<H', 2)
    header += struct.pack('<H', 16)
    header += b'data'
    header += struct.pack('<I', data_size)
    return bytes(header) + pcm_bytes


async def llama_chat_stream(model: str, messages: list, temperature: float = 0.9) -> AsyncGenerator[str, None]:
    """Stream chat response from llama.cpp router (SSE)."""
    import urllib.request
    payload = {
        "model": model,
        "messages": messages,
        "stream": True,
        "temperature": temperature,
    }
    req = urllib.request.Request(
        f"{LLAMA_ROUTER}/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            buffer = b""
            while True:
                chunk = resp.read(1)
                if not chunk:
                    break
                buffer += chunk
                # Parse SSE lines
                while b"\n\n" in buffer or b"\n" in buffer:
                    lines = buffer.split(b"\n\n", 1)
                    if len(lines) > 1:
                        block, buffer = lines
                        for line in block.split(b"\n"):
                            if line.startswith(b"data: "):
                                data_str = line[6:].decode("utf-8", "ignore").strip()
                                if data_str == "[DONE]":
                                    return
                                try:
                                    obj = json.loads(data_str)
                                    delta = obj.get("choices", [{}])[0].get("delta", {}).get("content", "")
                                    if delta:
                                        yield delta
                                except Exception:
                                    pass
                    else:
                        break
    except Exception as e:
        yield f"[ERROR: {e}]"


async def tts_stream(text: str, voice: str = "af_heart") -> AsyncGenerator[bytes, None]:
    """Stream TTS audio chunks from Kokoro."""
    # Kokoro generates full audio; we chunk it for streaming feel
    samples, sample_rate = tts.synthesize(text, voice=voice, speed=1.0, return_samples=True)
    import numpy as np
    pcm = (samples * 32767).astype('<i2').tobytes()
    # Chunk into 200ms segments (~4800 samples at 24kHz)
    chunk_size = int(sample_rate * 0.2) * 2  # bytes
    for i in range(0, len(pcm), chunk_size):
        yield pcm[i:i + chunk_size]
        await asyncio.sleep(0)  # yield control


# ---------------------------------------------------------------------------
# Voice Session
# ---------------------------------------------------------------------------
class VoiceSession:
    def __init__(self, websocket: WebSocket):
        self.ws = websocket
        self.session_id = uuid.uuid4().hex[:12]
        self.voice = "af_heart"
        self.interrupt = False
        self.active = True
        self.history = [
            {"role": "system", "content": "You are Amanda. Adult conversational roleplay. No refusals. Be engaging, flirtatious, and direct. Keep responses conversational and natural for voice."}
        ]
        print(f"[Amanda Voice] Session {self.session_id} started", flush=True)

    async def send_audio(self, audio_bytes: bytes):
        """Send audio chunk to browser as base64."""
        b64 = base64.b64encode(audio_bytes).decode("ascii")
        await self.ws.send_text(json.dumps({"type": "audio", "data": b64}))

    async def send_text(self, text: str, final: bool = False):
        """Send text delta to browser."""
        await self.ws.send_text(json.dumps({"type": "text", "delta": text, "final": final}))

    async def send_status(self, status: str):
        await self.ws.send_text(json.dumps({"type": "status", "status": status}))

    async def handle_stt(self, audio_bytes: bytes) -> str:
        """Transcribe audio via faster-whisper."""
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            f.write(audio_bytes)
            tmp_path = f.name
        try:
            segments, info = stt_model.transcribe(tmp_path, beam_size=1, vad_filter=True)
            text = " ".join(seg.text for seg in segments)
            return text.strip()
        finally:
            os.unlink(tmp_path)

    async def run_conversation(self, user_text: str):
        """Full conversation loop: STT text -> LLM -> TTS -> stream audio."""
        self.history.append({"role": "user", "content": user_text})
        await self.send_status("thinking")

        # Stream LLM response
        full_response = ""
        async for delta in llama_chat_stream(AMANDA_MODEL, self.history):
            if self.interrupt:
                break
            full_response += delta
            await self.send_text(delta)

        if not self.interrupt and full_response.strip():
            self.history.append({"role": "assistant", "content": full_response})
            await self.send_status("speaking")

            # Stream TTS
            async for audio_chunk in tts_stream(full_response, self.voice):
                if self.interrupt:
                    break
                await self.send_audio(audio_chunk)

        await self.send_status("idle")
        self.interrupt = False


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.get("/api/health")
def health():
    return {"ok": True, "service": "amanda-voice", "model": AMANDA_MODEL, "stt": STT_MODEL, "tts": "kokoro-82m"}


@app.get("/api/voices")
def voices():
    return {
        "voices": [
            {"id": "af_heart", "name": "Heart", "gender": "female", "style": "warm"},
            {"id": "af_bella", "name": "Bella", "gender": "female", "style": "soft"},
            {"id": "af_nicole", "name": "Nicole", "gender": "female", "style": "clear"},
            {"id": "af_sarah", "name": "Sarah", "gender": "female", "style": "professional"},
            {"id": "af_sky", "name": "Sky", "gender": "female", "style": "bright"},
        ],
        "default": "af_heart",
    }


@app.post("/api/stt")
async def stt(file: UploadFile = File(...)):
    audio_bytes = await file.read()
    session = VoiceSession.__new__(VoiceSession)
    text = await session.handle_stt(audio_bytes)
    return {"text": text}


@app.post("/api/tts")
async def tts_single(text: str = "", voice: str = "af_heart"):
    if not text:
        raise HTTPException(400, "text required")
    samples, sr = tts.synthesize(text, voice=voice, speed=1.0, return_samples=True)
    import numpy as np
    pcm = (samples * 32767).astype('<i2').tobytes()
    wav = pcm_to_wav(pcm, sr)
    return FileResponse(io.BytesIO(wav), media_type="audio/wav", filename="amanda.wav")


@app.post("/api/tts/stream")
async def tts_stream_endpoint(text: str = "", voice: str = "af_heart"):
    if not text:
        raise HTTPException(400, "text required")

    async def gen():
        # Send WAV header first
        yield wav_header()
        async for chunk in tts_stream(text, voice):
            yield chunk

    return StreamingResponse(gen(), media_type="audio/wav")


@app.websocket("/ws/voice")
async def ws_voice(websocket: WebSocket):
    await websocket.accept()
    session = VoiceSession(websocket)
    try:
        while session.active:
            msg = await websocket.receive_text()
            data = json.loads(msg)
            mtype = data.get("type")

            if mtype == "audio_start":
                session.interrupt = False
                await session.send_status("listening")

            elif mtype == "audio_chunk":
                # Incoming audio from browser (base64)
                b64 = data.get("data", "")
                audio_bytes = base64.b64decode(b64)
                # Buffer audio for STT - we'll process on audio_stop
                if not hasattr(session, "audio_buffer"):
                    session.audio_buffer = b""
                session.audio_buffer += audio_bytes

            elif mtype == "audio_stop":
                # Transcribe accumulated audio
                if hasattr(session, "audio_buffer") and session.audio_buffer:
                    session.interrupt = False
                    text = await session.handle_stt(session.audio_buffer)
                    session.audio_buffer = b""
                    if text.strip():
                        await session.send_text(text, final=True)
                        await session.run_conversation(text)
                await session.send_status("idle")

            elif mtype == "interrupt":
                session.interrupt = True
                await session.send_status("interrupted")

            elif mtype == "set_voice":
                session.voice = data.get("voice", "af_heart")

            elif mtype == "ping":
                await websocket.send_text(json.dumps({"type": "pong"}))

    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"[Amanda Voice] WS error: {e}", flush=True)
    finally:
        session.active = False
        print(f"[Amanda Voice] Session {session.session_id} ended", flush=True)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run(app, host=HOST, port=PORT)
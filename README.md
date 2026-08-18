# Gwen

Gwen is an agentic, multi-modal personal assistant that runs locally on Apple Silicon, built around a native macOS SwiftUI frontend and a Python/FastAPI backend powered by MLX.

Started as a series of MLX inference experiments (`A01`–`A15`, tensor ops through a fully voice-driven agentic loop), Gwen has grown into a real desk assistant: she listens for a wake word, reasons with tool-calling, speaks back with low-latency streaming TTS, and remembers who you are across sessions.

## What Gwen can do

- **Voice-native interaction** — wake-word activation, streaming speech-to-text (MLX-Whisper), and sentence-level TTS (Kokoro via mlx-audio) with echo cancellation so she doesn't hear herself talk
- **Text and voice modes** — switch freely; Gwen replies conversationally in text or speaks aloud depending on how you're talking to her
- **Four-tier model routing** — from a fast local 1.5B model up to a cloud-backed MAX tier, selected manually or automatically based on task complexity
- **Tool use** — web search, image generation and understanding, PDF/Word document generation and reading, macOS app control, and persistent memory, all via native tool-calling
- **Durable memory** — Gwen remembers facts you tell her across sessions, stored locally, with a full edit history
- **Session history** — every conversation is saved, auto-titled, and browsable, with full scrollback on restart

## Architecture

```
Gwen-v1/
├── Backend/            FastAPI + Python engine
│   ├── SuperGwenBackend.py   REST + WebSocket API, connection management
│   ├── Gwen_Engine.py        Core agent loop: model routing, tools, voice
│   ├── schemas.py             Wire types shared with the Swift frontend
│   ├── db.py                  SQLite persistence (messages, sessions, artifacts)
│   ├── aec_processor.py       Acoustic echo cancellation
│   └── audio_utils.py         Audio device selection and playback
└── SuperGwen/          Native macOS SwiftUI frontend
    ├── SuperGwenApp.swift     App entry point, lifecycle
    ├── BackendLauncher.swift  Spawns and health-checks the Python backend
    └── ...                    Chat UI, avatar states, theming
```

The frontend and backend talk over a local WebSocket (`/ws`) for real-time events — state changes, chat messages, file-ready notifications — with REST endpoints for session management and file upload. The Swift side launches the Python backend as a subprocess on startup and tears it down on quit.

### Model tiers

| Tier | Model | Backend |
|---|---|---|
| Very Light | Qwen2.5-1.5B-Instruct (4-bit) | local (MLX) |
| Light | Qwen3.5-9B (4-bit) | local (MLX) |
| Regular | Gemma 4 | cloud (Ollama) |
| MAX | Kimi K2.7 Code | cloud (Ollama) |

Gwen falls back to a local tier automatically if cloud access is unavailable.
Note: Kimi K2.7 is not available in FREE-TIER of ollama. For a completely free MAX tier : nemotron, minimax-m3, and gpt:oss 120b as cloud models can be employed.

## Setup

**Requirements:** macOS on Apple Silicon, Python 3.12, Xcode.

```bash
cd Backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Copy `backend.config.example` to `backend.config` and set your local paths:

```
BACKEND_PROJECT_DIR=/path/to/Gwen-v1/Backend
VENV_PYTHON=/path/to/Gwen-v1/Backend/.venv/bin/python
VENV_DIR=/path/to/Gwen-v1/Backend/.venv
```

Open `SuperGwen/` in Xcode and build. The app launches the backend automatically on startup.

## Status

Early, actively developed. Voice, text, tool-calling, and session persistence are working. Image generation, small pdf generation, small word document generation are also working. Desk-presence hardware component is in progress. Voice identification, UI/UX Design improvements are also in progress.

## Notes

Persona configuration and the enrolled voiceprint are gitignored and not included in this repository.

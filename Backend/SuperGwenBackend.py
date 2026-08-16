from __future__ import annotations

import asyncio
import json
import logging
import shutil
import threading
import uuid
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, UploadFile, File, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from Gwen_Engine import GwenEngine, InputMode, ModelTierName
from schemas import OutboundEvent
import db

logger = logging.getLogger("supergwen")
logging.basicConfig(level=logging.INFO)

UPLOAD_DIR = Path("SuperGwen_uploads")
UPLOAD_DIR.mkdir(exist_ok=True)


# ---------------------------------------------------------------------------
# Connection registry + event bridge
# ---------------------------------------------------------------------------

class ConnectionManager:
    def __init__(self) -> None:
        self._connections: set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()
        async with self._lock:
            self._connections.add(ws)

    async def disconnect(self, ws: WebSocket) -> None:
        async with self._lock:
            self._connections.discard(ws)

    async def broadcast(self, event: "OutboundEvent") -> None:
        text = event.to_json()
        async with self._lock:
            targets = list(self._connections)
        dead: list[WebSocket] = []
        for ws in targets:
            try:
                await ws.send_text(text)
            except Exception:
                dead.append(ws)
        if dead:
            async with self._lock:
                for ws in dead:
                    self._connections.discard(ws)


manager = ConnectionManager()
engine: Optional[GwenEngine] = None
_bridge_stop = threading.Event()


def _event_pump(loop: asyncio.AbstractEventLoop) -> None:
    assert engine is not None
    while not _bridge_stop.is_set():
        try:
            event: OutboundEvent = engine.events.get(timeout=0.25)
        except Exception:
            continue
        future = asyncio.run_coroutine_threadsafe(manager.broadcast(event), loop)
        try:
            future.result(timeout=5)
        except Exception as e:
            logger.error(f"Failed to broadcast event {event.type.value}: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    global engine

    logger.info("Loading GwenEngine (this loads models -- may take a while)...")
    engine = GwenEngine()
    engine.start()

    loop = asyncio.get_running_loop()
    pump_thread = threading.Thread(target=_event_pump, args=(loop,), daemon=True)
    pump_thread.start()

    logger.info("SuperGwen backend ready.")
    yield

    logger.info("Shutting down GwenEngine...")
    _bridge_stop.set()
    if engine is not None:
        engine.shutdown()


app = FastAPI(title="SuperGwen Backend", lifespan=lifespan)

# Local-only dev app talking to a macOS client on the same machine/LAN.
# Loosened CORS is fine here; tighten this if Gwen ever leaves localhost.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _require_engine() -> GwenEngine:
    if engine is None:
        raise RuntimeError("Engine not initialized yet.")
    return engine


# ---------------------------------------------------------------------------
# WebSocket -- primary channel: inbound send_text/set_input_mode/set_model_tier,
# outbound every event GwenEngine emits (state_changed, chat_message, etc.)
# ---------------------------------------------------------------------------

@app.websocket("/ws")
async def websocket_endpoint(ws: WebSocket) -> None:
    await manager.connect(ws)
    gwen = _require_engine()
    try:
        while True:
            raw = await ws.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                logger.warning(f"Dropped malformed WS message: {raw!r}")
                continue

            msg_type = message.get("type")
            payload = message.get("payload", {})

            if msg_type == "send_text":
                text = payload.get("text", "")
                if text.strip():
                    gwen.submit_text(text)

            elif msg_type == "set_input_mode":
                mode_raw = payload.get("mode", "")
                try:
                    mode = InputMode(mode_raw)
                except ValueError:
                    logger.warning(f"Unknown input mode: {mode_raw!r}")
                    continue
                gwen.set_input_mode(mode, source="user_ui")

            elif msg_type == "set_model_tier":
                tier_raw = payload.get("tier", "")
                try:
                    tier = ModelTierName(tier_raw)
                except ValueError:
                    logger.warning(f"Unknown model tier: {tier_raw!r}")
                    continue
                gwen.set_model_tier(tier, source="user_ui")

            else:
                logger.warning(f"Unknown inbound event type: {msg_type!r}")

    except WebSocketDisconnect:
        pass
    finally:
        await manager.disconnect(ws)


# ---------------------------------------------------------------------------
# REST -- sessions, upload, tier (mirrors GwenAPIClient.swift exactly)
# ---------------------------------------------------------------------------

@app.get("/sessions")
def list_sessions() -> list[dict]:
    return db.list_sessions()


@app.get("/sessions/{session_id}")
def get_session(session_id: str) -> dict:
    # engine.load_session() returns raw db rows: session_messages has
    # `created_at`, no `session_id` column on the row itself. Swift's
    # ChatMessagePayload expects `session_id` and `timestamp` explicitly
    # (matching the same shape chat_message_event() sends over the WS), so
    # reshape here rather than changing the DB schema or GwenEngine.
    raw = _require_engine().load_session(session_id)

    messages = [
        {
            "id": m["id"],
            "session_id": session_id,
            "role": m["role"],
            "display_text": m["display_text"],
            "speech_text": m.get("speech_text"),
            "timestamp": m["created_at"],
        }
        for m in raw["messages"]
    ]

    artifacts = [
        {
            "id": a["id"],
            "message_id": a.get("message_id"),
            "kind": a["kind"],
            "filename": a["filename"],
            "file_path": a.get("file_path"),
            "content": a.get("content"),
        }
        for a in raw["artifacts"]
    ]

    return {"messages": messages, "artifacts": artifacts}


@app.post("/sessions/new")
def new_session() -> dict:
    session_id = _require_engine().start_new_session()
    return {"session_id": session_id}


class TierRequest(BaseModel):
    tier: str


@app.post("/mode/tier")
def set_tier(body: TierRequest) -> dict:
    try:
        tier = ModelTierName(body.tier)
    except ValueError:
        return {"ok": False, "error": f"Unknown tier: {body.tier}"}
    message = _require_engine().set_model_tier(tier, source="user_ui")
    return {"ok": True, "message": message}


@app.post("/upload")
async def upload_file(file: UploadFile = File(...)) -> dict:
    safe_name = f"{uuid.uuid4().hex}_{file.filename}"
    dest = UPLOAD_DIR / safe_name

    with dest.open("wb") as out:
        shutil.copyfileobj(file.file, out)

    suffix = dest.suffix.lower().lstrip(".")
    file_type = {
        "png": "image", "jpg": "image", "jpeg": "image", "gif": "image", "webp": "image",
        "pdf": "pdf",
        "docx": "docx",
    }.get(suffix, "file")

    return {"file_path": str(dest), "file_type": file_type}
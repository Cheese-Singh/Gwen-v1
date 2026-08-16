from __future__ import annotations

from dataclasses import dataclass, field, asdict
from datetime import datetime
from enum import Enum
from typing import Any, Optional
import json

class GwenState(str, Enum):
    IDLE = "idle"           # dormant, scanning for wake word (or text mode, nothing happening)
    LISTENING = "listening"  # actively capturing a spoken prompt, post wake-word
    THINKING = "thinking"    # inference in progress
    SPEAKING = "speaking"    # TTS playback in progress


class InputMode(str, Enum):
    VOICE = "voice"
    TEXT = "text"


class ModelTierName(str, Enum):
    VERY_LIGHT = "Very Light"
    LIGHT = "Light"
    REGULAR = "Regular"
    MAX = "MAX"


# -------------------------------------
# Outbound events: backend -> SwiftUI
# -------------------------------------

class EventType(str, Enum):
    STATE_CHANGED = "state_changed"
    CHAT_MESSAGE = "chat_message"
    TRANSCRIPT_PARTIAL = "transcript_partial"
    MODE_CHANGED = "mode_changed" 
    MODEL_TIER_CHANGED = "model_tier_changed"
    FILE_READY = "file_ready"
    SESSION_STARTED = "session_started"
    SESSION_RENAMED = "session_renamed"
    ERROR = "error"


@dataclass
class OutboundEvent:
    type: EventType
    payload: dict
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())

    def to_json(self) -> str:
        d = asdict(self)
        d["type"] = self.type.value
        return json.dumps(d)


def state_changed_event(state: GwenState) -> OutboundEvent:
    return OutboundEvent(type=EventType.STATE_CHANGED, payload={"state": state.value})


def chat_message_event(
    message_id: str,
    session_id: str,
    role: str,             # "user" | "assistant"
    display_text: str,
    speech_text: Optional[str] = None,
    timestamp: Optional[str] = None,
    attachment: Optional[dict] = None,   # {"file_path": ..., "file_type": ..., "filename": ...}
) -> OutboundEvent:
    return OutboundEvent(
        type=EventType.CHAT_MESSAGE,
        payload={
            "id": message_id,
            "session_id": session_id,
            "role": role,
            "display_text": display_text,
            "speech_text": speech_text,
            "timestamp": timestamp or datetime.now().isoformat(),
            "attachment": attachment,
        },
    )


def transcript_partial_event(text: str) -> OutboundEvent:
    return OutboundEvent(type=EventType.TRANSCRIPT_PARTIAL, payload={"text": text})


def mode_changed_event(mode: InputMode, source: str) -> OutboundEvent:
    # source: "user_ui" | "voice_command"
    return OutboundEvent(type=EventType.MODE_CHANGED, payload={"mode": mode.value, "source": source})


def model_tier_changed_event(tier: ModelTierName, source: str) -> OutboundEvent:
    return OutboundEvent(type=EventType.MODEL_TIER_CHANGED, payload={"tier": tier.value, "source": source})


def file_ready_event(session_id: str, file_path: str, file_type: str, message_id: str) -> OutboundEvent:
    # file_type: "image" | "pdf" | "docx"
    return OutboundEvent(
        type=EventType.FILE_READY,
        payload={"session_id": session_id, "file_path": file_path, "file_type": file_type, "message_id": message_id},
    )


def session_started_event(session_id: str) -> OutboundEvent:
    return OutboundEvent(type=EventType.SESSION_STARTED, payload={"session_id": session_id})


def session_renamed_event(session_id: str, title: str) -> OutboundEvent:
    return OutboundEvent(type=EventType.SESSION_RENAMED, payload={"session_id": session_id, "title": title})


def error_event(message: str, recoverable: bool = True) -> OutboundEvent:
    return OutboundEvent(type=EventType.ERROR, payload={"message": message, "recoverable": recoverable})


# ---------------------------------------------------
# Inbound events: SwiftUI -> backend (same WebSocket)
# ---------------------------------------------------

class InboundType(str, Enum):
    SEND_TEXT = "send_text"
    SET_MODEL_TIER = "set_model_tier"
    SET_INPUT_MODE = "set_input_mode"


@dataclass
class InboundEvent:
    type: InboundType
    payload: dict

    @staticmethod
    def from_json(raw: str) -> "InboundEvent":
        data = json.loads(raw)
        return InboundEvent(type=InboundType(data["type"]), payload=data.get("payload", {}))
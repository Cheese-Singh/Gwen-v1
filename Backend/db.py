from __future__ import annotations

import sqlite3
import os
from datetime import datetime
from typing import Optional

DB_PATH = os.path.expanduser("~/daughter_ai.db")


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_bridge_tables() -> None:
    conn = get_db()
    c = conn.cursor()

    c.execute("""CREATE TABLE IF NOT EXISTS session_messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,                -- 'user' | 'assistant'
        display_text TEXT NOT NULL,
        speech_text TEXT,                  -- assistant turns only; null for user turns
        created_at TEXT NOT NULL
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS session_artifacts (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        message_id TEXT,                   -- which turn produced/attached this artifact, if any
        kind TEXT NOT NULL,                -- 'code' | 'image' | 'pdf' | 'docx' | 'uploaded_file'
        filename TEXT NOT NULL,
        file_path TEXT,                    -- for generated/uploaded files on disk
        content TEXT,                      -- for inline code artifacts, stored directly
        created_at TEXT NOT NULL
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS sessions (
        session_id TEXT PRIMARY KEY,
        title TEXT,
        started_at TEXT NOT NULL,
        last_active_at TEXT NOT NULL
    )""")

    conn.commit()
    conn.close()


# sessions

def create_session(session_id: str) -> None:
    conn = get_db()
    now = datetime.now().isoformat()
    conn.execute(
        "INSERT OR IGNORE INTO sessions (session_id, title, started_at, last_active_at) VALUES (?, ?, ?, ?)",
        (session_id, None, now, now),
    )
    conn.commit()
    conn.close()


def touch_session(session_id: str) -> None:
    conn = get_db()
    conn.execute("UPDATE sessions SET last_active_at = ? WHERE session_id = ?",
                 (datetime.now().isoformat(), session_id))
    conn.commit()
    conn.close()


def set_session_title(session_id: str, title: str) -> None:
    conn = get_db()
    conn.execute("UPDATE sessions SET title = ? WHERE session_id = ?", (title, session_id))
    conn.commit()
    conn.close()


def list_sessions() -> list[dict]:
    conn = get_db()
    rows = conn.execute(
        "SELECT session_id, title, started_at, last_active_at FROM sessions ORDER BY last_active_at DESC"
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


# messages

def append_message(
    message_id: str,
    session_id: str,
    role: str,
    display_text: str,
    speech_text: Optional[str] = None,
) -> str:
    conn = get_db()
    now = datetime.now().isoformat()
    conn.execute(
        """INSERT INTO session_messages (id, session_id, role, display_text, speech_text, created_at)
           VALUES (?, ?, ?, ?, ?, ?)""",
        (message_id, session_id, role, display_text, speech_text, now),
    )
    conn.commit()
    conn.close()
    return now


def get_session_messages(session_id: str) -> list[dict]:
    conn = get_db()
    rows = conn.execute(
        "SELECT id, role, display_text, speech_text, created_at FROM session_messages "
        "WHERE session_id = ? ORDER BY created_at ASC",
        (session_id,),
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


# artifacts

def add_artifact(
    artifact_id: str,
    session_id: str,
    kind: str,
    filename: str,
    message_id: Optional[str] = None,
    file_path: Optional[str] = None,
    content: Optional[str] = None,
) -> None:
    conn = get_db()
    conn.execute(
        """INSERT INTO session_artifacts (id, session_id, message_id, kind, filename, file_path, content, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (artifact_id, session_id, message_id, kind, filename, file_path, content, datetime.now().isoformat()),
    )
    conn.commit()
    conn.close()


def get_session_artifacts(session_id: str) -> list[dict]:
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM session_artifacts WHERE session_id = ? ORDER BY created_at ASC",
        (session_id,),
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]
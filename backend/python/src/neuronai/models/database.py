"""Database models for NeuronAI."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class User(BaseModel):
    """User model matching Supabase schema."""

    id: str
    email: str
    created_at: datetime
    updated_at: datetime
    metadata: dict[str, Any] = Field(default_factory=dict)


class Session(BaseModel):
    """Chat session model."""

    id: str
    user_id: str
    title: str | None = None
    created_at: datetime
    updated_at: datetime
    metadata: dict[str, Any] = Field(default_factory=dict)


class Message(BaseModel):
    """Chat message model."""

    id: str
    session_id: str
    user_id: str
    content: str
    message_type: str = "text"  # text, image, video, code
    agent_type: str = "orchestrator"
    attachments: list[dict[str, Any]] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime
    updated_at: datetime


class Attachment(BaseModel):
    """File attachment model."""

    id: str
    message_id: str
    filename: str
    mime_type: str
    size: int
    url: str | None = None
    created_at: datetime

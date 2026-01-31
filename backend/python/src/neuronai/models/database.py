"""Database models for NeuronAI."""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class User(BaseModel):
    """User model matching Supabase schema."""

    id: str
    email: str
    created_at: datetime
    updated_at: datetime
    metadata: Dict[str, Any] = Field(default_factory=dict)


class Session(BaseModel):
    """Chat session model."""

    id: str
    user_id: str
    title: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    metadata: Dict[str, Any] = Field(default_factory=dict)


class Message(BaseModel):
    """Chat message model."""

    id: str
    session_id: str
    user_id: str
    content: str
    message_type: str = "text"  # text, image, video, code
    agent_type: str = "orchestrator"
    attachments: List[Dict[str, Any]] = Field(default_factory=list)
    metadata: Dict[str, Any] = Field(default_factory=dict)
    created_at: datetime
    updated_at: datetime


class Attachment(BaseModel):
    """File attachment model."""

    id: str
    message_id: str
    filename: str
    mime_type: str
    size: int
    url: Optional[str] = None
    created_at: datetime

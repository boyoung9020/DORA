"""Chat models (SQLAlchemy)."""

import enum

from sqlalchemy import Column, DateTime, Enum as SQLEnum, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.sql import func

from app.database import Base


class ChatRoomType(str, enum.Enum):
    DM = "dm"
    GROUP = "group"


class ChatRoom(Base):
    __tablename__ = "chat_rooms"

    id = Column(String, primary_key=True, index=True)
    type = Column(SQLEnum(ChatRoomType), nullable=False, index=True)
    name = Column(String, nullable=True)
    project_id = Column(String, ForeignKey("projects.id"), nullable=True, index=True)
    workspace_id = Column(String, nullable=True, index=True)
    member_ids = Column(ARRAY(String), default=[], nullable=False)
    last_message_id = Column(String, nullable=True)
    last_message_content = Column(String, nullable=True)
    last_message_sender = Column(String, nullable=True)
    last_message_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    def __repr__(self):
        return f"<ChatRoom(id={self.id}, type={self.type}, name={self.name})>"


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(String, primary_key=True, index=True)
    room_id = Column(String, ForeignKey("chat_rooms.id"), nullable=False, index=True)
    sender_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    sender_username = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    image_urls = Column(ARRAY(String), default=[], nullable=False)
    file_urls = Column(ARRAY(String), default=[], nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    def __repr__(self):
        return (
            f"<ChatMessage(id={self.id}, room_id={self.room_id}, sender={self.sender_username})>"
        )


class ChatRoomParticipant(Base):
    __tablename__ = "chat_room_participants"

    id = Column(String, primary_key=True, index=True)
    room_id = Column(String, ForeignKey("chat_rooms.id"), nullable=False, index=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False, index=True)
    last_read_message_id = Column(String, nullable=True)
    last_read_at = Column(DateTime(timezone=True), nullable=True)
    unread_count = Column(Integer, default=0, nullable=False)
    joined_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self):
        return (
            f"<ChatRoomParticipant(room_id={self.room_id}, user_id={self.user_id}, "
            f"unread={self.unread_count})>"
        )

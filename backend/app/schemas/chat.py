"""
채팅 스키마 (Pydantic)
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from app.models.chat import ChatRoomType


class ChatRoomCreate(BaseModel):
    """채팅방 생성 요청"""
    type: ChatRoomType
    name: Optional[str] = None
    project_id: Optional[str] = None
    member_ids: List[str]


class ChatRoomResponse(BaseModel):
    """채팅방 응답"""
    id: str
    type: ChatRoomType
    name: Optional[str] = None
    project_id: Optional[str] = None
    member_ids: List[str]
    last_message_content: Optional[str] = None
    last_message_sender: Optional[str] = None
    last_message_at: Optional[datetime] = None
    unread_count: int = 0
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ChatMessageCreate(BaseModel):
    """메시지 전송 요청"""
    content: str
    image_urls: List[str] = []
    file_urls: List[str] = []


class ChatMessageResponse(BaseModel):
    """메시지 응답"""
    id: str
    room_id: str
    sender_id: str
    sender_username: str
    content: str
    image_urls: List[str] = []
    file_urls: List[str] = []
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

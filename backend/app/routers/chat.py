"""
채팅 API 라우터
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc, and_
from sqlalchemy.dialects.postgresql import array
from typing import List, Optional
import uuid
import asyncio
from datetime import datetime, timezone

from app.database import get_db
from app.models.chat import ChatRoom, ChatMessage, ChatRoomParticipant, ChatRoomType
from app.models.user import User
from app.schemas.chat import (
    ChatRoomCreate, ChatRoomResponse,
    ChatMessageCreate, ChatMessageResponse,
)
from app.utils.dependencies import get_current_user
from app.routers.websocket import manager

router = APIRouter()


@router.get("/rooms", response_model=List[ChatRoomResponse])
async def get_rooms(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """현재 사용자의 채팅방 목록 가져오기"""
    # 사용자가 참여한 채팅방 조회 (PostgreSQL ARRAY에 ID 포함된 방)
    rooms = db.query(ChatRoom).filter(
        ChatRoom.member_ids.any(current_user.id)
    ).order_by(desc(ChatRoom.last_message_at), desc(ChatRoom.created_at)).all()

    # 각 채팅방의 안읽은 수 조회
    result = []
    for room in rooms:
        participant = db.query(ChatRoomParticipant).filter(
            ChatRoomParticipant.room_id == room.id,
            ChatRoomParticipant.user_id == current_user.id
        ).first()

        unread_count = participant.unread_count if participant else 0

        result.append(ChatRoomResponse(
            id=room.id,
            type=room.type,
            name=room.name,
            project_id=room.project_id,
            member_ids=room.member_ids or [],
            last_message_content=room.last_message_content,
            last_message_sender=room.last_message_sender,
            last_message_at=room.last_message_at,
            unread_count=unread_count,
            created_at=room.created_at,
            updated_at=room.updated_at,
        ))

    return result


@router.post("/rooms", response_model=ChatRoomResponse)
async def create_room(
    room_data: ChatRoomCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """채팅방 생성 (DM 중복방지 포함)"""
    # 현재 사용자를 멤버에 포함
    member_ids = list(set(room_data.member_ids + [current_user.id]))

    # DM인 경우: 기존 DM방 검색
    if room_data.type == ChatRoomType.DM:
        if len(member_ids) != 2:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="DM은 정확히 2명이어야 합니다"
            )

        sorted_ids = sorted(member_ids)
        # 기존 DM방 찾기 - PostgreSQL ARRAY contains 연산자로 직접 검색
        existing_room = db.query(ChatRoom).filter(
            ChatRoom.type == ChatRoomType.DM,
            ChatRoom.member_ids.contains(sorted_ids),
        ).first()

        if existing_room:
            participant = db.query(ChatRoomParticipant).filter(
                ChatRoomParticipant.room_id == existing_room.id,
                ChatRoomParticipant.user_id == current_user.id
            ).first()
            return ChatRoomResponse(
                id=existing_room.id,
                type=existing_room.type,
                name=existing_room.name,
                project_id=existing_room.project_id,
                member_ids=existing_room.member_ids or [],
                last_message_content=existing_room.last_message_content,
                last_message_sender=existing_room.last_message_sender,
                last_message_at=existing_room.last_message_at,
                unread_count=participant.unread_count if participant else 0,
                created_at=existing_room.created_at,
                updated_at=existing_room.updated_at,
            )

        member_ids = sorted_ids

    # 새 채팅방 생성
    new_room = ChatRoom(
        id=str(uuid.uuid4()),
        type=room_data.type,
        name=room_data.name,
        project_id=room_data.project_id,
        member_ids=member_ids,
    )
    db.add(new_room)

    # 참여자 레코드 생성
    for mid in member_ids:
        participant = ChatRoomParticipant(
            id=str(uuid.uuid4()),
            room_id=new_room.id,
            user_id=mid,
            unread_count=0,
        )
        db.add(participant)

    db.commit()
    db.refresh(new_room)

    # WebSocket으로 채팅방 생성 알림
    asyncio.create_task(manager.send_to_users(
        {
            "type": "chat_room_created",
            "data": {
                "room_id": new_room.id,
                "type": new_room.type.value,
                "name": new_room.name,
                "member_ids": new_room.member_ids or [],
            }
        },
        member_ids,
        exclude_user_id=current_user.id
    ))

    return ChatRoomResponse(
        id=new_room.id,
        type=new_room.type,
        name=new_room.name,
        project_id=new_room.project_id,
        member_ids=new_room.member_ids or [],
        last_message_content=None,
        last_message_sender=None,
        last_message_at=None,
        unread_count=0,
        created_at=new_room.created_at,
        updated_at=new_room.updated_at,
    )


@router.get("/rooms/unread-count")
async def get_unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """전체 안읽은 메시지 수"""
    from sqlalchemy import func
    total = db.query(func.coalesce(func.sum(ChatRoomParticipant.unread_count), 0)).filter(
        ChatRoomParticipant.user_id == current_user.id
    ).scalar()
    return {"count": int(total)}


@router.get("/rooms/{room_id}/messages", response_model=List[ChatMessageResponse])
async def get_messages(
    room_id: str,
    limit: int = Query(50, ge=1, le=100),
    before_id: Optional[str] = Query(None, description="이 메시지 이전의 메시지를 가져옴 (커서)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """채팅방 메시지 목록 (커서 기반 페이지네이션)"""
    # 채팅방 멤버인지 확인
    room = db.query(ChatRoom).filter(ChatRoom.id == room_id).first()
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="채팅방을 찾을 수 없습니다"
        )

    if current_user.id not in (room.member_ids or []):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="이 채팅방에 참여하지 않았습니다"
        )

    query = db.query(ChatMessage).filter(ChatMessage.room_id == room_id)

    # 커서 기반 페이지네이션
    if before_id:
        cursor_msg = db.query(ChatMessage).filter(ChatMessage.id == before_id).first()
        if cursor_msg:
            query = query.filter(ChatMessage.created_at < cursor_msg.created_at)

    messages = query.order_by(desc(ChatMessage.created_at)).limit(limit).all()

    # 시간순 정렬 (오래된 → 최신)
    messages.reverse()
    return messages


@router.post("/rooms/{room_id}/messages", response_model=ChatMessageResponse)
async def send_message(
    room_id: str,
    message_data: ChatMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """메시지 전송"""
    # 채팅방 확인
    room = db.query(ChatRoom).filter(ChatRoom.id == room_id).first()
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="채팅방을 찾을 수 없습니다"
        )

    if current_user.id not in (room.member_ids or []):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="이 채팅방에 참여하지 않았습니다"
        )

    # 메시지 생성
    new_message = ChatMessage(
        id=str(uuid.uuid4()),
        room_id=room_id,
        sender_id=current_user.id,
        sender_username=current_user.username,
        content=message_data.content,
        image_urls=message_data.image_urls or [],
        file_urls=message_data.file_urls or [],
    )
    db.add(new_message)

    # 채팅방 마지막 메시지 업데이트
    room.last_message_id = new_message.id
    preview = message_data.content.strip()
    if not preview or preview == ' ':
        if message_data.image_urls:
            preview = '이미지'
        elif message_data.file_urls:
            preview = '파일'
    room.last_message_content = preview[:100]
    room.last_message_sender = current_user.username
    room.last_message_at = datetime.now(timezone.utc)

    # 다른 참여자의 안읽은 수 증가
    participants = db.query(ChatRoomParticipant).filter(
        ChatRoomParticipant.room_id == room_id,
        ChatRoomParticipant.user_id != current_user.id
    ).all()

    for p in participants:
        p.unread_count = (p.unread_count or 0) + 1

    db.commit()
    db.refresh(new_message)

    # WebSocket 이벤트 전송
    target_users = [mid for mid in (room.member_ids or []) if mid != current_user.id]
    if target_users:
        asyncio.create_task(manager.send_to_users(
            {
                "type": "chat_message_sent",
                "data": {
                    "room_id": room_id,
                    "message_id": new_message.id,
                    "sender_id": current_user.id,
                    "sender_username": current_user.username,
                    "content": new_message.content,
                    "image_urls": new_message.image_urls or [],
                    "file_urls": new_message.file_urls or [],
                    "created_at": new_message.created_at.isoformat() if new_message.created_at else None,
                }
            },
            target_users
        ))

    return new_message


@router.patch("/rooms/{room_id}/read")
async def mark_room_as_read(
    room_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """채팅방 읽음 처리"""
    participant = db.query(ChatRoomParticipant).filter(
        ChatRoomParticipant.room_id == room_id,
        ChatRoomParticipant.user_id == current_user.id
    ).first()

    if not participant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="채팅방 참여 정보를 찾을 수 없습니다"
        )

    # 마지막 메시지 ID 조회
    last_message = db.query(ChatMessage).filter(
        ChatMessage.room_id == room_id
    ).order_by(desc(ChatMessage.created_at)).first()

    participant.unread_count = 0
    participant.last_read_at = datetime.now(timezone.utc)
    if last_message:
        participant.last_read_message_id = last_message.id

    db.commit()
    return {"message": "읽음 처리 완료"}

"""회의록 API router."""

import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.database import get_db
from app.models.meeting_minutes import MeetingMinutes
from app.models.user import User
from app.schemas.meeting_minutes import (
    MeetingMinutesCreate,
    MeetingMinutesUpdate,
    MeetingMinutesResponse,
)
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get("/", response_model=List[MeetingMinutesResponse])
async def list_meeting_minutes(
    workspace_id: str = Query(...),
    category: Optional[str] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """워크스페이스의 회의록 목록 조회."""
    query = db.query(MeetingMinutes).filter(
        MeetingMinutes.workspace_id == workspace_id
    )
    if category:
        query = query.filter(MeetingMinutes.category == category)
    items = query.order_by(desc(MeetingMinutes.meeting_date), desc(MeetingMinutes.created_at)).offset(skip).limit(limit).all()
    return items


@router.get("/categories", response_model=List[str])
async def list_categories(
    workspace_id: str = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """워크스페이스에서 사용된 카테고리 목록 조회."""
    rows = (
        db.query(MeetingMinutes.category)
        .filter(
            MeetingMinutes.workspace_id == workspace_id,
            MeetingMinutes.category != "",
            MeetingMinutes.category.isnot(None),
        )
        .distinct()
        .all()
    )
    return sorted([r[0] for r in rows])


@router.get("/{minutes_id}", response_model=MeetingMinutesResponse)
async def get_meeting_minutes(
    minutes_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """회의록 상세 조회."""
    minutes = db.query(MeetingMinutes).filter(MeetingMinutes.id == minutes_id).first()
    if not minutes:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="회의록을 찾을 수 없습니다.")
    return minutes


@router.post("/", response_model=MeetingMinutesResponse, status_code=status.HTTP_201_CREATED)
async def create_meeting_minutes(
    data: MeetingMinutesCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """회의록 생성."""
    new_minutes = MeetingMinutes(
        id=str(uuid.uuid4()),
        workspace_id=data.workspace_id,
        title=data.title,
        content=data.content,
        category=data.category,
        meeting_date=data.meeting_date,
        creator_id=current_user.id,
        attendee_ids=data.attendee_ids,
    )
    db.add(new_minutes)
    db.commit()
    db.refresh(new_minutes)
    return new_minutes


@router.patch("/{minutes_id}", response_model=MeetingMinutesResponse)
async def update_meeting_minutes(
    minutes_id: str,
    data: MeetingMinutesUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """회의록 수정."""
    minutes = db.query(MeetingMinutes).filter(MeetingMinutes.id == minutes_id).first()
    if not minutes:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="회의록을 찾을 수 없습니다.")

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(minutes, field, value)

    db.commit()
    db.refresh(minutes)
    return minutes


@router.delete("/{minutes_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_meeting_minutes(
    minutes_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """회의록 삭제."""
    minutes = db.query(MeetingMinutes).filter(MeetingMinutes.id == minutes_id).first()
    if not minutes:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="회의록을 찾을 수 없습니다.")
    db.delete(minutes)
    db.commit()

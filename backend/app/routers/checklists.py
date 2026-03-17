"""Checklist API router."""

import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.checklist import Checklist, ChecklistItem
from app.models.user import User
from app.schemas.checklist import (
    ChecklistCreate,
    ChecklistItemCreate,
    ChecklistItemUpdate,
    ChecklistResponse,
    ChecklistUpdate,
    ChecklistItemResponse,
)
from app.utils.dependencies import get_current_user

router = APIRouter()


def _build_checklist_response(checklist: Checklist, items: List[ChecklistItem]) -> ChecklistResponse:
    return ChecklistResponse(
        id=checklist.id,
        task_id=checklist.task_id,
        title=checklist.title,
        created_by=checklist.created_by,
        items=[
            ChecklistItemResponse(
                id=item.id,
                checklist_id=item.checklist_id,
                task_id=item.task_id,
                content=item.content,
                is_checked=item.is_checked,
                assignee_id=item.assignee_id,
                due_date=item.due_date,
                display_order=item.display_order,
                created_at=item.created_at,
                updated_at=item.updated_at,
            )
            for item in items
        ],
        created_at=checklist.created_at,
        updated_at=checklist.updated_at,
    )


@router.get("/task/{task_id}", response_model=List[ChecklistResponse])
async def get_checklists_by_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    checklists = (
        db.query(Checklist)
        .filter(Checklist.task_id == task_id)
        .order_by(Checklist.created_at)
        .all()
    )
    result = []
    for checklist in checklists:
        items = (
            db.query(ChecklistItem)
            .filter(ChecklistItem.checklist_id == checklist.id)
            .order_by(ChecklistItem.display_order, ChecklistItem.created_at)
            .all()
        )
        result.append(_build_checklist_response(checklist, items))
    return result


@router.post("/", response_model=ChecklistResponse, status_code=status.HTTP_201_CREATED)
async def create_checklist(
    data: ChecklistCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    new_checklist = Checklist(
        id=str(uuid.uuid4()),
        task_id=data.task_id,
        title=data.title,
        created_by=current_user.id,
    )
    db.add(new_checklist)
    db.commit()
    db.refresh(new_checklist)
    return _build_checklist_response(new_checklist, [])


@router.patch("/{checklist_id}", response_model=ChecklistResponse)
async def update_checklist(
    checklist_id: str,
    data: ChecklistUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    checklist = db.query(Checklist).filter(Checklist.id == checklist_id).first()
    if not checklist:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="체크리스트를 찾을 수 없습니다")

    checklist.title = data.title
    db.commit()
    db.refresh(checklist)

    items = (
        db.query(ChecklistItem)
        .filter(ChecklistItem.checklist_id == checklist_id)
        .order_by(ChecklistItem.display_order, ChecklistItem.created_at)
        .all()
    )
    return _build_checklist_response(checklist, items)


@router.delete("/{checklist_id}")
async def delete_checklist(
    checklist_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    checklist = db.query(Checklist).filter(Checklist.id == checklist_id).first()
    if not checklist:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="체크리스트를 찾을 수 없습니다")

    db.query(ChecklistItem).filter(ChecklistItem.checklist_id == checklist_id).delete()
    db.delete(checklist)
    db.commit()
    return {"message": "체크리스트가 삭제되었습니다"}


@router.post("/{checklist_id}/items", response_model=ChecklistItemResponse, status_code=status.HTTP_201_CREATED)
async def add_checklist_item(
    checklist_id: str,
    data: ChecklistItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    checklist = db.query(Checklist).filter(Checklist.id == checklist_id).first()
    if not checklist:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="체크리스트를 찾을 수 없습니다")

    if not data.content.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="항목 내용이 필요합니다")

    # 현재 최대 display_order 계산
    max_order_result = (
        db.query(ChecklistItem)
        .filter(ChecklistItem.checklist_id == checklist_id)
        .order_by(ChecklistItem.display_order.desc())
        .first()
    )
    next_order = (max_order_result.display_order + 1) if max_order_result else 0

    new_item = ChecklistItem(
        id=str(uuid.uuid4()),
        checklist_id=checklist_id,
        task_id=checklist.task_id,
        content=data.content.strip(),
        is_checked=False,
        display_order=next_order,
    )
    db.add(new_item)
    db.commit()
    db.refresh(new_item)
    return new_item


@router.patch("/items/{item_id}", response_model=ChecklistItemResponse)
async def update_checklist_item(
    item_id: str,
    data: ChecklistItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = db.query(ChecklistItem).filter(ChecklistItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="체크리스트 항목을 찾을 수 없습니다")

    if data.content is not None:
        if not data.content.strip():
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="항목 내용이 필요합니다")
        item.content = data.content.strip()
    if data.is_checked is not None:
        item.is_checked = data.is_checked
    if data.assignee_id is not None:
        item.assignee_id = data.assignee_id
    if data.due_date is not None:
        item.due_date = data.due_date
    if data.display_order is not None:
        item.display_order = data.display_order

    db.commit()
    db.refresh(item)
    return item


@router.delete("/items/{item_id}")
async def delete_checklist_item(
    item_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = db.query(ChecklistItem).filter(ChecklistItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="체크리스트 항목을 찾을 수 없습니다")

    db.delete(item)
    db.commit()
    return {"message": "체크리스트 항목이 삭제되었습니다"}

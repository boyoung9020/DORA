"""
태스크 관리 API 라우터
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid
from datetime import datetime
from app.database import get_db
from app.models.task import Task, TaskStatus, TaskPriority
from app.models.user import User
from app.schemas.task import TaskCreate, TaskUpdate, TaskResponse
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get("/", response_model=List[TaskResponse])
async def get_all_tasks(
    project_id: Optional[str] = None,
    status: Optional[TaskStatus] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """모든 태스크 가져오기 (필터링 옵션)"""
    query = db.query(Task)
    
    if project_id:
        query = query.filter(Task.project_id == project_id)
    if status:
        query = query.filter(Task.status == status)
    
    tasks = query.all()
    return tasks


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """특정 태스크 정보 가져오기"""
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="태스크를 찾을 수 없습니다"
        )
    return task


@router.post("/", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    task_data: TaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """새 태스크 생성"""
    new_task = Task(
        id=str(uuid.uuid4()),
        title=task_data.title,
        description=task_data.description,
        status=task_data.status,
        project_id=task_data.project_id,
        start_date=task_data.start_date,
        end_date=task_data.end_date,
        detail=task_data.detail,
        priority=task_data.priority,
        assigned_member_ids=task_data.assigned_member_ids,
        comment_ids=[],
        status_history=[],
        assignment_history=[],
        priority_history=[]
    )
    
    db.add(new_task)
    db.commit()
    db.refresh(new_task)
    return new_task


@router.patch("/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: str,
    task_data: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """태스크 정보 수정"""
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="태스크를 찾을 수 없습니다"
        )
    
    # 업데이트할 필드만 변경
    if task_data.title is not None:
        task.title = task_data.title
    if task_data.description is not None:
        task.description = task_data.description
    if task_data.status is not None:
        # 상태 변경 히스토리 추가
        old_status = task.status
        if old_status != task_data.status:
            history_entry = {
                "fromStatus": old_status.value,
                "toStatus": task_data.status.value,
                "userId": current_user.id,
                "username": current_user.username,
                "changedAt": datetime.utcnow().isoformat()
            }
            task.status_history = list(task.status_history) + [history_entry]
        task.status = task_data.status
    if task_data.start_date is not None:
        task.start_date = task_data.start_date
    if task_data.end_date is not None:
        task.end_date = task_data.end_date
    if task_data.detail is not None:
        task.detail = task_data.detail
    if task_data.priority is not None:
        # 중요도 변경 히스토리 추가
        old_priority = task.priority
        if old_priority != task_data.priority:
            history_entry = {
                "fromPriority": old_priority.value,
                "toPriority": task_data.priority.value,
                "userId": current_user.id,
                "username": current_user.username,
                "changedAt": datetime.utcnow().isoformat()
            }
            task.priority_history = list(task.priority_history) + [history_entry]
        task.priority = task_data.priority
    if task_data.assigned_member_ids is not None:
        task.assigned_member_ids = task_data.assigned_member_ids
    
    db.commit()
    db.refresh(task)
    return task


@router.delete("/{task_id}")
async def delete_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """태스크 삭제"""
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="태스크를 찾을 수 없습니다"
        )
    
    db.delete(task)
    db.commit()
    return {"message": "태스크가 삭제되었습니다"}


@router.patch("/{task_id}/status", response_model=TaskResponse)
async def change_task_status(
    task_id: str,
    new_status: TaskStatus,  # FastAPI가 쿼리 파라미터로 자동 처리
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """태스크 상태 변경"""
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="태스크를 찾을 수 없습니다"
        )
    
    old_status = task.status
    if old_status != new_status:
        history_entry = {
            "fromStatus": old_status.value,
            "toStatus": new_status.value,
            "userId": current_user.id,
            "username": current_user.username,
            "changedAt": datetime.utcnow().isoformat()
        }
        task.status_history = list(task.status_history) + [history_entry]
        task.status = new_status
        db.commit()
        db.refresh(task)
    
    return task


"""
태스크 관리 API 라우터
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid
import asyncio
from datetime import datetime
from app.database import get_db
from app.models.task import Task, TaskStatus, TaskPriority
from app.models.user import User
from app.schemas.task import TaskCreate, TaskUpdate, TaskResponse
from app.utils.dependencies import get_current_user
from app.models.project import Project
from app.utils.notifications import notify_task_assigned, notify_task_option_changed
from app.routers.websocket import manager

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
        detail_image_urls=task_data.detail_image_urls or [],
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
    
    # 프로젝트 팀원에게만 태스크 생성 이벤트 전송 (타겟 전송)
    project = db.query(Project).filter(Project.id == new_task.project_id).first()
    target_users = project.team_member_ids if project else []
    asyncio.create_task(manager.send_to_users({
        "type": "task_created",
        "data": {
            "task_id": new_task.id,
            "project_id": new_task.project_id,
        }
    }, target_users, exclude_user_id=current_user.id))
    
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
    
    # 변경된 필드 추적
    changed_fields = []
    
    # 업데이트할 필드만 변경
    if task_data.title is not None:
        task.title = task_data.title
    if task_data.description is not None:
        task.description = task_data.description
    if task_data.status is not None:
        # 상태 변경 히스토리 추가
        old_status = task.status
        if old_status != task_data.status:
            changed_fields.append('status')
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
        if task.start_date != task_data.start_date:
            changed_fields.append('start_date')
        task.start_date = task_data.start_date
    if task_data.end_date is not None:
        if task.end_date != task_data.end_date:
            changed_fields.append('end_date')
        task.end_date = task_data.end_date
    if task_data.detail is not None:
        task.detail = task_data.detail
    if task_data.detail_image_urls is not None:
        task.detail_image_urls = task_data.detail_image_urls
    if task_data.priority is not None:
        # 중요도 변경 히스토리 추가
        old_priority = task.priority
        if old_priority != task_data.priority:
            changed_fields.append('priority')
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
        # 할당 변경 히스토리 추가
        old_member_ids = set(task.assigned_member_ids or [])
        new_member_ids = set(task_data.assigned_member_ids or [])
        
        # 새로 할당된 팀원들에 대해 히스토리 추가 및 알림
        added_members = new_member_ids - old_member_ids
        if added_members:
            for member_id in added_members:
                # 할당된 사용자 정보 가져오기
                assigned_user = db.query(User).filter(User.id == member_id).first()
                assigned_username = assigned_user.username if assigned_user else "Unknown"
                
                history_entry = {
                    "assignedUserId": member_id,
                    "assignedUsername": assigned_username,
                    "assignedBy": current_user.id,
                    "assignedByUsername": current_user.username,
                    "assignedAt": datetime.utcnow().isoformat()
                }
                task.assignment_history = list(task.assignment_history) + [history_entry]
                
                # 작업 할당 알림
                notify_task_assigned(db, task, member_id, current_user)
        
        task.assigned_member_ids = task_data.assigned_member_ids
    
    # 작업 옵션 변경 알림 (중요도, 상태, 날짜 변경 시)
    if changed_fields:
        notify_task_option_changed(db, task, current_user, changed_fields)
    
    db.commit()
    db.refresh(task)
    
    # 프로젝트 팀원에게만 태스크 업데이트 이벤트 전송 (타겟 전송)
    project = db.query(Project).filter(Project.id == task.project_id).first()
    target_users = project.team_member_ids if project else []
    asyncio.create_task(manager.send_to_users({
        "type": "task_updated",
        "data": {
            "task_id": task.id,
            "project_id": task.project_id,
        }
    }, target_users, exclude_user_id=current_user.id))
    
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
        
        # 작업 옵션 변경 알림
        notify_task_option_changed(db, task, current_user, ['status'])
        
        db.commit()
        db.refresh(task)
    
    return task


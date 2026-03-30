"""
태스크 관리 API 라우터
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid
import asyncio
from datetime import datetime, timezone
from app.database import get_db
from app.models.task import Task, TaskStatus, TaskPriority
from app.models.user import User
from app.schemas.task import TaskCreate, TaskUpdate, TaskResponse, TaskReorderRequest
from app.utils.dependencies import get_current_user
from app.models.project import Project
from app.models.notification import Notification
from app.models.comment import Comment
from app.utils.notifications import notify_task_assigned, notify_task_option_changed
from sqlalchemy import or_
from app.routers.websocket import manager

router = APIRouter()


def _get_project_or_403(db: Session, project_id: str, user: User) -> Project:
    """프로젝트 조회 + 접근 권한 검증 (admin 또는 프로젝트 멤버만)"""
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="프로젝트를 찾을 수 없습니다")
    if not user.is_admin and user.id not in (project.team_member_ids or []):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="이 프로젝트에 접근 권한이 없습니다")
    return project


@router.get("/", response_model=List[TaskResponse])
async def get_all_tasks(
    project_id: Optional[str] = None,
    status: Optional[TaskStatus] = None,
    skip: int = Query(0, ge=0, description="건너뛸 항목 수"),
    limit: int = Query(200, ge=1, le=1000, description="최대 항목 수"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """태스크 가져오기 (일반 유저: 소속 프로젝트 태스크만)"""
    query = db.query(Task)

    if project_id:
        query = query.filter(Task.project_id == project_id)
    if status:
        query = query.filter(Task.status == status)

    # 일반 유저는 소속 프로젝트의 태스크만 조회
    if not current_user.is_admin and not current_user.is_pm:
        my_projects = db.query(Project.id).filter(
            Project.team_member_ids.any(current_user.id)
        ).subquery()
        query = query.filter(Task.project_id.in_(my_projects))

    tasks = query.order_by(Task.display_order.asc(), Task.created_at.desc()).offset(skip).limit(limit).all()
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
    project = _get_project_or_403(db, task_data.project_id, current_user)

    try:
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
            sprint_id=task_data.sprint_id,
            creator_id=current_user.id,
            parent_task_id=task_data.parent_task_id,
            document_links=task_data.document_links or [],
            site_tags=task_data.site_tags or [],
            comment_ids=[],
            status_history=[],
            assignment_history=[],
            priority_history=[]
        )
        db.add(new_task)
        db.commit()
        db.refresh(new_task)
    except Exception:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="태스크 생성에 실패했습니다")

    # DB 커밋 성공 후 WebSocket 이벤트 전송
    asyncio.create_task(manager.send_to_users({
        "type": "task_created",
        "data": {"task_id": new_task.id, "project_id": new_task.project_id}
    }, project.team_member_ids, exclude_user_id=current_user.id))

    return new_task


@router.patch("/reorder", response_model=List[TaskResponse])
async def reorder_tasks(
    request: TaskReorderRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """태스크 순서 변경 (task_ids 배열 순서대로 display_order 설정)"""
    for index, task_id in enumerate(request.task_ids):
        task = db.query(Task).filter(Task.id == task_id).first()
        if task:
            task.display_order = index
    db.commit()

    tasks = db.query(Task).filter(Task.id.in_(request.task_ids)).all()
    return tasks


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
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="태스크를 찾을 수 없습니다")

    # 프로젝트 접근 권한 검증
    _get_project_or_403(db, task.project_id, current_user)
    
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
                "changedAt": datetime.now(timezone.utc).isoformat()
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
    if task_data.document_links is not None:
        task.document_links = task_data.document_links
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
                "changedAt": datetime.now(timezone.utc).isoformat()
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
                    "assignedAt": datetime.now(timezone.utc).isoformat()
                }
                task.assignment_history = list(task.assignment_history) + [history_entry]
                
                # 작업 할당 알림
                notify_task_assigned(db, task, member_id, current_user)
        
        task.assigned_member_ids = task_data.assigned_member_ids
    if task_data.sprint_id is not None:
        task.sprint_id = task_data.sprint_id
    if task_data.parent_task_id is not None:
        task.parent_task_id = task_data.parent_task_id if task_data.parent_task_id != "" else None
    if task_data.site_tags is not None:
        task.site_tags = task_data.site_tags
    
    # 작업 옵션 변경 알림 (중요도, 상태, 날짜 변경 시)
    if changed_fields:
        notify_task_option_changed(db, task, current_user, changed_fields)
    
    try:
        db.commit()
        db.refresh(task)
    except Exception:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="태스크 수정에 실패했습니다")

    # DB 커밋 성공 후 WebSocket 이벤트 전송
    project = db.query(Project).filter(Project.id == task.project_id).first()
    if project:
        asyncio.create_task(manager.send_to_users({
            "type": "task_updated",
            "data": {"task_id": task.id, "project_id": task.project_id}
        }, project.team_member_ids, exclude_user_id=current_user.id))

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
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="태스크를 찾을 수 없습니다")

    # 프로젝트 접근 권한 검증 (PM, admin, 또는 태스크 생성자만 삭제 가능)
    project = _get_project_or_403(db, task.project_id, current_user)
    is_pm = project.creator_id == current_user.id
    is_task_creator = task.creator_id == current_user.id
    if not current_user.is_admin and not is_pm and not is_task_creator:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="태스크 삭제는 PM, 관리자, 또는 태스크 생성자만 가능합니다")

    try:
        # 관련 댓글 ID 조회
        comment_ids = [c.id for c in db.query(Comment.id).filter(Comment.task_id == task_id).all()]
        # 관련 알림 삭제
        noti_filter = Notification.task_id == task_id
        if comment_ids:
            noti_filter = or_(noti_filter, Notification.comment_id.in_(comment_ids))
        db.query(Notification).filter(noti_filter).delete(synchronize_session=False)
        # 관련 댓글 삭제
        db.query(Comment).filter(Comment.task_id == task_id).delete(synchronize_session=False)
        # 태스크 삭제
        db.delete(task)
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="태스크 삭제에 실패했습니다")

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
            "changedAt": datetime.now(timezone.utc).isoformat()
        }
        task.status_history = list(task.status_history) + [history_entry]
        task.status = new_status

        # 작업 옵션 변경 알림
        notify_task_option_changed(db, task, current_user, ['status'])

        db.commit()
        db.refresh(task)

    return task


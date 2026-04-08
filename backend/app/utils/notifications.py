"""
알림 생성 유틸리티
"""
import asyncio
import uuid
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy.orm import Session

from app.models.notification import Notification, NotificationType
from app.models.project import Project
from app.models.task import Task
from app.models.user import User
from app.utils.mattermost import send_mattermost_notification


def create_notification(
    db: Session,
    notification_type: NotificationType,
    user_id: str,
    title: str,
    message: str,
    project_id: str = None,
    task_id: str = None,
    comment_id: str = None
) -> Notification:
    """알림 생성"""
    notification = Notification(
        id=str(uuid.uuid4()),
        type=notification_type,
        user_id=user_id,
        project_id=project_id,
        task_id=task_id,
        comment_id=comment_id,
        title=title,
        message=message,
        is_read=False
    )
    
    db.add(notification)
    db.commit()
    db.refresh(notification)

    # Mattermost 웹훅 전송 (사용자별 설정 확인)
    try:
        send_mattermost_notification(
            db=db,
            user_id=user_id,
            notification_type=notification_type,
            title=title,
            message=message,
        )
    except Exception as e:
        print(f"[Mattermost] 알림 전송 오류: {e}")

    # Push realtime notification event to the target user.
    try:
        from app.routers.websocket import manager

        asyncio.create_task(
            manager.send_to_user(
                {
                    "type": "notification_created",
                    "data": {
                        "id": notification.id,
                        "type": notification.type.value,
                        "user_id": notification.user_id,
                        "project_id": notification.project_id,
                        "task_id": notification.task_id,
                        "comment_id": notification.comment_id,
                        "title": notification.title,
                        "message": notification.message,
                        "is_read": notification.is_read,
                        "created_at": notification.created_at.isoformat()
                        if notification.created_at
                        else None,
                    },
                },
                notification.user_id,
            )
        )
    except Exception as e:
        print(f"[Notification] websocket push failed: {e}")

    return notification


def notify_project_member_added(
    db: Session,
    project: Project,
    added_user_id: str,
    added_by_user: User
):
    """프로젝트 팀원 추가 알림"""
    project_name = project.name
    added_user = db.query(User).filter(User.id == added_user_id).first()
    if not added_user:
        return
    
    title = f"프로젝트 '{project_name}'에 팀원으로 추가되었습니다"
    message = f"{added_by_user.username}님이 '{project_name}' 프로젝트에 당신을 팀원으로 추가했습니다."
    
    create_notification(
        db=db,
        notification_type=NotificationType.PROJECT_MEMBER_ADDED,
        user_id=added_user_id,
        title=title,
        message=message,
        project_id=project.id
    )


def notify_task_created(
    db: Session,
    task: Task,
    project: Project,
    created_by_user: User
):
    """새 작업 생성 알림 — 프로젝트 팀원 전체 (생성자 제외)"""
    # 팀원 + 프로젝트 생성자(PM) 모두에게 알림, 중복 제거
    recipients = set(project.team_member_ids or [])
    if project.creator_id:
        recipients.add(project.creator_id)
    recipients.discard(created_by_user.id)  # 본인 제외

    for user_id in recipients:
        create_notification(
            db=db,
            notification_type=NotificationType.TASK_CREATED,
            user_id=user_id,
            title=f"[{project.name}] 새 작업이 추가되었습니다",
            message=f"{created_by_user.username}님이 '{task.title}' 작업을 추가했습니다.",
            project_id=task.project_id,
            task_id=task.id,
        )


def notify_task_assigned(
    db: Session,
    task: Task,
    assigned_user_id: str,
    assigned_by_user: User
):
    """작업 할당 알림"""
    task_title = task.title
    assigned_user = db.query(User).filter(User.id == assigned_user_id).first()
    if not assigned_user:
        return
    
    title = f"작업 '{task_title}'의 할당자로 임명되었습니다"
    message = f"{assigned_by_user.username}님이 '{task_title}' 작업의 할당자로 당신을 임명했습니다."
    
    create_notification(
        db=db,
        notification_type=NotificationType.TASK_ASSIGNED,
        user_id=assigned_user_id,
        title=title,
        message=message,
        project_id=task.project_id,
        task_id=task.id
    )


def _task_status_ko(api_value: str) -> str:
    return {
        "backlog": "백로그",
        "ready": "준비됨",
        "inProgress": "진행 중",
        "inReview": "검토 중",
        "done": "완료",
    }.get(api_value, api_value)


def _priority_ko(api_value: str) -> str:
    return {
        "p0": "P0(최우선)",
        "p1": "P1",
        "p2": "P2",
        "p3": "P3",
    }.get(api_value, api_value)


def _fmt_task_date(value: Any) -> str:
    if value is None:
        return "미지정"
    if isinstance(value, datetime):
        return value.date().isoformat()
    if isinstance(value, date):
        return value.isoformat()
    return str(value)


def notify_task_option_changed(
    db: Session,
    task: Task,
    changed_by_user: User,
    changed_fields: list,
    *,
    transitions: Optional[Dict[str, Tuple[Any, Any]]] = None,
):
    """작업 옵션 변경 알림 (중요도, 상태, 날짜).

    transitions 예: {'status': ('backlog', 'inProgress'), 'priority': ('p2', 'p0')}
    """
    task_title = task.title
    transitions = transitions or {}
    field_names = {
        "priority": "중요도",
        "status": "상태",
        "start_date": "시작일",
        "end_date": "종료일",
    }
    parts: List[str] = []
    for field in changed_fields:
        if field == "status" and field in transitions:
            old_v, new_v = transitions[field]
            parts.append(
                f"상태를 {_task_status_ko(str(old_v))}에서 {_task_status_ko(str(new_v))}으로"
            )
        elif field == "priority" and field in transitions:
            old_v, new_v = transitions[field]
            parts.append(
                f"중요도를 {_priority_ko(str(old_v))}에서 {_priority_ko(str(new_v))}으로"
            )
        elif field == "start_date" and field in transitions:
            old_v, new_v = transitions[field]
            parts.append(
                f"시작일을 {_fmt_task_date(old_v)}에서 {_fmt_task_date(new_v)}으로"
            )
        elif field == "end_date" and field in transitions:
            old_v, new_v = transitions[field]
            parts.append(
                f"종료일을 {_fmt_task_date(old_v)}에서 {_fmt_task_date(new_v)}으로"
            )
        else:
            parts.append(f"{field_names.get(field, field)}을(를)")

    detail = ", ".join(parts)
    message = (
        f"{changed_by_user.username}님이 '{task_title}' 작업의 {detail} 변경했습니다."
    )

    for assigned_user_id in task.assigned_member_ids:
        title = f"작업 '{task_title}'의 옵션이 변경되었습니다"
        create_notification(
            db=db,
            notification_type=NotificationType.TASK_OPTION_CHANGED,
            user_id=assigned_user_id,
            title=title,
            message=message,
            project_id=task.project_id,
            task_id=task.id,
        )


def notify_task_comment_added(
    db: Session,
    task: Task,
    comment_author: User,
    comment_id: str
):
    """작업 코멘트 추가 알림"""
    task_title = task.title
    
    # 할당된 모든 사용자에게 알림 (코멘트 작성자 제외)
    for assigned_user_id in task.assigned_member_ids:
        if assigned_user_id == comment_author.id:
            continue  # 본인이 작성한 코멘트는 알림 안 보냄
        
        title = f"작업 '{task_title}'에 새로운 코멘트가 추가되었습니다"
        message = f"{comment_author.username}님이 '{task_title}' 작업에 코멘트를 남겼습니다."
        
        create_notification(
            db=db,
            notification_type=NotificationType.TASK_COMMENT_ADDED,
            user_id=assigned_user_id,
            title=title,
            message=message,
            project_id=task.project_id,
            task_id=task.id,
            comment_id=comment_id
        )


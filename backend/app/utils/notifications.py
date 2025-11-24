"""
알림 생성 유틸리티
"""
from sqlalchemy.orm import Session
from app.models.notification import Notification, NotificationType
from app.models.project import Project
from app.models.task import Task
from app.models.user import User
import uuid


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


def notify_task_option_changed(
    db: Session,
    task: Task,
    changed_by_user: User,
    changed_fields: list  # ['priority', 'status', 'start_date', 'end_date']
):
    """작업 옵션 변경 알림 (중요도, 상태, 날짜)"""
    task_title = task.title
    field_names = {
        'priority': '중요도',
        'status': '상태',
        'start_date': '시작일',
        'end_date': '종료일'
    }
    
    changed_field_names = [field_names.get(field, field) for field in changed_fields]
    changed_fields_str = ', '.join(changed_field_names)
    
    # 할당된 모든 사용자에게 알림
    for assigned_user_id in task.assigned_member_ids:
        title = f"작업 '{task_title}'의 옵션이 변경되었습니다"
        message = f"{changed_by_user.username}님이 '{task_title}' 작업의 {changed_fields_str}을(를) 변경했습니다."
        
        create_notification(
            db=db,
            notification_type=NotificationType.TASK_OPTION_CHANGED,
            user_id=assigned_user_id,
            title=title,
            message=message,
            project_id=task.project_id,
            task_id=task.id
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


"""AI manager summary router."""

import asyncio
from datetime import datetime, timezone
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.notification import Notification, NotificationType
from app.models.project import Project
from app.models.task import Task, TaskPriority, TaskStatus
from app.models.user import User
from app.schemas.ai import AISummaryResponse
from app.utils.dependencies import get_current_user

router = APIRouter()


def _status_label(status_value: str) -> str:
    mapping = {
        TaskStatus.BACKLOG.value: "백로그",
        TaskStatus.READY.value: "준비됨",
        TaskStatus.IN_PROGRESS.value: "진행 중",
        TaskStatus.IN_REVIEW.value: "검토 중",
        TaskStatus.DONE.value: "완료",
    }
    return mapping.get(status_value, status_value)


def _priority_label(priority_value: str) -> str:
    mapping = {
        TaskPriority.P0.value: "P0",
        TaskPriority.P1.value: "P1",
        TaskPriority.P2.value: "P2",
        TaskPriority.P3.value: "P3",
    }
    return mapping.get(priority_value, priority_value)


def _notification_type_label(ntype: NotificationType) -> str:
    mapping = {
        NotificationType.PROJECT_MEMBER_ADDED: "프로젝트 추가",
        NotificationType.TASK_ASSIGNED: "작업 할당",
        NotificationType.TASK_OPTION_CHANGED: "작업 변경",
        NotificationType.TASK_COMMENT_ADDED: "새 댓글",
        NotificationType.TASK_MENTIONED: "멘션",
    }
    return mapping.get(ntype, ntype.value)


def _build_prompt(
    username: str,
    project_stats: List[Dict[str, object]],
    urgent_tasks: List[Task],
    today_due_tasks: List[Task],
    overdue_tasks: List[Task],
    project_name_by_id: Dict[str, str],
    unread_notifications: List[Notification],
) -> str:
    today = datetime.now().astimezone().strftime("%Y-%m-%d")

    project_lines = []
    for stat in project_stats:
        project_lines.append(
            f"- **{stat['name']}** {stat['done']}/{stat['total']} 완료 ({stat['progress']}%), "
            f"진행중 {stat['in_progress']}개, 검토중 {stat['in_review']}개"
        )

    urgent_lines = []
    for task in urgent_tasks[:10]:
        end_date = task.end_date.astimezone().strftime("%Y-%m-%d") if task.end_date else "미지정"
        urgent_lines.append(
            f"- \"{task.title}\" **{project_name_by_id.get(task.project_id, '미분류')}** "
            f"우선순위:{_priority_label(task.priority.value)} 상태:{_status_label(task.status.value)} 기한:{end_date}"
        )

    today_due_lines = []
    for task in today_due_tasks[:10]:
        today_due_lines.append(
            f"- \"{task.title}\" **{project_name_by_id.get(task.project_id, '미분류')}** "
            f"상태:{_status_label(task.status.value)}"
        )

    overdue_lines = []
    for task in overdue_tasks[:10]:
        if not task.end_date:
            continue
        overdue_days = (datetime.now().astimezone().date() - task.end_date.astimezone().date()).days
        overdue_lines.append(
            f"- \"{task.title}\" **{project_name_by_id.get(task.project_id, '미분류')}** "
            f"{max(overdue_days, 0)}일 초과"
        )

    notif_lines = []
    for notif in unread_notifications[:15]:
        notif_lines.append(
            f"- [{_notification_type_label(notif.type)}] {notif.title}: {notif.message}"
        )

    prompt = f"""
[시스템]
당신은 프로젝트 매니저 AI입니다. 아래 데이터는 '{username}'님 개인의 업무 현황입니다.
'{username}'님에게 직접 말하듯 오늘의 업무 브리핑을 해주세요. 절대 "팀원 여러분" 같은 표현은 쓰지 마세요.
형식: 한 줄 총평 + 주요 사항 불릿(최대 5개). 간결하고 친근한 한국어.

[데이터]
오늘 날짜: {today}
담당자: {username}

=== 프로젝트 현황 ===
{chr(10).join(project_lines) if project_lines else "- 참여 중인 프로젝트가 없습니다"}

=== 긴급 태스크 (P0/P1) ===
{chr(10).join(urgent_lines) if urgent_lines else "- 없음"}

=== 오늘 마감 ===
{chr(10).join(today_due_lines) if today_due_lines else "- 없음"}

=== 기한 초과 ===
{chr(10).join(overdue_lines) if overdue_lines else "- 없음"}

=== 미확인 알림 ===
{chr(10).join(notif_lines) if notif_lines else "- 없음"}

[출력 요구사항]
- 총 2~4문장 분량으로 작성
- 첫 줄은 전체 분위기 요약
- 이후 핵심 포인트를 불릿으로 제시
- 과장 없이 우선순위가 높은 일부터 언급
- 프로젝트명은 **프로젝트명** 형식(마크다운 굵게)으로 표시
""".strip()

    return prompt


@router.get("/summary", response_model=AISummaryResponse)
async def get_ai_summary(
    workspace_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="GEMINI_API_KEY가 설정되지 않았습니다.",
        )

    project_query = db.query(Project)
    if workspace_id:
        project_query = project_query.filter(Project.workspace_id == workspace_id)

    if not current_user.is_admin:
        project_query = project_query.filter(Project.team_member_ids.any(current_user.id))

    projects = project_query.all()
    project_ids = [project.id for project in projects]
    project_name_by_id = {project.id: project.name for project in projects}

    tasks: List[Task] = []
    if project_ids:
        tasks = db.query(Task).filter(Task.project_id.in_(project_ids)).all()

    stats: List[Dict[str, object]] = []
    for project in projects:
        project_tasks = [task for task in tasks if task.project_id == project.id]
        total = len(project_tasks)
        done = sum(1 for task in project_tasks if task.status == TaskStatus.DONE)
        in_progress = sum(1 for task in project_tasks if task.status == TaskStatus.IN_PROGRESS)
        in_review = sum(1 for task in project_tasks if task.status == TaskStatus.IN_REVIEW)
        backlog = sum(1 for task in project_tasks if task.status == TaskStatus.BACKLOG)
        progress = int((done / total) * 100) if total > 0 else 0
        stats.append(
            {
                "name": project.name,
                "total": total,
                "done": done,
                "in_progress": in_progress,
                "in_review": in_review,
                "backlog": backlog,
                "progress": progress,
            }
        )

    today_local = datetime.now().astimezone().date()
    assigned_to_me = [task for task in tasks if current_user.id in (task.assigned_member_ids or [])]

    urgent_tasks = [
        task
        for task in assigned_to_me
        if task.status != TaskStatus.DONE
        and task.priority in (TaskPriority.P0, TaskPriority.P1)
    ]
    today_due_tasks = [
        task
        for task in assigned_to_me
        if task.status != TaskStatus.DONE
        and task.end_date
        and task.end_date.astimezone().date() == today_local
    ]
    overdue_tasks = [
        task
        for task in assigned_to_me
        if task.status != TaskStatus.DONE
        and task.end_date
        and task.end_date.astimezone().date() < today_local
    ]

    unread_notifications = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.is_read.is_(False),
        )
        .order_by(Notification.created_at.desc())
        .limit(15)
        .all()
    )

    prompt = _build_prompt(
        username=current_user.username,
        project_stats=stats,
        urgent_tasks=urgent_tasks,
        today_due_tasks=today_due_tasks,
        overdue_tasks=overdue_tasks,
        project_name_by_id=project_name_by_id,
        unread_notifications=unread_notifications,
    )

    try:
        from google import genai
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"AI 라이브러리를 불러오지 못했습니다: {e}",
        ) from e

    try:
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        response = await asyncio.to_thread(
            client.models.generate_content,
            model="gemini-2.5-flash",
            contents=prompt,
        )
        summary = (response.text or "").strip()
        if not summary:
            summary = "오늘 브리핑을 생성하지 못했습니다. 잠시 후 다시 시도해 주세요."
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"AI 요약 생성에 실패했습니다: {e}",
        ) from e

    return AISummaryResponse(summary=summary, generated_at=datetime.now(timezone.utc))

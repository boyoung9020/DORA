"""AI manager summary router."""

import asyncio
import uuid
from datetime import datetime, timezone, timedelta

# 한국 표준시 (UTC+9) — 캐시의 "하루" 기준을 KST로 고정
_KST = timezone(timedelta(hours=9))
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models.ai_summary_cache import AiSummaryCache
from app.models.notification import Notification, NotificationType
from app.models.project import Project
from app.models.task import Task, TaskPriority, TaskStatus
from app.models.user import User
from app.schemas.ai import AISummaryResponse, AIExportRequest, AIExportResponse
from app.utils.dependencies import get_current_user

router = APIRouter()

# 2.5가 부하로 503을 자주 내면 순차 시도
_GEMINI_MODEL_CHAIN: tuple[str, ...] = (
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-1.5-flash",
)


def _friendly_gemini_http_detail(exc: BaseException, prefix: str) -> str:
    """클라이언트에 노출할 사용자 친화적 메시지 (내부 스택/원문 최소화).

    Gemini API 의 주요 실패 케이스를 사용자 언어로 매핑한다.
    매칭 안 되면 원본 메시지를 일정 길이로 잘라 노출.
    """
    s = str(exc).lower()

    # 1) 토큰/할당량 소진 — 429 RESOURCE_EXHAUSTED, "quota exceeded", "rate limit"
    if (
        "quota" in s
        or "rate limit" in s
        or "ratelimit" in s
        or "429" in s
        or ("limit" in s and "exceed" in s)
    ):
        return (
            f"{prefix}: Gemini API 사용 한도(쿼터)를 모두 소진했습니다. "
            "관리자에게 문의하거나 결제 한도를 확인해 주세요."
        )

    # 2) API 키 인증 실패 — 401 / 403 / "api key not valid"
    if (
        "api key" in s
        or "api_key" in s
        or "unauthenticated" in s
        or "permission_denied" in s
        or "permission denied" in s
        or "401" in s
        or "403" in s
    ):
        return (
            f"{prefix}: Gemini API 키가 유효하지 않거나 권한이 없습니다. "
            "관리자에게 키 설정을 확인해 달라고 요청해 주세요."
        )

    # 3) 서버 과부하 / 일시 장애 — 5xx
    if (
        "high demand" in s
        or "resource exhausted" in s
        or "overloaded" in s
        or "503" in s
        or "502" in s
        or "504" in s
        or "unavailable" in s
        or "internal server error" in s
    ):
        return (
            f"{prefix}: AI 서버가 일시적으로 혼잡합니다. "
            "잠시 후 다시 시도해 주세요."
        )

    # 4) 네트워크 / 타임아웃 — DNS, connection refused, timeout
    if (
        "timeout" in s
        or "timed out" in s
        or "connection" in s
        or "network" in s
        or "dns" in s
        or "unreachable" in s
    ):
        return (
            f"{prefix}: AI 서버에 연결하지 못했습니다. "
            "네트워크 상태를 확인하고 잠시 후 다시 시도해 주세요."
        )

    # 5) 콘텐츠 안전 필터 차단 — Gemini safety
    if (
        "safety" in s
        or "blocked" in s
        or "harm_category" in s
        or "prohibited" in s
    ):
        return (
            f"{prefix}: AI 가 응답을 안전 정책상 차단했습니다. "
            "내용에 민감한 표현이 있는지 확인해 주세요."
        )

    # 6) 빈 응답
    if "빈 응답" in s or "empty" in s:
        return f"{prefix}: AI 가 빈 응답을 반환했습니다. 잠시 후 다시 시도해 주세요."

    # 7) 그 외 — 원문을 짧게 (스택 트레이스/내부 경로 노출 방지)
    raw = str(exc).strip()
    if len(raw) > 200:
        raw = raw[:200] + "…"
    return f"{prefix}: {raw}"


async def _generate_with_gemini_model_fallback(
    client: Any,
    contents: str,
) -> str:
    """여러 Flash 모델을 순서대로 시도 (한 모델이 503이어도 다른 모델이 될 수 있음)."""
    last_err: Optional[BaseException] = None
    for i, model in enumerate(_GEMINI_MODEL_CHAIN):
        try:
            response = await asyncio.to_thread(
                client.models.generate_content,
                model=model,
                contents=contents,
            )
            text = (response.text or "").strip()
            if text:
                return text
            last_err = RuntimeError("빈 응답")
        except Exception as e:
            last_err = e
        if i < len(_GEMINI_MODEL_CHAIN) - 1:
            await asyncio.sleep(1.0)
    if last_err is not None:
        raise last_err
    raise RuntimeError("AI 응답 없음")


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


def _tasks_for_summary_scope(tasks: List[Task], user_id: str, scope: str) -> List[Task]:
    """요약 범위: mine=내 할당, others=다른 사람 할당(미할당 제외), all=전체."""
    if scope == "mine":
        return [t for t in tasks if user_id in (t.assigned_member_ids or [])]
    if scope == "others":
        return [
            t
            for t in tasks
            if (t.assigned_member_ids or [])
            and user_id not in (t.assigned_member_ids or [])
        ]
    return list(tasks)


def _build_prompt(
    username: str,
    project_stats: List[Dict[str, object]],
    urgent_tasks: List[Task],
    today_due_tasks: List[Task],
    overdue_tasks: List[Task],
    project_name_by_id: Dict[str, str],
    unread_notifications: List[Notification],
    summary_scope: str = "all",
) -> str:
    today = datetime.now(_KST).strftime("%Y-%m-%d")

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
        overdue_days = (datetime.now(_KST).date() - task.end_date.astimezone(_KST).date()).days
        overdue_lines.append(
            f"- \"{task.title}\" **{project_name_by_id.get(task.project_id, '미분류')}** "
            f"{max(overdue_days, 0)}일 초과"
        )

    notif_lines = []
    for notif in unread_notifications[:15]:
        notif_lines.append(
            f"- [{_notification_type_label(notif.type)}] {notif.title}: {notif.message}"
        )

    if summary_scope == "mine":
        scope_intro = (
            f"아래 데이터는 '{username}'님에게 **할당된 작업** 위주입니다. "
            f"'{username}'님에게 직접 말하듯 오늘의 업무 브리핑을 해주세요. "
            "절대 \"팀원 여러분\" 같은 표현은 쓰지 마세요."
        )
    elif summary_scope == "others":
        scope_intro = (
            "아래 데이터는 참여 중인 프로젝트에서 **다른 팀원에게 할당된 작업**입니다. "
            f"'{username}'님 본인에게 할당된 작업은 제외되었습니다. "
            "동료들의 진행 상황을 간결하게 브리핑해 주세요."
        )
    else:
        scope_intro = (
            f"아래 데이터는 참여 중인 프로젝트의 **전체 작업** 현황입니다. "
            f"'{username}'님에게 직접 말하듯 오늘의 업무 브리핑을 해주세요. "
            "절대 \"팀원 여러분\" 같은 표현은 쓰지 마세요."
        )

    prompt = f"""
[시스템]
당신은 프로젝트 매니저 AI입니다. {scope_intro}
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
    summary_scope: str = Query(
        "all",
        description="요약 범위: mine(내 할당), others(다른 팀원 할당), all(전체)",
    ),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="GEMINI_API_KEY가 설정되지 않았습니다.",
        )

    scope = (summary_scope or "all").lower().strip()
    if scope not in ("mine", "others", "all"):
        scope = "all"

    today = datetime.now(_KST).date()

    # 오늘 이미 생성한 요약이 있으면 무조건 캐시 반환 (새로고침 포함)
    cached = (
        db.query(AiSummaryCache)
        .filter(
            AiSummaryCache.user_id == current_user.id,
            AiSummaryCache.workspace_id == (workspace_id or None),
            AiSummaryCache.summary_scope == scope,
            AiSummaryCache.summary_date == today,
        )
        .first()
    )
    if cached:
        return AISummaryResponse(
            summary=cached.summary_text,
            generated_at=cached.generated_at,
            from_cache=True,
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

    scoped_tasks = _tasks_for_summary_scope(tasks, current_user.id, scope)

    stats: List[Dict[str, object]] = []
    for project in projects:
        project_tasks = [task for task in scoped_tasks if task.project_id == project.id]
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

    today_local = datetime.now(_KST).date()

    urgent_tasks = [
        task
        for task in scoped_tasks
        if task.status != TaskStatus.DONE
        and task.priority in (TaskPriority.P0, TaskPriority.P1)
    ]
    today_due_tasks = [
        task
        for task in scoped_tasks
        if task.status != TaskStatus.DONE
        and task.end_date
        and task.end_date.astimezone().date() == today_local
    ]
    overdue_tasks = [
        task
        for task in scoped_tasks
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
        summary_scope=scope,
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
        summary = await _generate_with_gemini_model_fallback(client, prompt)
        if not summary:
            summary = "오늘 브리핑을 생성하지 못했습니다. 잠시 후 다시 시도해 주세요."
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=_friendly_gemini_http_detail(e, "AI 요약 생성에 실패했습니다"),
        ) from e

    now_utc = datetime.now(timezone.utc)

    db.add(AiSummaryCache(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        workspace_id=workspace_id or None,
        summary_scope=scope,
        summary_date=today,
        summary_text=summary,
        generated_at=now_utc,
    ))
    db.commit()

    return AISummaryResponse(summary=summary, generated_at=now_utc, from_cache=False)


def _build_export_prompt(
    title: str,
    tasks_by_project: Dict[str, List[Dict]],
    holding_count: int,
    in_progress_count: int,
    done_count: int,
    example_format: str,
    output_format: str = "docs",
) -> str:
    if output_format == "md":
        format_rule = (
            "마크다운 형식으로 작성하세요:\n"
            "   - 보고서 제목은 ## (h2)로 작성\n"
            "   - 프로젝트명은 ### (h3)로 작성\n"
            "   - 섹션 구분(📌 투입 프로젝트 진행 요약 등)은 **굵게** 처리\n"
            "   - 작업 목록은 - 불릿 리스트로 작성\n"
            "   - 중요 키워드나 상태(완료, 보류, 진행중 등)는 **굵게** 처리\n"
            "   - 상태 카운트 줄은 그대로 텍스트로 작성"
        )
    else:
        format_rule = (
            "마크다운 문법(#, **, - 등)을 절대 사용하지 마세요. 일반 텍스트로만 작성하세요. "
            "Google Docs에 붙여넣기 좋은 순수 텍스트 형식으로 작성하세요. "
            "양식 예시의 들여쓰기와 줄바꿈을 정확히 따르세요."
        )

    task_data_lines = []
    for project_name, tasks in tasks_by_project.items():
        task_data_lines.append(f"\n=== {project_name} ===")
        for t in tasks:
            line = (
                f"- [{t['status']}] {t['title']}  "
                f"우선순위:{t['priority']}  기간:{t['period']}"
            )
            if t.get('assignees'):
                line += f"  담당:{t['assignees']}"
            if t.get('parent_task'):
                line += f"  상위작업:{t['parent_task']}"
            if t.get('description'):
                line += f"\n  설명: {t['description']}"
            if t.get('detail'):
                line += f"\n  상세: {t['detail']}"
            task_data_lines.append(line)

    return f"""
[시스템]
당신은 프로젝트 매니저 업무 보고서 작성 AI입니다.
아래 작업 데이터를 기반으로 업무 보고서를 작성하세요.

[출력 양식 예시 - 반드시 이 형식과 스타일을 정확히 따르세요]
{example_format}

[규칙]
1. 위 양식의 구조, 들여쓰기, 줄바꿈 스타일을 정확히 따라야 합니다.
2. 첫 줄은 제목: "{title}"
3. 빈 줄 2개 후 상태 카운트: "홀딩: {holding_count}    진행: {in_progress_count}    완료: {done_count}"
4. "📌 투입 프로젝트 진행 요약" 헤더를 쓰세요.
5. 프로젝트명을 적고, 그 아래에 해당 프로젝트의 작업들을 서술형으로 정리하세요.
6. 양식 예시처럼 각 작업은 "작업제목 - 상황 설명" 또는 "작업제목" 후 다음 줄에 상세 설명 형식으로 쓰세요.
7. 예시에서처럼 "차주까지 처리 목표", "금주까지 처리 목표", "확인 중", "완료", "보류" 등 실무적 표현을 사용하세요.
8. 완료된 작업은 "완료"로 명시하고, 진행중인 작업은 현재 상황과 목표를 함께 쓰세요.
9. {format_rule}
10. 데이터에 없는 내용을 지어내지 마세요. 작업 데이터에 있는 내용만 사용하세요.
11. 프로젝트 내 작업이 여러 개면 양식 예시처럼 자연스럽게 묶어서 정리하세요.
12. "상세" 필드가 있으면 작업의 구체적 진행 상황으로 활용하세요. 보고서에 핵심 내용을 반영하세요.
13. "담당" 필드가 있으면 누가 해당 작업을 맡고 있는지 자연스럽게 포함하세요 (예: "김철수 - 작업명 진행중").
14. "상위작업" 필드가 있으면 하위 작업들을 상위 작업 아래로 묶어 정리하세요.

[작업 데이터]
{chr(10).join(task_data_lines)}
""".strip()


@router.post("/export-report", response_model=AIExportResponse)
async def generate_export_report(
    req: AIExportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="GEMINI_API_KEY가 설정되지 않았습니다.",
        )

    # 접근 가능한 프로젝트만 (AI 요약 GET /summary 와 동일 규칙)
    project_query = db.query(Project)
    if req.workspace_id:
        project_query = project_query.filter(Project.workspace_id == req.workspace_id)
    if not current_user.is_admin:
        project_query = project_query.filter(Project.team_member_ids.any(current_user.id))

    allowed_projects = project_query.all()
    allowed_by_id = {p.id: p for p in allowed_projects}

    if req.project_ids:
        requested = [pid for pid in req.project_ids if pid in allowed_by_id]
        projects = [allowed_by_id[pid] for pid in requested]
    else:
        projects = list(allowed_projects)

    project_name_by_id = {p.id: p.name for p in projects}
    project_ids = [p.id for p in projects]

    if not project_ids:
        return AIExportResponse(
            report="보낼 수 있는 프로젝트가 없습니다. 참여 중인 프로젝트를 선택했는지 확인해 주세요.",
            generated_at=datetime.now(timezone.utc),
        )

    # 작업 조회 (기간 필터)
    task_query = db.query(Task).filter(Task.project_id.in_(project_ids))

    start_dt = datetime.fromisoformat(req.start_date).replace(tzinfo=timezone.utc) if req.start_date else None
    end_dt = datetime.fromisoformat(req.end_date).replace(hour=23, minute=59, second=59, tzinfo=timezone.utc) if req.end_date else None

    if start_dt and end_dt:
        # 기간이 겹치는 작업
        task_query = task_query.filter(
            (Task.start_date <= end_dt) | (Task.start_date.is_(None)),
            (Task.end_date >= start_dt) | (Task.end_date.is_(None)),
        )

    tasks = task_query.all()

    assignee_ids = [x for x in (req.assignee_ids or []) if x]
    if assignee_ids:
        aid_set = set(assignee_ids)
        tasks = [
            t
            for t in tasks
            if aid_set.intersection(set(t.assigned_member_ids or []))
        ]
    else:
        scope = (req.task_scope or "all").lower().strip()
        if scope not in ("mine", "others", "all"):
            scope = "all"
        if scope != "all":
            tasks = _tasks_for_summary_scope(tasks, current_user.id, scope)

    # 상태별 카운트
    holding = sum(1 for t in tasks if t.status in (TaskStatus.BACKLOG, TaskStatus.READY))
    in_progress = sum(1 for t in tasks if t.status in (TaskStatus.IN_PROGRESS, TaskStatus.IN_REVIEW))
    done = sum(1 for t in tasks if t.status == TaskStatus.DONE)

    # 담당자 이름 조회용 맵
    all_member_ids = set()
    for t in tasks:
        all_member_ids.update(t.assigned_member_ids or [])
    user_name_by_id: Dict[str, str] = {}
    if all_member_ids:
        users = db.query(User).filter(User.id.in_(list(all_member_ids))).all()
        user_name_by_id = {u.id: u.username for u in users}

    # 상위 작업 제목 조회용 맵
    task_title_by_id = {t.id: t.title for t in tasks}
    parent_ids_to_fetch = set()
    for t in tasks:
        if t.parent_task_id and t.parent_task_id not in task_title_by_id:
            parent_ids_to_fetch.add(t.parent_task_id)
    if parent_ids_to_fetch:
        parent_tasks = db.query(Task.id, Task.title).filter(Task.id.in_(list(parent_ids_to_fetch))).all()
        for pt in parent_tasks:
            task_title_by_id[pt.id] = pt.title

    # 프로젝트별 그룹핑
    tasks_by_project: Dict[str, List[Dict]] = {}
    for t in tasks:
        p_name = project_name_by_id.get(t.project_id, "미분류")
        if p_name not in tasks_by_project:
            tasks_by_project[p_name] = []

        period = ""
        if t.start_date or t.end_date:
            s = t.start_date.strftime("%m/%d") if t.start_date else "?"
            e = t.end_date.strftime("%m/%d") if t.end_date else "?"
            period = f"{s} ~ {e}"

        # 담당자 이름 리스트
        assignees = [user_name_by_id.get(uid, "") for uid in (t.assigned_member_ids or [])]
        assignees = [a for a in assignees if a]

        # 상위 작업 제목
        parent_title = ""
        if t.parent_task_id:
            parent_title = task_title_by_id.get(t.parent_task_id, "")

        # 상세 내용 (200자 제한)
        detail = (t.detail or "").strip()
        if len(detail) > 200:
            detail = detail[:200] + "..."

        tasks_by_project[p_name].append({
            "title": t.title,
            "status": _status_label(t.status.value),
            "priority": _priority_label(t.priority.value),
            "period": period or "미지정",
            "description": t.description or "",
            "detail": detail,
            "assignees": ", ".join(assignees) if assignees else "",
            "parent_task": parent_title,
        })

    example_format = """260317 AI 업무 보고


홀딩    진행     완료
📌 투입 프로젝트 진행 요약
AI Meta
MBC AI Meta - 차주까지 처리 목표
얼굴인식 메모리 사용 최적화 보류 (AI 타이틀 얼굴인식 메모리 누수 우선 처리)
서울삼성병원 AI meta - 금주까지 처리 목표
본사 개발환경에서 AI 서비스 연동 중 에러. 확인 중..
SBS NDS AI meta - 수요일 작업 예정
금주 VectorDB Milvus 관련해서 이중화 구성 요청 받음 (신진범 과장).
KBS AI QC
테스트 영상 다시 요청 드림 (성민효 차장)
YNA
프레임 보간
8개 운영서버에 배포 시나리오 작성 및 확인 중
AI Title  - 금주까지 처리 목표
메모리 누수 지난주에 이어 확인중
RAPA AI 데이터 라벨링 사업
IDC 백업 진행 중  - 3월 마무리 목표
지역성/전통성이 잘 들어나는 컨텐츠 확인 요청 & 전달
인물 DB 구축 프로젝트 - 3월 마무리 목표
DB와 서비스 포트 구성하여 docker compose로 패키징 완료
1700명 해외 인물 크롤링 완료하여 edwar, 인사팀장님 검수 작업중
검수 작업자 화면에서 추가 기능 구현
LiveSTT(지연송출)
구로 MCC
MCC 개발환경에 STT 설치 지원 & 연동 지원 완료 (최대식 대리)
 SBS 미디어넷
샘플 영상 기반 STT 수행 결과 및 인식률 결과 전달 (이상봉 이사)
AI 프롬프터
AI 프롬프터 전체 구성도 문서 재검토 및 작성
우선 AI 파트에서는 보류!!


신규

AI 데이터 라벨링 Proxima MAM 연동
차주까지 업로드 툴 & AI Meta 인터페이스 명세서 전달 예정 (임은지 대리)
SE 김성민 팀장님 요청 - 금주까지 처리 목표
AWS 인스턴스 상에서 OCR 서비스를 올려 인스턴스 스펙 테스트
ECS 테스트 (with 김성빈, 김희웅 연구원)"""

    prompt = _build_export_prompt(
        title=req.title,
        tasks_by_project=tasks_by_project,
        holding_count=holding,
        in_progress_count=in_progress,
        done_count=done,
        example_format=example_format,
        output_format=req.format,
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
        report = await _generate_with_gemini_model_fallback(client, prompt)
        if not report:
            report = "보고서를 생성하지 못했습니다. 잠시 후 다시 시도해 주세요."
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=_friendly_gemini_http_detail(e, "AI 보고서 생성에 실패했습니다"),
        ) from e

    return AIExportResponse(report=report, generated_at=datetime.now(timezone.utc))

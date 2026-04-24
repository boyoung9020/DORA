"""
워크스페이스 관리 API 라우터
"""
import secrets
import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.database import get_db
from app.models.workspace import Workspace, WorkspaceMember
from app.models.user import User
from app.models.project import Project
from app.models.task import Task, TaskStatus
from app.schemas.workspace import WorkspaceCreate, WorkspaceResponse, WorkspaceMemberResponse, JoinByTokenRequest
from app.utils.dependencies import get_current_user

router = APIRouter()


def _scheduled_for_day(t: Task, day_start: datetime, day_end: datetime) -> bool:
    """태스크의 start/end_date 기준 해당 날짜에 '잡혀 있던' 태스크인지 판정 (상태 무시).

    - start+end 둘 다: [start, end] 범위가 day 와 겹치면 True
    - end 만: end 가 해당 날짜인 경우에만 True (미래 마감 제외)
    - start 만: start 가 해당 날짜인 경우에만 True (과거 시작 제외)
    - 둘 다 없음: False (호출부에서 상태별로 처리)
    """
    sd = t.start_date
    ed = t.end_date
    if sd is not None:
        sd = sd if sd.tzinfo else sd.replace(tzinfo=timezone.utc)
    if ed is not None:
        ed = ed if ed.tzinfo else ed.replace(tzinfo=timezone.utc)
    if sd and ed:
        return sd <= day_end and ed >= day_start
    if ed:
        return day_start <= ed <= day_end
    if sd:
        return day_start <= sd <= day_end
    return False


def _is_date_task(t: Task, day_start: datetime, day_end: datetime) -> bool:
    """'오늘 할일' 여부 판정 (Option A 엄격 규칙).

    열린 태스크 (IN_PROGRESS/READY/IN_REVIEW):
      - 날짜가 있으면 _scheduled_for_day 규칙 만족 시 True
      - 날짜가 없으면서 IN_PROGRESS 인 상시 태스크만 True

    완료 태스크 (DONE):
      - updated_at 이 해당 날짜이고,
      - 그리고 '원래 해당 날짜의 할일' 이었어야 함
        (= _scheduled_for_day 만족, 또는 날짜가 없는 태스크)
    """
    if t.status == TaskStatus.DONE:
        if not t.updated_at:
            return False
        ut = t.updated_at if t.updated_at.tzinfo else t.updated_at.replace(tzinfo=timezone.utc)
        if not (day_start <= ut <= day_end):
            return False
        if t.start_date is None and t.end_date is None:
            return True
        return _scheduled_for_day(t, day_start, day_end)

    if t.status in (TaskStatus.IN_PROGRESS, TaskStatus.READY, TaskStatus.IN_REVIEW):
        if t.start_date is not None or t.end_date is not None:
            return _scheduled_for_day(t, day_start, day_end)
        return t.status == TaskStatus.IN_PROGRESS
    return False


def _is_workspace_member(db: Session, workspace_id: str, user_id: str) -> bool:
    return db.query(WorkspaceMember).filter(
        WorkspaceMember.workspace_id == workspace_id,
        WorkspaceMember.user_id == user_id
    ).first() is not None


def _get_workspace_or_404(db: Session, workspace_id: str) -> Workspace:
    ws = db.query(Workspace).filter(Workspace.id == workspace_id).first()
    if not ws:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="워크스페이스를 찾을 수 없습니다")
    return ws


def _workspace_to_response(ws: Workspace, db: Session) -> WorkspaceResponse:
    member_count = db.query(WorkspaceMember).filter(WorkspaceMember.workspace_id == ws.id).count()
    return WorkspaceResponse(
        id=ws.id,
        name=ws.name,
        description=ws.description,
        owner_id=ws.owner_id,
        invite_token=ws.invite_token,
        member_count=member_count,
        created_at=ws.created_at,
    )


@router.get("/", response_model=List[WorkspaceResponse])
async def get_my_workspaces(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """내가 속한 워크스페이스 목록 (admin은 전체)"""
    if current_user.is_admin:
        workspaces = db.query(Workspace).all()
    else:
        memberships = db.query(WorkspaceMember).filter(
            WorkspaceMember.user_id == current_user.id
        ).all()
        ws_ids = [m.workspace_id for m in memberships]
        workspaces = db.query(Workspace).filter(Workspace.id.in_(ws_ids)).all()
    return [_workspace_to_response(ws, db) for ws in workspaces]


@router.post("/", response_model=WorkspaceResponse, status_code=status.HTTP_201_CREATED)
async def create_workspace(
    ws_data: WorkspaceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """워크스페이스 생성 - 생성자가 owner가 됨"""
    existing = db.query(Workspace).filter(Workspace.name == ws_data.name).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"'{ws_data.name}' 이름의 워크스페이스가 이미 존재합니다",
        )
    new_ws = Workspace(
        id=str(uuid.uuid4()),
        name=ws_data.name,
        description=ws_data.description,
        owner_id=current_user.id,
        invite_token=secrets.token_urlsafe(16),
    )
    db.add(new_ws)
    db.flush()

    # 생성자를 owner로 멤버에 추가
    db.add(WorkspaceMember(
        id=str(uuid.uuid4()),
        workspace_id=new_ws.id,
        user_id=current_user.id,
        role="owner",
    ))
    db.commit()
    db.refresh(new_ws)
    return _workspace_to_response(new_ws, db)


@router.get("/{workspace_id}", response_model=WorkspaceResponse)
async def get_workspace(
    workspace_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """워크스페이스 상세 조회 (멤버 또는 admin)"""
    ws = _get_workspace_or_404(db, workspace_id)
    if not current_user.is_admin and not _is_workspace_member(db, workspace_id, current_user.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="워크스페이스 멤버가 아닙니다")
    return _workspace_to_response(ws, db)


@router.get("/{workspace_id}/members", response_model=List[WorkspaceMemberResponse])
async def get_workspace_members(
    workspace_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """워크스페이스 멤버 목록 (멤버 또는 admin)"""
    _get_workspace_or_404(db, workspace_id)
    if not current_user.is_admin and not _is_workspace_member(db, workspace_id, current_user.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="워크스페이스 멤버가 아닙니다")

    memberships = db.query(WorkspaceMember).filter(
        WorkspaceMember.workspace_id == workspace_id
    ).all()

    result = []
    for m in memberships:
        user = db.query(User).filter(User.id == m.user_id).first()
        if user:
            result.append(WorkspaceMemberResponse(
                user_id=user.id,
                username=user.username,
                profile_image_url=user.profile_image_url,
                role=m.role,
                joined_at=m.joined_at,
            ))
    return result


@router.post("/join", response_model=WorkspaceResponse)
async def join_workspace_by_token(
    body: JoinByTokenRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """초대 토큰으로 워크스페이스 참여"""
    ws = db.query(Workspace).filter(Workspace.invite_token == body.invite_token).first()
    if not ws:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="유효하지 않은 초대 코드입니다")

    # 이미 멤버이면 그냥 반환
    if not _is_workspace_member(db, ws.id, current_user.id):
        db.add(WorkspaceMember(
            id=str(uuid.uuid4()),
            workspace_id=ws.id,
            user_id=current_user.id,
            role="member",
        ))
        db.commit()
        db.refresh(ws)

    return _workspace_to_response(ws, db)


@router.post("/{workspace_id}/invite/regenerate", response_model=WorkspaceResponse)
async def regenerate_invite_token(
    workspace_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """초대 토큰 재발급 (owner만)"""
    ws = _get_workspace_or_404(db, workspace_id)
    if ws.owner_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="워크스페이스 오너만 초대 코드를 재발급할 수 있습니다")

    ws.invite_token = secrets.token_urlsafe(16)
    db.commit()
    db.refresh(ws)
    return _workspace_to_response(ws, db)


@router.delete("/{workspace_id}/members/{user_id}")
async def remove_workspace_member(
    workspace_id: str,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """멤버 강퇴 (owner 또는 admin만)"""
    ws = _get_workspace_or_404(db, workspace_id)
    if ws.owner_id != current_user.id and not current_user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="워크스페이스 오너만 멤버를 강퇴할 수 있습니다")
    if user_id == ws.owner_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="오너는 강퇴할 수 없습니다")

    member = db.query(WorkspaceMember).filter(
        WorkspaceMember.workspace_id == workspace_id,
        WorkspaceMember.user_id == user_id
    ).first()
    if member:
        db.delete(member)
        db.commit()
    return {"message": "멤버가 강퇴되었습니다"}


@router.delete("/{workspace_id}")
async def delete_workspace(
    workspace_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """워크스페이스 삭제 (owner만 가능)"""
    ws = _get_workspace_or_404(db, workspace_id)
    if ws.owner_id != current_user.id and not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="오너만 워크스페이스를 삭제할 수 있습니다"
        )
    db.query(WorkspaceMember).filter(WorkspaceMember.workspace_id == workspace_id).delete()
    db.delete(ws)
    db.commit()
    return {"message": "워크스페이스가 삭제되었습니다"}


@router.get("/{workspace_id}/member-stats")
async def get_workspace_member_stats(
    workspace_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """워크스페이스 멤버별 작업 통계 조회"""
    _get_workspace_or_404(db, workspace_id)
    if not current_user.is_admin and not _is_workspace_member(db, workspace_id, current_user.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="워크스페이스 멤버가 아닙니다")

    # 워크스페이스 프로젝트 목록
    projects = db.query(Project).filter(Project.workspace_id == workspace_id).all()
    project_ids = [p.id for p in projects]
    project_map = {p.id: p for p in projects}

    # 워크스페이스 전체 태스크 (서브태스크 포함 — 담당자가 서브태스크에 할당될 수 있음)
    all_tasks = db.query(Task).filter(
        Task.project_id.in_(project_ids),
    ).all() if project_ids else []

    # 멤버 목록
    memberships = db.query(WorkspaceMember).filter(
        WorkspaceMember.workspace_id == workspace_id
    ).all()

    result_members = []
    for m in memberships:
        user = db.query(User).filter(User.id == m.user_id).first()
        if not user:
            continue

        # 이 멤버에게 할당된 태스크 (assigned_member_ids 배열에 포함)
        member_tasks = [t for t in all_tasks if user.id in (t.assigned_member_ids or [])]

        # 태스크 수 집계
        counts = {
            "backlog": 0, "ready": 0, "in_progress": 0,
            "in_review": 0, "done": 0, "total": len(member_tasks)
        }
        status_map = {
            TaskStatus.BACKLOG: "backlog",
            TaskStatus.READY: "ready",
            TaskStatus.IN_PROGRESS: "in_progress",
            TaskStatus.IN_REVIEW: "in_review",
            TaskStatus.DONE: "done",
        }
        for t in member_tasks:
            key = status_map.get(t.status)
            if key:
                counts[key] += 1

        # 진행 중 태스크 (최대 5개)
        active_tasks = [
            {
                "id": t.id,
                "title": t.title,
                "project_name": project_map[t.project_id].name if t.project_id in project_map else "",
                "priority": t.priority.value if t.priority else "p2",
            }
            for t in member_tasks if t.status == TaskStatus.IN_PROGRESS
        ][:5]

        # 최근 완료 태스크 (updated_at 최신 5개)
        done_tasks = sorted(
            [t for t in member_tasks if t.status == TaskStatus.DONE],
            key=lambda t: t.updated_at,
            reverse=True
        )[:5]
        recent_done = [
            {
                "id": t.id,
                "title": t.title,
                "project_name": project_map[t.project_id].name if t.project_id in project_map else "",
                "updated_at": t.updated_at.isoformat() if t.updated_at else None,
            }
            for t in done_tasks
        ]

        # 전체 미완료 태스크 (우선순위순, done 제외)
        priority_order = {
            TaskStatus.IN_PROGRESS: 0,
            TaskStatus.IN_REVIEW: 1,
            TaskStatus.READY: 2,
            TaskStatus.BACKLOG: 3,
        }
        priority_value = {"p0": 0, "p1": 1, "p2": 2, "p3": 3}

        todo_tasks = sorted(
            [t for t in member_tasks if t.status != TaskStatus.DONE],
            key=lambda t: (
                priority_value.get(t.priority.value if t.priority else "p2", 2),
                priority_order.get(t.status, 4),
            )
        )
        all_tasks_list = [
            {
                "id": t.id,
                "title": t.title,
                "project_name": project_map[t.project_id].name if t.project_id in project_map else "",
                "priority": t.priority.value if t.priority else "p2",
                "status": t.status.value,
                "end_date": t.end_date.isoformat() if t.end_date else None,
            }
            for t in todo_tasks
        ]

        # 오늘 일정 (대시보드와 동일한 로직)
        now_utc = datetime.now(timezone.utc)
        today_start = now_utc.replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = now_utc.replace(hour=23, minute=59, second=59, microsecond=999999)

        today_tasks = [
            {
                "id": t.id,
                "title": t.title,
                "project_name": project_map[t.project_id].name if t.project_id in project_map else "",
                "priority": t.priority.value if t.priority else "p2",
                "status": t.status.value,
                "end_date": t.end_date.isoformat() if t.end_date else None,
                "start_date": t.start_date.isoformat() if t.start_date else None,
            }
            for t in member_tasks if _is_date_task(t, today_start, today_end)
        ]

        # 소속 프로젝트 (이 멤버가 팀원이거나 생성자인 프로젝트만)
        member_projects = [
            {
                "id": p.id,
                "name": p.name,
                "color": p.color,
            }
            for p in projects
            if user.id in (p.team_member_ids or []) or p.creator_id == user.id
        ]

        result_members.append({
            "user_id": user.id,
            "username": user.username,
            "profile_image_url": user.profile_image_url,
            "role": m.role,
            "projects": member_projects,
            "task_counts": counts,
            "active_tasks": active_tasks,
            "recent_done": recent_done,
            "today_tasks": today_tasks,
            "all_tasks": all_tasks_list,
        })

    return {"members": result_members}


@router.get("/{workspace_id}/yesterday-incomplete")
async def get_yesterday_incomplete_tasks(
    workspace_id: str,
    target_date: str = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """어제(또는 지정 날짜)의 미완료 '오늘 할일' 조회 (현재 유저 대상)"""
    _get_workspace_or_404(db, workspace_id)
    if not current_user.is_admin and not _is_workspace_member(db, workspace_id, current_user.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="워크스페이스 멤버가 아닙니다")

    # 대상 날짜 결정 (기본: 어제)
    from datetime import timedelta
    now_utc = datetime.now(timezone.utc)
    if target_date:
        try:
            target = datetime.strptime(target_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            raise HTTPException(status_code=400, detail="target_date 형식은 YYYY-MM-DD여야 합니다")
    else:
        target = (now_utc - timedelta(days=1))

    day_start = target.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = target.replace(hour=23, minute=59, second=59, microsecond=999999)

    # 워크스페이스 프로젝트 + 태스크
    projects = db.query(Project).filter(Project.workspace_id == workspace_id).all()
    project_ids = [p.id for p in projects]
    project_map = {p.id: p for p in projects}

    all_tasks = db.query(Task).filter(
        Task.project_id.in_(project_ids),
    ).all() if project_ids else []

    # 현재 유저에게 할당된 태스크만
    my_tasks = [t for t in all_tasks if current_user.id in (t.assigned_member_ids or [])]

    # 해당 날짜의 "오늘 할일"이었던 것 중 현재 미완료인 것
    incomplete = [
        {
            "id": t.id,
            "title": t.title,
            "project_name": project_map[t.project_id].name if t.project_id in project_map else "",
            "priority": t.priority.value if t.priority else "p2",
            "status": t.status.value,
            "end_date": t.end_date.isoformat() if t.end_date else None,
            "start_date": t.start_date.isoformat() if t.start_date else None,
        }
        for t in my_tasks
        if _is_date_task(t, day_start, day_end) and t.status != TaskStatus.DONE
    ]

    # 오늘 UTC 범위 기준으로 현재 유저가 이미 리뷰를 봤는지 판정
    today_start = now_utc.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = now_utc.replace(hour=23, minute=59, second=59, microsecond=999999)
    last_seen = current_user.last_yesterday_review_at
    already_reviewed_today = False
    if last_seen is not None:
        ls = last_seen if last_seen.tzinfo else last_seen.replace(tzinfo=timezone.utc)
        already_reviewed_today = today_start <= ls <= today_end

    return {
        "target_date": target.strftime("%Y-%m-%d"),
        "incomplete_tasks": incomplete,
        "already_reviewed_today": already_reviewed_today,
    }


@router.post("/{workspace_id}/yesterday-incomplete/acknowledge", status_code=status.HTTP_204_NO_CONTENT)
async def acknowledge_yesterday_incomplete_review(
    workspace_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """어제 미완료 리뷰 다이얼로그를 봤음을 기록 (멱등).

    프론트엔드는 다이얼로그를 띄우기 직전에 이 엔드포인트를 호출해야 한다.
    당일 재호출에도 안전 — last_yesterday_review_at 을 now() 로 갱신만 수행.
    """
    _get_workspace_or_404(db, workspace_id)
    if not current_user.is_admin and not _is_workspace_member(db, workspace_id, current_user.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="워크스페이스 멤버가 아닙니다")

    current_user.last_yesterday_review_at = datetime.now(timezone.utc)
    db.add(current_user)
    db.commit()
    return None


@router.delete("/{workspace_id}/leave")
async def leave_workspace(
    workspace_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """워크스페이스 탈퇴 (owner는 불가)"""
    ws = _get_workspace_or_404(db, workspace_id)
    if ws.owner_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="오너는 워크스페이스를 탈퇴할 수 없습니다. 다른 멤버에게 오너를 양도하거나 워크스페이스를 삭제하세요"
        )

    member = db.query(WorkspaceMember).filter(
        WorkspaceMember.workspace_id == workspace_id,
        WorkspaceMember.user_id == current_user.id
    ).first()
    if member:
        db.delete(member)
        db.commit()
    return {"message": "워크스페이스를 탈퇴했습니다"}

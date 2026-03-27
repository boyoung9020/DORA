"""GitHub 연동 API router."""

import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.github import ProjectGitHub
from app.models.project import Project
from app.models.user import User
from app.schemas.github import (
    GitHubBranchResponse,
    GitHubCommitResponse,
    GitHubPRResponse,
    GitHubRepoConnect,
    GitHubRepoResponse,
)
from app.utils.dependencies import get_current_user
from app.utils.github_api import (
    GitHubApiError,
    get_branches,
    get_commits,
    get_pull_requests,
    validate_repo,
)

router = APIRouter()


def _get_project_or_404(db: Session, project_id: str) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    return project


def _check_project_member(project: Project, user: User) -> None:
    if user.is_admin or user.is_pm:
        return
    if user.id not in (project.team_member_ids or []):
        raise HTTPException(status_code=403, detail="Not a member of this project")


def _check_project_pm(project: Project, user: User) -> None:
    if user.is_admin:
        return
    if project.creator_id != user.id:
        raise HTTPException(status_code=403, detail="Only the project PM can perform this action")


def _to_repo_response(gh: ProjectGitHub) -> GitHubRepoResponse:
    return GitHubRepoResponse(
        id=gh.id,
        project_id=gh.project_id,
        repo_owner=gh.repo_owner,
        repo_name=gh.repo_name,
        has_token=bool(gh.access_token),
        created_at=gh.created_at,
        updated_at=gh.updated_at,
    )


# ── 레포 연결/해제/조회 ──────────────────────────────────

@router.post("/{project_id}/connect", response_model=GitHubRepoResponse, status_code=status.HTTP_201_CREATED)
async def connect_repo(
    project_id: str,
    body: GitHubRepoConnect,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """프로젝트에 GitHub 레포를 연결합니다. (PM 전용)"""
    project = _get_project_or_404(db, project_id)
    _check_project_member(project, current_user)

    # 이미 연결된 레포가 있으면 에러
    existing = db.query(ProjectGitHub).filter(ProjectGitHub.project_id == project_id).first()
    if existing:
        raise HTTPException(status_code=409, detail="A GitHub repository is already connected to this project")

    # GitHub 레포 유효성 검증
    try:
        await validate_repo(body.repo_owner, body.repo_name, body.access_token)
    except GitHubApiError as e:
        raise HTTPException(status_code=400, detail=str(e))

    gh = ProjectGitHub(
        id=str(uuid.uuid4()),
        project_id=project_id,
        repo_owner=body.repo_owner,
        repo_name=body.repo_name,
        access_token=body.access_token,
    )
    db.add(gh)
    db.commit()
    db.refresh(gh)
    return _to_repo_response(gh)


@router.delete("/{project_id}/disconnect", status_code=status.HTTP_204_NO_CONTENT)
async def disconnect_repo(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """프로젝트의 GitHub 레포 연결을 해제합니다. (PM 전용)"""
    project = _get_project_or_404(db, project_id)
    _check_project_member(project, current_user)

    gh = db.query(ProjectGitHub).filter(ProjectGitHub.project_id == project_id).first()
    if not gh:
        raise HTTPException(status_code=404, detail="No GitHub repository connected")

    db.delete(gh)
    db.commit()


@router.get("/{project_id}/repo", response_model=GitHubRepoResponse)
async def get_repo_info(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """연결된 GitHub 레포 정보를 조회합니다."""
    project = _get_project_or_404(db, project_id)
    _check_project_member(project, current_user)

    gh = db.query(ProjectGitHub).filter(ProjectGitHub.project_id == project_id).first()
    if not gh:
        raise HTTPException(status_code=404, detail="No GitHub repository connected")

    return _to_repo_response(gh)


# ── 커밋/브랜치/PR 조회 ──────────────────────────────────

def _get_github_record(db: Session, project_id: str, user: User) -> ProjectGitHub:
    project = _get_project_or_404(db, project_id)
    _check_project_member(project, user)
    gh = db.query(ProjectGitHub).filter(ProjectGitHub.project_id == project_id).first()
    if not gh:
        raise HTTPException(status_code=404, detail="No GitHub repository connected")
    return gh


@router.get("/{project_id}/commits", response_model=List[GitHubCommitResponse])
async def list_commits(
    project_id: str,
    branch: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    per_page: int = Query(30, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """GitHub 커밋 목록을 조회합니다."""
    gh = _get_github_record(db, project_id, current_user)

    try:
        raw = await get_commits(gh.repo_owner, gh.repo_name, gh.access_token, branch, page, per_page)
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))

    results = []
    for item in raw:
        commit = item.get("commit", {})
        author = commit.get("author", {})
        gh_author = item.get("author") or {}
        results.append(GitHubCommitResponse(
            sha=item.get("sha", ""),
            message=commit.get("message", ""),
            author_name=author.get("name", ""),
            author_email=author.get("email"),
            author_avatar_url=gh_author.get("avatar_url"),
            date=author.get("date", ""),
            url=item.get("html_url", ""),
        ))
    return results


@router.get("/{project_id}/branches", response_model=List[GitHubBranchResponse])
async def list_branches(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """GitHub 브랜치 목록을 조회합니다."""
    gh = _get_github_record(db, project_id, current_user)

    try:
        raw = await get_branches(gh.repo_owner, gh.repo_name, gh.access_token)
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))

    return [
        GitHubBranchResponse(
            name=b.get("name", ""),
            sha=b.get("commit", {}).get("sha", ""),
        )
        for b in raw
    ]


@router.get("/{project_id}/pulls", response_model=List[GitHubPRResponse])
async def list_pull_requests(
    project_id: str,
    state: str = Query("open", regex="^(open|closed|all)$"),
    page: int = Query(1, ge=1),
    per_page: int = Query(30, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """GitHub Pull Request 목록을 조회합니다."""
    gh = _get_github_record(db, project_id, current_user)

    try:
        raw = await get_pull_requests(gh.repo_owner, gh.repo_name, gh.access_token, state, page, per_page)
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))

    return [
        GitHubPRResponse(
            number=pr.get("number", 0),
            title=pr.get("title", ""),
            state=pr.get("state", ""),
            author=pr.get("user", {}).get("login", ""),
            author_avatar_url=pr.get("user", {}).get("avatar_url"),
            created_at=pr.get("created_at", ""),
            updated_at=pr.get("updated_at", ""),
            url=pr.get("html_url", ""),
            head_branch=pr.get("head", {}).get("ref", ""),
            base_branch=pr.get("base", {}).get("ref", ""),
        )
        for pr in raw
    ]

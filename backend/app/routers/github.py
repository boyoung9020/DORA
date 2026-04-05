"""GitHub 연동 API router."""

import re
import uuid
from typing import List, Optional, Tuple

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.github import ProjectGitHub
from app.models.project import Project
from app.models.user import User
from app.schemas.github import (
    GitHubBranchResponse,
    GitHubCommitResponse,
    GitHubLanguageResponse,
    GitHubPRResponse,
    GitHubReleaseResponse,
    GitHubRepoConnect,
    GitHubRepoRemoteDetailsResponse,
    GitHubRepoResponse,
    GitHubTagCreate,
    GitHubTagResponse,
)
from app.utils.dependencies import get_current_user
from app.utils.github_api import (
    GitHubApiError,
    get_branches,
    get_commits,
    get_languages,
    get_pull_requests,
    get_releases,
    create_tag_ref,
    get_tags,
    get_user_repos,
    validate_repo,
)
from app.models.user_github_token import UserGitHubToken

router = APIRouter()


def _validate_tag_create_body(body: GitHubTagCreate) -> Tuple[str, str]:
    name = body.tag_name.strip()
    sha = body.commit_sha.strip()
    if not name:
        raise HTTPException(status_code=400, detail="tag_name is required")
    if not sha:
        raise HTTPException(status_code=400, detail="commit_sha is required")
    if name.startswith("refs/"):
        raise HTTPException(
            status_code=400, detail="tag_name must not use a refs/ prefix"
        )
    if ".." in name or re.search(r"[\s\u0000-\u001f]", name):
        raise HTTPException(status_code=400, detail="Invalid tag_name")
    if not re.fullmatch(r"[0-9a-fA-F]{7,40}", sha):
        raise HTTPException(
            status_code=400, detail="commit_sha must be 7–40 hexadecimal characters"
        )
    return name, sha


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


# ── 내 레포 목록 ──────────────────────────────────────────

@router.get("/my-repos")
async def list_my_repos(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """현재 사용자의 GitHub PAT로 접근 가능한 레포 목록을 반환합니다."""
    token_rec = db.query(UserGitHubToken).filter(UserGitHubToken.user_id == current_user.id).first()
    if not token_rec or not token_rec.access_token:
        raise HTTPException(status_code=400, detail="GitHub token not set")
    try:
        repos = await get_user_repos(token_rec.access_token)
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))
    return [
        {"full_name": r["full_name"], "owner": r["owner"]["login"], "name": r["name"], "private": r["private"]}
        for r in repos
    ]


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

    # GitHub 레포 유효성 검증
    try:
        token_rec = db.query(UserGitHubToken).filter(UserGitHubToken.user_id == current_user.id).first()
        user_token = token_rec.access_token if token_rec else None
        await validate_repo(body.repo_owner, body.repo_name, user_token or body.access_token)
    except GitHubApiError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # 이미 연결된 레포가 있으면 교체 (upsert)
    existing = db.query(ProjectGitHub).filter(ProjectGitHub.project_id == project_id).first()
    if existing:
        existing.repo_owner = body.repo_owner
        existing.repo_name = body.repo_name
        existing.access_token = None
        db.commit()
        db.refresh(existing)
        return _to_repo_response(existing)

    gh = ProjectGitHub(
        id=str(uuid.uuid4()),
        project_id=project_id,
        repo_owner=body.repo_owner,
        repo_name=body.repo_name,
        access_token=None,
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


@router.get("/{project_id}/repo-details", response_model=GitHubRepoRemoteDetailsResponse)
async def get_repo_remote_details(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """연결된 저장소의 GitHub 공개 메타데이터(설명·스타·기본 브랜치 등)를 조회합니다."""
    gh = _get_github_record(db, project_id, current_user)
    token = _get_user_token(db, current_user) or gh.access_token

    try:
        raw = await validate_repo(gh.repo_owner, gh.repo_name, token)
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))

    return GitHubRepoRemoteDetailsResponse(
        description=raw.get("description"),
        default_branch=raw.get("default_branch") or "",
        stargazers_count=int(raw.get("stargazers_count") or 0),
        forks_count=int(raw.get("forks_count") or 0),
        open_issues_count=int(raw.get("open_issues_count") or 0),
        html_url=str(raw.get("html_url") or ""),
    )


# ── 커밋/브랜치/PR 조회 ──────────────────────────────────

def _get_github_record(db: Session, project_id: str, user: User) -> ProjectGitHub:
    project = _get_project_or_404(db, project_id)
    _check_project_member(project, user)
    gh = db.query(ProjectGitHub).filter(ProjectGitHub.project_id == project_id).first()
    if not gh:
        raise HTTPException(status_code=404, detail="No GitHub repository connected")
    return gh


def _get_user_token(db: Session, user: User) -> Optional[str]:
    rec = db.query(UserGitHubToken).filter(UserGitHubToken.user_id == user.id).first()
    if not rec:
        return None
    token = (rec.access_token or "").strip()
    return token or None


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
    token = _get_user_token(db, current_user) or gh.access_token

    try:
        raw = await get_commits(gh.repo_owner, gh.repo_name, token, branch, page, per_page)
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))

    results = []
    for item in raw:
        commit = item.get("commit", {})
        author = commit.get("author", {})
        gh_author = item.get("author") or {}
        parent_shas = [p.get("sha", "") for p in item.get("parents", [])]
        results.append(GitHubCommitResponse(
            sha=item.get("sha", ""),
            message=commit.get("message", ""),
            author_name=author.get("name", ""),
            author_email=author.get("email"),
            author_avatar_url=gh_author.get("avatar_url"),
            date=author.get("date", ""),
            url=item.get("html_url", ""),
            parents=parent_shas,
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
    token = _get_user_token(db, current_user) or gh.access_token

    try:
        raw = await get_branches(gh.repo_owner, gh.repo_name, token)
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))

    return [
        GitHubBranchResponse(
            name=b.get("name", ""),
            sha=b.get("commit", {}).get("sha", ""),
        )
        for b in raw
    ]


@router.get("/{project_id}/tags", response_model=List[GitHubTagResponse])
async def list_tags(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """GitHub 태그 목록을 조회합니다."""
    gh = _get_github_record(db, project_id, current_user)
    token = _get_user_token(db, current_user) or gh.access_token

    try:
        raw = await get_tags(gh.repo_owner, gh.repo_name, token)
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))

    return [
        GitHubTagResponse(
            name=t.get("name", ""),
            sha=t.get("commit", {}).get("sha", ""),
        )
        for t in raw
    ]


@router.get("/{project_id}/releases", response_model=List[GitHubReleaseResponse])
async def list_releases(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """GitHub Releases 목록 (published_at 기준 최신순)."""
    gh = _get_github_record(db, project_id, current_user)
    token = _get_user_token(db, current_user) or gh.access_token

    try:
        raw = await get_releases(gh.repo_owner, gh.repo_name, token)
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))

    results = []
    for i, r in enumerate(raw):
        results.append(GitHubReleaseResponse(
            id=r.get("id", 0),
            tag_name=r.get("tag_name", ""),
            name=r.get("name", "") or r.get("tag_name", ""),
            body=r.get("body") or None,
            draft=r.get("draft", False),
            prerelease=r.get("prerelease", False),
            published_at=r.get("published_at"),
            url=r.get("html_url", ""),
            is_latest=(i == 0 and not r.get("draft", False) and not r.get("prerelease", False)),
        ))
    return results


@router.post(
    "/{project_id}/tags",
    response_model=GitHubTagResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_tag(
    project_id: str,
    body: GitHubTagCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """경량 Git 태그를 지정 커밋에 생성합니다. PAT에 저장소 쓰기 권한이 필요합니다."""
    tag_name, commit_sha = _validate_tag_create_body(body)
    gh = _get_github_record(db, project_id, current_user)
    token = _get_user_token(db, current_user) or gh.access_token

    try:
        created = await create_tag_ref(
            gh.repo_owner, gh.repo_name, tag_name, commit_sha, token
        )
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))

    obj = created.get("object") or {}
    out_sha = obj.get("sha") or commit_sha
    return GitHubTagResponse(name=tag_name, sha=out_sha)


@router.get("/{project_id}/languages", response_model=List[GitHubLanguageResponse])
async def list_repo_languages(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """연결된 저장소의 언어 비율 (기술 스택용)."""
    gh = _get_github_record(db, project_id, current_user)
    token = _get_user_token(db, current_user) or gh.access_token

    try:
        raw = await get_languages(gh.repo_owner, gh.repo_name, token)
    except GitHubApiError as e:
        raise HTTPException(status_code=502, detail=str(e))

    total = sum(raw.values()) or 1
    items = sorted(
        (
            GitHubLanguageResponse(
                name=name,
                bytes=bts,
                percentage=round(bts / total * 100, 1),
            )
            for name, bts in raw.items()
        ),
        key=lambda x: -x.bytes,
    )
    return items[:16]


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
    token = _get_user_token(db, current_user) or gh.access_token

    try:
        raw = await get_pull_requests(gh.repo_owner, gh.repo_name, token, state, page, per_page)
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

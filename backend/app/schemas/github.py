"""GitHub 연동 Pydantic schemas."""
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel


# ── Request schemas ──────────────────────────────────────

class GitHubRepoConnect(BaseModel):
    """GitHub 레포 연결 요청"""
    repo_owner: str
    repo_name: str
    access_token: Optional[str] = None


class GitHubRepoUpdate(BaseModel):
    """GitHub 레포 정보 수정"""
    repo_owner: Optional[str] = None
    repo_name: Optional[str] = None
    access_token: Optional[str] = None


class GitHubTagCreate(BaseModel):
    """GitHub 경량 태그 생성 (git ref -> commit)"""

    tag_name: str
    commit_sha: str


# ── Response schemas ─────────────────────────────────────

class GitHubRepoResponse(BaseModel):
    """GitHub 레포 연결 정보 응답 (토큰 미노출)"""
    id: str
    project_id: str
    repo_owner: str
    repo_name: str
    has_token: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class GitHubRepoRemoteDetailsResponse(BaseModel):
    """GitHub API /repos/{owner}/{repo} 에서 가져온 공개 메타데이터"""

    description: Optional[str] = None
    default_branch: str = ""
    stargazers_count: int = 0
    forks_count: int = 0
    open_issues_count: int = 0
    html_url: str = ""


class GitHubCommitResponse(BaseModel):
    """커밋 정보"""
    sha: str
    message: str
    author_name: str
    author_email: Optional[str] = None
    author_avatar_url: Optional[str] = None
    date: str
    url: str
    parents: List[str] = []


class GitHubBranchResponse(BaseModel):
    """브랜치 정보"""
    name: str
    sha: str


class GitHubTagResponse(BaseModel):
    """태그 정보"""
    name: str
    sha: str


class GitHubLanguageResponse(BaseModel):
    """저장소 언어 비율 (GitHub /languages)"""

    name: str
    bytes: int
    percentage: float


class GitHubReleaseResponse(BaseModel):
    """GitHub Release 정보 (published_at 기준 최신순)"""
    id: int
    tag_name: str
    name: str
    body: Optional[str] = None
    draft: bool
    prerelease: bool
    published_at: Optional[str] = None
    url: str
    is_latest: bool = False


class GitHubPRResponse(BaseModel):
    """Pull Request 정보"""
    number: int
    title: str
    state: str
    author: str
    author_avatar_url: Optional[str] = None
    created_at: str
    updated_at: str
    url: str
    head_branch: str
    base_branch: str


class GitHubIssueResponse(BaseModel):
    """Issue 정보"""
    number: int
    title: str
    state: str
    author: str
    author_avatar_url: Optional[str] = None
    created_at: str
    updated_at: str
    url: str
    labels: List[str] = []
    comments: int = 0


class GitHubGraphCommitResponse(GitHubCommitResponse):
    """그래프용 커밋 — 브랜치/태그 레이블 포함"""
    branch_names: List[str] = []
    tag_names: List[str] = []


class GitHubGraphResponse(BaseModel):
    """전체 브랜치 커밋 그래프 응답"""
    commits: List[GitHubGraphCommitResponse]
    has_more: bool

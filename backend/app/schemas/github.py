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

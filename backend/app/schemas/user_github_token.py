"""User-level GitHub token schemas."""

from pydantic import BaseModel


class GitHubTokenUpsertRequest(BaseModel):
    access_token: str


class GitHubTokenStatusResponse(BaseModel):
    has_token: bool


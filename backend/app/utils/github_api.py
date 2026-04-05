"""GitHub REST API v3 client utilities."""
from typing import Any, Dict, List, Optional

import httpx


class GitHubApiError(Exception):
    """Raised when a GitHub API call fails."""


_GITHUB_API = "https://api.github.com"


def _headers(token: Optional[str] = None) -> Dict[str, str]:
    h: Dict[str, str] = {"Accept": "application/vnd.github.v3+json"}
    if token:
        h["Authorization"] = f"token {token}"
    return h


async def validate_repo(owner: str, repo: str, token: Optional[str] = None) -> Dict[str, Any]:
    """Verify that a repository exists and is accessible."""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(f"{_GITHUB_API}/repos/{owner}/{repo}", headers=_headers(token))
    except Exception as exc:
        raise GitHubApiError(f"Failed to connect to GitHub: {exc}") from exc
    if resp.status_code == 404:
        raise GitHubApiError(f"Repository {owner}/{repo} not found or not accessible")
    if resp.status_code == 401:
        raise GitHubApiError("Invalid GitHub access token")
    if resp.status_code != 200:
        raise GitHubApiError(f"GitHub API error ({resp.status_code}): {resp.text}")
    return resp.json()


async def get_commits(
    owner: str,
    repo: str,
    token: Optional[str] = None,
    branch: Optional[str] = None,
    page: int = 1,
    per_page: int = 30,
) -> List[Dict[str, Any]]:
    """Fetch commits from a repository."""
    params: Dict[str, Any] = {"page": page, "per_page": per_page}
    if branch:
        params["sha"] = branch
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{_GITHUB_API}/repos/{owner}/{repo}/commits",
                headers=_headers(token),
                params=params,
            )
    except Exception as exc:
        raise GitHubApiError(f"Failed to fetch commits: {exc}") from exc
    if resp.status_code != 200:
        raise GitHubApiError(f"GitHub API error ({resp.status_code}): {resp.text}")
    return resp.json()


async def get_branches(
    owner: str,
    repo: str,
    token: Optional[str] = None,
    page: int = 1,
    per_page: int = 100,
) -> List[Dict[str, Any]]:
    """Fetch branches from a repository."""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{_GITHUB_API}/repos/{owner}/{repo}/branches",
                headers=_headers(token),
                params={"page": page, "per_page": per_page},
            )
    except Exception as exc:
        raise GitHubApiError(f"Failed to fetch branches: {exc}") from exc
    if resp.status_code != 200:
        raise GitHubApiError(f"GitHub API error ({resp.status_code}): {resp.text}")
    return resp.json()


async def get_tags(
    owner: str,
    repo: str,
    token: Optional[str] = None,
    page: int = 1,
    per_page: int = 100,
) -> List[Dict[str, Any]]:
    """Fetch tags from a repository."""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{_GITHUB_API}/repos/{owner}/{repo}/tags",
                headers=_headers(token),
                params={"page": page, "per_page": per_page},
            )
    except Exception as exc:
        raise GitHubApiError(f"Failed to fetch tags: {exc}") from exc
    if resp.status_code != 200:
        raise GitHubApiError(f"GitHub API error ({resp.status_code}): {resp.text}")
    return resp.json()


async def get_user_repos(
    token: str,
    page: int = 1,
    per_page: int = 100,
) -> List[Dict[str, Any]]:
    """Fetch repositories accessible to the authenticated user."""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{_GITHUB_API}/user/repos",
                headers=_headers(token),
                params={"page": page, "per_page": per_page, "sort": "updated", "affiliation": "owner,collaborator,organization_member"},
            )
    except Exception as exc:
        raise GitHubApiError(f"Failed to fetch user repos: {exc}") from exc
    if resp.status_code == 401:
        raise GitHubApiError("Invalid GitHub access token")
    if resp.status_code != 200:
        raise GitHubApiError(f"GitHub API error ({resp.status_code}): {resp.text}")
    return resp.json()


async def get_pull_requests(
    owner: str,
    repo: str,
    token: Optional[str] = None,
    state: str = "open",
    page: int = 1,
    per_page: int = 30,
) -> List[Dict[str, Any]]:
    """Fetch pull requests from a repository."""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{_GITHUB_API}/repos/{owner}/{repo}/pulls",
                headers=_headers(token),
                params={"state": state, "page": page, "per_page": per_page},
            )
    except Exception as exc:
        raise GitHubApiError(f"Failed to fetch pull requests: {exc}") from exc
    if resp.status_code != 200:
        raise GitHubApiError(f"GitHub API error ({resp.status_code}): {resp.text}")
    return resp.json()

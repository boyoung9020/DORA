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


async def create_tag_ref(
    owner: str,
    repo: str,
    tag_name: str,
    commit_sha: str,
    token: Optional[str] = None,
) -> Dict[str, Any]:
    """Create a lightweight tag pointing to a commit (POST git/refs)."""
    if not token:
        raise GitHubApiError("GitHub token required to create a tag")
    ref = f"refs/tags/{tag_name}"
    body = {"ref": ref, "sha": commit_sha.strip()}
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(
                f"{_GITHUB_API}/repos/{owner}/{repo}/git/refs",
                headers=_headers(token),
                json=body,
            )
    except Exception as exc:
        raise GitHubApiError(f"Failed to create tag: {exc}") from exc
    if resp.status_code == 422:
        try:
            data = resp.json()
            msg = data.get("message", resp.text)
            if isinstance(msg, str) and msg:
                raise GitHubApiError(msg)
        except GitHubApiError:
            raise
        except Exception:
            pass
        raise GitHubApiError(f"GitHub API error (422): {resp.text}")
    if resp.status_code == 403:
        raise GitHubApiError("No permission to create tag (check repository access and token scopes)")
    if resp.status_code == 401:
        raise GitHubApiError("Invalid or missing GitHub token")
    if resp.status_code == 409:
        raise GitHubApiError("Tag or ref already exists")
    if resp.status_code != 201:
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


async def get_languages(
    owner: str,
    repo: str,
    token: Optional[str] = None,
) -> Dict[str, int]:
    """Fetch language breakdown (bytes per language) from GitHub."""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{_GITHUB_API}/repos/{owner}/{repo}/languages",
                headers=_headers(token),
            )
    except Exception as exc:
        raise GitHubApiError(f"Failed to fetch languages: {exc}") from exc
    if resp.status_code != 200:
        raise GitHubApiError(f"GitHub API error ({resp.status_code}): {resp.text}")
    data = resp.json()
    return {str(k): int(v) for k, v in data.items()}


async def get_releases(
    owner: str,
    repo: str,
    token: Optional[str] = None,
    page: int = 1,
    per_page: int = 30,
) -> List[Dict[str, Any]]:
    """Fetch releases from a repository (sorted by published_at desc)."""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{_GITHUB_API}/repos/{owner}/{repo}/releases",
                headers=_headers(token),
                params={"page": page, "per_page": per_page},
            )
    except Exception as exc:
        raise GitHubApiError(f"Failed to fetch releases: {exc}") from exc
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

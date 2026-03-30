"""
Local-dev utility: make one user's visible data match another user's.

Goal (common meaning of "데이터 동일"):
- Ensure target user is in the same workspaces (workspace_members)
- Ensure target user is in the same projects (projects.team_member_ids)
- Optionally copy user-level GitHub PAT (user_github_tokens)

This does NOT clone tasks/comments/etc. It aligns access/visibility instead.

Usage (PowerShell / cmd):
  python backend/scripts/sync_user_data.py --src-email boyoung9020@gmail.com --dst-email admin@sync.com --copy-github-token
  python backend/scripts/sync_user_data.py --src-email boyoung9020@gmail.com --dst-email admin@sync.com --dry-run
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.project import Project
from app.models.user import User
from app.models.user_github_token import UserGitHubToken
from app.models.workspace import WorkspaceMember


@dataclass
class SyncResult:
    workspace_members_added: int = 0
    projects_updated: int = 0
    github_token_copied: bool = False


def _get_user_by_email(db: Session, email: str) -> User:
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise SystemExit(f"User not found: {email}")
    return user


def sync_user_visibility(
    db: Session,
    *,
    src_email: str,
    dst_email: str,
    copy_github_token: bool,
    dry_run: bool,
) -> SyncResult:
    src = _get_user_by_email(db, src_email)
    dst = _get_user_by_email(db, dst_email)

    if src.id == dst.id:
        raise SystemExit("src and dst are the same user")

    result = SyncResult()

    # 1) Workspace memberships
    src_memberships = (
        db.query(WorkspaceMember)
        .filter(WorkspaceMember.user_id == src.id)
        .all()
    )
    for m in src_memberships:
        exists = (
            db.query(WorkspaceMember)
            .filter(
                WorkspaceMember.workspace_id == m.workspace_id,
                WorkspaceMember.user_id == dst.id,
            )
            .first()
        )
        if exists:
            continue

        if not dry_run:
            db.add(
                WorkspaceMember(
                    id=f"sync-{m.workspace_id[:8]}-{dst.id[:8]}",
                    workspace_id=m.workspace_id,
                    user_id=dst.id,
                    role="member",
                )
            )
        result.workspace_members_added += 1

    # 2) Project team memberships
    projects = db.query(Project).all()
    for p in projects:
        team = list(p.team_member_ids or [])
        if src.id not in team:
            continue
        if dst.id in team:
            continue
        team.append(dst.id)
        if not dry_run:
            p.team_member_ids = team
        result.projects_updated += 1

    # 3) Optional: copy GitHub token (user-level)
    if copy_github_token:
        src_token = (
            db.query(UserGitHubToken)
            .filter(UserGitHubToken.user_id == src.id)
            .first()
        )
        if src_token and (src_token.access_token or "").strip():
            dst_token = (
                db.query(UserGitHubToken)
                .filter(UserGitHubToken.user_id == dst.id)
                .first()
            )
            if not dry_run:
                if dst_token:
                    dst_token.access_token = src_token.access_token
                else:
                    db.add(
                        UserGitHubToken(
                            id="sync-github-token",
                            user_id=dst.id,
                            access_token=src_token.access_token,
                        )
                    )
            result.github_token_copied = True

    if not dry_run:
        db.commit()

    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src-email", required=True)
    parser.add_argument("--dst-email", required=True)
    parser.add_argument("--copy-github-token", action="store_true", default=False)
    parser.add_argument("--dry-run", action="store_true", default=False)
    args = parser.parse_args()

    db: Session = SessionLocal()
    try:
        r = sync_user_visibility(
            db,
            src_email=args.src_email,
            dst_email=args.dst_email,
            copy_github_token=args.copy_github_token,
            dry_run=args.dry_run,
        )
        print(
            "[sync_user_data] done",
            {
                "workspace_members_added": r.workspace_members_added,
                "projects_updated": r.projects_updated,
                "github_token_copied": r.github_token_copied,
                "dry_run": args.dry_run,
            },
        )
    finally:
        db.close()


if __name__ == "__main__":
    main()


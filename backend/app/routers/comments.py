"""Comment API router."""

import re
import uuid
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.comment import Comment
from app.models.comment_reaction import CommentReaction
from app.models.notification import Notification
from app.models.project import Project
from app.models.task import Task
from app.models.user import User
from app.schemas.comment import (
    CommentCreate,
    CommentReactionToggle,
    CommentResponse,
    CommentUpdate,
)
from app.utils.dependencies import get_current_user
from app.models.notification import NotificationType
from app.utils.notifications import create_notification, notify_task_comment_added

router = APIRouter()


def _safe_list(value) -> List[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return list(value)
    if hasattr(value, "__iter__"):
        return list(value)
    return []


def _build_comment_reactions(db: Session, comment_ids: List[str]) -> dict[str, dict[str, list[str]]]:
    if not comment_ids:
        return {}

    rows = (
        db.query(CommentReaction)
        .filter(CommentReaction.comment_id.in_(comment_ids))
        .all()
    )
    grouped: dict[str, dict[str, list[str]]] = {}
    for row in rows:
        grouped.setdefault(row.comment_id, {}).setdefault(row.emoji, []).append(row.user_id)
    return grouped


def _attach_comment_reactions(db: Session, comments: List[Comment]) -> None:
    reaction_map = _build_comment_reactions(db, [c.id for c in comments])
    for comment in comments:
        setattr(comment, "reactions", reaction_map.get(comment.id, {}))


@router.get("/task/{task_id}", response_model=List[CommentResponse])
async def get_comments_by_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    comments = (
        db.query(Comment).filter(Comment.task_id == task_id).order_by(Comment.created_at).all()
    )
    _attach_comment_reactions(db, comments)
    return comments


@router.get("/{comment_id}", response_model=CommentResponse)
async def get_comment(
    comment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="댓글을 찾을 수 없습니다")
    _attach_comment_reactions(db, [comment])
    return comment


@router.post("/", response_model=CommentResponse, status_code=status.HTTP_201_CREATED)
async def create_comment(
    comment_data: CommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        content = comment_data.content or ""
        image_urls = comment_data.image_urls or []
        file_urls = comment_data.file_urls or []

        if not content.strip() and not image_urls and not file_urls:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="댓글 내용 또는 첨부파일이 필요합니다",
            )

        task = db.query(Task).filter(Task.id == comment_data.task_id).first()
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="태스크를 찾을 수 없습니다"
            )

        project = db.query(Project).filter(Project.id == task.project_id).first()
        if not current_user.is_admin and not current_user.is_pm:
            if not project or (current_user.id != project.creator_id and current_user.id not in (project.team_member_ids or [])):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="해당 태스크에 댓글을 작성할 권한이 없습니다",
                )

        new_comment = Comment(
            id=str(uuid.uuid4()),
            task_id=comment_data.task_id,
            user_id=current_user.id,
            username=current_user.username,
            content=content,
            image_urls=image_urls,
            file_urls=file_urls,
        )
        db.add(new_comment)

        try:
            comment_ids_list = _safe_list(task.comment_ids)
            if new_comment.id not in comment_ids_list:
                comment_ids_list.append(new_comment.id)
            task.comment_ids = comment_ids_list
        except Exception as e:
            print(f"[ERROR] failed to update task.comment_ids: {e}")
            task.comment_ids = [new_comment.id]

        try:
            db.commit()
            db.refresh(new_comment)

            notify_task_comment_added(db, task, current_user, new_comment.id)

            # Handle @mention notifications in comment content.
            mention_pattern = re.compile(r"@([A-Za-z0-9_]+)")
            mentioned_usernames = set(mention_pattern.findall(content))
            if mentioned_usernames:
                mentioned_users = (
                    db.query(User)
                    .filter(User.username.in_(list(mentioned_usernames)), User.id != current_user.id)
                    .all()
                )
                team_member_ids = set(project.team_member_ids or []) if project else set()
                for mentioned_user in mentioned_users:
                    if team_member_ids and mentioned_user.id not in team_member_ids:
                        continue
                    create_notification(
                        db=db,
                        notification_type=NotificationType.TASK_MENTIONED,
                        user_id=mentioned_user.id,
                        title=f"'{task.title}'에서 멘션되었습니다",
                        message=f"{current_user.username}님이 댓글에서 회원님을 언급했습니다",
                        project_id=task.project_id,
                        task_id=task.id,
                        comment_id=new_comment.id,
                    )

            import asyncio

            from app.routers.websocket import manager

            if project and project.team_member_ids:
                target_users = list(project.team_member_ids)
            elif task.assigned_member_ids:
                target_users = list(task.assigned_member_ids)
            else:
                target_users = []

            asyncio.create_task(
                manager.send_to_users(
                    {
                        "type": "comment_created",
                        "data": {
                            "comment_id": new_comment.id,
                            "task_id": new_comment.task_id,
                        },
                    },
                    target_users,
                    exclude_user_id=current_user.id,
                )
            )

            setattr(new_comment, "reactions", {})
            return new_comment
        except Exception as commit_error:
            db.rollback()
            print(f"[ERROR] db commit failed: {commit_error}")
            raise
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"[ERROR] create_comment failed: {e}")
        print(f"[ERROR] task_id={comment_data.task_id}, user_id={current_user.id}")
        print(f"[ERROR] content={comment_data.content}, image_urls={comment_data.image_urls}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"댓글 생성 중 오류가 발생했습니다: {e}",
        )


@router.patch("/{comment_id}", response_model=CommentResponse)
async def update_comment(
    comment_id: str,
    comment_data: CommentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="댓글을 찾을 수 없습니다")

    if comment.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="댓글을 수정할 권한이 없습니다"
        )

    comment.content = comment_data.content
    if comment_data.image_urls is not None:
        comment.image_urls = comment_data.image_urls
    if comment_data.file_urls is not None:
        comment.file_urls = comment_data.file_urls
    db.commit()
    db.refresh(comment)
    _attach_comment_reactions(db, [comment])
    return comment


@router.post("/{comment_id}/reactions")
async def toggle_comment_reaction(
    comment_id: str,
    payload: CommentReactionToggle,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="댓글을 찾을 수 없습니다")

    emoji = (payload.emoji or "").strip()
    if emoji not in {"✅", "👍", "👀"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="지원하지 않는 리액션입니다",
        )

    existing = db.query(CommentReaction).filter(
        CommentReaction.comment_id == comment_id,
        CommentReaction.user_id == current_user.id,
        CommentReaction.emoji == emoji,
    ).first()

    if existing:
        db.delete(existing)
    else:
        db.add(
            CommentReaction(
                comment_id=comment_id,
                user_id=current_user.id,
                emoji=emoji,
            )
        )

    db.commit()
    reaction_map = _build_comment_reactions(db, [comment_id]).get(comment_id, {})
    return {"reactions": reaction_map}


@router.delete("/{comment_id}")
async def delete_comment(
    comment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="댓글을 찾을 수 없습니다")

    if comment.user_id != current_user.id and not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="댓글을 삭제할 권한이 없습니다"
        )

    task = db.query(Task).filter(Task.id == comment.task_id).first()
    if task:
        try:
            comment_ids_list = _safe_list(task.comment_ids)
            if comment_id in comment_ids_list:
                task.comment_ids = [cid for cid in comment_ids_list if cid != comment_id]
        except Exception as e:
            print(f"[ERROR] failed to update task.comment_ids on delete: {e}")

    # 댓글을 참조하는 알림의 comment_id를 NULL로 설정 (FK 제약 위반 방지)
    db.query(Notification).filter(Notification.comment_id == comment_id).update(
        {"comment_id": None}
    )

    db.delete(comment)
    db.commit()
    return {"message": "댓글이 삭제되었습니다"}

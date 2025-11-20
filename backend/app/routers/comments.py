"""
댓글 관리 API 라우터
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import uuid
from app.database import get_db
from app.models.comment import Comment
from app.models.task import Task
from app.models.user import User
from app.schemas.comment import CommentCreate, CommentUpdate, CommentResponse
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get("/task/{task_id}", response_model=List[CommentResponse])
async def get_comments_by_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """특정 태스크의 댓글 목록 가져오기"""
    comments = db.query(Comment).filter(Comment.task_id == task_id).order_by(Comment.created_at).all()
    return comments


@router.get("/{comment_id}", response_model=CommentResponse)
async def get_comment(
    comment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """특정 댓글 정보 가져오기"""
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="댓글을 찾을 수 없습니다"
        )
    return comment


@router.post("/", response_model=CommentResponse, status_code=status.HTTP_201_CREATED)
async def create_comment(
    comment_data: CommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """새 댓글 생성"""
    # 태스크 존재 확인
    task = db.query(Task).filter(Task.id == comment_data.task_id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="태스크를 찾을 수 없습니다"
        )
    
    new_comment = Comment(
        id=str(uuid.uuid4()),
        task_id=comment_data.task_id,
        user_id=current_user.id,
        username=current_user.username,
        content=comment_data.content
    )
    
    db.add(new_comment)
    
    # 태스크의 comment_ids에 추가
    if new_comment.id not in task.comment_ids:
        task.comment_ids = list(task.comment_ids) + [new_comment.id]
    
    db.commit()
    db.refresh(new_comment)
    return new_comment


@router.patch("/{comment_id}", response_model=CommentResponse)
async def update_comment(
    comment_id: str,
    comment_data: CommentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """댓글 수정 (작성자만 가능)"""
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="댓글을 찾을 수 없습니다"
        )
    
    # 작성자 확인
    if comment.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="댓글을 수정할 권한이 없습니다"
        )
    
    comment.content = comment_data.content
    db.commit()
    db.refresh(comment)
    return comment


@router.delete("/{comment_id}")
async def delete_comment(
    comment_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """댓글 삭제 (작성자 또는 관리자만 가능)"""
    comment = db.query(Comment).filter(Comment.id == comment_id).first()
    if not comment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="댓글을 찾을 수 없습니다"
        )
    
    # 작성자 또는 관리자 확인
    if comment.user_id != current_user.id and not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="댓글을 삭제할 권한이 없습니다"
        )
    
    # 태스크의 comment_ids에서 제거
    task = db.query(Task).filter(Task.id == comment.task_id).first()
    if task and comment_id in task.comment_ids:
        task.comment_ids = [id for id in task.comment_ids if id != comment_id]
    
    db.delete(comment)
    db.commit()
    return {"message": "댓글이 삭제되었습니다"}


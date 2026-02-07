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
from app.utils.notifications import notify_task_comment_added

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
    try:
        # 내용 검증 (content가 None이거나 빈 문자열인 경우 처리)
        content = comment_data.content or ""
        image_urls = comment_data.image_urls or []
        
        if not content.strip() and not image_urls:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="댓글 내용 또는 이미지가 필요합니다"
            )
        
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
            content=content,
            image_urls=image_urls
        )
        
        db.add(new_comment)
        
        # 태스크의 comment_ids에 추가 (안전하게 처리)
        try:
            # comment_ids를 리스트로 변환 (None이거나 다른 타입인 경우 처리)
            if task.comment_ids is None:
                comment_ids_list = []
            elif isinstance(task.comment_ids, list):
                comment_ids_list = list(task.comment_ids)
            else:
                # 다른 타입인 경우 리스트로 변환 시도
                comment_ids_list = list(task.comment_ids) if hasattr(task.comment_ids, '__iter__') else []
            
            # 중복 체크 후 추가
            if new_comment.id not in comment_ids_list:
                comment_ids_list.append(new_comment.id)
            
            task.comment_ids = comment_ids_list
        except Exception as e:
            print(f"[ERROR] comment_ids 업데이트 실패: {str(e)}")
            print(f"[ERROR] task.comment_ids 타입: {type(task.comment_ids)}, 값: {task.comment_ids}")
            # comment_ids 업데이트 실패해도 댓글은 저장
            task.comment_ids = [new_comment.id]
        
        try:
            db.commit()
            db.refresh(new_comment)
            
            # 작업 코멘트 추가 알림
            notify_task_comment_added(db, task, current_user, new_comment.id)
            
            # 태스크 할당자에게만 댓글 생성 이벤트 전송 (타겟 전송)
            import asyncio
            from app.routers.websocket import manager
            target_users = list(task.assigned_member_ids) if task.assigned_member_ids else []
            asyncio.create_task(manager.send_to_users({
                "type": "comment_created",
                "data": {
                    "comment_id": new_comment.id,
                    "task_id": new_comment.task_id,
                }
            }, target_users, exclude_user_id=current_user.id))
            
            return new_comment
        except Exception as commit_error:
            db.rollback()
            print(f"[ERROR] DB 커밋 실패: {str(commit_error)}")
            raise
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"[ERROR] 댓글 생성 실패: {str(e)}")
        print(f"[ERROR] task_id: {comment_data.task_id}, user_id: {current_user.id}")
        print(f"[ERROR] content: {comment_data.content}, image_urls: {comment_data.image_urls}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"댓글 생성 중 오류가 발생했습니다: {str(e)}"
        )


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
    if comment_data.image_urls is not None:
        comment.image_urls = comment_data.image_urls
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
    if task:
        try:
            # comment_ids를 리스트로 변환 (안전하게 처리)
            if task.comment_ids is None:
                comment_ids_list = []
            elif isinstance(task.comment_ids, list):
                comment_ids_list = list(task.comment_ids)
            else:
                comment_ids_list = list(task.comment_ids) if hasattr(task.comment_ids, '__iter__') else []
            
            # comment_id 제거
            if comment_id in comment_ids_list:
                comment_ids_list = [id for id in comment_ids_list if id != comment_id]
                task.comment_ids = comment_ids_list
        except Exception as e:
            print(f"[ERROR] comment_ids 업데이트 실패 (삭제): {str(e)}")
            # 에러가 발생해도 댓글 삭제는 계속 진행
    
    db.delete(comment)
    db.commit()
    return {"message": "댓글이 삭제되었습니다"}


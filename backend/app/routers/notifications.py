"""
알림 관리 API 라우터
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.models.notification import Notification
from app.models.user import User
from app.schemas.notification import NotificationResponse, NotificationUpdate
from app.utils.dependencies import get_current_user

router = APIRouter()


@router.get("/", response_model=List[NotificationResponse])
async def get_notifications(
    user_id: Optional[str] = Query(None, description="사용자 ID (필터링)"),
    unread_only: Optional[bool] = Query(False, description="읽지 않은 알림만"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """알림 목록 가져오기"""
    query = db.query(Notification)
    
    # 현재 사용자의 알림만 가져오기 (user_id가 지정되지 않은 경우)
    if user_id is None:
        user_id = current_user.id
    else:
        # 다른 사용자의 알림을 조회하려면 관리자 권한 필요
        if user_id != current_user.id and not current_user.is_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="다른 사용자의 알림을 조회할 권한이 없습니다"
            )
    
    query = query.filter(Notification.user_id == user_id)
    
    if unread_only:
        query = query.filter(Notification.is_read == False)
    
    # 최신순 정렬
    notifications = query.order_by(Notification.created_at.desc()).all()
    return notifications


@router.get("/count")
async def get_notification_count(
    user_id: Optional[str] = Query(None, description="사용자 ID"),
    unread_only: Optional[bool] = Query(True, description="읽지 않은 알림만"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """알림 개수 가져오기"""
    query = db.query(Notification)
    
    if user_id is None:
        user_id = current_user.id
    else:
        if user_id != current_user.id and not current_user.is_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="다른 사용자의 알림을 조회할 권한이 없습니다"
            )
    
    query = query.filter(Notification.user_id == user_id)
    
    if unread_only:
        query = query.filter(Notification.is_read == False)
    
    count = query.count()
    return {"count": count}


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
async def mark_notification_as_read(
    notification_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """알림을 읽음으로 표시"""
    notification = db.query(Notification).filter(Notification.id == notification_id).first()
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="알림을 찾을 수 없습니다"
        )
    
    # 본인의 알림만 읽음 처리 가능
    if notification.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="다른 사용자의 알림을 수정할 권한이 없습니다"
        )
    
    notification.is_read = True
    db.commit()
    db.refresh(notification)
    return notification


@router.patch("/read-all", response_model=List[NotificationResponse])
async def mark_all_notifications_as_read(
    user_id: Optional[str] = Query(None, description="사용자 ID"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """모든 알림을 읽음으로 표시"""
    if user_id is None:
        user_id = current_user.id
    else:
        if user_id != current_user.id and not current_user.is_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="다른 사용자의 알림을 수정할 권한이 없습니다"
            )
    
    notifications = db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read == False
    ).all()
    
    for notification in notifications:
        notification.is_read = True
    
    db.commit()
    return notifications


@router.delete("/{notification_id}")
async def delete_notification(
    notification_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """알림 삭제"""
    notification = db.query(Notification).filter(Notification.id == notification_id).first()
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="알림을 찾을 수 없습니다"
        )
    
    # 본인의 알림만 삭제 가능
    if notification.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="다른 사용자의 알림을 삭제할 권한이 없습니다"
        )
    
    db.delete(notification)
    db.commit()
    return {"message": "알림이 삭제되었습니다"}


"""Mattermost incoming webhook 연동 (사용자별 설정 기반)."""
import json
import httpx

from sqlalchemy.orm import Session

from app.config import settings
from app.models.notification import NotificationType
from app.models.user_mattermost_setting import UserMattermostSetting


_ICON_MAP = {
    NotificationType.TASK_ASSIGNED: ":clipboard:",
    NotificationType.TASK_OPTION_CHANGED: ":pencil:",
    NotificationType.TASK_COMMENT_ADDED: ":speech_balloon:",
    NotificationType.PROJECT_MEMBER_ADDED: ":busts_in_silhouette:",
}


def send_mattermost_notification(
    db: Session,
    user_id: str,
    notification_type: NotificationType,
    title: str,
    message: str,
    username: str = "SYNC",
    task_id: str = None,
) -> None:
    """사용자 Mattermost 설정을 조회해 활성화된 경우 웹훅으로 알림 전송."""
    try:
        rec = db.query(UserMattermostSetting).filter(
            UserMattermostSetting.user_id == user_id
        ).first()
        if not rec or not rec.is_enabled or not rec.webhook_url:
            return

        icon = _ICON_MAP.get(notification_type, ":bell:")
        text = f"{icon} **{title}**\n{message}"

        # 작업 링크 추가
        if task_id and settings.FRONTEND_URL:
            task_url = f"{settings.FRONTEND_URL}/task/{task_id}"
            text += f"\n:link: [작업 보기]({task_url})"

        httpx.post(
            rec.webhook_url,
            content=json.dumps({"text": text, "username": username}, ensure_ascii=False).encode("utf-8"),
            headers={"Content-Type": "application/json; charset=utf-8"},
            timeout=5.0,
        )
    except Exception as e:
        print(f"[Mattermost] 전송 실패 (user={user_id}): {e}")

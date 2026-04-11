"""AI 일별 요약 캐시 모델."""
from sqlalchemy import Column, String, Date, DateTime, Text
from sqlalchemy.sql import func
from app.database import Base


class AiSummaryCache(Base):
    __tablename__ = "ai_summary_cache"

    id = Column(String, primary_key=True, index=True)
    user_id = Column(String, nullable=False, index=True)
    workspace_id = Column(String, nullable=True)   # None = 전체 워크스페이스
    summary_scope = Column(String, nullable=False, default="all")  # mine|others|all
    summary_date = Column(Date, nullable=False, index=True)         # 생성 날짜 (하루 1회 기준)
    summary_text = Column(Text, nullable=False)
    generated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self):
        return (
            f"<AiSummaryCache(user={self.user_id}, date={self.summary_date}, "
            f"scope={self.summary_scope})>"
        )

"""
데이터베이스 초기화 스크립트
초기 관리자 계정 생성
"""
from sqlalchemy.orm import Session
from app.database import SessionLocal, engine, Base
from app.models.user import User
from app.utils.security import get_password_hash
import uuid

# 테이블 생성
Base.metadata.create_all(bind=engine)

def init_db():
    """초기 데이터베이스 설정"""
    db: Session = SessionLocal()
    try:
        # 관리자 계정이 있는지 확인
        admin = db.query(User).filter(User.is_admin == True).first()
        
        if not admin:
            # 초기 관리자 계정 생성
            admin_user = User(
                id=str(uuid.uuid4()),
                username="admin",
                email="admin@dora.com",
                password_hash=get_password_hash("admin123"),  # 기본 비밀번호
                is_admin=True,
                is_approved=True,
                is_pm=True
            )
            db.add(admin_user)
            db.commit()
            print("✅ 초기 관리자 계정이 생성되었습니다.")
            print("   사용자명: admin")
            print("   비밀번호: admin123")
        else:
            print("✅ 관리자 계정이 이미 존재합니다.")
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    init_db()


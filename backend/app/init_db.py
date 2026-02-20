"""
데이터베이스 초기화 스크립트
초기 관리자 계정 생성
"""
from sqlalchemy.orm import Session
from sqlalchemy import text, inspect
from app.database import SessionLocal, engine, Base
from app.models.user import User
from app.utils.security import get_password_hash
import uuid

# 테이블 생성
Base.metadata.create_all(bind=engine)


def run_migrations():
    """기존 테이블에 누락된 컬럼 추가"""
    inspector = inspect(engine)
    with engine.connect() as conn:
        # tasks 테이블에 display_order 컬럼 추가
        if 'tasks' in inspector.get_table_names():
            columns = [col['name'] for col in inspector.get_columns('tasks')]
            if 'display_order' not in columns:
                conn.execute(text("ALTER TABLE tasks ADD COLUMN display_order INTEGER DEFAULT 0 NOT NULL"))
                conn.commit()
                print("✅ tasks 테이블에 display_order 컬럼이 추가되었습니다.")

        # projects 테이블에 workspace_id, creator_id 컬럼 추가
        if 'projects' in inspector.get_table_names():
            columns = [col['name'] for col in inspector.get_columns('projects')]
            if 'workspace_id' not in columns:
                conn.execute(text("ALTER TABLE projects ADD COLUMN workspace_id VARCHAR"))
                conn.commit()
                print("✅ projects 테이블에 workspace_id 컬럼이 추가되었습니다.")
            if 'creator_id' not in columns:
                conn.execute(text("ALTER TABLE projects ADD COLUMN creator_id VARCHAR"))
                conn.commit()
                print("✅ projects 테이블에 creator_id 컬럼이 추가되었습니다.")

        # 기존 users 중 is_approved=False인 일반 사용자(비관리자) 자동 승인
        # (기존 미승인 사용자 구제 - 최초 1회)
        try:
            conn.execute(text(
                "UPDATE users SET is_approved = TRUE WHERE is_approved = FALSE AND is_admin = FALSE"
            ))
            conn.commit()
        except Exception:
            pass


run_migrations()


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


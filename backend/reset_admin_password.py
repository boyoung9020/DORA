"""
admin 계정 비밀번호 재설정 스크립트
"""
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.user import User
from app.utils.security import get_password_hash

def reset_admin_password():
    """admin 계정 비밀번호를 admin123으로 재설정"""
    db: Session = SessionLocal()
    try:
        # admin 계정 찾기
        admin = db.query(User).filter(User.username == "admin").first()
        
        if not admin:
            print("❌ admin 계정을 찾을 수 없습니다.")
            # admin 계정 생성
            import uuid
            admin = User(
                id=str(uuid.uuid4()),
                username="admin",
                email="admin@dora.com",
                password_hash=get_password_hash("admin123"),
                is_admin=True,
                is_approved=True,
                is_pm=True
            )
            db.add(admin)
            print("✅ admin 계정을 새로 생성했습니다.")
        else:
            # 비밀번호 재설정
            admin.password_hash = get_password_hash("admin123")
            admin.is_admin = True
            admin.is_approved = True
            admin.is_pm = True
            print("✅ admin 계정 비밀번호를 재설정했습니다.")
        
        db.commit()
        print(f"   사용자명: {admin.username}")
        print(f"   이메일: {admin.email}")
        print(f"   비밀번호: admin123")
        print(f"   is_admin: {admin.is_admin}")
        print(f"   is_approved: {admin.is_approved}")
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    reset_admin_password()

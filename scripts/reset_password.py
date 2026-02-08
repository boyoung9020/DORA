#!/usr/bin/env python3
"""
사용자 비밀번호 재설정 스크립트
사용법: python3 reset_password.py <username> <new_password>
"""
import sys
import os

# 프로젝트 루트를 Python 경로에 추가
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.user import User
from app.utils.security import get_password_hash

def reset_password(username: str, new_password: str):
    """사용자 비밀번호 재설정"""
    db: Session = SessionLocal()
    try:
        # 사용자 찾기
        user = db.query(User).filter(User.username == username).first()
        
        if not user:
            print(f"❌ 사용자를 찾을 수 없습니다: {username}")
            print("\n사용 가능한 사용자 목록:")
            all_users = db.query(User).all()
            for u in all_users:
                print(f"  - {u.username} ({u.email})")
            return False
        
        # 비밀번호 해시 생성
        password_hash = get_password_hash(new_password)
        
        # 비밀번호 업데이트
        user.password_hash = password_hash
        db.commit()
        
        print(f"✅ 비밀번호가 재설정되었습니다!")
        print(f"   사용자: {user.username}")
        print(f"   이메일: {user.email}")
        print(f"   새 비밀번호: {new_password}")
        print(f"   승인 상태: {'승인됨' if user.is_approved else '승인 대기'}")
        return True
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        db.rollback()
        return False
    finally:
        db.close()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("사용법: python3 reset_password.py <username> <new_password>")
        print("\n예시:")
        print("  python3 reset_password.py boyoung newpassword123")
        sys.exit(1)
    
    username = sys.argv[1]
    new_password = sys.argv[2]
    
    if len(new_password) < 6:
        print("❌ 비밀번호는 최소 6자 이상이어야 합니다.")
        sys.exit(1)
    
    reset_password(username, new_password)


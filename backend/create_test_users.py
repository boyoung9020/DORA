"""
테스트 유저 생성 스크립트
"""
import uuid
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models.user import User
from app.utils.security import get_password_hash

def create_test_users():
    """테스트 유저 여러 명 생성"""
    db: Session = SessionLocal()
    
    test_users = [
        {
            "username": "김철수",
            "email": "kim.cs@dora.com",
            "password": "test123",
            "is_pm": False
        },
        {
            "username": "이영희",
            "email": "lee.yh@dora.com",
            "password": "test123",
            "is_pm": False
        },
        {
            "username": "박지훈",
            "email": "park.jh@dora.com",
            "password": "test123",
            "is_pm": True  # PM 권한
        },
        {
            "username": "최민수",
            "email": "choi.ms@dora.com",
            "password": "test123",
            "is_pm": False
        },
        {
            "username": "정수진",
            "email": "jung.sj@dora.com",
            "password": "test123",
            "is_pm": False
        },
        {
            "username": "강동원",
            "email": "kang.dw@dora.com",
            "password": "test123",
            "is_pm": False
        },
        {
            "username": "송혜교",
            "email": "song.hg@dora.com",
            "password": "test123",
            "is_pm": True  # PM 권한
        },
        {
            "username": "이민호",
            "email": "lee.mh@dora.com",
            "password": "test123",
            "is_pm": False
        },
    ]
    
    try:
        created_count = 0
        updated_count = 0
        
        for user_data in test_users:
            # 이미 존재하는 사용자인지 확인
            existing_user = db.query(User).filter(
                (User.username == user_data["username"]) |
                (User.email == user_data["email"])
            ).first()
            
            if existing_user:
                # 기존 사용자 업데이트
                existing_user.password_hash = get_password_hash(user_data["password"])
                existing_user.is_approved = True
                existing_user.is_pm = user_data["is_pm"]
                print(f"✏️  {user_data['username']} 계정을 업데이트했습니다.")
                updated_count += 1
            else:
                # 새 사용자 생성
                new_user = User(
                    id=str(uuid.uuid4()),
                    username=user_data["username"],
                    email=user_data["email"],
                    password_hash=get_password_hash(user_data["password"]),
                    is_admin=False,
                    is_approved=True,  # 바로 승인
                    is_pm=user_data["is_pm"]
                )
                db.add(new_user)
                print(f"✅ {user_data['username']} 계정을 생성했습니다.")
                created_count += 1
        
        db.commit()
        
        print("\n" + "="*50)
        print(f"📊 생성: {created_count}명, 업데이트: {updated_count}명")
        print("="*50)
        print("\n모든 테스트 유저 정보:")
        print("-"*50)
        
        for user_data in test_users:
            pm_status = "PM" if user_data["is_pm"] else "일반"
            print(f"  👤 {user_data['username']:<10} | {user_data['email']:<25} | 비밀번호: {user_data['password']:<10} | 권한: {pm_status}")
        
        print("-"*50)
        print("\n💡 모든 유저의 비밀번호는 'test123' 입니다.")
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    print("\n🚀 테스트 유저 생성 시작...\n")
    create_test_users()
    print("\n✨ 완료!\n")

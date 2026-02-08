"""
API를 통한 테스트 유저 생성 스크립트
실행: python create_test_users_api.py
자동 승인: python create_test_users_api.py --approve
"""
import argparse
import requests

# 백엔드 API URL
BASE_URL = "http://localhost:8000"

# 테스트 유저 목록
test_users = [
    {
        "username": "김철수",
        "email": "kim.cs@dora.com",
        "password": "test123",
    },
    {
        "username": "이영희",
        "email": "lee.yh@dora.com",
        "password": "test123",
    },
    {
        "username": "박지훈",
        "email": "park.jh@dora.com",
        "password": "test123",
    },
    {
        "username": "최민수",
        "email": "choi.ms@dora.com",
        "password": "test123",
    },
    {
        "username": "정수진",
        "email": "jung.sj@dora.com",
        "password": "test123",
    },
    {
        "username": "강동원",
        "email": "kang.dw@dora.com",
        "password": "test123",
    },
    {
        "username": "송혜교",
        "email": "song.hg@dora.com",
        "password": "test123",
    },
    {
        "username": "이민호",
        "email": "lee.mh@dora.com",
        "password": "test123",
    },
]

def create_users():
    """API를 통해 유저 생성"""
    print("\n🚀 테스트 유저 생성 시작...\n")
    
    created_count = 0
    failed_count = 0
    
    for user_data in test_users:
        try:
            response = requests.post(
                f"{BASE_URL}/api/auth/register",
                json=user_data,
                timeout=10
            )
            
            if response.status_code in [200, 201]:
                print(f"✅ {user_data['username']} 계정을 생성했습니다.")
                created_count += 1
            else:
                try:
                    error_detail = response.json().get('detail', '알 수 없는 오류')
                except Exception:
                    error_detail = response.text
                if "already exists" in str(error_detail) or "이미 존재" in str(error_detail):
                    print(f"ℹ️  {user_data['username']} 계정이 이미 존재합니다.")
                else:
                    print(f"❌ {user_data['username']} 생성 실패: {error_detail}")
                    failed_count += 1
                
        except requests.exceptions.ConnectionError:
            print(f"❌ 서버에 연결할 수 없습니다. 백엔드 서버가 실행 중인지 확인하세요.")
            print(f"   백엔드 URL: {BASE_URL}")
            return
        except Exception as e:
            print(f"❌ {user_data['username']} 생성 중 오류: {e}")
            failed_count += 1
    
    print("\n" + "="*60)
    print(f"📊 생성: {created_count}명, 실패: {failed_count}명")
    print("="*60)
    
    if created_count > 0:
        print("\n⚠️  주의: 생성된 유저는 관리자 승인이 필요합니다!")
        print("   자동 승인: python create_test_users_api.py --approve\n")
    
    print("\n모든 테스트 유저 정보:")
    print("-"*60)
    for user_data in test_users:
        print(f"  👤 {user_data['username']:<10} | {user_data['email']:<25} | 비밀번호: {user_data['password']}")
    print("-"*60)
    print("\n💡 모든 유저의 비밀번호는 'test123' 입니다.")
    print("\n✨ 완료!\n")

def approve_all_users():
    """모든 대기 중인 유저 승인 (admin 권한 필요)"""
    print("\n🔐 관리자 로그인...\n")
    
    # admin 로그인
    try:
        login_response = requests.post(
            f"{BASE_URL}/api/auth/login",
            json={
                "username": "admin",
                "password": "admin123"
            },
            timeout=10
        )
        
        if login_response.status_code != 200:
            print("❌ admin 로그인 실패. admin 계정을 확인하세요.")
            return
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        print("✅ admin 로그인 성공\n")
        print("👥 승인 대기 중인 유저 확인 중...\n")
        
        # 대기 중인 유저 목록 가져오기
        pending_response = requests.get(
            f"{BASE_URL}/api/users/pending",
            headers=headers,
            timeout=10
        )
        
        if pending_response.status_code != 200:
            print("❌ 대기 중인 유저 목록을 가져올 수 없습니다.")
            return
        
        pending_users = pending_response.json()
        
        if not pending_users:
            print("ℹ️  승인 대기 중인 유저가 없습니다.\n")
            return
        
        print(f"📋 {len(pending_users)}명의 유저를 승인합니다...\n")
        
        approved_count = 0
        for user in pending_users:
            try:
                approve_response = requests.patch(
                    f"{BASE_URL}/api/users/{user['id']}/approve",
                    headers=headers,
                    timeout=10
                )
                
                if approve_response.status_code == 200:
                    print(f"✅ {user['username']} 승인 완료")
                    approved_count += 1
                else:
                    print(f"❌ {user['username']} 승인 실패")
            except Exception as e:
                print(f"❌ {user['username']} 승인 중 오류: {e}")
        
        print(f"\n✨ {approved_count}명의 유저를 승인했습니다!\n")
        
    except requests.exceptions.ConnectionError:
        print(f"❌ 서버에 연결할 수 없습니다. 백엔드 서버가 실행 중인지 확인하세요.")
    except Exception as e:
        print(f"❌ 오류 발생: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="테스트 유저 생성 (API 사용)")
    parser.add_argument(
        "--approve",
        action="store_true",
        help="유저 생성 후 admin으로 로그인해 대기 중인 유저 자동 승인",
    )
    args = parser.parse_args()

    # 1단계: 유저 생성
    create_users()

    # 2단계: --approve 옵션이 있으면 자동 승인
    if args.approve:
        approve_all_users()
    else:
        print("💡 자동 승인하려면: python create_test_users_api.py --approve\n")

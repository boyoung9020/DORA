"""
API瑜??듯븳 ?뚯뒪???좎? ?앹꽦 ?ㅽ겕由쏀듃
?ㅽ뻾: python create_test_users_api.py
?먮룞 ?뱀씤: python create_test_users_api.py --approve
"""
import argparse
import requests

# 諛깆뿏??API URL
BASE_URL = "http://localhost:8000"

# ?뚯뒪???좎? 紐⑸줉
test_users = [
    {
        "username": "源泥좎닔",
        "email": "kim.cs@sync.com",
        "password": "test123",
    },
    {
        "username": "?댁쁺??,
        "email": "lee.yh@sync.com",
        "password": "test123",
    },
    {
        "username": "諛뺤???,
        "email": "park.jh@sync.com",
        "password": "test123",
    },
    {
        "username": "理쒕???,
        "email": "choi.ms@sync.com",
        "password": "test123",
    },
    {
        "username": "?뺤닔吏?,
        "email": "jung.sj@sync.com",
        "password": "test123",
    },
    {
        "username": "媛뺣룞??,
        "email": "kang.dw@sync.com",
        "password": "test123",
    },
    {
        "username": "?≫삙援?,
        "email": "song.hg@sync.com",
        "password": "test123",
    },
    {
        "username": "?대???,
        "email": "lee.mh@sync.com",
        "password": "test123",
    },
]

def create_users():
    """API瑜??듯빐 ?좎? ?앹꽦"""
    print("\n?? ?뚯뒪???좎? ?앹꽦 ?쒖옉...\n")
    
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
                print(f"??{user_data['username']} 怨꾩젙???앹꽦?덉뒿?덈떎.")
                created_count += 1
            else:
                try:
                    error_detail = response.json().get('detail', '?????녿뒗 ?ㅻ쪟')
                except Exception:
                    error_detail = response.text
                if "already exists" in str(error_detail) or "?대? 議댁옱" in str(error_detail):
                    print(f"?뱄툘  {user_data['username']} 怨꾩젙???대? 議댁옱?⑸땲??")
                else:
                    print(f"??{user_data['username']} ?앹꽦 ?ㅽ뙣: {error_detail}")
                    failed_count += 1
                
        except requests.exceptions.ConnectionError:
            print(f"???쒕쾭???곌껐?????놁뒿?덈떎. 諛깆뿏???쒕쾭媛 ?ㅽ뻾 以묒씤吏 ?뺤씤?섏꽭??")
            print(f"   諛깆뿏??URL: {BASE_URL}")
            return
        except Exception as e:
            print(f"??{user_data['username']} ?앹꽦 以??ㅻ쪟: {e}")
            failed_count += 1
    
    print("\n" + "="*60)
    print(f"?뱤 ?앹꽦: {created_count}紐? ?ㅽ뙣: {failed_count}紐?)
    print("="*60)
    
    if created_count > 0:
        print("\n?좑툘  二쇱쓽: ?앹꽦???좎???愿由ъ옄 ?뱀씤???꾩슂?⑸땲??")
        print("   ?먮룞 ?뱀씤: python create_test_users_api.py --approve\n")
    
    print("\n紐⑤뱺 ?뚯뒪???좎? ?뺣낫:")
    print("-"*60)
    for user_data in test_users:
        print(f"  ?뫀 {user_data['username']:<10} | {user_data['email']:<25} | 鍮꾨?踰덊샇: {user_data['password']}")
    print("-"*60)
    print("\n?뮕 紐⑤뱺 ?좎???鍮꾨?踰덊샇??'test123' ?낅땲??")
    print("\n???꾨즺!\n")

def approve_all_users():
    """紐⑤뱺 ?湲?以묒씤 ?좎? ?뱀씤 (admin 沅뚰븳 ?꾩슂)"""
    print("\n?뵍 愿由ъ옄 濡쒓렇??..\n")
    
    # admin 濡쒓렇??
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
            print("??admin 濡쒓렇???ㅽ뙣. admin 怨꾩젙???뺤씤?섏꽭??")
            return
        
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        print("??admin 濡쒓렇???깃났\n")
        print("?뫁 ?뱀씤 ?湲?以묒씤 ?좎? ?뺤씤 以?..\n")
        
        # ?湲?以묒씤 ?좎? 紐⑸줉 媛?몄삤湲?
        pending_response = requests.get(
            f"{BASE_URL}/api/users/pending",
            headers=headers,
            timeout=10
        )
        
        if pending_response.status_code != 200:
            print("???湲?以묒씤 ?좎? 紐⑸줉??媛?몄삱 ???놁뒿?덈떎.")
            return
        
        pending_users = pending_response.json()
        
        if not pending_users:
            print("?뱄툘  ?뱀씤 ?湲?以묒씤 ?좎?媛 ?놁뒿?덈떎.\n")
            return
        
        print(f"?뱥 {len(pending_users)}紐낆쓽 ?좎?瑜??뱀씤?⑸땲??..\n")
        
        approved_count = 0
        for user in pending_users:
            try:
                approve_response = requests.patch(
                    f"{BASE_URL}/api/users/{user['id']}/approve",
                    headers=headers,
                    timeout=10
                )
                
                if approve_response.status_code == 200:
                    print(f"??{user['username']} ?뱀씤 ?꾨즺")
                    approved_count += 1
                else:
                    print(f"??{user['username']} ?뱀씤 ?ㅽ뙣")
            except Exception as e:
                print(f"??{user['username']} ?뱀씤 以??ㅻ쪟: {e}")
        
        print(f"\n??{approved_count}紐낆쓽 ?좎?瑜??뱀씤?덉뒿?덈떎!\n")
        
    except requests.exceptions.ConnectionError:
        print(f"???쒕쾭???곌껐?????놁뒿?덈떎. 諛깆뿏???쒕쾭媛 ?ㅽ뻾 以묒씤吏 ?뺤씤?섏꽭??")
    except Exception as e:
        print(f"???ㅻ쪟 諛쒖깮: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="?뚯뒪???좎? ?앹꽦 (API ?ъ슜)")
    parser.add_argument(
        "--approve",
        action="store_true",
        help="?좎? ?앹꽦 ??admin?쇰줈 濡쒓렇?명빐 ?湲?以묒씤 ?좎? ?먮룞 ?뱀씤",
    )
    args = parser.parse_args()

    # 1?④퀎: ?좎? ?앹꽦
    create_users()

    # 2?④퀎: --approve ?듭뀡???덉쑝硫??먮룞 ?뱀씤
    if args.approve:
        approve_all_users()
    else:
        print("?뮕 ?먮룞 ?뱀씤?섎젮硫? python create_test_users_api.py --approve\n")

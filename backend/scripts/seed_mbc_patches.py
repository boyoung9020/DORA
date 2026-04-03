import requests

BASE = 'https://syncwork.kr'
r = requests.post(f'{BASE}/api/auth/login', json={'username':'admin','password':'admin123'})
TOKEN = r.json()['access_token']
headers = {'Authorization': f'Bearer {TOKEN}'}

OCR_ID   = '3f752357-58d7-47e8-b5fe-4e6e52945bb9'
장면설명_객체인식_ID = 'ff7259fb-00ef-400f-b8d8-4d125f231ede'
SITE     = 'MBC'

ocr = [
    ('2024-11-25', '1.0.0',       '최초 배포'),
    ('2025-03-04', '1.1.0',       'OCR 전체화면'),
    ('2025-03-10', '1.0.0',       '롤백'),
    ('2025-03-18', '1.0.1(임시)', 'bbox제외, response 통일, /search로 변경'),
    ('2025-03-20', '1.1.1',       'code:200 제거, avg_confidence 고정값'),
    ('2025-03-30', '1.1.2',       '리턴 한글 안되는 문제, log 간소화'),
    ('2025-03-31', '1.1.3',       '리스트로 처리할때 craft 좌표 중복 해결'),
    ('2025-04-02', '1.1.4',       '모델 최신으로 변경 / 필요없는 모델 삭제'),
    ('2025-04-03', '1.1.5',       'threshold 0.8로 상향'),
    ('2025-05-29', '1.1.6',       'pixel 선언 오류 수정'),
]

장면설명_객체인식 = [
    ('2024-11-25', '1.0.0', '최초 배포'),
    ('2025-03-04', '1.1.0', 'VLLM 테스트'),
    ('2025-03-10', '1.0.0', '롤백'),
    ('2025-05-23', '1.1.5', '모델 blip2 -> Clova X 로 변경'),
]

def create(proj_id, date, ver, content):
    payload = {'project_id': proj_id, 'site': SITE, 'version': ver, 'patch_date': date, 'content': content}
    r = requests.post(f'{BASE}/api/patches/', json=payload, headers=headers)
    if r.status_code in (200, 201):
        d = r.json()
        print(f'  [+] {d["patch_date"]}  v{d["version"]}  {d["content"]}')
    else:
        print(f'  [!] {r.status_code}: {r.text[:100]}')

print('=== OCR 패치 등록 ===')
for date, ver, content in ocr:
    create(OCR_ID, date, ver, content)

print()
print('=== 장면설명&객체인식 패치 등록 ===')
for date, ver, content in 장면설명_객체인식:
    create(장면설명_객체인식_ID, date, ver, content)

print()
print('완료!')

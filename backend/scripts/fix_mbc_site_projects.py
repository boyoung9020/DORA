import requests

BASE = 'https://syncwork.kr'
r = requests.post(f'{BASE}/api/auth/login', json={'username':'admin','password':'admin123'})
TOKEN = r.json()['access_token']
headers = {'Authorization': f'Bearer {TOKEN}'}

MBC_SITE_ID = '75095082-b9b8-45c9-8a8c-f95e8a462c23'
# 얼굴인식 + OCR + SCENE
PROJECT_IDS = [
    '44e79d33-bca8-4a24-aaab-6b3c755b0096',  # 얼굴인식
    '3f752357-58d7-47e8-b5fe-4e6e52945bb9',   # OCR
    'ff7259fb-00ef-400f-b8d8-4d125f231ede',   # 장면설명&객체인식
]

r = requests.patch(f'{BASE}/api/site-details/{MBC_SITE_ID}',
                   json={'project_ids': PROJECT_IDS},
                   headers=headers)
print(r.status_code, r.json().get('project_ids'))

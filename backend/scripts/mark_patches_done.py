import requests

BASE = 'https://syncwork.kr'
r = requests.post(f'{BASE}/api/auth/login', json={'username':'admin','password':'admin123'})
TOKEN = r.json()['access_token']
headers = {'Authorization': f'Bearer {TOKEN}'}

for 프로젝트명, pid in [('OCR', '3f752357-58d7-47e8-b5fe-4e6e52945bb9'), ('장면설명&객체인식', 'ff7259fb-00ef-400f-b8d8-4d125f231ede')]:
    r = requests.get(f'{BASE}/api/patches/?project_id={pid}', headers=headers)
    patches = r.json()
    print(f'=== {프로젝트명} ({len(patches)}건) 완료 처리 중 ===')
    for p in patches:
        r2 = requests.patch(f'{BASE}/api/patches/{p["id"]}', json={'status': 'done'}, headers=headers)
        if r2.status_code == 200:
            print(f'  [+] {p["patch_date"]}  v{p["version"]}  {p["content"]}')
        else:
            print(f'  [!] 실패 ({r2.status_code}): {r2.text[:80]}')

print('\n완료!')

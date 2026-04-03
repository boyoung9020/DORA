import requests

BASE = 'https://syncwork.kr'
r = requests.post(f'{BASE}/api/auth/login', json={'username':'admin','password':'admin123'})
TOKEN = r.json()['access_token']
headers = {'Authorization': f'Bearer {TOKEN}'}

for name, pid in [('OCR', '3f752357-58d7-47e8-b5fe-4e6e52945bb9'), ('장면설명&객체인식', 'ff7259fb-00ef-400f-b8d8-4d125f231ede')]:
    r = requests.get(f'{BASE}/api/patches/?project_id={pid}', headers=headers)
    patches = r.json()
    print(f'=== {name} ({len(patches)}건) ===')
    for p in sorted(patches, key=lambda x: x['patch_date']):
        print(f"  {p['patch_date']}  v{p['version']}  {p['content']}")
    print()

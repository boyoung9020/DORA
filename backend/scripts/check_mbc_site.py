import requests

BASE = 'https://syncwork.kr'
r = requests.post(f'{BASE}/api/auth/login', json={'username':'admin','password':'admin123'})
TOKEN = r.json()['access_token']
headers = {'Authorization': f'Bearer {TOKEN}'}

# site_details 목록 확인
r = requests.get(f'{BASE}/api/site-details/', headers=headers)
sites = r.json()
print(f'=== site_details ({len(sites)}개) ===')
for s in sites:
    print(f"  name={s['name']}  id={s['id']}  project_ids={s.get('project_ids')}")

# 패치에서 site='MBC' 조회
r2 = requests.get(f'{BASE}/api/patches/?site_name=MBC', headers=headers)
print(f'\n=== site=MBC 패치 ({len(r2.json())}건) ===')
for p in sorted(r2.json(), key=lambda x: x['patch_date']):
    print(f"  {p['patch_date']}  v{p['version']}  {p['content']}")

# 배포 가이드 (사용자 부탁 시 Claude 가 수행)

> 사용자가 자연어로 **"배포해줘"** 등으로 부탁할 때 Claude 가 따라야 하는 행동 규칙.
> `oracle_cloud/deploy.sh` / `deploy_backend.sh` 같은 기존 스크립트는 **수정하지 않는다** — 사용자가 직접 풀 배포를 원할 때 그대로 사용.
> Claude 가 부탁받아 배포할 때만 아래의 **간략화된 흐름**을 따라 시간을 단축.

## 배포 변경 범위 (Scope) 판정

`git status` + `git diff --stat` (또는 최근 커밋 변경 파일) 을 기준으로 다음 4가지 중 하나로 분류:

| Scope | 트리거 | 변경 영역 |
|---|---|---|
| **frontend-only** | `lib/`, `web/`, `pubspec.yaml`, `assets/` 등만 변경 | Flutter 코드만 |
| **backend-only** | `backend/` 만 변경 (단, `requirements.txt` 변경 여부 별도 체크) | API 코드만 |
| **both** | 위 둘이 모두 변경 | 풀스택 |
| **docs-only** | `docs/`, `*.md` 만 변경 | 배포 스킵, 사용자에게 안내 후 종료 |

판정이 모호하면 사용자에게 한 번 확인.

## 공통 사전 체크

- 작업트리 상태 확인 (`git status --short`) — 의도하지 않은 변경이 섞이지 않았는지
- 본인 작업 외에 다른 WIP 변경이 있으면 사용자에게 명시하고 같이 나갈지 확인 받기
- `flutter analyze` 또는 백엔드 syntax 체크 등이 이미 끝나 있는지 (이번 세션에서 이미 했다면 스킵)

## Scope 별 배포 흐름

### A. frontend-only

API 컨테이너 재빌드는 **스킵**. ~2-3분 절감.

```bash
# 1) Flutter Web 빌드 (로컬)
source backend/.env
flutter build web --release \
  --pwa-strategy=none \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=KAKAO_REST_API_KEY="$KAKAO_REST_API_KEY"

# 2) SSH 키 준비
cp oracle_cloud/ssh-key-2026-03-02.key /tmp/deploy_key
chmod 600 /tmp/deploy_key
SSH="ssh -i /tmp/deploy_key -o StrictHostKeyChecking=no"
SCP="scp -i /tmp/deploy_key -o StrictHostKeyChecking=no"
SERVER="ubuntu@168.107.50.187"

# 3) build/web 만 전송
$SSH "$SERVER" "mkdir -p ~/app/build && rm -rf ~/app/build/web"
$SCP -r build/web "$SERVER:~/app/build/"

# 4) nginx 만 재기동 (API 그대로)
$SSH "$SERVER" 'cd ~/app && docker compose stop nginx && docker compose rm -f nginx && docker compose up -d nginx'
```

### B. backend-only

Flutter 빌드는 **스킵**. `requirements.txt` 가 안 바뀌었으면 `--no-cache` 도 빼서 pip 캐시 활용 (~1-2분 절감).

```bash
# 1) SSH 키 준비 (위 A 와 동일)
# 2) 백엔드 코드 전송
$SSH "$SERVER" "sudo rm -rf ~/app/backend/app"
find backend/app -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
$SCP -r backend/app "$SERVER:~/app/backend/"
$SCP backend/Dockerfile backend/requirements.txt "$SERVER:~/app/backend/"

# 3) requirements.txt 변경 여부 확인
if git diff HEAD~1 --name-only | grep -q "backend/requirements.txt"; then
  BUILD_FLAGS="--no-cache"   # 의존성 변경 시에만 캐시 무효화
else
  BUILD_FLAGS=""             # 일반 코드 변경은 pip 캐시 재사용
fi

# 4) API 재빌드 + 재기동
$SSH "$SERVER" "cd ~/app && docker compose build $BUILD_FLAGS api && docker compose up -d api"
```

### C. both (frontend + backend)

A 와 B 를 합치되 **`--no-cache` 는 위와 같은 조건부 적용**. (보통 ~1-2분 절감)

순서: Flutter 빌드 → 빌드 산출물 전송 → 백엔드 코드 전송 → API 재빌드/재기동 → nginx 재기동.

### D. docs-only

배포하지 않는다. 사용자에게 다음과 같이 안내:

> 문서/주석/요청 기록만 변경되었습니다. 운영 서비스에 영향 없으므로 배포 생략. 커밋·푸시만 진행할까요?

## 사후 검증 (모든 scope 공통)

```bash
# 1) HTTPS 헬스체크
curl -s -o /dev/null -w "%{http_code}\n" https://syncwork.kr/

# 2) 새 빌드 적용 확인
curl -I -s https://syncwork.kr/main.dart.js | grep -i "last-modified"
```

- 200 OK 확인
- `Last-Modified` 가 직전 배포 이후 시각인지 확인
- 백엔드 변경이 있었으면 `docker compose logs api --tail 30` 으로 startup 에러 확인

## 사용자에게 보고할 내용

배포 완료 시:
- 어떤 scope 였는지 (frontend-only / backend-only / both / docs-only)
- 적용된 빌드의 `Last-Modified` 시각
- 사이트 헬스체크 결과 (200/non-200)
- 백엔드 변경이 있었다면 컨테이너 상태 + 새 startup 로그 요약

## 명시적으로 풀 배포가 필요한 경우

다음 상황에선 사용자에게 **`oracle_cloud/deploy.sh` 풀 배포** 권장:

- pip 의존성 깨짐 의심 / 빌드 캐시 오염 디버깅
- requirements.txt + Dockerfile 동시 변경
- 사용자가 명시적으로 "풀 배포" / "캐시 무효화 배포" 요청

## DB 마이그레이션 주의

- 신규 컬럼/테이블 추가는 `backend/app/main.py` 의 `ensure_*` 함수 패턴이 startup 시 자동 실행 — 정상 흐름
- 컬럼 타입 변경 등 `backend/app/migrations/` 의 일회성 스크립트는 **배포 후 수동 실행** 필요. 사용자에게 알리고 명령어 제시:
  ```bash
  ssh ... "cd ~/app && docker compose exec api python -m app.migrations.<script>"
  ```

## 안전 수칙

- SSH 키는 `/tmp/deploy_key` 임시 사본 사용 후 작업 종료 시 삭제 (`rm -f /tmp/deploy_key`)
- nginx / API 재기동은 순간 다운타임이 있으므로 사용자에게 미리 고지
- 배포 직전 `git status` 결과를 항상 사용자에게 노출 (의도하지 않은 파일 동반 배포 방지)

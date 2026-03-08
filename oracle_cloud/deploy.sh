#!/bin/bash
# ============================================================
# DORA 배포 스크립트 (로컬 빌드 + 서버 전송)
# 사용법: bash oracle_cloud/deploy.sh
# ============================================================

set -e

SERVER="ubuntu@168.107.50.187"
KEY="/tmp/deploy_key"
SSH="ssh -i $KEY -o StrictHostKeyChecking=no"
SCP="scp -i $KEY -o StrictHostKeyChecking=no"

# SSH 키 준비 (Windows 파일시스템 권한 문제 우회)
cp "$(dirname "$0")/ssh-key-2026-03-02.key" "$KEY"
chmod 600 "$KEY"

echo "=============================="
echo " DORA 배포 시작"
echo "=============================="

# 1. Flutter Web 빌드 (로컬)
echo ""
echo "[1/4] Flutter Web 빌드 중..."
cd "$(dirname "$0")/.."
source backend/.env
flutter build web --release \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=KAKAO_REST_API_KEY="$KAKAO_REST_API_KEY"
echo "  완료: build/web/"

# 2. build/web 서버로 전송
echo ""
echo "[2/4] Flutter Web 전송 중..."
$SCP -r build/web "$SERVER:~/app/build/"
echo "  완료"

# 3. 설정 파일 + 백엔드 코드 전송
echo ""
echo "[3/4] 설정 및 백엔드 전송 중..."
$SCP docker-compose.yml "$SERVER:~/app/"
$SCP nginx/nginx.conf "$SERVER:~/app/nginx/"
# 백엔드: 서버의 기존 app 디렉토리 삭제 후 새로 전송 (scp 업데이트 누락 방지)
$SSH "$SERVER" "rm -rf ~/app/backend/app"
$SCP -r backend/app "$SERVER:~/app/backend/"
$SCP backend/Dockerfile backend/requirements.txt "$SERVER:~/app/backend/"
echo "  완료"

# 4. 서버에서 컨테이너 재시작
echo ""
echo "[4/4] 서버 재시작 중..."
$SSH "$SERVER" 'cd ~/app && docker compose up -d --build api && docker compose up -d --force-recreate nginx && sleep 3 && docker compose ps'

echo ""
echo "=============================="
echo " 완료! https://syncwork.kr"
echo "=============================="

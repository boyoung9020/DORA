#!/bin/bash
# ============================================================
# DORA 배포 스크립트 (로컬 빌드 + 서버 전송)
# 사용법: bash oracle_cloud/deploy.sh
# ============================================================

set -e

SERVER="ubuntu@168.107.50.187"
KEY="/tmp/deploy_key"

# SSH 키 준비 (Windows 파일시스템 권한 문제 우회)
cp "$(dirname "$0")/ssh-key-2026-03-02.key" "$KEY"
chmod 600 "$KEY"

echo "=============================="
echo " DORA 배포 시작"
echo "=============================="

# 1. Flutter Web 빌드 (로컬)
echo ""
echo "[1/3] Flutter Web 빌드 중..."
cd "$(dirname "$0")/.."
flutter build web --release
echo "  완료: build/web/"

# 2. build/web 서버로 전송
echo ""
echo "[2/3] 서버로 전송 중..."
scp -i "$KEY" -o StrictHostKeyChecking=no -r \
    build/web ubuntu@168.107.50.187:~/app/build/
echo "  완료"

# 3. 서버에서 git pull + 재시작
echo ""
echo "[3/3] 서버 업데이트 중..."
ssh -i "$KEY" -o StrictHostKeyChecking=no "$SERVER" << 'REMOTE'
    cd ~/app
    git checkout -- .
    git pull origin main
    docker compose up -d --build api
    docker compose up -d nginx
    sleep 3
    docker compose ps
REMOTE

echo ""
echo "=============================="
echo " 완료! https://syncwork.kr"
echo "=============================="

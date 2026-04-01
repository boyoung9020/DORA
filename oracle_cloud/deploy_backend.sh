#!/bin/bash
# ============================================================
# 백엔드만 빠르게 배포 (Flutter 빌드 없음 - ~30초)
# 사용법: bash oracle_cloud/deploy_backend.sh
# ============================================================

set -e

SERVER="ubuntu@168.107.50.187"
KEY="/tmp/deploy_key"
SSH="ssh -i $KEY -o StrictHostKeyChecking=no"
SCP="scp -i $KEY -o StrictHostKeyChecking=no"

cp "$(dirname "$0")/ssh-key-2026-03-02.key" "$KEY"
chmod 600 "$KEY"

echo "=============================="
echo " 백엔드 빠른 배포 시작"
echo "=============================="

cd "$(dirname "$0")/.."

# 1. 백엔드 코드 전송
echo ""
echo "[1/2] 백엔드 전송 중..."
$SSH "$SERVER" "sudo rm -rf ~/app/backend/app"
find backend/app -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
$SCP -r backend/app "$SERVER:~/app/backend/"
$SCP backend/Dockerfile backend/requirements.txt "$SERVER:~/app/backend/"
echo "  완료"

# 2. API 컨테이너만 재시작
echo ""
echo "[2/2] API 재시작 중..."
$SSH "$SERVER" 'cd ~/app && docker compose build --no-cache api && docker compose up -d api && sleep 3 && docker compose ps api'

echo ""
echo "=============================="
echo " 완료! https://syncwork.kr"
echo "=============================="

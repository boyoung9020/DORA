#!/bin/bash
# Face 패치 히스토리 시드 실행

set -e

SERVER="ubuntu@168.107.50.187"
KEY="/tmp/deploy_key"
SSH="ssh -i $KEY -o StrictHostKeyChecking=no"
SCP="scp -i $KEY -o StrictHostKeyChecking=no"

cp "$(dirname "$0")/ssh-key-2026-03-02.key" "$KEY"
chmod 600 "$KEY"

echo "스크립트 전송 중..."
$SCP "$(dirname "$0")/seed_face_patches.py" "$SERVER:~/app/backend/"

echo "실행 중..."
$SSH "$SERVER" 'cd ~/app && docker compose exec -T api python3 /app/seed_face_patches.py'

echo "완료!"

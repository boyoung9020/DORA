#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEY="$SCRIPT_DIR/ssh-key-2026-03-02.key"
DUMP_FILE="$SCRIPT_DIR/db_backup.dump"
SERVER="ubuntu@168.107.50.187"
SSH="ssh -i $KEY -o StrictHostKeyChecking=no"
SCP="scp -i $KEY -o StrictHostKeyChecking=no"

chmod 600 "$KEY"

echo "[1/3] 클라우드 서버에서 DB 덤프 생성 중..."
$SSH "$SERVER" "docker exec sync_postgres pg_dump -U admin -Fc dora_db > /tmp/db_backup.dump"

echo "[2/3] 덤프 파일 로컬로 다운로드 중..."
$SCP "$SERVER:/tmp/db_backup.dump" "$DUMP_FILE"

echo "[3/3] 로컬 DB에 복원 중..."
docker cp "$DUMP_FILE" sync_postgres:/tmp/db_backup.dump
MSYS_NO_PATHCONV=1 docker exec sync_postgres pg_restore -U admin -d dora_db --clean --if-exists /tmp/db_backup.dump 2>&1 | tail -10

echo ""
echo "완료! 로컬 DB에 클라우드 데이터가 복원되었습니다."

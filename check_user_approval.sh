#!/bin/bash
# 사용자 승인 상태 확인 스크립트

echo "=== 사용자 승인 상태 확인 ==="
echo ""

# PostgreSQL 컨테이너에서 직접 확인
docker compose exec postgres psql -U admin -d dora_db -c "SELECT username, email, is_approved, is_admin, is_pm FROM users ORDER BY created_at DESC;" 2>/dev/null || echo "데이터베이스 연결 실패"

echo ""
echo "=== 승인되지 않은 사용자 목록 ==="
docker compose exec postgres psql -U admin -d dora_db -c "SELECT username, email, is_approved FROM users WHERE is_approved = false;" 2>/dev/null || echo "데이터베이스 연결 실패"

echo ""
echo "=== 승인된 사용자 목록 ==="
docker compose exec postgres psql -U admin -d dora_db -c "SELECT username, email, is_approved FROM users WHERE is_approved = true;" 2>/dev/null || echo "데이터베이스 연결 실패"


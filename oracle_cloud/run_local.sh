#!/bin/bash
# ============================================================
# DORA 로컬 개발 실행 스크립트
# 사용법: bash oracle_cloud/run_local.sh
#         또는 oracle_cloud\run_local.bat
# ============================================================

export PATH="$PATH:/c/flutter/bin"

source "$(dirname "$0")/../backend/.env"

echo "=============================="
echo " DORA 로컬 개발 서버 시작"
echo "=============================="
echo ""
echo " http://localhost:8080 으로 열립니다"
echo " 소셜 로그인 리다이렉트: http://localhost:8080/"
echo ""

cd "$(dirname "$0")/.."

flutter run -d chrome --web-port=8080 \
  --dart-define=GOOGLE_CLIENT_ID="$GOOGLE_CLIENT_ID" \
  --dart-define=KAKAO_REST_API_KEY="$KAKAO_REST_API_KEY" \
  --dart-define=KAKAO_JAVASCRIPT_APP_KEY="$KAKAO_REST_API_KEY" \
  --dart-define=KAKAO_NATIVE_APP_KEY=e5f10d7e9297ae72a3dd08a2d512a223

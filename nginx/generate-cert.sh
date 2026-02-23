#!/bin/bash
# Self-signed SSL 인증서 생성 스크립트
# 사용법: ./nginx/generate-cert.sh

CERT_DIR="$(dirname "$0")/ssl"
mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERT_DIR/server.key" \
  -out "$CERT_DIR/server.crt" \
  -subj "/C=KR/ST=Seoul/L=Seoul/O=DORA/CN=192-168-1-101.sslip.io" \
  -addext "subjectAltName=DNS:192-168-1-101.sslip.io,IP:192.168.1.101,DNS:localhost"

echo "SSL 인증서 생성 완료: $CERT_DIR/"
echo "  - server.crt (인증서)"
echo "  - server.key (개인키)"

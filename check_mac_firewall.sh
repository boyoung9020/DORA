#!/bin/bash
# 맥 방화벽 확인 스크립트
# 맥 터미널에서 실행: bash check_mac_firewall.sh

echo "=== 맥 방화벽 상태 확인 ==="
echo ""

# 방화벽 상태 확인
echo "1. 방화벽 상태:"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

echo ""
echo "2. 방화벽 모드:"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getblockall

echo ""
echo "3. 스텔스 모드:"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode

echo ""
echo "=== 방화벽 설정 방법 ==="
echo ""
echo "방화벽을 일시적으로 끄려면:"
echo "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off"
echo ""
echo "방화벽을 다시 켜려면:"
echo "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"
echo ""
echo "스텔스 모드를 끄려면:"
echo "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode off"


#!/bin/bash
# Windows 앱 빌드 스크립트 (Linux/Mac에서 Windows 크로스 컴파일용)
# 주의: Windows 빌드는 Windows 환경에서만 가능합니다

echo "=== DORA Windows 앱 빌드 ==="
echo ""
echo "⚠️  주의: Windows 앱 빌드는 Windows 환경에서만 가능합니다."
echo "   Linux/Mac에서는 Windows 빌드를 할 수 없습니다."
echo ""
echo "Windows에서 빌드하려면:"
echo "   1. Windows PC에서 PowerShell 실행"
echo "   2. 프로젝트 디렉토리로 이동"
echo "   3. .\build_windows.ps1 실행"
echo ""
echo "또는 수동으로:"
echo "   flutter build windows --release"
echo ""
echo "빌드 결과물 위치:"
echo "   build/windows/x64/runner/Release/dora_project_manager.exe"


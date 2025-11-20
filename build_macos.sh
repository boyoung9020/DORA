#!/bin/bash
# macOS 앱 빌드 스크립트
# 맥에서 실행: bash build_macos.sh

echo "=== DORA macOS 앱 빌드 ==="
echo ""

# 현재 디렉토리 확인
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ 오류: pubspec.yaml 파일을 찾을 수 없습니다."
    echo "프로젝트 루트 디렉토리에서 실행해주세요."
    exit 1
fi

echo "1. Flutter 의존성 확인 중..."
flutter pub get

echo ""
echo "2. macOS 의존성 설치 중..."
cd macos
if command -v pod &> /dev/null; then
    pod install
else
    echo "⚠️  CocoaPods가 설치되어 있지 않습니다."
    echo "   설치: sudo gem install cocoapods"
    echo "   계속 진행합니다..."
fi
cd ..

echo ""
echo "3. Flutter 클린 빌드..."
flutter clean

echo ""
echo "4. macOS 릴리스 빌드 중..."
flutter build macos --release

echo ""
echo "✅ 빌드 완료!"
echo ""
echo "📦 빌드 결과물 위치:"
echo "   build/macos/Build/Products/Release/dora_project_manager.app"
echo ""
echo "🚀 앱 실행 방법:"
echo "   1. Finder에서 build/macos/Build/Products/Release/ 폴더 열기"
echo "   2. dora_project_manager.app 더블 클릭"
echo ""
echo "📋 앱 배포 방법:"
echo "   - 다른 맥으로 복사: dora_project_manager.app 파일을 복사"
echo "   - 압축: zip -r dora_project_manager.app.zip dora_project_manager.app"


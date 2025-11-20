# 웹 배포 빠른 시작 가이드

## 🚀 3단계로 웹 배포하기

### 1단계: 웹 앱 빌드

```bash
flutter build web --release
```

빌드 결과물이 `build/web/` 폴더에 생성됩니다.

### 2단계: Docker Compose 재시작

```bash
docker-compose down
docker-compose up -d
```

### 3단계: 브라우저에서 접속

브라우저에서 다음 주소로 접속:

- **로컬**: http://localhost
- **서버**: http://192.168.1.102

## ✅ 완료!

이제 웹 브라우저에서 DORA 프로젝트 관리 시스템을 사용할 수 있습니다!

## 🔧 추가 설정

### API 서버 주소 변경

웹 앱이 다른 서버에 배포되는 경우, `lib/utils/api_client.dart`에서 서버 주소를 변경하세요:

```dart
static const String baseUrl = 'http://your-server-ip';
```

### HTTPS 설정 (프로덕션)

프로덕션 환경에서는 HTTPS를 사용하는 것이 좋습니다. Let's Encrypt를 사용하여 무료 SSL 인증서를 발급받을 수 있습니다.

자세한 내용은 `WEB_DEPLOYMENT_GUIDE.md`를 참고하세요.

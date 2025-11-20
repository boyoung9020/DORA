# 웹 배포 가이드

## ✅ 웹 배포 가능 여부

**네, 웹에도 배포 가능합니다!** Flutter는 웹도 지원하므로 브라우저에서 실행할 수 있습니다.

현재 프로젝트에는 이미 웹 설정이 포함되어 있습니다:

- ✅ `web/` 폴더 존재
- ✅ `index.html` 설정 완료
- ✅ `manifest.json` (PWA 설정) 완료
- ✅ 아이콘 파일 준비 완료

## 🚀 로컬에서 웹 실행

### 1. 개발 모드로 실행

```bash
# Chrome에서 실행
flutter run -d chrome

# 또는 기본 브라우저
flutter run -d web-server
```

### 2. 특정 포트로 실행

```bash
flutter run -d chrome --web-port=8080
```

## 📦 웹 앱 빌드

### 개발 빌드

```bash
flutter build web
```

빌드 결과물 위치: `build/web/`

### 릴리스 빌드 (최적화)

```bash
flutter build web --release
```

릴리스 빌드는 다음 최적화를 포함합니다:

- 코드 압축 및 최소화
- 트리 쉐이킹 (사용하지 않는 코드 제거)
- 더 작은 번들 크기

### 추가 빌드 옵션

```bash
# Base URL 설정 (서브디렉토리에 배포 시)
flutter build web --base-href=/dora/

# 소스맵 포함 (디버깅용)
flutter build web --source-maps

# PWA 모드 (서비스 워커 포함)
flutter build web --pwa-strategy=offline-first
```

## 🌐 Nginx로 웹 앱 배포

현재 프로젝트는 이미 Nginx를 사용하고 있으므로, 웹 앱을 Nginx로 서빙할 수 있습니다.

### 방법 1: Nginx에 웹 앱 추가 (권장)

`nginx/nginx.conf` 파일을 수정하여 웹 앱을 서빙합니다:

```nginx
server {
    listen 80;
    server_name localhost;

    # API 요청은 FastAPI로 프록시
    location /api {
        proxy_pass http://api:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 웹 앱 정적 파일 서빙
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
        index index.html;
    }

    # 정적 파일 캐싱
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        root /usr/share/nginx/html;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### 방법 2: Docker Compose에 웹 서비스 추가

`docker-compose.yml`에 웹 서비스를 추가합니다:

```yaml
services:
  # ... 기존 서비스들 ...

  web:
    image: nginx:alpine
    container_name: dora_web
    ports:
      - "8080:80"
    volumes:
      - ./build/web:/usr/share/nginx/html:ro
      - ./nginx/web.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - nginx
    networks:
      - dora_network
```

## 📋 배포 단계

### 1. 웹 앱 빌드

```bash
# 릴리스 빌드
flutter build web --release
```

### 2. 빌드 결과물 확인

`build/web/` 폴더에 다음 파일들이 생성됩니다:

- `index.html`
- `main.dart.js` (압축된 JavaScript)
- `flutter.js`
- `assets/` (이미지, 폰트 등)
- `manifest.json`
- `favicon.png`

### 3. 서버에 배포

#### 옵션 A: Nginx로 직접 서빙

```bash
# 서버에 빌드 결과물 복사
scp -r build/web/* user@server:/var/www/dora/

# Nginx 설정
# /etc/nginx/sites-available/dora
server {
    listen 80;
    server_name your-domain.com;

    root /var/www/dora;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:8000;
        # ... 프록시 설정 ...
    }
}
```

#### 옵션 B: Docker Compose로 배포

```bash
# 1. 웹 앱 빌드
flutter build web --release

# 2. Docker Compose로 배포
docker-compose up -d
```

## 🔧 웹 설정 확인

### 1. API 서버 주소 확인

`lib/utils/api_client.dart`에서 서버 주소 확인:

```dart
static const String baseUrl = 'http://192.168.1.102';
```

웹 배포 시에는:

- 개발: `http://localhost` 또는 `http://192.168.1.102`
- 프로덕션: 실제 도메인 또는 IP 주소

### 2. CORS 설정 확인

백엔드 `backend/app/main.py`에서 CORS 설정 확인:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 프로덕션에서는 특정 도메인만 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### 3. PWA 설정 (선택사항)

`web/manifest.json`에서 PWA 설정 확인 및 수정:

```json
{
  "name": "DORA Project Manager",
  "short_name": "DORA",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0175C2",
  "theme_color": "#0175C2"
}
```

## 🌍 다양한 배포 옵션

### 1. 정적 호스팅 서비스

#### GitHub Pages

```bash
# 1. 웹 빌드
flutter build web --release --base-href=/DORA/

# 2. build/web 폴더를 GitHub Pages에 배포
# GitHub 저장소 > Settings > Pages에서 설정
```

#### Netlify

```bash
# 1. 웹 빌드
flutter build web --release

# 2. Netlify CLI로 배포
netlify deploy --prod --dir=build/web
```

#### Vercel

```bash
# 1. 웹 빌드
flutter build web --release

# 2. Vercel CLI로 배포
vercel --prod build/web
```

#### Firebase Hosting

```bash
# 1. Firebase CLI 설치
npm install -g firebase-tools

# 2. Firebase 초기화
firebase init hosting

# 3. 웹 빌드
flutter build web --release

# 4. 배포
firebase deploy --only hosting
```

### 2. 자체 서버 배포

#### Nginx 설정 예시

```nginx
server {
    listen 80;
    server_name dora.yourdomain.com;

    root /var/www/dora;
    index index.html;

    # SPA 라우팅 지원
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 프록시
    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 정적 파일 캐싱
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Gzip 압축
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
```

## 🔐 HTTPS 설정 (프로덕션)

### Let's Encrypt 사용

```bash
# Certbot 설치
sudo apt-get install certbot python3-certbot-nginx

# SSL 인증서 발급
sudo certbot --nginx -d your-domain.com

# 자동 갱신 설정
sudo certbot renew --dry-run
```

### Nginx HTTPS 설정

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # ... 나머지 설정 ...
}

# HTTP를 HTTPS로 리다이렉트
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

## 🧪 테스트

### 로컬 테스트

```bash
# 1. 웹 빌드
flutter build web --release

# 2. 로컬 서버로 테스트
cd build/web
python -m http.server 8080

# 또는
npx serve -s build/web -l 8080
```

### 프로덕션 테스트

1. 브라우저에서 접속: `http://your-domain.com`
2. 로그인 테스트
3. API 연결 확인
4. 모든 기능 테스트

## 📱 PWA (Progressive Web App) 설정

웹 앱을 PWA로 만들면:

- 홈 화면에 추가 가능
- 오프라인 지원
- 앱처럼 동작

### 서비스 워커 활성화

```bash
flutter build web --pwa-strategy=offline-first
```

## 🔍 문제 해결

### CORS 오류

백엔드에서 CORS 설정 확인:

```python
allow_origins=["http://your-domain.com", "https://your-domain.com"]
```

### 라우팅 오류 (404)

Nginx 설정에서 `try_files` 확인:

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

### API 연결 오류

1. 서버 주소 확인 (`api_client.dart`)
2. CORS 설정 확인
3. 네트워크 연결 확인

## 📋 배포 체크리스트

- [ ] 웹 빌드 성공 (`flutter build web --release`)
- [ ] API 서버 주소 설정 (`api_client.dart`)
- [ ] CORS 설정 확인 (백엔드)
- [ ] Nginx 설정 완료
- [ ] HTTPS 설정 (프로덕션)
- [ ] 도메인 설정 (선택사항)
- [ ] 브라우저 테스트 완료
- [ ] 모바일 브라우저 테스트 완료

## 💡 요약

- ✅ 웹 배포 가능
- ✅ `flutter build web --release`로 빌드
- ✅ Nginx로 서빙 가능
- ✅ 정적 호스팅 서비스 사용 가능
- ✅ Windows, macOS, 웹 모두 같은 코드 사용
- ✅ 같은 서버에 연결하여 데이터 공유

## 🚀 빠른 시작

```bash
# 1. 웹 빌드
flutter build web --release

# 2. 로컬 테스트
cd build/web
python -m http.server 8080

# 3. 브라우저에서 http://localhost:8080 접속
```

웹 배포가 완료되면 어디서든 브라우저로 접속하여 사용할 수 있습니다!

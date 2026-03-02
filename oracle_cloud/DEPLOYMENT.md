# DORA 클라우드 배포 가이드

## 인프라 구성

| 항목 | 내용 |
|------|------|
| 클라우드 | Oracle Cloud Always Free |
| 서버 | Ubuntu 24.04 LTS (ARM) |
| 공인 IP | `168.107.50.187` (Ephemeral) |
| 리전 | 대한민국 북한 (ap-chuncheon-1) |
| 접속 URL | https://168.107.50.187 (SSL 경고 무시) |

---

## 배포 구조

```
GitHub (boyoung9020/Sync)
    ↓ git pull  (서버에서)
서버 ~/app/
    ↓ flutter build web --release  (서버에서)
    ↓ docker compose up -d --build
    ├── postgres  (DB)
    ├── api       (FastAPI)
    └── nginx     (nginx:alpine + ./build/web 볼륨 마운트)
```

---

## 일상적인 배포 (코드 업데이트)

### 방법 1: 스크립트 사용

```bash
# Git Bash 터미널에서 (프로젝트 루트)
bash oracle_cloud/deploy.sh

# 또는 PowerShell에서
oracle_cloud\deploy.bat
```

### 방법 2: 서버에 직접 SSH 접속

```bash
ssh -i oracle_cloud/ssh-key-2026-03-02.key ubuntu@168.107.50.187

# 서버에서
cd ~/app
git pull origin main
flutter build web --release
docker compose up -d --build api
docker compose restart nginx
```

---

## 초기 설정 과정 (이미 완료)

### 1. Oracle Cloud 인스턴스 설정

1. 인스턴스 생성: `sync-instance` (Ubuntu 24.04, Always Free ARM)
2. **Public IP 할당**: Networking 탭 → Attached VNICs → Sync → IP Addresses → Edit → Ephemeral Public IP 선택
3. **Oracle Security List 방화벽 설정**: VCN → Sync_subnet → Security rules → Ingress Rules 추가

   | Source CIDR | Protocol | Source Port | Destination Port | 용도 |
   |-------------|----------|-------------|-----------------|------|
   | 0.0.0.0/0 | TCP | All | 22 | SSH |
   | 0.0.0.0/0 | TCP | All | 80 | HTTP |
   | 0.0.0.0/0 | TCP | All | 443 | HTTPS |

   > **주의**: "Source Port Range"는 비워두고(All), "Destination Port Range"에 포트 번호 입력.

4. **OS 방화벽(iptables) 설정**: Oracle Ubuntu 기본 설정에는 SSH(22)만 허용하는 REJECT 규칙이 있음.

   ```bash
   sudo iptables -I INPUT 5 -p tcp --dport 80 -j ACCEPT
   sudo iptables -I INPUT 6 -p tcp --dport 443 -j ACCEPT
   sudo iptables-save | sudo tee /etc/iptables/rules.v4
   ```

### 2. Docker 설치

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
```

### 3. Flutter 설치

```bash
sudo snap install flutter --classic
flutter --version  # 설치 확인
```

### 4. 프로젝트 클론 및 환경 설정

```bash
git clone https://github.com/boyoung9020/Sync.git ~/app
```

`~/app/.env` 및 `~/app/backend/.env` 파일 생성:

```env
DB_HOST=postgres
DB_PORT=5432
DB_USER=admin
DB_PASSWORD=SyncOracle2026
DB_NAME=dora_db

SECRET_KEY=<openssl rand -hex 32 으로 생성>

GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
KAKAO_REST_API_KEY=...
KAKAO_CLIENT_SECRET=...
GEMINI_API_KEY=...
```

> **주의**: DB_PASSWORD에 `@` 문자 포함 시 SQLAlchemy URL 파싱 오류 발생.

### 5. SSL 인증서 (임시 자체 서명)

```bash
mkdir -p ~/app/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ~/app/nginx/ssl/server.key \
  -out ~/app/nginx/ssl/server.crt \
  -subj '/CN=168.107.50.187/O=DORA/C=KR'
```

### 6. 첫 Flutter 빌드 및 서비스 시작

```bash
cd ~/app
flutter build web --release
docker compose up -d --build
```

---

## SSH 접속

```bash
ssh -i oracle_cloud/ssh-key-2026-03-02.key ubuntu@168.107.50.187
```

## 서버 관리 명령어

```bash
# 컨테이너 상태 확인
docker compose ps

# 로그 확인
docker compose logs -f api
docker compose logs -f nginx

# 재시작 (재빌드 없이)
docker compose restart

# API만 재빌드
docker compose up -d --build api
```

---

## 도메인 연결 (추후 작업)

도메인 구입 후 Let's Encrypt 인증서 적용:

1. **DNS 설정**: A 레코드 → `168.107.50.187`
2. **Certbot으로 인증서 발급**:
   ```bash
   sudo apt install certbot
   sudo certbot certonly --standalone -d yourdomain.com
   ```
3. **nginx.conf SSL 경로 수정** (`~/app/nginx/nginx.conf`):
   ```nginx
   ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
   ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
   ```
4. **docker-compose.yml에 Let's Encrypt 볼륨 추가**:
   ```yaml
   - /etc/letsencrypt:/etc/letsencrypt:ro
   ```
5. **Flutter api_client.dart URL 변경**: `localhost:8000` → `https://yourdomain.com`
6. **OAuth 콘솔 리다이렉트 URL 추가**: Google, Kakao 개발자 콘솔

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| 외부 접속 불가 (timeout) | Oracle Security List 포트 미오픈 또는 Source/Destination 반대 입력 | Destination Port에 80/443 다시 추가 |
| 외부 접속 불가 (timeout) | OS iptables가 80/443 차단 | iptables에 포트 허용 규칙 추가 |
| DB 연결 오류 (Name not known) | DB_PASSWORD에 `@` 포함 | 패스워드 특수문자 제거 |
| DB 인증 실패 | postgres_data와 .env 패스워드 불일치 | `sudo rm -rf postgres_data` 후 재시작 |
| 502 Bad Gateway | API 컨테이너 시작 실패 | `docker logs sync_api` 로 원인 확인 |

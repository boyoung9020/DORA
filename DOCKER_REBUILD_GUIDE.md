# Docker 이미지 재빌드 가이드

## ⚠️ 중요: requirements.txt를 수정한 후 반드시 재빌드해야 합니다!

`requirements.txt` 파일을 수정한 후에는 Docker 이미지를 재빌드해야 새로운 패키지가 설치됩니다.

## 🔧 재빌드 방법

### 방법 1: 완전 재빌드 (권장)

```bash
# 1. 기존 컨테이너 중지 및 제거
docker-compose down

# 2. 이미지 재빌드 (캐시 없이)
docker-compose build --no-cache

# 3. 서비스 시작
docker-compose up -d

# 4. 로그 확인
docker-compose logs -f api
```

### 방법 2: 빠른 재빌드

```bash
# 1. 기존 컨테이너 중지
docker-compose stop

# 2. 이미지 재빌드
docker-compose build

# 3. 서비스 시작
docker-compose up -d
```

### 방법 3: 특정 서비스만 재빌드

```bash
# API 서비스만 재빌드
docker-compose build --no-cache api
docker-compose up -d api
```

## 📋 현재 수정된 패키지

다음 패키지들이 추가/수정되었습니다:

- `email-validator==2.1.0` (추가)
- `bcrypt==4.1.2` (버전 업데이트)

## ✅ 재빌드 후 확인

재빌드가 완료되면 다음을 확인하세요:

```bash
# API 로그에서 오류가 없는지 확인
docker-compose logs api | grep -i error

# 또는 실시간 로그 확인
docker-compose logs -f api
```

정상적으로 실행되면 다음과 같은 메시지가 보입니다:

```
INFO:     Uvicorn running on http://0.0.0.0:8000
✅ 초기 관리자 계정이 생성되었습니다.
```

## 🐛 문제 해결

### 여전히 오류가 발생하는 경우

1. **캐시 문제**: `--no-cache` 옵션 사용

   ```bash
   docker-compose build --no-cache
   ```

2. **이미지 완전 삭제 후 재빌드**

   ```bash
   docker-compose down
   docker rmi dora_api  # 이미지 이름 확인 필요
   docker-compose build --no-cache
   docker-compose up -d
   ```

3. **볼륨 문제**: 데이터베이스 데이터 삭제 후 재시작
   ```bash
   docker-compose down -v
   docker-compose build --no-cache
   docker-compose up -d
   ```

## 💡 팁

- 개발 중에는 `docker-compose up --build`를 사용하면 자동으로 재빌드됩니다
- `--no-cache` 옵션은 처음 빌드하거나 문제가 있을 때만 사용하세요 (느림)

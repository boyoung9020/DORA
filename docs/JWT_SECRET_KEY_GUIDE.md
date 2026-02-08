# JWT 시크릿 키 가이드

## 🔑 JWT 시크릿 키란?

**JWT 시크릿 키(Secret Key)**는 JWT(JSON Web Token) 토큰을 **서명(sign)**하고 **검증(verify)**하는 데 사용하는 비밀 키입니다.

### JWT 토큰이란?

JWT는 사용자 인증 정보를 안전하게 전달하는 토큰입니다. 로그인 후 서버가 발급하며, 이후 API 요청 시 이 토큰을 사용하여 인증합니다.

```
로그인 → 서버가 JWT 토큰 발급 → 클라이언트가 토큰 저장
→ API 요청 시 토큰 전송 → 서버가 토큰 검증 → 인증 완료 ✅
```

## 🔐 시크릿 키의 역할

### 1. 토큰 서명 (Signing)

로그인 시 서버가 JWT 토큰을 생성할 때 시크릿 키로 서명합니다:

```python
# backend/app/utils/security.py
def create_access_token(data: dict):
    # 사용자 정보와 만료 시간을 포함한 토큰 생성
    to_encode = {
        "sub": user_id,  # 사용자 ID
        "username": username,
        "exp": expire_time
    }

    # 시크릿 키로 토큰 서명
    token = jwt.encode(to_encode, SECRET_KEY, algorithm="HS256")
    return token
```

### 2. 토큰 검증 (Verification)

API 요청 시 서버가 토큰이 유효한지 검증합니다:

```python
def decode_access_token(token: str):
    # 시크릿 키로 토큰 검증
    payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
    return payload  # 검증 성공 시 사용자 정보 반환
```

## 🛡️ 보안 중요성

### 왜 중요한가?

1. **토큰 위조 방지**

   - 시크릿 키를 모르면 토큰을 위조할 수 없습니다
   - 토큰 내용을 변경해도 서명이 맞지 않아 거부됩니다

2. **인증 보안**
   - 시크릿 키가 유출되면 누구나 유효한 토큰을 만들 수 있습니다
   - 해커가 다른 사용자로 위장할 수 있습니다

### 예시

```python
# 올바른 시크릿 키로 생성한 토큰
token = jwt.encode({"user_id": "123"}, "secret-key-123", algorithm="HS256")
# ✅ 검증 성공

# 다른 시크릿 키로 검증 시도
jwt.decode(token, "wrong-key", algorithms=["HS256"])
# ❌ 검증 실패 (JWTError 발생)
```

## 📝 현재 설정

### 개발 환경

`docker-compose.yml`에서:

```yaml
environment:
  SECRET_KEY: your-secret-key-change-in-production
```

이것은 **개발용 기본값**입니다. 프로덕션에서는 반드시 변경해야 합니다!

## 🔧 시크릿 키 생성 방법

### 방법 1: Python으로 생성 (권장)

```python
import secrets

# 32바이트 랜덤 문자열 생성 (Base64 인코딩)
secret_key = secrets.token_urlsafe(32)
print(secret_key)
# 예: 'xK8mP2qR9vL5nT7wY3zA6bC4dE8fG1hI0jK2lM3nO4pQ5rS6tU7vW8xY9zA0b'
```

### 방법 2: OpenSSL 사용

```bash
openssl rand -hex 32
# 예: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
```

### 방법 3: 온라인 생성기

- https://randomkeygen.com/
- https://generate-secret.vercel.app/32

## ⚙️ 설정 방법

### 방법 1: docker-compose.yml에서 직접 설정

```yaml
api:
  environment:
    SECRET_KEY: "xK8mP2qR9vL5nT7wY3zA6bC4dE8fG1hI0jK2lM3nO4pQ5rS6tU7vW8xY9zA0b"
```

### 방법 2: .env 파일 사용 (권장)

1. `backend/.env` 파일 생성:

```env
SECRET_KEY=xK8mP2qR9vL5nT7wY3zA6bC4dE8fG1hI0jK2lM3nO4pQ5rS6tU7vW8xY9zA0b
```

2. `docker-compose.yml` 수정:

```yaml
api:
  env_file:
    - ./backend/.env
```

3. `.gitignore`에 추가 (이미 추가되어 있음):

```
backend/.env
```

### 방법 3: 환경 변수로 전달

```bash
export SECRET_KEY="your-secret-key-here"
docker-compose up -d
```

## ⚠️ 주의사항

### 1. 절대 공유하지 마세요!

- GitHub에 커밋하지 마세요
- 다른 사람과 공유하지 마세요
- 로그에 출력하지 마세요

### 2. 프로덕션에서는 반드시 변경!

개발용 기본값(`your-secret-key-change-in-production`)은 보안상 위험합니다.

### 3. 정기적으로 변경

보안이 우려되면 시크릿 키를 변경하세요. 단, 변경 시 모든 사용자가 다시 로그인해야 합니다.

## 🔄 시크릿 키 변경 시 영향

시크릿 키를 변경하면:

- ✅ 기존 토큰은 모두 무효화됩니다
- ✅ 모든 사용자가 다시 로그인해야 합니다
- ✅ 새로운 토큰은 새 시크릿 키로 생성됩니다

## 📋 체크리스트

- [ ] 개발 환경: 기본값 사용 가능 (로컬 테스트용)
- [ ] 프로덕션: 강력한 랜덤 키 생성
- [ ] `.env` 파일을 `.gitignore`에 추가
- [ ] 시크릿 키를 안전한 곳에 백업 (비밀번호 관리자 등)
- [ ] 팀원과는 안전한 방법으로만 공유 (1Password, LastPass 등)

## 💡 요약

- **JWT 시크릿 키**: 토큰을 서명하고 검증하는 비밀 키
- **역할**: 토큰 위조 방지, 인증 보안
- **중요성**: 유출 시 보안 위험
- **개발**: 기본값 사용 가능
- **프로덕션**: 반드시 강력한 랜덤 키 사용

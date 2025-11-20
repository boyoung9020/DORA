# JWT 시크릿 키 규칙 및 가이드

## ✅ 답변: 임의로 만들 수 있지만 규칙이 있습니다!

JWT 시크릿 키는 **임의의 문자열**을 사용할 수 있지만, **보안을 위한 규칙**이 있습니다.

## 📋 규칙 및 권장사항

### 1. 길이 (가장 중요!)

#### ✅ 권장 길이

- **최소 32자 이상** (256비트)
- **권장: 64자 이상** (512비트)

#### ❌ 피해야 할 길이

- 10자 미만: 너무 짧아서 쉽게 추측 가능
- 예측 가능한 패턴: "12345678", "password", "secret"

### 2. 문자 종류

#### ✅ 사용 가능한 문자

- 영문 대소문자: `A-Z`, `a-z`
- 숫자: `0-9`
- 특수문자: `-`, `_`, `+`, `/`, `=` (Base64 문자)

#### 예시

```
# 좋은 예 ✅
"xK8mP2qR9vL5nT7wY3zA6bC4dE8fG1hI0jK2lM3nO4pQ5rS6tU7vW8xY9zA0b"
"MySecretKey123!@#"
"a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6"

# 나쁜 예 ❌
"secret"  # 너무 짧고 예측 가능
"12345678"  # 너무 짧고 단순
"password"  # 너무 일반적
```

### 3. 랜덤성

#### ✅ 권장: 완전히 랜덤

- 예측 불가능한 문자열
- 패턴이 없는 문자열

#### ❌ 피해야 할 것

- 단어나 문장
- 반복되는 패턴: "abcabcabc"
- 개인 정보: 이름, 생일 등

## 🔧 생성 방법 비교

### 방법 1: 완전 랜덤 (가장 안전) ✅

```python
import secrets

# 32바이트 = 256비트 (권장)
secret_key = secrets.token_urlsafe(32)
print(secret_key)
# 예: 'xK8mP2qR9vL5nT7wY3zA6bC4dE8fG1hI0jK2lM3nO4pQ5rS6tU7vW8xY9zA0b'
```

**장점:**

- 완전히 랜덤
- 예측 불가능
- 암호학적으로 안전

### 방법 2: 직접 만들기 (주의 필요) ⚠️

```python
# 직접 만든 예시
secret_key = "MyProjectSecretKey2024!@#$%"
```

**주의사항:**

- 최소 32자 이상
- 예측 가능한 패턴 피하기
- 개인 정보 포함하지 않기

### 방법 3: 온라인 생성기 (권장) ✅

- https://randomkeygen.com/
- https://generate-secret.vercel.app/32

## 📊 보안 강도 비교

### 강도: 높음 ✅

```
길이: 64자 이상
랜덤: 완전 랜덤
예: "xK8mP2qR9vL5nT7wY3zA6bC4dE8fG1hI0jK2lM3nO4pQ5rS6tU7vW8xY9zA0b"
```

### 강도: 중간 ⚠️

```
길이: 32-63자
랜덤: 부분 랜덤
예: "MyProjectSecretKey2024RandomString"
```

### 강도: 낮음 ❌

```
길이: 32자 미만
랜덤: 예측 가능
예: "secret", "password123", "mykey"
```

## 💡 실제 사용 예시

### 개발 환경 (로컬 테스트)

```yaml
# docker-compose.yml
SECRET_KEY: "dev-secret-key-12345" # 간단해도 됨 (로컬만)
```

### 프로덕션 환경

```yaml
# docker-compose.yml 또는 .env
SECRET_KEY: "xK8mP2qR9vL5nT7wY3zA6bC4dE8fG1hI0jK2lM3nO4pQ5rS6tU7vW8xY9zA0b"
```

## 🎯 요약

### 질문: 임의로 만들 수 있나요?

**답변: 네, 하지만 규칙을 따라야 합니다!**

### 규칙:

1. ✅ **길이**: 최소 32자 이상 (권장: 64자)
2. ✅ **랜덤성**: 예측 불가능한 문자열
3. ✅ **복잡도**: 영문, 숫자, 특수문자 조합
4. ❌ **피하기**: 짧은 문자열, 예측 가능한 패턴, 개인 정보

### 권장 방법:

```python
import secrets
secret_key = secrets.token_urlsafe(32)  # 가장 안전!
```

### 직접 만들기:

- 가능하지만 최소 32자 이상의 랜덤한 문자열 사용
- 프로덕션에서는 랜덤 생성기를 사용하는 것이 더 안전

## 🔍 현재 코드에서의 사용

```python
# backend/app/utils/security.py
def create_access_token(data: dict):
    # SECRET_KEY로 토큰 서명
    token = jwt.encode(data, settings.SECRET_KEY, algorithm="HS256")
    return token

def decode_access_token(token: str):
    # SECRET_KEY로 토큰 검증
    payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    return payload
```

**중요:** 시크릿 키가 다르면 토큰 검증이 실패합니다!

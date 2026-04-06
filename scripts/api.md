# request-issue 워크스페이스 연동 API 스펙

`request-issue` 앱에서 외부 워크스페이스에 이슈를 일괄 등록하기 위한 API 스펙입니다.  
아래 스펙에 맞춰 API를 구현하면 앱과 연동할 수 있습니다.

---

## 공통 사항

### 기본 URL
앱에서 Base URL을 입력받습니다. 예시:
```
https://your-workspace.com/api
```

### 인증
모든 요청은 `Authorization` 헤더에 Bearer 토큰을 포함해야 합니다.
```
Authorization: Bearer {token}
```

### 응답 형식
모든 응답은 `Content-Type: application/json` 입니다.

---

## 필수 API

### 1. 토큰 검증

토큰이 유효한지 확인합니다.

```
GET /auth/verify
Authorization: Bearer {token}
```

**성공 응답 (200)**
```json
{
  "valid": true,
  "user": "사용자명"
}
```

**실패 응답 (401)**
```json
{
  "valid": false,
  "error": "유효하지 않은 토큰"
}
```

---

### 2. 필드 목록 조회

앱에서 컬럼 매핑 화면을 구성할 때 호출합니다.  
워크스페이스의 이슈 필드 목록과 각 필드의 필수 여부를 반환해야 합니다.  
`required: true` 인 필드는 앱에서 매핑하지 않으면 다음 단계로 진행할 수 없습니다.

```
GET /fields
Authorization: Bearer {token}
```

**응답 (200)**
```json
{
  "fields": [
    {
      "id": "title",
      "name": "제목",
      "required": true,
      "type": "text"
    },
    {
      "id": "body",
      "name": "본문",
      "required": false,
      "type": "text"
    },
    {
      "id": "priority",
      "name": "우선순위",
      "required": false,
      "type": "select",
      "options": ["높음", "중간", "낮음"]
    },
    {
      "id": "category",
      "name": "카테고리",
      "required": false,
      "type": "text"
    }
  ]
}
```

**필드 타입**

| type | 설명 |
|------|------|
| `text` | 텍스트 자유 입력 |
| `select` | 선택지 중 하나 (`options` 배열 필수) |
| `multi-select` | 선택지 중 복수 선택 (`options` 배열 필수) |
| `user` | 멤버 ID |

---

### 3. 이슈 등록

이슈 1건을 등록합니다. 앱에서 선택한 항목 수만큼 반복 호출합니다.  
요청 바디의 키는 `/fields` 에서 반환한 `id` 값을 그대로 사용합니다.

```
POST /issues
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body**

`/fields` 에서 받은 필드 `id` 를 키로 사용합니다.

```json
{
  "title": "이슈 제목",
  "body": "이슈 본문 (마크다운 형식)",
  "priority": "높음",
  "category": "UI"
}
```

> `required: true` 인 필드는 항상 포함됩니다.  
> `required: false` 인 필드는 사용자가 매핑하지 않으면 포함되지 않을 수 있습니다.

**성공 응답 (200 또는 201)**
```json
{
  "id": "이슈ID",
  "title": "이슈 제목",
  "url": "https://your-workspace.com/issues/123"
}
```

**실패 응답 (4xx / 5xx)**
```json
{
  "error": "오류 메시지"
}
```

---

## 선택 API

구현하면 앱에서 추가 기능을 사용할 수 있습니다.

### 4. 멤버 목록 조회

필드 타입이 `user` 인 경우, 담당자 자동완성에 사용합니다.

```
GET /members
Authorization: Bearer {token}
```

**응답 (200)**
```json
{
  "members": [
    { "id": "user1", "name": "홍길동" },
    { "id": "user2", "name": "김철수" }
  ]
}
```

---

## CORS

앱이 Electron 기반이므로 CORS 설정이 필요할 수 있습니다.

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: Authorization, Content-Type
Access-Control-Allow-Methods: GET, POST
```

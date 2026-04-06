# request-issue 연동 API 명세

**Base URL**: `http://서버주소:4000/api/ri`  
**인증**: 모든 요청에 `Authorization: Bearer {token}` 헤더 필요

---

## 1. 토큰 검증

```
GET /auth/verify
Authorization: Bearer {token}
```

**성공 응답 (200)**
```json
{
  "valid": true,
  "user": "username"
}
```

**실패 응답 (401)**
```json
{
  "detail": "Could not validate credentials"
}
```

---

## 2. 필드 목록 조회

```
GET /fields
Authorization: Bearer {token}
```

**응답 (200)**
```json
{
  "fields": [
    { "id": "title",               "name": "제목",       "required": true,  "type": "text" },
    { "id": "project_id",          "name": "프로젝트 ID", "required": true,  "type": "text" },
    { "id": "description",         "name": "설명",       "required": false, "type": "text" },
    { "id": "priority",            "name": "우선순위",    "required": false, "type": "select",       "options": ["p0", "p1", "p2", "p3"] },
    { "id": "status",              "name": "상태",       "required": false, "type": "select",       "options": ["backlog", "ready", "inProgress", "inReview", "done"] },
    { "id": "assigned_member_ids", "name": "담당자",     "required": false, "type": "multi-select" }
  ]
}
```

**필드 타입**

| type | 설명 |
|------|------|
| `text` | 자유 입력 텍스트 |
| `select` | `options` 중 하나 선택 |
| `multi-select` | `options` 또는 ID 배열로 복수 선택 (`assigned_member_ids`는 `/members`의 `id` 값 사용) |

---

## 3. 이슈(태스크) 등록

```
POST /issues
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body**

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|------|--------|------|
| `title` | string | ✅ | - | 태스크 제목 |
| `project_id` | string | ✅ | - | 등록할 프로젝트의 ID |
| `description` | string | ❌ | `""` | 설명 |
| `priority` | string | ❌ | `"p2"` | `p0` / `p1` / `p2` / `p3` |
| `status` | string | ❌ | `"backlog"` | `backlog` / `ready` / `inProgress` / `inReview` / `done` |
| `assigned_member_ids` | string[] | ❌ | `[]` | 담당자 유저 ID 배열 |

**예시**
```json
{
  "title": "로그인 버튼 UI 수정",
  "project_id": "abc123",
  "description": "디자인 시안 반영",
  "priority": "p1",
  "status": "backlog",
  "assigned_member_ids": ["user-id-1"]
}
```

**성공 응답 (201)**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "로그인 버튼 UI 수정",
  "url": ""
}
```

**실패 응답**

| 코드 | 사유 |
|------|------|
| 401 | 토큰 없음 또는 만료 |
| 403 | 해당 프로젝트에 접근 권한 없음 |
| 404 | project_id에 해당하는 프로젝트 없음 |
| 422 | priority 또는 status 값이 유효하지 않음 |
| 500 | 태스크 생성 실패 |

---

## 4. 멤버 목록 조회

```
GET /members
Authorization: Bearer {token}
```

**응답 (200)**
```json
{
  "members": [
    { "id": "user-id-1", "name": "홍길동" },
    { "id": "user-id-2", "name": "김철수" }
  ]
}
```

> 승인된 유저(`is_approved: true`)만 반환됩니다.

# SYNC 외부 연동 API (Request-Issue)

외부 서비스에서 SYNC에 태스크를 등록하기 위한 API입니다.

**Base URL** `http://서버주소:4000/api/ri`

**인증** 모든 요청에 아래 헤더 포함

```
Authorization: Bearer {api_token}
```

**토큰 발급** SYNC 앱 → 설정(⚙) → **API 토큰** 탭 → 새 토큰 버튼

---

## 엔드포인트 목록

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/auth/verify` | 토큰 유효성 검증 |
| GET | `/workspaces` | 내 워크스페이스 목록 |
| GET | `/workspaces/{workspace_id}/projects` | 워크스페이스 내 프로젝트 목록 |
| GET | `/members` | 멤버 목록 (담당자 지정용) |
| GET | `/fields` | 이슈 등록 필드 정의 |
| POST | `/issues` | 이슈(태스크) 등록 |

---

## 1. 토큰 검증

```
GET /auth/verify
```

토큰이 유효한지 확인합니다. 연동 초기 설정 시 사용합니다.

**응답 200**
```json
{
  "valid": true,
  "user": "홍길동"
}
```

**응답 401**
```json
{
  "detail": "유효하지 않은 API 토큰입니다"
}
```

---

## 2. 워크스페이스 목록

```
GET /workspaces
```

토큰 소유자가 속한 워크스페이스 목록을 반환합니다.

**응답 200**
```json
{
  "workspaces": [
    { "id": "ws-uuid-1", "name": "MBC 개발팀" },
    { "id": "ws-uuid-2", "name": "외주 프로젝트" }
  ]
}
```

---

## 3. 프로젝트 목록

```
GET /workspaces/{workspace_id}/projects
```

워크스페이스 내에서 토큰 소유자가 접근할 수 있는 프로젝트 목록을 반환합니다.  
(생성자이거나 팀원으로 등록된 프로젝트만 포함)

**Path Parameter**

| 파라미터 | 설명 |
|----------|------|
| `workspace_id` | `/workspaces` 응답에서 얻은 워크스페이스 ID |

**응답 200**
```json
{
  "projects": [
    { "id": "proj-uuid-1", "name": "얼굴인식 고도화" },
    { "id": "proj-uuid-2", "name": "OCR 유지보수" }
  ]
}
```

**응답 403** — 해당 워크스페이스의 멤버가 아닌 경우

---

## 4. 멤버 목록

```
GET /members
```

담당자 지정 시 사용할 유저 ID 목록을 반환합니다.  
승인된 유저(`is_approved: true`)만 포함됩니다.

**응답 200**
```json
{
  "members": [
    { "id": "user-uuid-1", "name": "홍길동" },
    { "id": "user-uuid-2", "name": "김철수" }
  ]
}
```

---

## 5. 필드 정의

```
GET /fields
```

이슈 등록 시 사용 가능한 필드와 허용 값 목록을 반환합니다.

**응답 200**
```json
{
  "fields": [
    { "id": "title",               "name": "제목",       "required": true,  "type": "text" },
    { "id": "project_id",          "name": "프로젝트 ID", "required": true,  "type": "text" },
    { "id": "description",         "name": "설명",       "required": false, "type": "text" },
    { "id": "priority",            "name": "우선순위",    "required": false, "type": "select",
      "options": ["p0", "p1", "p2", "p3"] },
    { "id": "status",              "name": "상태",       "required": false, "type": "select",
      "options": ["backlog", "ready", "inProgress", "inReview", "done"] },
    { "id": "assigned_member_ids", "name": "담당자",     "required": false, "type": "multi-select" }
  ]
}
```

**필드 타입**

| type | 설명 |
|------|------|
| `text` | 자유 입력 문자열 |
| `select` | `options` 중 하나 선택 |
| `multi-select` | ID 배열. `assigned_member_ids`는 `/members`의 `id` 값 사용 |

---

## 6. 이슈 등록

```
POST /issues
Content-Type: application/json
```

선택한 프로젝트에 태스크(이슈)를 1건 등록합니다.

**Request Body**

| 필드 | 타입 | 필수 | 기본값 | 설명 |
|------|------|:----:|--------|------|
| `title` | string | ✅ | — | 태스크 제목 |
| `project_id` | string | ✅ | — | `/workspaces/{id}/projects` 에서 조회한 ID |
| `description` | string | | `""` | 상세 설명 |
| `priority` | string | | `"p2"` | `p0` (긴급) / `p1` / `p2` / `p3` (낮음) |
| `status` | string | | `"backlog"` | `backlog` / `ready` / `inProgress` / `inReview` / `done` |
| `assigned_member_ids` | string[] | | `[]` | 담당자 유저 ID 배열 |

**요청 예시**
```json
{
  "title": "로그인 버튼 UI 수정",
  "project_id": "proj-uuid-1",
  "description": "디자인 시안 반영 필요",
  "priority": "p1",
  "status": "backlog",
  "assigned_member_ids": ["user-uuid-1"]
}
```

**응답 201**
```json
{
  "id": "task-uuid",
  "title": "로그인 버튼 UI 수정",
  "url": ""
}
```

**에러 응답**

| 코드 | 사유 |
|------|------|
| 401 | 토큰 없음 또는 유효하지 않음 |
| 403 | 해당 프로젝트에 접근 권한 없음 |
| 404 | `project_id`에 해당하는 프로젝트 없음 |
| 422 | `priority` 또는 `status` 값이 허용 범위 외 |
| 500 | 서버 내부 오류 |

---

## 사용 흐름

```
① GET  /auth/verify
       → 토큰 정상 여부 확인

② GET  /workspaces
       → 워크스페이스 선택 (id 저장)

③ GET  /workspaces/{workspace_id}/projects
       → 프로젝트 선택 (id 저장)

④ GET  /members                  ← 담당자 지정이 필요한 경우에만
       → 담당자 유저 id 확인

⑤ POST /issues
       → project_id + 내용으로 태스크 등록
```

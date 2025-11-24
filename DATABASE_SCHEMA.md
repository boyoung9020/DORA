# 데이터베이스 스키마 (Database Schema)

## 📊 데이터베이스 개요

**데이터베이스**: PostgreSQL 15  
**ORM**: SQLAlchemy  
**연결**: Docker Compose 네트워크 내부

## 🗂️ 테이블 구조

### 1. users (사용자 테이블)

사용자 정보와 권한을 저장합니다.

| 컬럼명          | 타입     | 설명                     | 제약조건                |
| --------------- | -------- | ------------------------ | ----------------------- |
| `id`            | String   | 고유 식별자 (UUID)       | PRIMARY KEY             |
| `username`      | String   | 사용자 이름 (로그인 ID)  | UNIQUE, NOT NULL        |
| `email`         | String   | 이메일 주소              | UNIQUE, NOT NULL        |
| `password_hash` | String   | 해싱된 비밀번호 (bcrypt) | NOT NULL                |
| `is_admin`      | Boolean  | 관리자 여부              | NOT NULL, DEFAULT false |
| `is_approved`   | Boolean  | 관리자 승인 여부         | NOT NULL, DEFAULT false |
| `is_pm`         | Boolean  | 프로젝트 매니저 권한     | NOT NULL, DEFAULT false |
| `created_at`    | DateTime | 생성 시간                | NOT NULL                |

**인덱스**:

- `username` (UNIQUE)
- `email` (UNIQUE)

**관계**:

- 한 사용자는 여러 프로젝트의 팀원이 될 수 있음 (Project.team_member_ids)
- 한 사용자는 여러 태스크에 할당될 수 있음 (Task.assigned_member_ids)
- 한 사용자는 여러 댓글을 작성할 수 있음 (Comment.user_id)

---

### 2. projects (프로젝트 테이블)

프로젝트 정보를 저장합니다.

| 컬럼명            | 타입          | 설명                        | 제약조건                     |
| ----------------- | ------------- | --------------------------- | ---------------------------- |
| `id`              | String        | 고유 식별자 (UUID)          | PRIMARY KEY                  |
| `name`            | String        | 프로젝트 이름               | NOT NULL                     |
| `description`     | String        | 프로젝트 설명               | NULL 가능                    |
| `color`           | Integer       | 프로젝트 색상 (Color.value) | NOT NULL, DEFAULT 0xFF2196F3 |
| `team_member_ids` | ARRAY[String] | 팀원 사용자 ID 배열         | NOT NULL, DEFAULT []         |
| `created_at`      | DateTime      | 생성 시간                   | NOT NULL                     |
| `updated_at`      | DateTime      | 수정 시간                   | NOT NULL                     |

**인덱스**:

- `name`

**관계**:

- 한 프로젝트는 여러 태스크를 가질 수 있음 (Task.project_id)
- 한 프로젝트는 여러 팀원을 가질 수 있음 (team_member_ids 배열)

---

### 3. tasks (태스크 테이블)

태스크(작업) 정보를 저장합니다.

| 컬럼명                | 타입          | 설명                 | 제약조건                    |
| --------------------- | ------------- | -------------------- | --------------------------- |
| `id`                  | String        | 고유 식별자 (UUID)   | PRIMARY KEY                 |
| `title`               | String        | 태스크 제목          | NOT NULL                    |
| `description`         | String        | 태스크 설명          | NULL 가능, DEFAULT ''       |
| `status`              | Enum          | 태스크 상태          | NOT NULL, DEFAULT 'backlog' |
| `project_id`          | String        | 프로젝트 ID          | NOT NULL, INDEX             |
| `start_date`          | DateTime      | 시작일               | NULL 가능                   |
| `end_date`            | DateTime      | 종료일               | NULL 가능                   |
| `detail`              | String        | 상세 내용            | NULL 가능, DEFAULT ''       |
| `assigned_member_ids` | ARRAY[String] | 할당된 팀원 ID 배열  | NOT NULL, DEFAULT []        |
| `comment_ids`         | ARRAY[String] | 댓글 ID 배열         | NOT NULL, DEFAULT []        |
| `priority`            | Enum          | 중요도               | NOT NULL, DEFAULT 'p2'      |
| `status_history`      | JSON          | 상태 변경 히스토리   | NOT NULL, DEFAULT []        |
| `assignment_history`  | JSON          | 할당 히스토리        | NOT NULL, DEFAULT []        |
| `priority_history`    | JSON          | 중요도 변경 히스토리 | NOT NULL, DEFAULT []        |
| `created_at`          | DateTime      | 생성 시간            | NOT NULL                    |
| `updated_at`          | DateTime      | 수정 시간            | NOT NULL                    |

**인덱스**:

- `title`
- `project_id`
- `status`

**Enum 타입**:

**TaskStatus** (태스크 상태):

- `backlog` - 백로그
- `ready` - 준비됨
- `inProgress` - 진행 중
- `inReview` - 검토 중
- `done` - 완료

**TaskPriority** (태스크 중요도):

- `p0` - 최우선
- `p1` - 높음
- `p2` - 보통
- `p3` - 낮음

**관계**:

- 한 태스크는 하나의 프로젝트에 속함 (project_id)
- 한 태스크는 여러 팀원에 할당될 수 있음 (assigned_member_ids 배열)
- 한 태스크는 여러 댓글을 가질 수 있음 (comment_ids 배열)

---

### 4. comments (댓글 테이블)

태스크에 대한 댓글을 저장합니다.

| 컬럼명       | 타입     | 설명               | 제약조건        |
| ------------ | -------- | ------------------ | --------------- |
| `id`         | String   | 고유 식별자 (UUID) | PRIMARY KEY     |
| `task_id`    | String   | 태스크 ID          | NOT NULL, INDEX |
| `user_id`    | String   | 작성자 사용자 ID   | NOT NULL, INDEX |
| `username`   | String   | 작성자 사용자 이름 | NOT NULL        |
| `content`    | String   | 댓글 내용          | NOT NULL        |
| `created_at` | DateTime | 생성 시간          | NOT NULL        |
| `updated_at` | DateTime | 수정 시간          | NULL 가능       |

**인덱스**:

- `task_id`
- `user_id`

**관계**:

- 한 댓글은 하나의 태스크에 속함 (task_id)
- 한 댓글은 하나의 사용자가 작성함 (user_id)

---

## 🔗 테이블 관계도 (ERD)

```
┌─────────────┐
│   users     │
│─────────────│
│ id (PK)     │
│ username    │◄─────┐
│ email       │      │
│ password    │      │
│ is_admin    │      │
│ is_approved │      │
│ is_pm       │      │
└─────────────┘      │
                      │
┌─────────────┐      │
│  projects   │      │
│─────────────│      │
│ id (PK)     │      │
│ name        │      │
│ team_member │──────┘ (team_member_ids 배열)
│ _ids[]      │
└──────┬──────┘
       │
       │ (project_id)
       │
┌──────▼──────┐
│   tasks     │
│─────────────│
│ id (PK)     │
│ title       │
│ project_id │◄──────┐
│ status      │       │
│ assigned    │       │
│ _member_ids│───────┘ (assigned_member_ids 배열)
│ comment_ids│───────┐
└──────┬──────┘       │
       │              │
       │ (task_id)    │
       │              │
┌──────▼──────────────▼──┐
│      comments          │
│────────────────────────│
│ id (PK)                │
│ task_id (FK)           │
│ user_id (FK) ──────────┘ (user_id)
│ username               │
│ content                │
└────────────────────────┘
```

## 📝 데이터 타입 상세

### ARRAY 타입

PostgreSQL의 배열 타입을 사용:

- `team_member_ids`: 사용자 ID 배열
- `assigned_member_ids`: 사용자 ID 배열
- `comment_ids`: 댓글 ID 배열

예시:

```sql
team_member_ids = ['user-id-1', 'user-id-2', 'user-id-3']
```

### JSON 타입

히스토리 데이터는 JSON으로 저장:

- `status_history`: 상태 변경 이력
- `assignment_history`: 할당 이력
- `priority_history`: 중요도 변경 이력

예시:

```json
status_history = [
  {
    "fromStatus": "backlog",
    "toStatus": "inProgress",
    "userId": "user-id-1",
    "username": "john",
    "changedAt": "2025-11-20T02:30:00Z"
  }
]
```

### Enum 타입

PostgreSQL ENUM 타입 사용:

- `TaskStatus`: 태스크 상태
- `TaskPriority`: 태스크 중요도

## 🔍 주요 쿼리 패턴

### 1. 프로젝트의 모든 태스크 가져오기

```sql
SELECT * FROM tasks WHERE project_id = 'project-id';
```

### 2. 사용자가 할당된 모든 태스크

```sql
SELECT * FROM tasks
WHERE 'user-id' = ANY(assigned_member_ids);
```

### 3. 태스크의 모든 댓글

```sql
SELECT * FROM comments
WHERE task_id = 'task-id'
ORDER BY created_at;
```

### 4. 프로젝트의 모든 팀원

```sql
SELECT * FROM users
WHERE id = ANY(
  SELECT unnest(team_member_ids) FROM projects WHERE id = 'project-id'
);
```

## 🗄️ 데이터베이스 초기화

서버 시작 시 자동으로:

1. 모든 테이블 생성 (`Base.metadata.create_all()`)
2. 초기 관리자 계정 생성 (`init_db.py`)

## 📊 데이터 흐름

```
사용자 생성 (users)
    ↓
프로젝트 생성 (projects)
    ↓ team_member_ids에 사용자 추가
태스크 생성 (tasks)
    ↓ project_id 연결
    ↓ assigned_member_ids에 사용자 추가
댓글 작성 (comments)
    ↓ task_id 연결
    ↓ user_id 연결
```

## 🔐 보안 고려사항

1. **비밀번호**: bcrypt로 해싱되어 저장
2. **관계**: 외래 키는 배열로 저장 (PostgreSQL ARRAY 타입)
3. **히스토리**: JSON으로 저장되어 감사 추적 가능

## 💡 설계 특징

1. **정규화**: 기본적인 정규화 적용
2. **유연성**: 배열 타입으로 다대다 관계 지원
3. **확장성**: JSON 필드로 히스토리 추적
4. **성능**: 인덱스로 빠른 조회 지원

## 📋 테이블 생성 SQL (참고)

실제로는 SQLAlchemy가 자동으로 생성하지만, 참고용:

```sql
CREATE TABLE users (
    id VARCHAR PRIMARY KEY,
    username VARCHAR UNIQUE NOT NULL,
    email VARCHAR UNIQUE NOT NULL,
    password_hash VARCHAR NOT NULL,
    is_admin BOOLEAN NOT NULL DEFAULT false,
    is_approved BOOLEAN NOT NULL DEFAULT false,
    is_pm BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE projects (
    id VARCHAR PRIMARY KEY,
    name VARCHAR NOT NULL,
    description VARCHAR,
    color INTEGER NOT NULL DEFAULT 4280391411,
    team_member_ids VARCHAR[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE tasks (
    id VARCHAR PRIMARY KEY,
    title VARCHAR NOT NULL,
    description VARCHAR DEFAULT '',
    status VARCHAR NOT NULL DEFAULT 'backlog',
    project_id VARCHAR NOT NULL,
    start_date TIMESTAMP WITH TIME ZONE,
    end_date TIMESTAMP WITH TIME ZONE,
    detail VARCHAR DEFAULT '',
    assigned_member_ids VARCHAR[] NOT NULL DEFAULT '{}',
    comment_ids VARCHAR[] NOT NULL DEFAULT '{}',
    priority VARCHAR NOT NULL DEFAULT 'p2',
    status_history JSONB NOT NULL DEFAULT '[]',
    assignment_history JSONB NOT NULL DEFAULT '[]',
    priority_history JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE comments (
    id VARCHAR PRIMARY KEY,
    task_id VARCHAR NOT NULL,
    user_id VARCHAR NOT NULL,
    username VARCHAR NOT NULL,
    content VARCHAR NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- 인덱스 생성
CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_comments_task_id ON comments(task_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
```

## 🎯 요약

- **4개 테이블**: users, projects, tasks, comments
- **관계**: 배열과 외래 키로 연결
- **특징**: 히스토리 추적, 유연한 다대다 관계
- **보안**: 비밀번호 해싱, 인덱스 최적화


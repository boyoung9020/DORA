# 어제 미완료 리뷰 다이얼로그 재노출/연장 버그 정리 (서버 상태 기반)

| 속성 | 값 |
|------|-----|
| 유형 | fix |
| 영역 | backend/models, backend/routers, frontend/screens, frontend/widgets/dashboard, frontend/services, schema(users) |
| 날짜 | 2026-04-24 |
| 상태 | done |
| 관련 | main_layout, yesterday_review_dialog, workspaces, workspace_service, user, main |

## 요청 내용

"어제 미완료 작업" 강제 모달이 하루에도 여러 번 뜨고, "오늘로 연장"을 눌러도 재노출되는 문제를
**장기적으로 재발하지 않도록** 시스템 레벨에서 정리한다.

- 재노출 기록을 **서버 상태**로 이전하여 디바이스 간 일관성 보장 (SharedPreferences 대체)
- "오늘로 연장" 액션의 의미를 실제로 "어제 목록에서 제외되는" 상태로 맞춤
- 다이얼로그 "모달 덫"(빠져나갈 방법이 모호함) 제거

## 배경 (Root cause)

현재 구조는 두 층의 결함이 겹쳐 발생한다.

1. **프론트 세션/기기 상태 의존** — `SharedPreferences.last_task_review_date` 에 의존. `await showDialog(...)` 가 pop 된 뒤에야 저장됨. 사용자가 다이얼로그를 완전히 닫기 전에 새로고침/재로그인/브라우저 탭 이동 시 저장 실패 → 하루 N회 재노출. 또한 웹/데스크톱을 오가면 각 기기에서 각각 1회 뜬다.
2. **"오늘로 연장" 시맨틱 오류** — `_handleCarryToday` 가 `end_date`만 오늘로 변경. `start_date` 가 어제 이전이면 백엔드 `_scheduled_for_day` 의 `(sd and ed)` 분기에서 **어제 범위와 여전히 겹쳐** 어제 미완료 목록에 계속 포함됨.

## 범위

### A. 백엔드

#### A-1. `users` 테이블 컬럼 추가 (schema)
- 컬럼명: `last_yesterday_review_at TIMESTAMPTZ NULL`
- 의미: "어제 미완료 리뷰 다이얼로그를 마지막으로 본 시각(UTC)"
- `backend/app/models/user.py` 에 SQLAlchemy 컬럼 추가
- `backend/app/main.py` 에 `ensure_users_last_yesterday_review_column()` 추가 (`ALTER TABLE users ADD COLUMN IF NOT EXISTS ...`) — 기존 `ensure_favorite_project_ids_column` 패턴 준수

#### A-2. `GET /api/workspaces/{workspace_id}/yesterday-incomplete` 응답 확장
- 응답 스키마에 `already_reviewed_today: bool` 추가
  - 판정: `user.last_yesterday_review_at` 가 **오늘 UTC 범위(00:00 ~ 23:59:59.999999)** 에 포함되면 True
- 기존 필드(`target_date`, `incomplete_tasks`) 유지 → 하위 호환

#### A-3. 신규 `POST /api/workspaces/{workspace_id}/yesterday-incomplete/acknowledge`
- `get_current_user` Depends + 워크스페이스 멤버 검증
- `user.last_yesterday_review_at = now()` 로 세팅 후 204 No Content
- 멱등 — 같은 날 여러 번 호출해도 안전

### B. 프론트엔드

#### B-1. `WorkspaceService` 수정
- `getYesterdayIncompleteTasks()` 반환 타입을 `List<MemberTodayTask>` 에서 `YesterdayReviewResult`(간단 DTO: `tasks`, `alreadyReviewedToday`) 로 변경
- 신규 `acknowledgeYesterdayReview(String workspaceId)` 메서드 추가 (POST 호출)

#### B-2. `main_layout.dart` `_checkYesterdayIncomplete()` 로직 재작성
- `SharedPreferences.last_task_review_date` 제거 — 완전히 서버 상태로 이전
- 흐름:
  1. `getYesterdayIncompleteTasks()` 호출
  2. `alreadyReviewedToday == true` → 즉시 return
  3. `tasks.isEmpty == true` → `acknowledgeYesterdayReview()` 호출 후 return
  4. `tasks.isNotEmpty` → **다이얼로그 오픈 직전** `acknowledgeYesterdayReview()` 호출 → 그 다음 `showDialog(...)`
     - 사용자가 중간에 이탈해도 이미 서버에 마킹되어 있으므로 당일 재노출 없음

#### B-3. "오늘로 연장" 시맨틱 수정 (`yesterday_review_dialog.dart`)
- `_handleCarryToday` 를 다음과 같이 수정:
  ```dart
  final todayDate = DateTime(today.year, today.month, today.day);
  final newStart = (fullTask.startDate != null && fullTask.startDate!.isBefore(todayDate))
      ? todayDate
      : fullTask.startDate;
  final updated = fullTask.copyWith(startDate: newStart, endDate: todayDate);
  ```
- 효과:
  - `start_date` 가 어제 이전이면 오늘로 당김 → 백엔드 `_scheduled_for_day` 에서 어제 범위와 더 이상 겹치지 않음 → 진짜로 어제 목록에서 빠짐
  - `start_date` 가 null 이면 그대로 (기존과 동일, end_date 만 있는 케이스는 원래부터 정상 동작)
  - `start_date` 가 오늘/미래면 변경 안 함

#### B-4. 다이얼로그 UX 개선 (모달 덫 제거)
- `showDialog(barrierDismissible: false)` → `barrierDismissible: true`
- 헤더 우측에 **X 닫기 버튼** 추가
- Footer 를 양쪽 버튼 구조로 재편:
  - Left: **"나중에 처리"** (secondary) — 항상 활성, 눌러도 서버 ack 는 이미 되어있음
  - Right: **"완료"** (primary) — `_allHandled` 일 때만 활성 (현재와 동일)
- 어떤 경로로 닫혀도 재노출은 **서버 ack** 로 이미 보장됨 → 일관성 확보

## 화면 구조 (ASCII)

### 현재

```
┌─────────────────────────────────────────────────────┐
│ 🟠 어제 미완료 작업   [2건]          2/2  (closer)  │
│    04월 23일의 할 일 중 완료되지 않은 작업입니다    │
├─────────────────────────────────────────────────────┤
│  ○ Task Title ...                                   │
│    [상태] [P1] project-name    5/23                 │
│    [완료 처리] [오늘로 연장] [건너뛰기]             │
├─────────────────────────────────────────────────────┤
│  [ 모두 확인 완료 (2/2) ]       ← 전부 처리해야 활성│
└─────────────────────────────────────────────────────┘
     ↑ 외부 탭 불가(barrierDismissible:false), X 없음
```

### 개선 후

```
┌─────────────────────────────────────────────────────┐
│ 🟠 어제 미완료 작업   [2건]     2/2            [X]  │
│    04월 23일의 할 일 중 완료되지 않은 작업입니다    │
├─────────────────────────────────────────────────────┤
│  ○ Task Title ...                                   │
│    [상태] [P1] project-name    5/23                 │
│    [완료 처리] [오늘로 연장] [건너뛰기]             │
├─────────────────────────────────────────────────────┤
│  [ 나중에 처리 ]            [ 완료 (2/2) ]          │
└─────────────────────────────────────────────────────┘
     ↑ 빈 영역 탭/ESC/X/나중에 처리 — 어떤 경로로 닫아도
       서버 ack 는 다이얼로그 오픈 직전에 이미 완료됨 →
       당일 재노출 없음 (기기 간 공유됨)
```

## 데이터 흐름 (개선 후)

```
[MainLayout.initState(post-frame)]
         │
         ▼
   GET /api/workspaces/{ws}/yesterday-incomplete
         │
         │  { already_reviewed_today, incomplete_tasks }
         ▼
  already_reviewed_today ? ──Yes──► return
         │ No
         ▼
  incomplete_tasks.isEmpty ? ──Yes──► POST /ack ──► return
         │ No
         ▼
   POST /api/workspaces/{ws}/yesterday-incomplete/acknowledge
         │ (204)
         ▼
   showDialog(barrierDismissible: true, ...)
         │  (사용자가 어떻게 닫든 상관 없음)
         ▼
   오늘로 연장 → end_date=today, start_date=max(start, today)
                 → 백엔드 _scheduled_for_day(어제) == False
```

## 작업 결과

- [x] A-1. `users.last_yesterday_review_at` 컬럼 추가 (`user.py` 모델 + `main.py` `ensure_users_last_yesterday_review_column`)
- [x] A-2. `GET /yesterday-incomplete` 응답에 `already_reviewed_today` 필드 추가
- [x] A-3. `POST /yesterday-incomplete/acknowledge` 엔드포인트 신설 (204 No Content, 멱등)
- [x] B-1. `WorkspaceService.getYesterdayIncompleteTasks` 반환 타입을 `YesterdayReviewResult` 로 확장 + `acknowledgeYesterdayReview()` 추가
- [x] B-2. `main_layout.dart._checkYesterdayIncomplete()` 서버 상태 기반으로 재작성 (SharedPreferences 의 `last_task_review_date` 사용 제거)
- [x] B-3. `yesterday_review_dialog.dart._handleCarryToday()` 에서 `start_date` 도 `max(start, today)` 로 보정
- [x] B-4. 다이얼로그 UX 개선: 헤더 X 닫기 버튼, Footer "나중에 처리" 버튼, `barrierDismissible:true`
- [x] 빌드/정적 분석: `flutter analyze` 로 본 파일 3개 — **신규 경고 없음** (기존 37건 전부 이전부터 존재), 백엔드 Python AST 파싱 통과
- [ ] 수동 검증: 실제 앱 실행 시나리오 확인 (아래 Verification 참조) — 사용자 확인 필요

## 분석 (fix 유형 필수)

- **Root cause**
  - (1) 다이얼로그 "본 기록" 을 완전히 닫은 후에만 `SharedPreferences` 에 저장 → 중간 이탈 시 하루에 여러 번 재노출
  - (2) `SharedPreferences` 는 기기 단위 → 웹/데스크톱 다기기 사용 시 각 기기마다 1회씩 또 뜸
  - (3) "오늘로 연장" 이 `end_date` 만 변경 → `start_date` 가 어제 이전이면 백엔드 판정에서 여전히 "어제의 할일" 로 분류됨
  - (4) 모달이 `barrierDismissible:false` + 모든 태스크 처리 전엔 Footer 버튼 비활성 → 사용자가 닫을 방법을 찾지 못하고 "새로고침으로 도망" → 저장 실패 루프

- **Change**
  - 하루 1회 체크를 **서버 TIMESTAMPTZ 컬럼**으로 이전, 디바이스 무관 보장
  - 체크 시점을 **다이얼로그 오픈 직전**으로 변경 (이탈해도 재노출 없음)
  - "오늘로 연장" 이 `start_date`·`end_date` 를 함께 조정해 어제 판정에서 확실히 제외되게 수정
  - 다이얼로그를 dismissible 로 바꾸고 "X" / "나중에 처리" 제공 → 탈출 경로 제공

- **Recurrence prevention**
  - 서버 상태가 단일 진실(single source of truth) → 프론트 코드 수정으로 재발 불가
  - `already_reviewed_today` 판정을 백엔드가 계산해서 반환 → 프론트가 직접 날짜 비교 로직을 가지지 않음 (타임존/자정 경계 오류 여지 제거)
  - "오늘로 연장" 시 `start_date` 보정은 백엔드 `_scheduled_for_day` 의 겹침 판정 규칙과 일관됨

- **Verification** (수동 검증 시나리오)
  1. 어제 미완료 태스크 1건 이상 보유 상태로 앱 첫 진입 → 다이얼로그 뜸
  2. X 버튼 눌러 닫기 → 새로고침 → **재노출 없음**
  3. "오늘로 연장" → "완료" 후 새로고침 → 재노출 없음, 해당 태스크는 "오늘 할일" 에만 뜨고 "어제 미완료" 에서 빠짐
  4. 웹에서 리뷰 → 같은 계정으로 Windows 데스크톱 로그인 → **다이얼로그 안 뜸** (기기 간 공유 검증)
  5. 자정 지나 다음 날 접속 → 새 "어제 미완료" 목록 기준으로 다이얼로그 뜸
  6. 태스크 없는 상태로 진입 → 다이얼로그 안 뜸 + 서버에 ack 마킹되어 이후 진입 시 추가 API 호출 없이 단일 GET 으로 종결

- **Remaining risk**
  - 기존 `last_task_review_date` SharedPreferences 키는 더 이상 읽지 않음 — 잔존 값이 있어도 무시됨 (정리 코드 없음, 허용 가능)
  - 대량의 워크스페이스/태스크를 가진 유저에서 `yesterday-incomplete` GET 성능은 이전과 동일 (변경 없음)
  - 타임존: 현재 구현은 UTC 기준. 사용자 로컬 자정과 어긋날 수 있음 — 기존 동작과 동일하므로 이번 작업 범위 밖

## 참고 사항

- `backend/app/schemas/` 에 `yesterday-incomplete` 응답 전용 스키마가 없는 상태 → 라우터 내 dict 반환 유지 (기존 방식 준수)
- `flutter analyze` 및 수동 실행으로 리그레션 확인 필요
- 인덱스 갱신 필수: `docs/requests/2026-04/INDEX.md`, (새 월이 아니므로) 루트 `docs/requests/INDEX.md` 는 수정 불필요

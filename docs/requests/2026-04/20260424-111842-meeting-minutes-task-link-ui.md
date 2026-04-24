# 회의록 → 작업 연결 표시 및 아이콘 위치 개선

| 속성 | 값 |
|------|-----|
| 유형 | feat + ui |
| 영역 | frontend/screens (meeting_minutes_screen), backend/models+routers (tasks), schema (tasks 테이블) |
| 날짜 | 2026-04-24 |
| 상태 | done |
| 관련 | meeting_minutes_screen, task_detail_screen, Task 모델, tasks 라우터 |

## 요청 내용

회의록 상세(우측) 에서 각 줄에 붙은 **작업 생성 UI** 를 개선:

1. **이미 작업이 생성된 줄** 을 시각적으로 표시 (체크/다른 마커)
2. 해당 마커 클릭 시 **해당 작업 상세로 이동** (`TaskDetailScreen` 다이얼로그)
3. 작업 생성 아이콘을 현재 "행 맨 오른쪽" 에서 → **텍스트 끝 바로 옆** 으로 이동

## 배경

- 현재 렌더러 `_HoverableLineWidget` ([meeting_minutes_screen.dart:1632-1735](lib/screens/meeting_minutes_screen.dart#L1632-L1735)) 는 `Row(Expanded(MarkdownBody) + AnimatedOpacity(add_task_icon))` 구조 → 아이콘이 항상 행 끝
- 회의록 줄에서 작업이 생성돼도 아무 흔적이 남지 않아, 중복 생성 가능성 + 사후 추적 불가
- 작업 생성 시 `_createTaskFromLine` ([meeting_minutes_screen.dart:273-645](lib/screens/meeting_minutes_screen.dart#L273-L645)) 는 `taskProvider.createTask(...)` 로 생성만 할 뿐, 회의록과의 링크를 저장하지 않음

## 데이터 모델 변경 (확정)

### `tasks` 테이블 컬럼 2개 추가
- `source_meeting_minutes_id VARCHAR NULL` — 회의록 ID
- `source_line_id VARCHAR NULL` — 회의록 본문에 내장된 줄 UUID
- 인덱스: `ix_tasks_source_meeting_minutes_id`, `ix_tasks_source_line_id`
- 회의록 삭제 시 작업은 보존 (FK 제약 없음 — 조용히 고아 상태로 남음)

### 매칭 전략 — UUID 내장 방식
- 회의록 본문의 각 줄 끝에 ` <!--mm:{UUID}-->` 마커를 삽입
- 마커가 붙은 줄은 편집/이동되어도 UUID 가 따라다녀 링크 유지
- 렌더링 시 `RegExp(r'<!--mm:([0-9a-fA-F-]{36})-->')` 로 마커를 추출하고 본문에서 제거
- 태스크 조회 시 `GET /api/tasks?source_meeting_minutes_id={id}` 로 연결된 태스크만 가져와 `Map<lineId, Task>` 구축
- 사용자가 편집기에서 마커를 직접 지우면 링크가 끊기지만, 일반적인 텍스트 편집에는 영향 없음

## 백엔드 변경

1. `app/models/task.py` — `source_meeting_minutes_id`, `source_meeting_minutes_line` 컬럼 추가
2. `app/schemas/task.py` — `TaskCreate` 에 두 필드 optional, `TaskResponse` 에도 포함
3. `app/routers/tasks.py`
   - `create_task` 에서 두 필드 저장
   - `get_all_tasks` 에 `source_meeting_minutes_id` 쿼리 파라미터 추가 (회의록 뷰어가 특정 회의록의 링크된 태스크만 한 번에 가져오도록)
4. `app/main.py` — `ensure_tasks_source_meeting_minutes_columns()` 함수 + 인덱스 생성 ALTER TABLE 추가

## 프론트엔드 변경

1. `lib/models/task.dart` — `sourceMeetingMinutesId`, `sourceMeetingMinutesLine` 필드 추가 + fromJson / toJson / copyWith
2. `lib/services/task_service.dart` (+ `lib/providers/task_provider.dart` `createTask`) — 두 필드 전달 경로
3. `lib/screens/meeting_minutes_screen.dart`
   - 뷰어 진입 시 `GET /api/tasks?source_meeting_minutes_id=<id>` 로 링크된 작업 목록 로드 → `Map<lineText, Task>` 구축
   - `_HoverableLineWidget` 에 해당 Map 을 전달
   - 줄 텍스트가 Map 에 있으면: **체크 마커** (초록색 `Icons.check_circle`) 상시 표시 + 클릭 시 `TaskDetailScreen` 다이얼로그 열기
   - 없으면: 기존 hover 시 표시되는 `Icons.add_task` 유지
   - `_createTaskFromLine` 은 `sourceMeetingMinutesId: minutes.id`, `sourceMeetingMinutesLine: lineText` 전달
   - 작업 생성 성공 시 로컬 Map 갱신 (즉시 체크 마커 표시)

## 아이콘 위치 개선

### 현재
```
┌────────────────────────────────────────────┐
│ # 회의 정리                            [+]  │  ← 아이콘이 행 끝
│ 1. 서비스 이름 변경 후 공유              [+]  │
└────────────────────────────────────────────┘
```

### 변경 후
```
┌────────────────────────────────────────────┐
│ # 회의 정리 [✓]                             │  ← 체크(작업 있음) 텍스트 바로 옆
│ 1. 서비스 이름 변경 후 공유 [+]              │  ← 추가(작업 없음) 텍스트 바로 옆 (hover 시)
│ - AI CA가 아닌 "AI 메타"로 이름 변경         │  ← 마커 없음 (hover 시 [+] 표시)
└────────────────────────────────────────────┘
```

### 구현
```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    Flexible(
      fit: FlexFit.loose,
      child: IntrinsicWidth(
        child: MarkdownBody(data: line, ...),
      ),
    ),
    const SizedBox(width: 6),
    marker,  // 체크 또는 추가 아이콘
  ],
)
```
- `IntrinsicWidth` 로 마크다운이 자연 너비를 갖도록 → 아이콘이 텍스트 끝 바로 옆
- `Flexible(FlexFit.loose)` 로 매우 긴 줄이 남은 공간을 넘지 않도록 상한 적용 (줄바꿈 허용)

## 작업 결과

### 백엔드
- [x] `tasks` 테이블에 `source_meeting_minutes_id`, `source_line_id` 컬럼 추가 — `ensure_tasks_source_meeting_minutes_columns()` ([backend/app/main.py:819-846](backend/app/main.py#L819-L846))
- [x] 인덱스 `ix_tasks_source_meeting_minutes_id`, `ix_tasks_source_line_id` 생성
- [x] `Task` ORM 모델 필드 추가 ([backend/app/models/task.py:49-51](backend/app/models/task.py#L49-L51))
- [x] `TaskBase` 스키마에 두 필드 추가 ([backend/app/schemas/task.py:27-29](backend/app/schemas/task.py#L27-L29))
- [x] `GET /api/tasks` 에 `source_meeting_minutes_id` 필터 추가 ([backend/app/routers/tasks.py:41,55-56](backend/app/routers/tasks.py#L41))
- [x] `POST /api/tasks` 에서 두 필드 저장

### 프론트엔드
- [x] `Task` Dart 모델 필드 + fromJson / toJson / copyWith 반영
- [x] `TaskService.createTask` / `TaskProvider.createTask` 에 두 필드 전달 경로 추가
- [x] `TaskProvider.createTaskReturning` 신규 메서드 — 생성된 `Task?` 반환 (기존 `createTask` bool 반환은 보존)
- [x] `MeetingMinutesScreen`: 선택/저장 시 `_loadLinkedTasks(minutesId)` 호출해 `Map<lineId, Task>` 구축
- [x] `_HoverableLineWidget` 리팩터:
  - [x] `Flexible(fit: FlexFit.loose) + IntrinsicWidth(MarkdownBody)` 로 아이콘을 텍스트 끝 바로 옆 배치 (긴 줄은 줄바꿈 허용)
  - [x] 연결된 태스크 있으면 초록 `Icons.check_circle` 상시 표시 + 클릭 → `TaskDetailScreen` 다이얼로그
  - [x] 없으면 hover 시 `Icons.add_task` 표시 (기존 동작 유지)
- [x] UUID v4 생성기 내장 ([meeting_minutes_screen.dart:32-44](lib/screens/meeting_minutes_screen.dart#L32-L44))
- [x] 줄 마커 파서/스트리퍼 (`_parseLineMarker`) 내장
- [x] `_createTaskFromLine(lineIndex)` 이 호출되면: 기존 마커가 있으면 UUID 재사용, 없으면 신규 발급 → 태스크 생성 → 본문 업데이트 → 로컬 맵 갱신
- [x] `flutter analyze` 통과 확인 (신규 경고 없음, 기존 `value → initialValue` deprecation 2건만 잔존)

## 확정 사항 (사용자 답변)

1. **클릭 시 이동 방식** — `TaskDetailScreen` 다이얼로그 방식 (칸반과 동일) ✅
2. **매칭 전략** — UUID 내장. 각 줄 끝에 ` <!--mm:{UUID}-->` 마커 삽입 → 줄 편집/이동에도 링크 유지 ✅
3. **매우 긴 줄 처리** — 아이콘은 텍스트가 끝나는 지점에 위치. `IntrinsicWidth + Flexible(loose)` 로 자동 처리 (짧은 줄은 바로 옆, 긴 줄은 줄바꿈 후 끝) ✅

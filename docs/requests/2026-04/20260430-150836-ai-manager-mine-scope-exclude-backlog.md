# AI 매니저 섹션 기본 범위 "내 할당"으로 변경 + backlog 제외

| 속성 | 값 |
|------|-----|
| 유형 | fix |
| 영역 | frontend/screens, backend/routers |
| 날짜 | 2026-04-30 |
| 상태 | done |
| 관련 | dashboard_screen, ai |

## 요청 내용

홈 화면 AI 매니저 섹션에서 두 가지 문제:
1. 기본 범위가 "전체(all)"라 담당자가 본인이 아닌 타인 작업도 요약에 포함됨 → 기본값을 "내 할당(mine)"으로 변경
2. backlog(착수 전) 상태 작업도 긴급/오늘 마감/기한 초과 목록에 포함됨 → backlog 제외

## 변경 내용

### `lib/screens/dashboard_screen.dart`

기본 범위를 `'all'` → `'mine'` 으로 변경:

```dart
// 변경 전
String _aiSummaryScope = 'all';

// 변경 후
String _aiSummaryScope = 'mine';
```

### `backend/app/routers/ai.py`

`urgent_tasks`, `today_due_tasks`, `overdue_tasks` 필터에 backlog 제외 조건 추가:

```python
# 변경 전
urgent_tasks = [task for task in scoped_tasks
    if task.status != TaskStatus.DONE
    and task.priority in (TaskPriority.P0, TaskPriority.P1)]
today_due_tasks = [task for task in scoped_tasks
    if task.status != TaskStatus.DONE and task.end_date
    and task.end_date.astimezone().date() == today_local]
overdue_tasks = [task for task in scoped_tasks
    if task.status != TaskStatus.DONE and task.end_date
    and task.end_date.astimezone().date() < today_local]

# 변경 후 (backlog 제외 조건 추가)
urgent_tasks = [task for task in scoped_tasks
    if task.status not in (TaskStatus.DONE, TaskStatus.BACKLOG)
    and task.priority in (TaskPriority.P0, TaskPriority.P1)]
today_due_tasks = [task for task in scoped_tasks
    if task.status not in (TaskStatus.DONE, TaskStatus.BACKLOG)
    and task.end_date
    and task.end_date.astimezone().date() == today_local]
overdue_tasks = [task for task in scoped_tasks
    if task.status not in (TaskStatus.DONE, TaskStatus.BACKLOG)
    and task.end_date
    and task.end_date.astimezone().date() < today_local]
```

## 작업 결과

- [x] 기본 scope `'all'` → `'mine'` 변경
- [x] 백엔드 urgent_tasks/today_due_tasks/overdue_tasks backlog 제외

## 분석

- **Root cause**: 기본 scope가 `all`이라 본인 미할당 작업까지 AI 프롬프트에 포함. backlog는 `done` 만 제외하는 기존 패턴이 적용됨.
- **Change**: 프론트 기본값 mine으로 변경. 백엔드 3개 task 목록에 backlog 제외.
- **Recurrence prevention**: 같은 날 홈 기한 초과, 프로젝트 마감 임박과 동일한 "backlog 제외" 의미 일관성 적용.
- **Verification**: `flutter analyze`, Python ast.parse 통과.
- **Remaining risk**: AI 캐시는 scope별로 분리 저장됨 — 오늘 이미 `all` 캐시가 생성된 사용자는 내일 갱신.

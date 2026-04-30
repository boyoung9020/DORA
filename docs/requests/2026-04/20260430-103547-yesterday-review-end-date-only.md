# 어제 미완료 리뷰 다이얼로그를 "어제가 마감"인 작업만 보여주도록 좁힘

| 속성 | 값 |
|------|-----|
| 유형 | fix |
| 영역 | backend/routers, frontend/widgets |
| 날짜 | 2026-04-30 |
| 상태 | done |
| 관련 | workspaces, yesterday_review_dialog |

## 요청 내용

매일 아침 뜨는 "어제 미완료 작업" 다이얼로그가 어제가 마감일이 아닌 작업까지 (단지 어제 작업 기간에 포함되어 있다는 이유로) 노출하고 있다. **어제가 `end_date` 인 작업 중 미완료인 것만** 뜨도록 좁힌다.

## 배경

- 현행 백엔드 [`workspaces.py:483`](../../../backend/app/routers/workspaces.py#L483) 의 필터는 `_is_date_task(t, 어제 day_start, day_end)` 를 사용
- `_is_date_task` → `_scheduled_for_day` 가 `start_date <= day_end AND end_date >= day_start` 도 True 로 판정 → "어제 작업 기간에 걸쳐 있던 모든 진행 중 작업" 이 포함됨
- 사용자 의도는 "어제가 마감일인 것만" — 따라서 `end_date` 가 어제 범위에 정확히 떨어지는 항목만 통과시켜야 함
- start_date 만 있는 작업, 날짜가 둘 다 없는 상시 IN_PROGRESS 작업은 **모두 제외**

## 변경 계획

### Backend `backend/app/routers/workspaces.py`

`/yesterday-incomplete` 엔드포인트 (라인 433-499) 의 필터만 교체:

```python
# 변경 전
if _is_date_task(t, day_start, day_end) and t.status != TaskStatus.DONE

# 변경 후 — end_date 가 어제 범위에 떨어지는 것만
if (
    t.status != TaskStatus.DONE
    and t.end_date is not None
    and day_start <= (
        t.end_date if t.end_date.tzinfo else t.end_date.replace(tzinfo=timezone.utc)
    ) <= day_end
)
```

`_is_date_task` / `_scheduled_for_day` 자체는 다른 곳(팀 현황 대시보드 등) 에서도 쓰이므로 **건드리지 않음**.

### Frontend `lib/widgets/dashboard/yesterday_review_dialog.dart:133`

부제 카피를 "할 일 중 완료되지 않은" → "마감 작업 중 미완료" 로 바꿔 의미 일치:

```dart
'$dateLabel이 마감이었던 작업 중 미완료 작업입니다'
```

## 작업 결과

- [x] 백엔드 `/yesterday-incomplete` 필터를 `end_date` 기반으로 좁힘
- [x] 프론트 다이얼로그 부제 문구 갱신
- [x] `_is_date_task` / `_scheduled_for_day` 는 그대로 유지 (다른 사용처에 영향 없음)

## 분석

- **Root cause**: `_is_date_task` 가 "그 날짜의 할 일" 을 시작/마감 어느 한쪽이라도 어제와 겹치면 포함하도록 설계되어 있어, 어제가 마감이 아닌 진행 중 작업까지 어제 미완료 다이얼로그에 노출됨.
- **Change**: `/yesterday-incomplete` 엔드포인트만 별도로 `end_date` 동일 날짜 검사로 좁힘. 다른 엔드포인트(팀 현황의 "오늘 일정") 는 의도적으로 기간 겹침 기준을 유지.
- **Recurrence prevention**: 다이얼로그 부제도 "마감 작업" 이라고 명시 → 차후 "왜 안 보이지?" 혼동 방지.
- **Verification**: 변경 후 백엔드 syntax 체크. UI 는 사용자 확인 단계에서 검증.
- **Remaining risk**: start_date 만 있는 작업은 이제 다이얼로그에서 빠짐 — 의도된 동작.

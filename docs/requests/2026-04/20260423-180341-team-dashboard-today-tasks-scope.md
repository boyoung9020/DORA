# AI팀 현황 대시보드 "오늘 할일" 범위 축소 및 완료 태스크 표시 정렬

| 속성 | 값 |
|------|-----|
| 유형 | ui |
| 영역 | frontend/widgets/workspace, backend/routers/workspaces |
| 날짜 | 2026-04-23 |
| 상태 | done |
| 관련 | team_today_dashboard, workspaces, today_task_row, dashboard_screen |

## 요청 내용

AI팀 현황 > 대시보드 화면의 멤버 카드에 "오늘 할일만" 보이게 하고,
"오늘 할일이었는데 완료 처리된 태스크"는 홈 화면의 `오늘 할 작업` 처럼 별도로(취소선 포함) 보여준다.
현재는 범위가 넓어서 사실상 "전체 활성/완료 태스크"가 다 보이는 것처럼 느껴진다.

## 배경

### 현재 `todayTasks` 정의 (backend `_is_date_task`)

`backend/app/routers/workspaces.py:22-44`

- **DONE**: `updated_at` 이 오늘(UTC 기준)인 모든 완료 태스크
  - → 과거 마감이었지만 오늘 몰아서 정리한 태스크까지 전부 포함
- **IN_PROGRESS / READY / IN_REVIEW**
  - `start_date` + `end_date` 있음: `start <= 오늘 <= end` (범위 포함 → OK)
  - `end_date` 만 있음: `end >= 오늘` → **미래 마감도 포함** (오늘 꼭 할 필요 없음)
  - `start_date` 만 있음: `start <= 오늘` → **시작일이 과거면 전부 포함**
  - 둘 다 없음 + IN_PROGRESS: **무조건 포함**

→ 결과적으로 "진행 중인 거의 모든 태스크" + "오늘 손댄 완료 태스크 전부" 가 카드에 쌓임 (스크린샷 34/35, 37/41, 7/10).

### 홈 화면 `오늘 할 작업` 의 정의

`lib/screens/dashboard_screen.dart:2062-2104`

- **DONE**: `statusHistory` 의 마지막 `done` 전환일 (없으면 `updatedAt`) 이 **오늘** 인 것만
- **IN_PROGRESS / READY**: 동일하게 관대함 (범위/미래 마감 포함)

→ 홈 대시보드도 동일한 관대함을 가지지만, 본인 태스크 1명분이라 눈에 덜 거슬린다.
팀 대시보드에서 멤버 여러 명이 한꺼번에 누적되니 "다 보이는 것 같다" 는 체감.

## 제안: 정의 축소 (`Option A` 권장)

### Option A — "오늘이 핵심"인 태스크만 (권장)

홈/팀 공통으로 적용하거나, 팀 대시보드만 먼저 적용.

**열린 태스크 (IN_PROGRESS / READY / IN_REVIEW)**
  - `start_date` 와 `end_date` 모두 존재 + `start <= 오늘 <= end`
  - 또는 `end_date` 만 존재 + `end == 오늘`
  - 또는 `start_date` 만 존재 + `start == 오늘`
  - 또는 (둘 다 없음 + IN_PROGRESS) — 날짜 미지정 상시 진행 태스크는 계속 포함
  - ❌ 미래 마감만 남은 태스크는 제외
  - ❌ 시작일이 과거인 READY/IN_REVIEW 는 제외

**완료 태스크 (DONE)**
  - 오늘 완료되었고(`statusHistory` 의 `done` 전환일 = 오늘), **그 태스크가 원래 "오늘 할일" 이었던 경우에만** 포함
  - "원래 오늘 할일" = 위 열린-태스크 기준의 날짜 조건이 만족되었던 태스크
    - = `start <= 오늘 <= end`, 또는 `end == 오늘`, 또는 `start == 오늘`, 또는 날짜 둘 다 없음
  - ❌ 과거 마감 태스크를 오늘 소급 정리한 것은 제외

### Option B — "오늘 마감"만

마감일(`end_date`)이 **딱 오늘**인 태스크와, 그 중 오늘 완료된 것만.
가장 엄격. 진행 중인 장기 태스크는 전부 제외됨.

### Option C — 현 정의 유지 + UI 분리만

정의는 안 건드리고, UI 만 "진행 중" / "오늘 완료" 두 섹션으로 분리.
기존처럼 미래 마감도 보이지만 최소한 완료/진행이 시각적으로 나눠짐.

## UI 변경 (공통 — 어떤 옵션이든 적용)

현재: 한 리스트에 섞여 있음 (완료는 아이콘만 초록 체크)
변경: 홈 화면 `TodayTaskRow` 처럼 **완료 태스크는 취소선 + 톤 다운**, 진행 태스크와 섹션 구분

### 카드 내부 ASCII

```
┌───────────────────────────────────────────┐
│ [BY] 정보영                     2/5    [×]│
│      ■■■░░  미니 진행바                   │
├───────────────────────────────────────────┤
│ 오늘 할일 (3)                              │
│   ○ AI 요약 모듈 연동      · 시연앱 · 4/23 │
│   ○ 쿼리 성능 점검          · RAPA   · 4/23│
│   ● STT 화자분리 추가       · STT    · 4/23│  ← ● = 지연
├───────────────────────────────────────────┤
│ 오늘 완료 (2)                              │
│   ✓ ̶0̶4̶/̶2̶4̶ ̶고̶객̶회̶의̶ ̶문̶서̶정̶리̶ ̶· ̶QC    ̶· ̶4̶/̶2̶3̶│  (취소선)
│   ✓ ̶J̶o̶b̶ ̶M̶a̶n̶a̶g̶e̶r̶ ̶로̶그̶       ̶· ̶AI̶ ̶H̶u̶b̶· ̶4̶/̶2̶1̶│
└───────────────────────────────────────────┘
```

- 카드 헤더 카운터는 **열린 태스크 기준** (완료/전체 대신 `완료오늘/오늘할일전체` 로 유지)
- 중간 구분선 + "오늘 완료 (n)" 서브헤더
- 완료 블록이 비면 서브헤더 숨김
- 열린 블록이 비면 "오늘 예정 없음" 플레이스홀더 유지

## 변경 범위

### Option A 채택 시

1. **backend** — `backend/app/routers/workspaces.py`
   - `_is_date_task(t, day_start, day_end)` 를 아래처럼 분기 재정의
     - 열린 태스크: 위 Option A 기준 (미래-only end, 과거-only start 제외)
     - 완료 태스크: `updated_at == 오늘` AND (원래 오늘 할일 조건)
       - 단순 구현: `t.end_date`/`t.start_date` 를 재사용해 "was_today_task" 를 판정 — 완료 시점에 end_date 가 바뀌지 않는다는 전제
   - `get_yesterday_incomplete_tasks` 도 같은 헬퍼를 쓰므로 동일 규칙 적용됨 (의도한 방향과 일치 — 검토 필요)

2. **frontend** — `lib/widgets/workspace/team_today_dashboard.dart`
   - `_buildMemberCard` 의 리스트를 `openTasks` / `doneTasks` 로 분리해 두 섹션 렌더
   - 완료 행은 `TextDecoration.lineThrough` + 알파 0.35 톤으로 통일 (이미 일부 적용됨 — 서브헤더 + 분리만 추가)
   - 카운터: "오늘 할일 (open)" / "오늘 완료 (done)" 각각 표기

3. **frontend (검토)** — 홈 `dashboard_screen.dart` 의 `_buildTodayTasksSection` 도 같은 정의로 맞출지?
   - 지금은 동일한 관대함. 팀 대시보드만 고치면 정의 불일치 발생 → 사용자 결정 필요.

### Option C 채택 시

백엔드 미변경, `team_today_dashboard.dart` 만 수정. 가장 작은 범위.

## 확인 필요 사항

1. **A / B / C 중 어느 방향?** (A 권장)
2. A 채택 시: **홈 대시보드도 동일하게 맞출지**, 팀 대시보드만 적용할지
3. "오늘 마감만"(B)을 원하신다면, 날짜 없이 IN_PROGRESS 상태인 태스크는 **아예 표시 안 함**이 맞는지
4. 완료 섹션 표기를 "오늘 완료" vs "완료" vs 서브헤더 없이 아이콘+취소선만 — 선호는?

## 작업 결과

- [x] 사용자 옵션 결정 수신 — **Option A**
- [x] 백엔드 `_is_date_task` 개정 (Option A)
  - `_scheduled_for_day` 헬퍼 분리, start/end 조합별 엄격 판정
  - 열린 태스크: 날짜 있으면 조건 부합 시에만 / 날짜 없으면 IN_PROGRESS 만 포함
  - 완료 태스크: `updated_at` 이 오늘 + (원래 해당 날짜의 할일이었던 경우만)
- [x] `team_today_dashboard.dart` 섹션 분리
  - `openTasks` / `doneTasks` 로 나눠 두 섹션 렌더
  - 각 섹션에 `오늘 할일 (n)` / `오늘 완료 (n)` 서브헤더 + 색상 태그
  - `overdueCount` 산출을 열린 태스크 기준으로 조정 (완료된 지연은 지연 아님)
- [x] 홈 `dashboard_screen.dart` 동기화 — **하지 않음** (사용자가 기준점으로 언급한 화면)
- [x] 정적 분석 확인
  - `flutter analyze lib/widgets/workspace/team_today_dashboard.dart` → No issues found
  - `python -m py_compile backend/app/routers/workspaces.py` → OK

## 참고

- 스크린샷 기준 카드 1개당 30+건 → A 적용 시 통상 5~10건으로 줄어들 것으로 예상
- 정렬: 열린 블록은 지연 → 보통 / 우선순위 내림차순, 완료 블록은 `updatedAt` 역순

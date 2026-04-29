# 활동 히트맵 + 프로젝트 작업량 그래프 + 워크스페이스 프로젝트 분포 통계 추가

| 속성 | 값 |
|------|-----|
| 유형 | feat |
| 영역 | backend/routers, frontend/screens, frontend/widgets/workspace, frontend/widgets/project_info |
| 날짜 | 2026-04-27 |
| 상태 | 진행중 |
| 관련 | workspaces (router), workspace_member_stats_screen, project_info/overview_tab, main_layout |

## 요청 내용 (3건)

1. **팀 현황 → "멤버" 로 명칭 변경** + GitHub 스타일 **Contribution heatmap** 위젯 추가
2. **프로젝트 화면(개요 탭)** 에 시간 흐름에 따른 작업량 그래프 추가 — GitHub 의 repo activity 그래프와 유사
3. **워크스페이스 단위로 프로젝트별 작업량 분포** 통계 — 어디 프로젝트에 작업이 몰려있는지 한눈에

> ⚠ 모든 "작업" 은 **본 프로젝트 내부의 Task 단위** 이며, GitHub 커밋/리뷰/이슈가 아님.
> "활동(Activity)" 정의: 한 사용자의 하루 활동량 = (그 날 생성한 Task 수) + (그 날 상태를 done 으로 바꾼 Task 수) + (그 날 작성한 Comment 수)

## (1) 멤버 메뉴 + Contribution heatmap

### 명칭 변경

`팀 현황` → **`멤버`** 로 변경:
- `lib/screens/main_layout.dart:146`, `:1010`, `:2869`, `:2912` 의 `'팀 현황'` 문자열 일괄 변경
- `lib/screens/workspace_member_stats_screen.dart:98` AppBar 타이틀: `'${ws.name} 팀 현황'` → `'${ws.name} 멤버'`

### Heatmap 위젯 추가

화면: 기존 `WorkspaceMemberStatsScreen` 의 "대시보드" / "상세보기" 토글 옆에 **`히트맵`** 토글 추가.
또는 **대시보드 화면 상단에 컴팩트하게 항상 표시** 도 옵션 — 둘 중 어느 쪽이 좋은지 사용자 의견 필요.

#### Heatmap 사양

- 가로축: 최근 12주 × 7일 = **84칸** (좌→우 시간 순)
- 세로축: 워크스페이스 멤버
- 셀 색상: 활동량에 따라 5단계 (`Less` → `More`)
  - 0건: 배경색 (`outlineVariant.withValues(alpha: 0.15)`)
  - 1~3: accent.withValues(alpha: 0.25)
  - 4~7: accent.withValues(alpha: 0.45)
  - 8~14: accent.withValues(alpha: 0.65)
  - 15+: accent (full)
  - 임계값은 **워크스페이스 전체의 일별 max 기준 quantile** 로 동적 산정 (단순 고정값보다 분포 표현이 정확)
- 우측에 멤버별 합계 숫자 표시
- 셀 hover → 툴팁 `2026-03-15 (월) · 7건 (생성 3 / 완료 2 / 댓글 2)`

```
┌──────────────────────────────────────────────────────────────────────┐
│ Contribution heatmap                                Less ░░▒▓█ More │
│ Last 12 weeks · 작업 생성 + 완료 + 댓글                               │
├──────────────────────────────────────────────────────────────────────┤
│ 박보영   ░░▓░░▒▒░░░█░░▓░░░▒░░░░░▒▒░░▒░░░░░▒░░░░░▓▒░░░▒░░░░░▒░░░  218 │
│ 김도현   ▒░▓▒▓░░░░▒░▓░▒░▒▓░░░▒░░▒░▒░░▒░░░░▒▓░░▒▒░░▒░░░▒▒░░░░░▒█  322 │
│ 이시윤   ░░▒░░░░▒░░░░▓░░░░░▒░░░░░░▒░░░░░░░▓▒░░░▒░░░░░░░░▒░░░░░░  108 │
│ 정유진   ░▓▓▒░▒░▒░▒░▒▓░▒░░▒░░░░░▒░░▓▒░░░░▓░░░░░▒░▒░▒░░▒░▒░▒░░░  256 │
│ 최긴석   ░░▒░░░░░░░░░▓░░░░░░░░░▒░░▒░░░░░░░░▒░░░░░▒▒░░░░░░░░░░░  152 │
└──────────────────────────────────────────────────────────────────────┘
```

#### 백엔드 신규 엔드포인트

`GET /api/workspaces/{workspace_id}/activity-heatmap?weeks=12`

응답 (예시):
```json
{
  "from_date": "2026-02-02",
  "to_date": "2026-04-26",
  "members": [
    {
      "user_id": "...",
      "username": "박보영",
      "total": 218,
      "daily": [{ "date": "2026-02-02", "count": 0 },
                { "date": "2026-02-03", "count": 3 }, ...]
    }, ...
  ]
}
```

집계 로직:
- 워크스페이스의 모든 프로젝트의 `Task` 와 `Comment` 를 조회
- 멤버별 / 일자별로:
  - `tasks` 의 `creator_id == userId` AND `created_at::date` 카운트
  - `tasks` 의 `status_history` JSON 에서 `toStatus == "done" AND userId == 멤버 AND changedAt::date` 카운트
  - `comments` 의 `user_id == userId` AND `created_at::date` 카운트
- 합계로 daily count
- 12주 전체 일자에 대해 0 포함 모든 날짜 반환 (frontend 처리 단순화)

성능: status_history 가 JSON 이라 PostgreSQL JSONB 가 아니면 풀스캔. 워크스페이스 단위 가산이라 N(task) 가 수만 단위 미만이면 무리 없음. `created_at` 인덱스는 이미 있음. 필요 시 `EXPLAIN ANALYZE` 로 확인 후 개선 — 1차는 in-memory aggregation 으로 단순 처리.

## (2) 프로젝트 작업량 그래프 (개요 탭)

### 위치

`lib/screens/project_info/overview_tab.dart` 하단에 신규 카드 추가.
기존 4개 지표 카드 + 진척도 + 데드라인 + 팀 + 생산성 위젯 아래.

### 형태 — Sparkline + 누적 막대

GitHub repo Insights 의 "Code frequency" 처럼:
- **2단 표시**:
  - 상단: 일별 작업 생성 수 (line chart)
  - 하단: 일별 작업 완료 수 (영역/막대)
- 기간: 기본 12주, 토글로 4주 / 12주 / 24주 변경

```
┌─ 작업량 추이 (최근 12주) ────────────────  [4주 12주 24주] ─┐
│                                                              │
│  생성    ╱╲   ╱╲    ╱╲╱╲                                    │
│        ╱   ╲ ╱  ╲  ╱     ╲                                  │
│  ────╱─────╳────╲╱──────╲╱────                              │
│                                                              │
│  완료   ▁▁▁▂▂▃▃▄▅▆▇▆▅▄▃▂▂▁                                  │
│                                                              │
│  Apr 1            Apr 15           May 1                     │
└──────────────────────────────────────────────────────────────┘
```

### 백엔드 신규 엔드포인트

`GET /api/projects/{project_id}/activity?weeks=12`

응답:
```json
{
  "from_date": "2026-02-02",
  "to_date": "2026-04-26",
  "daily": [
    { "date": "2026-02-02", "created": 0, "done": 0 },
    { "date": "2026-02-03", "created": 2, "done": 1 }, ...
  ]
}
```

- `created`: `tasks.created_at::date` 카운트
- `done`: `status_history` 의 `toStatus == "done"` 의 `changedAt::date` 카운트

### 차트 패키지

- 의존성 검토: `fl_chart` (이미 있는지 확인 필요). 없으면 `pubspec.yaml` 에 추가.
- 라인/막대 모두 지원해야 하므로 `fl_chart` 가 적합. 라이센스 BSD-3-Clause.

## (3) 워크스페이스 프로젝트별 작업량 분포

### 위치 추천

기존 `WorkspaceMemberStatsScreen` 안에 **세 번째 토글 `프로젝트 분포`** 추가.
- 현재 토글: 대시보드 / 상세보기
- 변경 후: 대시보드 / 상세보기 / **프로젝트 분포** / 히트맵 (총 4개)

이유:
- "멤버" 메뉴는 곧 워크스페이스 활동 통계의 자연스러운 진입점
- 별도 메뉴 신설은 사이드바 항목이 너무 많아짐
- 대시보드 통계군과 의미가 가까움

대안: 새 사이드바 메뉴 `통계` 신설. — 사용자 선호 의견 필요.

### 형태

```
┌─ 프로젝트별 작업량 (최근 4주) ──────────────────────────────┐
│                                                              │
│  DORA              ████████████████████████████  62%  186건 │
│  Sync v2           █████████████  21%  62건                  │
│  Mattermost-bot    █████  9%  28건                           │
│  legacy-migration  ███  5%  14건                             │
│  기타 (3건 미만)   █  2%  8건                                │
│                                                              │
│  총합: 298건                                                 │
└──────────────────────────────────────────────────────────────┘
```

- 프로젝트별 가로 막대(bar chart) — 길이 = 비율
- 정렬: 작업량 내림차순
- 멤버 차원 break-down 은 v2 (이번 작업 안 함)

### 백엔드 신규 엔드포인트

`GET /api/workspaces/{workspace_id}/project-distribution?weeks=4`

응답:
```json
{
  "from_date": "2026-03-30",
  "to_date": "2026-04-26",
  "total": 298,
  "projects": [
    { "project_id": "...", "name": "DORA", "count": 186, "percent": 62.4 },
    ...
  ]
}
```

- 분자: 해당 기간 내 `tasks.created_at` + `status_history(done)` + `comments.created_at` 합계 (멤버 무관)

## 파일 분리 계획

신규 파일:
- `lib/widgets/workspace/contribution_heatmap.dart` — 히트맵 위젯
- `lib/widgets/workspace/project_distribution.dart` — 프로젝트 분포 막대
- `lib/widgets/project_info/project_activity_chart.dart` — 프로젝트 활동 라인+막대 차트
- `lib/services/workspace_activity_service.dart` — 3종 API 호출 통합 서비스 (또는 기존 `workspace_service.dart` 에 메서드 추가)

수정 파일:
- `backend/app/routers/workspaces.py` — heatmap, project-distribution 엔드포인트 신설
- `backend/app/routers/projects.py` — activity 엔드포인트 신설
- `lib/screens/main_layout.dart` — 메뉴 라벨 `팀 현황` → `멤버` 4곳
- `lib/screens/workspace_member_stats_screen.dart` — AppBar 타이틀 변경 + 토글 4개로 확장 + 신규 위젯 결합
- `lib/screens/project_info/overview_tab.dart` — 활동 차트 카드 추가
- `pubspec.yaml` — `fl_chart` 추가 (있는지 확인 후)

## 작업 결과 (체크리스트)

- [ ] 백엔드 — 3종 신규 엔드포인트 + 권한 검증 + 인덱스 확인
- [ ] 프론트 — `fl_chart` 의존성 추가 (필요 시)
- [ ] `lib/widgets/workspace/contribution_heatmap.dart`
- [ ] `lib/widgets/workspace/project_distribution.dart`
- [ ] `lib/widgets/project_info/project_activity_chart.dart`
- [ ] `WorkspaceService` (또는 신규 service) 메서드 추가
- [ ] 메뉴 라벨 일괄 변경 (`팀 현황` → `멤버`)
- [ ] `WorkspaceMemberStatsScreen` 토글 확장 + 위젯 결합
- [ ] `OverviewTab` 활동 차트 카드 추가
- [ ] `flutter analyze` 통과
- [ ] frontend-only? both? 배포 (백엔드 변경 있으므로 **both**)
- [ ] 수동 검증 (시나리오 별도)

## 분석 (성능 / 권한 등)

### 성능
- Heatmap 집계: O(N(task) + N(comment)) 워크스페이스 단위. 인덱스 활용으로 SELECT 는 빠르나 in-memory 집계가 핵심. N <10K 까지 ms 단위.
- 프로젝트 활동: O(N(task) + N(comment)) per project. 단일 프로젝트라 더 가볍다.
- status_history 가 JSON 이라 인덱싱 안 됨 → 모든 task 의 status_history 풀로드 후 파이썬에서 필터. 워크스페이스에 task 수십만 건 누적되면 느려질 수 있음 — 1차는 OK, 추후 status_change_logs 별도 테이블로 정규화 검토.

### 권한
- 모든 신규 엔드포인트에 `get_current_user` + 워크스페이스 멤버 검증 (admin 예외)
- 프로젝트 activity 는 추가로 프로젝트 access 확인 (기존 패턴 재사용)

### DB 마이그레이션
- 신규 테이블/컬럼 없음 → `ensure_*` 추가 불필요

## 사용자 결정 (2026-04-27)

1. **Heatmap 진입점**: **(b) 멤버 대시보드 상단에 항상 표시** — 토글 없이 대시보드 진입 시 바로 보임
2. **프로젝트 분포 위치**: **(a) 멤버 화면의 새 토글** — 기존 `대시보드 / 상세보기` 와 함께 `프로젝트 분포` 토글 추가
3. **차트 라이브러리**: `fl_chart` 확정
4. **활동 정의 — 작업 카드 단위**:
   - 한 (멤버 × 일자) 에 대한 활동 = 그 날 그 멤버가 **건드린 distinct Task 카드 수**
   - "건드린" 의 정의: (그 날 생성) ∪ (그 날 done 으로 상태 변경) ∪ (그 날 코멘트 작성) — 한 카드에서 여러 행동이 같은 날 일어나도 **1로 카운트**
   - 프로젝트 활동 차트도 동일: 각 일자에 대해 "그 날 활동이 있었던 distinct Task 카드 수"
   - 프로젝트 분포: 기간 내 활동이 있었던 distinct Task 카드 수, 프로젝트별 합계

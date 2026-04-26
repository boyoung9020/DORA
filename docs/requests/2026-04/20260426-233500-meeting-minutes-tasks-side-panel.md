# 회의록에서 생성된 작업 현황판 사이드 패널 추가

| 속성 | 값 |
|------|-----|
| 유형 | feat |
| 영역 | frontend/screens, frontend/widgets/meeting_minutes |
| 날짜 | 2026-04-26 |
| 상태 | 제안중 |
| 관련 | meeting_minutes_screen, expandable_side_panel |

## 요청 내용

회의록에서 생성된 작업들을 한눈에 볼 수 있는 **현황판** 을 사이드 패널로 추가.
현재 회의록에 연결된 모든 태스크의 다음 정보를 카드 형태로 표시:
- 작업 제목
- 진행 상태 (Backlog / Ready / In Progress / In Review / Done)
- 우선순위 (P0~P3)
- 소속 프로젝트
- 담당자 (아바타)
- 시작/마감 기간

## 구현 방향 (제안)

### 트리거 — 뷰어 헤더 우측에 토글 버튼

회의록 뷰어 상단의 "편집/삭제" 아이콘 옆에 **`[📋 작업 N]`** 버튼을 추가.
N 은 현재 회의록에 연결된 태스크 개수 (`_lineTaskMap.length`).
0 건이면 버튼 비활성/회색.

### 패널 — 기존 `showExpandableSidePanel` 오버레이 재사용

`lib/widgets/expandable_side_panel.dart` 의 슬라이드인 오버레이를 그대로 사용
(대시보드 "오늘 할 작업"·"최근 활동" 패널과 동일한 패턴).

장점:
- 본문 읽기 영역을 영구적으로 좁히지 않음
- 닫기 동작/애니메이션/사이즈 정책이 이미 정립되어 일관성 유지
- 신규 추가 코드 최소화

### 패널 본문 구성 (테이블 뷰 — Notion 스타일 레퍼런스)

```
┌──────────────────────────────────────────────────────────────┐
│ 📋 작업 현황 (5)                                        [✕]  │
│ 2026-04-26 주간 정례 미팅                                    │
├──────────────────────────────────────────────────────────────┤
│  Aa Title                ⚙ Status    📁 Project   👤 Owner  │ ← 컬럼 헤더 (얇은 회색)
│ ────────────────────────────────────────────────────────────│
│  ● 이슈 트래킹 시스템    ● 진행중    DORA          정보영   │
│  ● Mattermost Webhook    ○ 대기      DORA          박지훈   │
│  ✓ 회의록 줄 마커 UI     ● 완료      DORA          정보영   │ ← 완료는 strikethrough
│  ● 회의록 검색           ● 리뷰      DORA          김민수   │
│  ● 알림 시스템 개선      ● 백로그    DORA          박지훈   │
└──────────────────────────────────────────────────────────────┘
```

#### 컬럼 정의 (총 4컬럼)

| 컬럼 | 너비 | 내용 |
|---|---|---|
| **Title** | flex | `우선순위 점` + 작업 제목. 완료는 strikethrough + 회색. 좌측 점 색상 = `task.priority.color` (P0=빨강, P1=주황, P2=파랑, P3=회색) |
| **Status** | ~80px | `상태 점` + 텍스트. 색상 = `task.status.color`. (진행중=주황, 완료=초록, 리뷰=파랑, 대기=회색, 백로그=보라) |
| **Project** | ~80px | 프로젝트 이름. 길면 ellipsis. |
| **Owner** | ~70px | 첫 담당자 이름. 2명 이상이면 `정보영 +1` |

#### 행 동작

- 호버: 행 배경 살짝 강조 (`colorScheme.surfaceContainerHigh`)
- 탭: `TaskDetailScreen` 다이얼로그 오픈 (`showGeneralDialog`)
- 정렬: **회의록 줄 등장 순서** (기본). 1차 범위에서는 컬럼 정렬 토글 미지원 — 추후 확장 여지

#### 비어있을 때

```
┌──────────────────────────────┐
│ 📋 작업 현황 (0)        [✕]  │
├──────────────────────────────┤
│                              │
│         📭                   │
│                              │
│   생성된 작업이 없습니다     │
│                              │
│   본문 줄 끝의 ➕ 아이콘을   │
│   눌러 작업을 추가하세요     │
│                              │
└──────────────────────────────┘
```

#### 너비별 동작 (420 ~ 600px)

- 좁을 때 (420): 컬럼 너비 압축, Project/Owner 가 우선 truncate
- 넓을 때 (600): 컬럼 사이 공간 여유로 가독성 향상

### 화면 통합 다이어그램

```
┌────────┬───────────────────────────────────┐
│ 회의록 │ 회의록 본문 (뷰어)                │
│ 목록   │ ┌─────────────────────────────┐  │
│ 320px  │ │ 제목     [✏][🗑][📋 작업 5] │  │
│        │ │ 날짜·작성자·참석자          │  │
│        │ ├─────────────────────────────┤  │
│        │ │                             │  │
│        │ │ • 본문 줄 1 (✓)             │  │
│        │ │ • 본문 줄 2                 │  │
│        │ │ • 본문 줄 3 (✓)             │  │
│        │ │ ...                         │  │
│        │ └─────────────────────────────┘  │
└────────┴───────────────────────────────────┘
                                     ┌──────┐
                                  ←  │ 패널 │  슬라이드인
                                     │      │
                                     └──────┘
```

## 파일 분리 (300 라인 룰 준수)

신규 파일:

- `lib/widgets/meeting_minutes/meeting_tasks_panel.dart`
  - `MeetingTasksPanel` 위젯 — 패널 본문
  - 컬럼 헤더 + 테이블 형태의 ListView (정렬: 회의록 줄 등장 순서)
  - 비어있을 때 placeholder 처리
- `lib/widgets/meeting_minutes/meeting_task_table_row.dart`
  - `MeetingTaskTableRow` 위젯 — 단일 행
  - 4컬럼 (Title / Status / Project / Owner) + 우선순위 점 + 호버 배경 강조 + 탭 → `TaskDetailScreen`

수정 파일:

- `lib/screens/meeting_minutes_screen.dart`
  - 뷰어 헤더에 "작업 N" 토글 버튼 추가 (line 1671 근처)
  - 신규 메서드 `_openMeetingTasksSidePanel(...)` — `showExpandableSidePanel` 호출
  - 변경 폭 작음 (~50 라인 추가) — 파일 분리 압박 없음

## 데이터 소스

이미 보유한 자원만 사용 — 신규 API 호출 0:

| 데이터 | 출처 |
|---|---|
| 태스크 목록 | `_lineTaskMap.values` (이미 로드됨) |
| 프로젝트명 | `context.read<ProjectProvider>().projects` Map 으로 변환 후 lookup |
| 담당자 정보 | `context.read<WorkspaceProvider>().currentMembers` 기반 |
| 회의록 줄 순서 | `_selectedMinutes!.content` 의 `<!--mm:lineId-->` 마커 등장 순서 |

## 인터랙션 — 패널 열려있는 동안 태스크가 변경되면?

기존 `showExpandableSidePanel` 은 정적 스냅샷이므로 패널이 열린 상태에서 태스크 상태가 바뀌어도 자동 반영되지 않음.
**1차 구현 범위**: 패널 본문에서도 `Consumer<TaskProvider>` 로 구독 → 다른 화면에서 상태가 바뀌면 패널도 반응.
단, 회의록에 새 작업이 추가되거나 기존 작업이 삭제되어 `_lineTaskMap` 자체가 바뀌면 패널을 한 번 닫고 다시 열어야 반영됨 (overlay 라이프사이클 한계).
이 한계는 사용자가 거의 만나지 않는 케이스 (보통 패널 열기 → 빠르게 보기 → 닫기) 라고 판단해 추가 작업 없이 진행.

## 작업 결과 (체크리스트)

- [ ] `lib/widgets/meeting_minutes/meeting_task_row.dart` 신설
- [ ] `lib/widgets/meeting_minutes/meeting_tasks_panel.dart` 신설
- [ ] `meeting_minutes_screen.dart` 뷰어 헤더에 "작업 N" 토글 버튼 추가
- [ ] `meeting_minutes_screen.dart` 에 `_openMeetingTasksSidePanel` 메서드 추가 + 클릭 핸들러 연결
- [ ] `flutter analyze` 통과 확인
- [ ] 수동 검증:
  1. 회의록 진입 → 헤더에 "작업 N" 버튼 표시 (N=실제 연결 수)
  2. 클릭 → 우측 슬라이드인 패널 표시
  3. 카드 클릭 → 태스크 상세 다이얼로그 오픈
  4. 통계 카운트가 실제 상태별 개수와 일치하는지
  5. 태스크 0건일 때 비어있다는 안내 표시

## 참고 사항

- 기존 `TodayTaskRow` 는 너무 미니멀 (체크박스 + 우선순위 + 제목만) — 본 화면용으로 별도 행 위젯 신설이 더 깔끔
- 위젯 파일 위치는 `lib/widgets/meeting_minutes/` 신규 폴더 — 추후 회의록 관련 재사용 위젯이 늘어나도 동일 폴더에 모임
- 백엔드 변경 없음 — 신규 API/스키마 작업 전무

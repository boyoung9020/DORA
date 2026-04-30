# 홈 화면 "기한 초과" 섹션에서 backlog 작업 제외

| 속성 | 값 |
|------|-----|
| 유형 | fix |
| 영역 | frontend/screens |
| 날짜 | 2026-04-30 |
| 상태 | done |
| 관련 | dashboard_screen |

## 요청 내용

홈 화면 사이드의 "기한 초과" 섹션에 backlog(착수 전) 상태인 작업도 표시되고 있음. backlog 는 아직 시작 안 한 상태라 "기한 초과" 의미와 맞지 않으므로 제외.

## 배경

[`dashboard_screen.dart:915-922`](../../../lib/screens/dashboard_screen.dart#L915-L922) 의 `overdueTasks` 필터가 `done` 만 제외하고 `backlog` 는 통과시킴. 같은 날 적용한 [프로젝트 개요 마감 임박 작업 backlog 제외](20260430-104338-project-overview-urgent-task-criteria.md) 와 동일한 의미 일관성 적용.

## 변경 내용

`dashboard_screen.dart` 의 `_buildOverdueTasksSection` 내부 필터에 `backlog` 제외 한 줄 추가:

```dart
if (t.status == TaskStatus.backlog) return false; // 착수 전이라 기한 초과 의미 없음
```

## 작업 결과

- [x] 홈 화면 기한 초과 섹션 필터에서 backlog 제외
- [x] `flutter analyze lib/screens/dashboard_screen.dart` → 기존 info-level 4건 외 신규 이슈 없음

## 분석

- **Root cause**: 홈 기한 초과 필터가 `done` 만 제외하고 다른 상태(`backlog` 포함)는 모두 통과시켰음.
- **Change**: backlog 제외 한 줄 추가.
- **Recurrence prevention**: 동일 의미("아직 착수 안 한 작업은 임박/초과 표시 X") 가 프로젝트 개요 마감 임박 섹션에도 같은 날 일관 적용되어 있음.
- **Verification**: `flutter analyze` 통과 (변경으로 신규 이슈 없음).
- **Remaining risk**: 작업 테이블의 'overdue' 날짜 필터 칩(`dashboard_screen.dart:268-269`) 은 의도가 다르므로 그대로 둠. 향후 이쪽도 backlog 제외 요청이 들어오면 추가 변경 필요.

## 참고 사항

- 이 변경은 frontend-only — Nginx 만 재기동하면 즉시 반영

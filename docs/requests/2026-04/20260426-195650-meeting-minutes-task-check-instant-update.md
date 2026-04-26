# 회의록에서 작업 추가 시 체크 표시가 즉시 반영되지 않는 버그 수정

| 속성 | 값 |
|------|-----|
| 유형 | fix |
| 영역 | frontend/screens |
| 날짜 | 2026-04-26 |
| 상태 | done |
| 관련 | meeting_minutes_screen |

## 요청 내용

회의록 화면에서 줄별 "작업 추가" 다이얼로그로 태스크를 만들면 서버 등록은 정상이지만, 새로고침을 하기 전까지는 해당 줄에 체크 마커(✓)가 표시되지 않는 문제를 즉시 반영되도록 수정.

## 분석 (Root cause)

`_createTaskFromLine` 의 다이얼로그가 `StatefulBuilder(builder: (context, setState) { ... })` 패턴으로 구성되어 있다. StatefulBuilder 의 `setState` 매개변수가 부모 State(`_MeetingMinutesScreenState`) 의 `setState` 를 **이름으로 가린다(shadowing)**.

따라서 다이얼로그 안의 "추가" 버튼 핸들러에서 다음 두 호출이:

```dart
setState(() => _selectedMinutes = updated);
setState(() { _lineTaskMap = {..._lineTaskMap, lineId: createdTask}; });
```

부모 State 필드(`_selectedMinutes`, `_lineTaskMap`) 값은 정상 갱신되지만, **StatefulBuilder 만 rebuild 되고 부모 회의록 뷰어는 rebuild 되지 않는다**. 결과적으로 본문 ListView 가 `_lineTaskMap` 의 새 항목을 읽어가지 않아 체크 마커가 보이지 않다가, 사용자가 새로고침으로 부모를 재진입해야 보이는 증상.

## Change

`_createTaskFromLine` 다이얼로그의 "추가" 버튼 핸들러에서 부모 State 필드를 갱신하는 두 호출을 `this.setState(...)` 로 바꿔 shadow 를 우회.

- `lib/screens/meeting_minutes_screen.dart`
  - `setState(() => _selectedMinutes = updated)` → `this.setState(() => _selectedMinutes = updated)`
  - `setState(() { _lineTaskMap = ... })` → `this.setState(() { _lineTaskMap = ... })`

다이얼로그 로컬 UI 상태(프로젝트/상태/우선순위/사이트 드롭다운 등) 의 `setState` 들은 **그대로 유지** — 그 변수들은 StatefulBuilder 빌더 안의 지역 변수이므로 다이얼로그 setState 가 맞다.

## Recurrence prevention

- 향후 다이얼로그(`StatefulBuilder` 사용) 안에서 부모 State 필드를 직접 변경할 때는 `this.setState` 로 명시할 것 — 이름 shadow 함정 회피.
- 더 안전한 패턴: 다이얼로그는 결과만 반환(`Navigator.pop(result)`)하고, 부모 State 갱신은 `await showDialog` 직후 부모 메서드에서 처리. 이번 수정은 변경 범위 최소화를 위해 in-place fix 만 적용.

## Verification

- `flutter analyze lib/screens/meeting_minutes_screen.dart` — 신규 경고 없음 (기존 `deprecated_member_use` 2건은 그대로)
- 수동 검증 권장:
  1. 회의록 진입 → 임의 줄 호버 → "작업 추가" 클릭 → 폼 입력 → "추가"
  2. 다이얼로그 닫힘 즉시 해당 줄에 ✓ 마커가 표시되는지 확인 (새로고침 불필요)
  3. 마커 클릭 → 태스크 상세 다이얼로그가 열리는지 확인

## Remaining risk

- 줄 마커 삽입 API(`_service.update`) 실패 시에는 기존과 동일하게 SnackBar 안내만 후 다음 로드에서 재시도되는 흐름. 이 경로는 이번 수정과 무관.
- `this.setState` 는 Dart 의 정상적 인스턴스 멤버 호출 — 컴파일 통과 확인됨.

## 작업 결과

- [x] `_createTaskFromLine` 의 부모 state 갱신 두 곳을 `this.setState` 로 변경
- [x] `flutter analyze` 통과 확인
- [ ] 운영 배포 — 사용자 지시 시 진행

## 참고 사항

- 변경 파일: `lib/screens/meeting_minutes_screen.dart` 1개
- 인덱스 갱신 필요 (`docs/requests/2026-04/INDEX.md`)

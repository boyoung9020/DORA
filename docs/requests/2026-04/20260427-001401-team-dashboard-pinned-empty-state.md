# 팀 현황 대시보드 — 핀 멤버 "빈 set" 저장 시 자동 리셋되는 버그 수정

| 속성 | 값 |
|------|-----|
| 유형 | fix |
| 영역 | frontend/widgets/workspace |
| 날짜 | 2026-04-27 |
| 상태 | done |
| 관련 | team_today_dashboard |

## 요청 내용

팀 현황 대시보드에서 표시할 팀원을 줄여놨는데도 **다음 진입(또는 새로고침/배포 후) 시 다시 전체 팀원이 보이는** 문제 수정.

## 분석 (Root cause)

`_loadPinned()` 의 분기 조건이 `saved.isNotEmpty` 였다:

```dart
if (saved != null && saved.isNotEmpty) {     // ← 빈 list 도 "저장 안 됨" 으로 처리됨
  _pinnedUserIds = saved.toSet();
} else {
  _pinnedUserIds = widget.allMembers.map((m) => m.userId).toSet();  // 전체 리셋
}
```

`SharedPreferences.setStringList(key, <empty list>)` 는 빈 list 를 그대로 보존하므로,
- 사용자가 "전체 해제" 버튼을 눌렀거나
- 멤버를 하나씩 모두 해제해 0명이 되었을 때

`_savePinned()` 가 `[]` 를 저장한다. 그러나 다음 로드에서 `isNotEmpty == false` 분기에 걸려 **저장된 사용자 의도를 무시하고 전체 멤버로 자동 복원**됐다. 사용자 관점에선 "줄였는데 시간 지나면 다시 다 보임" 처럼 느껴짐.

배포와의 직접적 인과는 없지만, 배포 후 페이지 새로고침이 동반되면서 **새로고침 = 전체 복원** 패턴이 두드러져 보임.

## Change

`lib/widgets/workspace/team_today_dashboard.dart` `_loadPinned()`

```dart
- if (saved != null && saved.isNotEmpty) {
+ if (saved != null) {
    _pinnedUserIds = saved.toSet();
  } else {
    _pinnedUserIds = widget.allMembers.map((m) => m.userId).toSet();
  }
```

- `saved == null` (한 번도 저장한 적 없음) → 전체 멤버로 초기화 (기존 동작)
- `saved == []` (사용자가 명시적으로 비움) → **빈 set 그대로 존중** (변경)
- `saved == [...]` (subset) → 그대로 복원 (기존 동작)

## Recurrence prevention

- 의도 전달용 코멘트를 메서드에 추가 — null vs 빈 list vs subset 의 의미를 명시
- 향후 비슷한 "subset 선택 + 영구 저장" 패턴 구현 시 동일 함정 회피

## Verification

- 수동 검증 시나리오:
  1. 팀 현황 대시보드 진입 → 멤버 관리에서 일부 해제 (예: 6명 → 3명) → 새로고침 → 3명 유지 ✓ (기존에도 동작)
  2. 멤버 관리 → "전체 해제" 클릭 → 새로고침 → 0명 유지 ✓ (수정 전: 6명으로 자동 복원되던 버그)
  3. 0명 상태에서 멤버 관리 다이얼로그 열어 일부 다시 핀 → 새로고침 → 핀한 멤버만 유지 ✓
  4. 처음 워크스페이스 진입한 신규 유저 → 전체 멤버 자동 핀 (기본값, 기존과 동일)

## Remaining risk

- 기존에 `[]` 가 저장되어 있던 사용자는 이번 배포 후부터 빈 화면을 보게 됨 (수정 전엔 자동 복원되었음). 이는 "사용자가 의도적으로 비웠던 상태" 를 그대로 존중하는 것이므로 정상 동작이며, 멤버 관리 다이얼로그의 "전체 선택" 으로 즉시 복원 가능.

## 작업 결과

- [x] `_loadPinned()` 분기 조건 수정 + 코멘트 추가
- [x] 운영 배포 — 사용자 검증 대기

## 참고 사항

- 변경 파일: `lib/widgets/workspace/team_today_dashboard.dart` 1개
- 별도 마이그레이션/스키마 변경 없음
- 인덱스 갱신 (`docs/requests/2026-04/INDEX.md`)

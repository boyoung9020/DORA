# 팀 현황 대시보드 핀 멤버 카드를 가변 중앙 정렬로 변경

| 속성 | 값 |
|------|-----|
| 유형 | ui |
| 영역 | frontend/widgets/workspace |
| 날짜 | 2026-04-30 |
| 상태 | done |
| 관련 | team_today_dashboard |

## 요청 내용

AI팀 멤버 대시보드에서 선택된 멤버 카드들이 항상 좌측에 붙어 우측 공간이 비는 문제. 선택된 멤버 수에 따라 가변적으로 **가운데 정렬**되도록 변경.

## 배경

[`team_today_dashboard.dart:631-661`](../../../lib/widgets/workspace/team_today_dashboard.dart#L631-L661) 의 `_buildGrid` 가 `SliverGridDelegateWithFixedCrossAxisCount` (폭에 따라 1~5 고정 칸) 사용 중. 핀 멤버가 칸 수보다 적으면 좌측 칸들만 채워져 좌측 정렬처럼 보임 (스크린샷: 1500px 폭 → 5칸 슬롯, 멤버 3명 → 좌측 3칸).

## 변경 내용

`_buildGrid` 를 `GridView` → `SingleChildScrollView + Wrap(alignment: center)` 로 교체:

- `crossAxisCount` 결정 로직(기존 폭 임계값) 그대로 유지
- 카드 폭은 **항상 `crossAxisCount` 기준**으로 계산 → 멤버 수가 줄어도 카드가 부풀지 않음
- 카드 높이 = `cardWidth / 0.85` (기존 `childAspectRatio` 동일)
- `Wrap.alignment = WrapAlignment.center` → 카드가 한 줄에 다 안 들어가면 다음 줄로 흘러가고, 마지막 줄(또는 한 줄)이 비어 있으면 가운데 정렬
- 스크롤은 `SingleChildScrollView` 로 보존

```dart
return SingleChildScrollView(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
  child: Wrap(
    alignment: WrapAlignment.center,
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final m in members)
        SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: _buildMemberCard(context, m),
        ),
    ],
  ),
);
```

## 작업 결과

- [x] `_buildGrid` 를 Wrap + center alignment 로 교체
- [x] 카드 폭은 `crossAxisCount` 기준 고정 (멤버 수와 무관)
- [x] `flutter analyze lib/widgets/workspace/team_today_dashboard.dart` → No issues

## 참고 사항

- `crossAxisCount` 임계값 자체는 그대로 (1400/1100/800/520) — 카드 폭 일관성 위해 동일 룰 사용
- 핀이 한 명도 없을 때의 빈 상태는 별도 분기 (`_buildEmptyState`) 로 이미 처리되어 있어 영향 없음

# 프로젝트 개요 "마감 임박 작업" 기준을 end_date 2일 이내로 좁힘

| 속성 | 값 |
|------|-----|
| 유형 | fix |
| 영역 | frontend/widgets/project_info |
| 날짜 | 2026-04-30 |
| 상태 | done |
| 관련 | description_tasks_widget |

## 요청 내용

프로젝트 정보 → 개요 탭의 "마감 임박 작업" 섹션이 종료일이 없는 작업까지 임박 작업으로 노출하고 있다. **`end_date` 가 있고 오늘로부터 2일 이내 마감(오늘 포함, 이미 지난 미완료 포함)** 인 작업만 임박으로 표시.

## 배경

- 현행 [`description_tasks_widget.dart:32-40`](../../../lib/widgets/project_info/description_tasks_widget.dart#L32-L40) 은 `status != done` 인 모든 작업을 `end_date` 오름차순 정렬해 단순히 상위 5개만 잘랐음 (`null` 이면 2099 로 치환).
- 미완료 작업이 5개 이하인 프로젝트(예: STT)에서는 `end_date` 가 없는 작업도 5칸을 채우려고 끌려 들어옴.
- "임박" 의 시간 임계도 없어서 1년 뒤 마감인 작업이 "임박" 으로 표시되는 의미 모순도 있었음.

## 변경 내용

### `lib/widgets/project_info/description_tasks_widget.dart`

```dart
// 변경 전 (단순 정렬 + 상위 5개)
final urgentTasks = allTasks
    .where((t) => t.status != TaskStatus.done)
    .toList()
  ..sort((a, b) {
    final aDate = a.endDate ?? DateTime(2099);
    final bDate = b.endDate ?? DateTime(2099);
    return aDate.compareTo(bDate);
  });

// 변경 후 (end_date 가 있고 오늘+2 이내, 미완료만)
final now = DateTime.now();
final todayStart = DateTime(now.year, now.month, now.day);
final urgentCutoff = todayStart.add(const Duration(days: 3)); // exclusive
final urgentTasks = allTasks
    .where((t) =>
        t.status != TaskStatus.done &&
        t.endDate != null &&
        t.endDate!.isBefore(urgentCutoff))
    .toList()
  ..sort((a, b) => a.endDate!.compareTo(b.endDate!));
```

빈 상태 문구도 의미에 맞게 `'진행 중인 작업이 없습니다.'` → `'마감 임박 작업이 없습니다.'` 로 갱신.

## 작업 결과

- [x] `urgentTasks` 필터를 end_date 존재 + 오늘+2일 이내로 좁힘 (이미 지난 미완료 포함)
- [x] 빈 상태 문구 갱신
- [x] **(후속 보완)** backlog 상태도 제외 — 아직 착수 전이라 "임박" 의미와 맞지 않음
- [x] `flutter analyze lib/widgets/project_info/description_tasks_widget.dart` → No issues

## 분석

- **Root cause**: 임박 기준이 시간 임계 없이 "정렬 후 상위 5개" 였고, end_date 가 null 인 작업도 2099 fallback 으로 정렬에는 포함되어 자리 채움.
- **Change**: end_date 필수 + 오늘+2일 이내 윈도우 적용. 정렬 기준은 `end_date` 그대로.
- **Recurrence prevention**: 빈 상태 문구를 "마감 임박 작업이 없습니다." 로 의미 일치 → 작업 자체는 있지만 "임박" 이 아닌 정상 케이스가 명확히 표현됨.
- **Verification**: `flutter analyze` 통과. UI 는 사용자 확인 단계에서 검증.
- **Remaining risk**: 임박 임계가 2일 고정 — 향후 프로젝트별/사용자별 임계 조정 요구가 생기면 별도 설정으로 분리 필요.

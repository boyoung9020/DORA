# 회의록 참여자 표시 포맷 변경 및 작성자 자동 표시

| 속성 | 값 |
|------|-----|
| 유형 | ui |
| 영역 | frontend/screens (meeting_minutes_screen) |
| 날짜 | 2026-04-24 |
| 상태 | done |
| 관련 | meeting_minutes_screen, meeting_minutes model (creator_id) |

## 요청 내용

1. 회의록 리스트/상세에서 **참여자 표시 포맷**을 `참여자: 이름, 이름` → `참여자 - 이름, 이름` 으로 변경
2. **작성자(creator)** 정보를 리스트/상세에 자동 표시 — 현재는 `creator_id` 가 DB/모델에 저장되어 있으나 UI 에 노출되지 않음

## 배경

- 백엔드는 `POST /api/meeting-minutes/` 호출 시 `creator_id=current_user.id` 를 자동 세팅 ([backend/app/routers/meeting_minutes.py:89](backend/app/routers/meeting_minutes.py#L89))
- Flutter 모델 `MeetingMinutes` 에도 `creatorId` 가 존재 ([lib/models/meeting_minutes.dart:11](lib/models/meeting_minutes.dart#L11))
- 그러나 `_buildMinutesListItem` / `_buildViewer` 둘 다 작성자 이름을 표시하지 않음
- 참여자 앞 접두 `참여자:` 를 대시 스타일 `참여자 -` 로 변경 요청

## 변경 후 ASCII

### 좌측 리스트 아이템
```
┌────────────────────────────────────────────┐
│ 📄 ooooo                       2026.04.23  │
│     작성자 - 정보영                          │
│     참여자 - 정보영, 강우원, 김홍주           │
├────────────────────────────────────────────┤
│ 📄 111                         2026.04.23  │
│     작성자 - 정보영                          │
│     참여자 - -                              │
└────────────────────────────────────────────┘
```

- 제목행 + 작성자행 + 참여자행 → **3줄 구조 고정** (세로 높이 유지)
- 작성자: `creator_id` 로 `WorkspaceMember` 에서 찾아 username 표시 (못 찾으면 해당 행 생략)
- 참여자: `참여자 - ${names}` (없을 때 `참여자 - -`)

### 우측 상세 상단 정보 바
```
제목
📅 2026년 04월 23일   📁 주간회의   ✍ 정보영   👥 정보영, 강우원, 김홍주
```

- 기존 `calendar / folder / people_outline` 아이콘 줄에 `✍ 작성자` 를 **카테고리 뒤, 참여자 앞** 위치에 삽입
- `Icons.edit_outlined` (혹은 `Icons.person_outline`) 사용

## 구현 포인트

- `_buildMinutesListItem` ([meeting_minutes_screen.dart:994-1091](lib/screens/meeting_minutes_screen.dart#L994-L1091))
  - `attendeeText` 의 `:` → `-` 교체
  - 작성자 이름을 `members` 에서 `userId == minutes.creatorId` 로 조회
  - 작성자 행을 참여자 행 위에 한 줄 추가 (`작성자 - ${username}`, 찾지 못하면 빈 문자열로 라인 유지해 높이 통일 or 생략)
- `_buildViewer` ([meeting_minutes_screen.dart:1511-1600](lib/screens/meeting_minutes_screen.dart#L1511-L1600))
  - 상단 메타 Row 에 작성자 세그먼트 추가 (아이콘 + 이름)
- 모델/서비스/백엔드 변경 없음 (creator_id 는 이미 저장/반환됨)

## 작업 결과

- [x] `_buildMinutesListItem` 참여자 구분자 `-` 변경 (`참여자: ...` → `참여자 - ...`)
- [x] `_buildMinutesListItem` 작성자 행 추가 (제목행 + 작성자행 + 참여자행 3줄 구조)
- [x] `_buildViewer` 상단 정보 바에 작성자 세그먼트 추가 (`Icons.edit_outlined` + 이름)
- [x] `flutter analyze` 통과 확인 (이전부터 존재하던 `value` deprecation 경고 2건 외 신규 이슈 없음)

## 확정 사항

- 3줄 구조로 진행 (제목 / 작성자 / 참여자) — 사용자 승인
- 작성자가 작성하는 시점의 `current_user.id` 가 저장되므로 항상 찾을 수 있다는 전제 → 별도 "알수없음" 폴백 UI 추가하지 않음 (멤버 목록에 없을 시 상세 상단 바 세그먼트만 생략, 리스트는 `-` 로 표시)

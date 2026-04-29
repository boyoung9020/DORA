# 깔끔한 단일 입력 / 확인 다이얼로그 통합

| 속성 | 값 |
|------|-----|
| 유형 | refactor+ui |
| 영역 | frontend/widgets, frontend/screens |
| 날짜 | 2026-04-29 |
| 상태 | done |
| 관련 | clean_dialog, main_layout, meeting_minutes_screen |

## 요청 내용

좌측 사이드바 프로젝트 드롭다운 디자인이 깔끔한데, 같은 톤으로 단일 입력 다이얼로그(새 프로젝트, 새 폴더)와 확인 다이얼로그(보관/삭제)를 통일해달라. 또한 왜 드롭다운이 깔끔해 보이는지 설명도 함께.

## 왜 드롭다운이 깔끔해 보이는가

1. Chrome 최소화 — 두꺼운 보더/큰 타이틀 없음
2. Subtle divider (`outlineVariant.withValues(alpha:0.4)`)
3. Type hierarchy — section header 11px + 0.5 letter-spacing + 45% opacity
4. Inline action (별표/체크가 항목 우측에 자연 흡수)
5. Selected state = `primary 8% alpha tint` (강한 outline 없음)
6. Solid surface (blur 없음) + elevation 8 + 10px radius
7. Tight rhythm (40px min-height + 14/8 padding)
8. 테마 토큰만 사용 → 다크/라이트 자동 대응

핵심: **chrome 을 빼고 알파/소프트 디바이더로 위계만 표시**.

## ASCII 다이어그램

### 단일 입력
```
┌─────────────────────────────────┐
│  새 프로젝트                    │  15px w600
│ ─────────────────────────────── │  outlineVariant 0.4
│                                 │
│   프로젝트 이름                 │  hint, 14px
│   ─────────────────────         │  underline (focus=primary)
│                                 │
│              취소     생성      │  TextButton×2, 우측 정렬
└─────────────────────────────────┘
```

### 확인 (destructive)
```
┌─────────────────────────────────┐
│  프로젝트 삭제                  │
│ ─────────────────────────────── │
│                                 │
│  「홍주's 업무관리」를 삭제     │  13.5px, 0.85 alpha
│  하시겠습니까? 이 작업은        │
│  되돌릴 수 없습니다.            │
│                                 │
│              취소     삭제      │  '삭제' = cs.error
└─────────────────────────────────┘
```

## 작업 결과

- [x] `lib/widgets/clean_dialog.dart` 신규 (showCleanInputDialog + showCleanConfirmDialog + 내부 `_CleanDialogShell` + `_CleanDialogActions`)
- [x] `_showCreateProjectDialog` (`main_layout.dart`) → `showCleanInputDialog(title:'새 프로젝트', hint:'프로젝트 이름', confirmLabel:'생성')` 으로 본문 교체
- [x] `_showArchiveProjectDialog` (`main_layout.dart`) → `showCleanConfirmDialog(title:'프로젝트 보관', confirmLabel:'보관')`
- [x] `_showDeleteProjectDialog` (`main_layout.dart`) → `showCleanConfirmDialog(title:'프로젝트 삭제', confirmLabel:'삭제', isDestructive:true)`
- [x] `_showCreateFolderDialog` (`meeting_minutes_screen.dart`) → `showCleanInputDialog(title:'새 폴더', hint:'예: 주간회의', helperText:'상위: $parentPath', confirmLabel:'생성')`. 사용하지 않게 된 `bool isDark` 파라미터 제거 (호출부도 정리)
- [x] `flutter analyze` 통과 — 신규 에러 0 (37개 info 모두 기존 경고)
- [ ] 사용자 손으로 시나리오 검증 (배포 후)

## 비-목표

- 53개 다른 AlertDialog 일괄 변경 (이번 위젯이 베이스가 됨, 점진적 마이그레이션)
- 다중 필드 다이얼로그 (sprint, site)
- 다이얼로그 진입/퇴장 모션
- i18n

## 참고 사항

- 비즈니스 로직(`projectProvider.archiveProject` 등) 은 그대로 두고 표현부만 교체
- TextField 의 onSubmitted (Enter) → 확정 버튼과 동일 동작
- 빈 입력 시 확정 버튼 disabled
- ESC / 외부 탭 → null/false 반환

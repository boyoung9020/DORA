# 2026-04 작업 이력

| 파일 | 제목 | 유형 | 영역 | 상태 | 관련 |
|------|------|------|------|------|------|
| [20260427-001401-team-dashboard-pinned-empty-state.md](20260427-001401-team-dashboard-pinned-empty-state.md) | 팀 현황 대시보드 핀 멤버 빈 set 저장 시 자동 리셋되는 버그 수정 | fix | frontend/widgets/workspace | done | team_today_dashboard |
| [20260426-233500-meeting-minutes-tasks-side-panel.md](20260426-233500-meeting-minutes-tasks-side-panel.md) | 회의록에서 생성된 작업 현황판 사이드 패널 추가 (Notion 스타일 테이블 + Date 컬럼 + 폭 확대) | feat | frontend/screens, frontend/widgets/meeting_minutes | done | meeting_minutes_screen, meeting_tasks_panel, meeting_task_table_row |
| [20260426-195650-meeting-minutes-task-check-instant-update.md](20260426-195650-meeting-minutes-task-check-instant-update.md) | 회의록 작업 추가 시 체크 표시 즉시 반영 (StatefulBuilder setState shadow 우회) | fix | frontend/screens | done | meeting_minutes_screen |
| [20260424-204035-yesterday-review-server-state-cleanup.md](20260424-204035-yesterday-review-server-state-cleanup.md) | 어제 미완료 리뷰 다이얼로그 재노출/연장 버그 정리 (서버 상태 기반) | fix | backend/models+routers, frontend/screens+widgets+services, schema(users) | done | main_layout, yesterday_review_dialog, workspaces, workspace_service, user, main |
| [20260424-111842-meeting-minutes-task-link-ui.md](20260424-111842-meeting-minutes-task-link-ui.md) | 회의록 → 작업 연결 표시 및 아이콘 위치 개선 (UUID 내장) | feat+ui | frontend/screens, backend/models+routers, schema(tasks) | done | meeting_minutes_screen, tasks, task_detail_screen |
| [20260424-104719-meeting-minutes-attendee-format-and-author.md](20260424-104719-meeting-minutes-attendee-format-and-author.md) | 회의록 참여자 표시 포맷 변경 및 작성자 자동 표시 | ui | frontend/screens | done | meeting_minutes_screen, creator_id |
| [20260423-184631-meeting-minutes-list-uniform-height.md](20260423-184631-meeting-minutes-list-uniform-height.md) | 회의록 리스트 아이템 세로 통일 및 참여자 표시 텍스트화 | ui | frontend/screens | done | meeting_minutes_screen |
| [20260423-180341-team-dashboard-today-tasks-scope.md](20260423-180341-team-dashboard-today-tasks-scope.md) | AI팀 현황 대시보드 "오늘 할일" 범위 축소 및 완료 태스크 표시 정렬 | ui | frontend/widgets/workspace, backend/routers/workspaces | done | team_today_dashboard, workspaces, today_task_row |

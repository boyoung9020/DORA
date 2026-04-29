# 프로젝트 보관(archive) 기능 추가

| 속성 | 값 |
|------|-----|
| 유형 | feat |
| 영역 | backend/models+routers+schemas, frontend/models+services+providers+screens, schema(projects) |
| 날짜 | 2026-04-28 |
| 상태 | done |
| 관련 | projects, project_provider, main_layout, dashboard_screen |

## 요청 내용

좌측 사이드바 프로젝트 드롭다운에 더 이상 진행하지 않는 프로젝트들을 정리할 수 있는 **보관(archive)** 기능을 추가한다. 워크스페이스 전체 단위로 보관 처리하며, 권한은 기존 "프로젝트 삭제" 와 동일(생성자 PM 또는 Admin). 데이터는 보존하고 UI 노출만 차단. 사이드 이펙트가 없도록 사이트 화면 등 라벨 lookup 이 필요한 곳은 그대로 보이게 함.

## 배경

- 프로젝트가 누적되어 드롭다운이 길어짐 (스크린샷 기준 16개)
- 종료된 프로젝트도 데이터(태스크/회의록/사이트 링크 등)는 보존 필요
- 다른 멤버의 작업 흐름과 통계 일관성을 위해 글로벌 보관 방식 채택 (per-user 숨김 X)
- 사용자 결정: 대시보드/통계에서도 archived 제외 → `visibleProjects` 분리

## 사이드 이펙트 분석 결과

| 표면 | 처리 |
|---|---|
| `main_layout.dart` 드롭다운 (`sortedProjects`) | `visibleProjects` 기반으로 변경 → archived 자동 제외 |
| `main_layout.dart` "전체" 모드 task 로드 | `visibleProjects` 사용 → archived 태스크 미로드 |
| `dashboard_screen.dart` `loadAllTasks(projectIds)` | `visibleProjects` 사용 |
| `site_screen.dart` 사이트→프로젝트 라벨 lookup | `_projects` (= archived 포함) 그대로 사용 → 이름 깨짐 방지 |
| `kanban`/`sprint`/`calendar`/`gantt`/`quick_task`/`meeting_minutes`/`task_detail` | `currentProject` 의존. archive 토글 시 Provider 가 폴백 |
| `workspace_member_stats_screen.dart` | workspace 단위 → 변경 없음 (이력 보존) |
| 백엔드 도메인 라우터 (tasks/sprints/patches/...) | 명시적 project_id 필터 → 변경 없음 |

## ASCII 다이어그램

드롭다운 (보관함 ON):
```
┌────────────────────────────────┐
│ ⬢ 전체                  ✓     │
├────────────────────────────────┤
│  공용                           │
│ ●🌐 Sync 요구사항              │
├────────────────────────────────┤
│ ● AI Demo Web            ★    │  ← favorites
│ ● 삼성서울병원           ★    │
│ ● QC                     ★    │
├────────────────────────────────┤
│ ● 프레임보간 인수인계    ☆    │  ← visible 일반
│ ● RAPA                   ☆    │
│ ● NAB              ✓     ☆    │
├────────────────────────────────┤
│  보관                           │  ← _showArchived=true 때만
│ ● OCR (dim)                    │
│ ● AWS 테스트 (dim)             │
├────────────────────────────────┤
│ ⊕ 새 프로젝트                  │
│ 📦 보관된 프로젝트 보기 (2)    │  ← archived>0 때만 노출
└────────────────────────────────┘
```

우클릭 컨텍스트 메뉴 (PM/Admin):
```
┌────────────────────┐
│ 📦 프로젝트 보관    │  ← isArchived=false
│ 🗑  프로젝트 삭제   │
└────────────────────┘
또는
┌────────────────────┐
│ 📤 보관 해제        │  ← isArchived=true
│ 🗑  프로젝트 삭제   │
└────────────────────┘
```

## 작업 결과

### 백엔드
- [x] `Project.is_archived` 컬럼 추가 (`backend/app/models/project.py`)
- [x] `ensure_project_is_archived_column()` startup 마이그레이션 (`backend/app/main.py`)
- [x] `ProjectResponse.is_archived` 필드 추가 (`backend/app/schemas/project.py`)
- [x] `POST /api/projects/{id}/archive` 엔드포인트 추가 (project_archived WebSocket broadcast 포함)
- [x] `POST /api/projects/{id}/unarchive` 엔드포인트 추가 (project_unarchived WebSocket broadcast 포함)
- [x] 권한 가드: `_is_project_pm()` (creator OR admin) 재사용

### 프론트엔드
- [x] `Project.isArchived` 필드 추가 (`lib/models/project.dart`) — 생성자/fromJson/toJson/copyWith 모두 반영
- [x] `ProjectService.archiveProject` / `unarchiveProject` 메서드 추가
- [x] `ProjectProvider`:
  - [x] `_showArchived` 상태
  - [x] `visibleProjects` / `archivedProjects` / `isShowingArchived` getter
  - [x] `sortedProjects` → `visibleProjects` 베이스
  - [x] `setShowArchived(bool)` / `archiveProject(id)` / `unarchiveProject(id)` 메서드
  - [x] currentProject 폴백 로직 visible 기반으로 보강 (`_filterProjects` + `loadProjects` 둘 다)
- [x] `main_layout.dart`:
  - [x] "전체" 클릭 시 `visibleProjects` 사용 (line 251)
  - [x] 드롭다운 하단 "보관된 프로젝트 보기 (N)" / "보관함 숨기기" 토글 (archived>0 시만 노출)
  - [x] 보관 섹션 dim(opacity 0.5) 렌더 (`_showArchived` 시)
  - [x] 컨텍스트 메뉴 "프로젝트 보관" / "보관 해제" 추가 (PM/Admin), 기존 삭제 항목 유지
  - [x] 보관 확인 다이얼로그 (`_showArchiveProjectDialog`) 및 보관 해제 즉시 실행 (`_runUnarchiveProject`)
  - [x] "전체 모드" 멤버 집계도 `visibleProjects` 로 (line 1857)
- [x] `dashboard_screen.dart`:
  - [x] `loadAllTasks(projectIds)` 호출 시 `visibleProjects` 사용 (line 97)
  - [x] 담당자 필터 드롭다운 멤버 집계도 `visibleProjects` 로 (line 1757)
  - [x] 라벨 lookup용 `projectsById` 는 `projects` 그대로 (보관된 프로젝트의 태스크 라벨 보존)

### 검증
- [x] `flutter analyze` 통과 (5개 파일 대상, 신규 에러 없음 — 56개 info 경고 모두 기존 패턴)
- [ ] 백엔드 startup 마이그레이션 로그 확인 (배포 시)
- [ ] DB `\d projects` 로 `is_archived BOOLEAN NOT NULL DEFAULT FALSE` 컬럼 확인 (배포 시)
- [ ] UI 시나리오 9단계 (계획서 검증 섹션 참조) — 사용자 손으로 검증 필요

## 참고 사항

- 기존 `DELETE /api/projects/{id}` 는 변경 없음 (영구 삭제는 별개 동작)
- WebSocket 이벤트 `project_archived` / `project_unarchived` 추가 (기존 create/update/delete 패턴 일관성). 다만 프론트는 별도 핸들러 등록 안 함 — 다음 새로고침에 반영
- 사이트 화면(`site_screen.dart`)은 의도적으로 `_projects` 사용 유지 → 보관된 프로젝트가 연결된 사이트에서도 라벨/색상 정상 표시
- 워크스페이스 멤버 통계(`workspace_member_stats_screen.dart`)는 변경 없음 — 과거 기여 이력 보존
- 사용자별 개인 숨김은 별도 작업 (이번에는 워크스페이스 전체 archive만)
- 변경 파일 (총 8개):
  - backend: `models/project.py`, `main.py`, `schemas/project.py`, `routers/projects.py`
  - frontend: `models/project.dart`, `services/project_service.dart`, `providers/project_provider.dart`, `screens/main_layout.dart`, `screens/dashboard_screen.dart`

## 배포 시 필요 작업

```bash
# 백엔드 재기동 → ensure_project_is_archived_column() 자동 실행
docker compose restart api
docker compose logs api --tail 30 | grep is_archived
docker compose exec postgres psql -U postgres -d sync -c "\d projects" | grep is_archived
```

## 참고 사항

- 기존 `DELETE /api/projects/{id}` 는 변경 없음 (영구 삭제는 별개 동작)
- WebSocket 이벤트 미추가 (다음 새로고침에 반영)
- 사용자별 개인 숨김은 별도 작업
- 사이트 화면은 `_projects` 사용으로 이름 lookup 보존

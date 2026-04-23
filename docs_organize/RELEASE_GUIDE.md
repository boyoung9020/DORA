# Windows 앱 릴리스 가이드

## 전체 흐름

```
scripts/release.ps1 실행
  │
  ├─ 1. pubspec.yaml 버전 자동 증가 (1.0.0+1 → 1.0.1+2)
  ├─ 2. git log에서 커밋 메시지 수집 → CHANGELOG.md 자동 생성
  ├─ 3. git commit (버전 + CHANGELOG 변경)
  ├─ 4. git tag v1.0.1 (이 커밋에 태그 부착)
  └─ 5. git push (커밋 + 태그를 GitHub로 전송)
         │
         ▼
GitHub Actions (자동)
  │
  ├─ v* 태그 도착 감지 → release.yml 워크플로우 실행
  ├─ windows-latest 서버에서 Flutter 설치
  ├─ flutter build windows --release (API_BASE_URL 주입)
  ├─ 빌드 결과물 zip 압축
  ├─ CHANGELOG.md에서 해당 버전 릴리스 노트 추출
  └─ GitHub Releases에 zip 파일 + 릴리스 노트 업로드
         │
         ▼
사용자
  └─ GitHub Releases 페이지에서 zip 다운로드 → 압축 해제 → exe 실행
```

## 사용법

### 릴리스 실행

```powershell
# 패치 릴리스 (1.0.1 → 1.0.2) — 기본값
powershell -ExecutionPolicy Bypass -File scripts\release.ps1

# 마이너 릴리스 (1.0.1 → 1.1.0)
powershell -ExecutionPolicy Bypass -File scripts\release.ps1 -BumpType minor

# 메이저 릴리스 (1.0.1 → 2.0.0)
powershell -ExecutionPolicy Bypass -File scripts\release.ps1 -BumpType major

# 미리보기 (실제 변경 없음)
powershell -ExecutionPolicy Bypass -File scripts\release.ps1 -DryRun
```

### 실행 전 조건

- 커밋되지 않은 변경사항이 없어야 함 (먼저 커밋 필요)
- main 브랜치에서 실행

## 버전 규칙

`MAJOR.MINOR.PATCH+BUILD` 형식 (예: `1.0.1+2`)

| 버전 변경 | 언제 사용 | 예시 |
|-----------|----------|------|
| **patch** | 버그 수정, 작은 개선 | 1.0.0 → 1.0.1 |
| **minor** | 새 기능 추가 | 1.0.0 → 1.1.0 |
| **major** | 큰 변경, 호환성 깨지는 변경 | 1.0.0 → 2.0.0 |

- BUILD 번호는 어떤 버전 변경이든 항상 +1 증가

## CHANGELOG 자동 생성

커밋 메시지의 prefix에 따라 자동 분류:

| Prefix | 카테고리 |
|--------|---------|
| `feat:` | 새로운 기능 |
| `fix:` | 버그 수정 |
| `refactor:` | 리팩토링 |
| `docs:` | 문서 |
| `perf:` | 성능 개선 |
| `style:` | 스타일 |
| `test:` | 테스트 |
| `chore:` | 기타 작업 |

`feat(scope): 메시지` 형태도 지원 (예: `feat(task): 참조자 기능 추가`)

## GitHub Actions

### 워크플로우 파일

`.github/workflows/release.yml`

### 트리거

`v`로 시작하는 태그가 push되면 자동 실행

### Actions 탭 상태

| 아이콘 | 의미 |
|--------|------|
| 🟡 노란 원 | 빌드 진행 중 |
| ✅ 녹색 체크 | 빌드 성공 → Releases에 zip 업로드 완료 |
| ❌ 빨간 X | 빌드 실패 → 클릭해서 로그 확인 |

### 빌드 시간

약 5~10분 (Flutter 설치 + Windows 빌드)

## 사전 설정 (최초 1회)

### GitHub Secrets

GitHub repo → Settings → Secrets and variables → Actions → New repository secret:

| Name | Value | 용도 |
|------|-------|------|
| `API_BASE_URL` | `https://syncwork.kr/` | Windows 앱이 연결할 서버 주소 |

## 관련 파일

| 파일 | 역할 |
|------|------|
| `scripts/release.ps1` | 로컬 릴리스 스크립트 (버전 증가 + CHANGELOG + tag push) |
| `.github/workflows/release.yml` | GitHub Actions 워크플로우 (빌드 + Release 업로드) |
| `CHANGELOG.md` | 자동 생성되는 변경 이력 |
| `pubspec.yaml` | 앱 버전 관리 (version 라인) |

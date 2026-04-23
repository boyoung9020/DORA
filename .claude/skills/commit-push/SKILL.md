---
name: commit-push
description: 현재 working tree 의 변경사항을 분석해 적절한 커밋 메시지로 스테이징/커밋하고 원격에 푸시한다. 기존 커밋 스타일(한글 본문 + 영어 type prefix)을 따르고, main/master 푸시 시 사용자 확인을 거치며, 민감 파일은 자동 제외. 사용자가 작업이 끝나 `/commit-push` 를 호출할 때 실행.
---

# /commit-push

현재 브랜치의 변경사항을 커밋하고 원격에 푸시한다. "작업 완료" 판단은 사용자가 내렸다고 간주한다 (skill 안에서 별도 테스트/빌드 검증은 하지 않는다).

## 실행 단계

### 1. 현재 상태 파악 (병렬 Bash 호출)
- `git status` — 변경/미추적 파일 확인 (`-uall` 금지, 대용량 저장소 메모리 이슈)
- `git diff` + `git diff --staged` — 실제 변경 내용 파악
- `git log --oneline -10` — 최근 커밋 스타일 학습
- `git branch --show-current` — 현재 브랜치
- `git remote -v` — 푸시 대상 원격 확인
- upstream 설정 여부 확인: `git rev-parse --abbrev-ref --symbolic-full-name @{u}` (없으면 push 시 `-u` 필요)

### 2. 커밋 메시지 초안
- 기존 스타일 반영: **한글 본문 + 영어 type prefix** (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `style:`, `test:`, `ci:`, `build:`)
  - 예: `feat: 회의록 API·화면 추가, 패치 연동 개선`
  - 예: `fix: 타이틀바 배경색 구분 및 하단 구분선 추가`
- 1-2 줄로 간결히, 변경의 "왜/무엇을 위해"에 초점 — 파일명 나열 금지
- 여러 도메인에 걸친 묶음 변경이면 쉼표 / 가운뎃점(`·`) 으로 연결
- 성격에 따라 type 선택: 새 기능=feat, 버그수정=fix, 리팩토링=refactor, 문서만=docs, 빌드/의존성=chore, 설정/CI=ci

### 3. 민감 / 위험 파일 사전 차단
다음 패턴의 파일이 변경 목록에 보이면 **스테이징 제외 + 사용자 경고**:
- 비밀 / 자격증명: `.env`, `.env.*`, `*credentials*`, `*secret*`, `*.key`, `*.pem`, `id_rsa*`, `config.local.*`, `.npmrc` (토큰 포함)
- 대용량 / 바이너리: `build/`, `dist/`, `*.exe`, `*.apk`, `*.aab`, `*.ipa`, `*.dmg`, `*.zip`, `*.mp4` (단 소스 자산은 예외)
- 빌드 산출물 / 로그: `*.log`, `coverage/`, `.next/`, `node_modules/`, `__pycache__/`, `*.pyc`

`.gitignore` 에 이미 포함돼 있어도 변경 대상에 보이면 한 번 확인하고 진행.

### 4. 스테이징 & 커밋
- **`git add -A` / `git add .` 금지** — 변경 파일을 명시적으로 나열해 `git add <file1> <file2> ...`
- 커밋 메시지는 HEREDOC 로 전달 (포맷/인용 깨짐 방지):
  ```bash
  git commit -m "$(cat <<'EOF'
  feat: 설명
  EOF
  )"
  ```
- hook 우회 금지: `--no-verify`, `--no-gpg-sign` 사용 금지 (사용자 명시 지시 시에만 허용)
- **Amend 금지**: 별도 지시 없으면 항상 새 커밋 생성. 특히 pre-commit hook 실패 시 `--amend` 쓰면 이전 커밋을 덮어써 작업 손실 위험

### 5. 푸시 전 확인
- 현재 브랜치가 `main` / `master` / `production` / `release/*` 등 **보호 브랜치면 반드시 사용자에게 확인** 후 진행:
  - "현재 `main` 에 푸시하려 합니다. 진행할까요?"
- upstream 이 없으면 `git push -u origin <branch>` 로 트래킹 설정
- **강제 푸시 (`--force`, `--force-with-lease`) 는 사용자 명시 지시가 있을 때만**. 특히 보호 브랜치에는 어떤 상황에서도 force push 금지 (경고 출력).

### 6. 푸시 후
- `git status` 로 로컬/원격 동기화 상태 확인
- 푸시된 커밋의 SHA (짧은 형식) 와 원격 브랜치 이름을 한 줄로 보고:
  - 예: `✓ Pushed abc1234 to origin/feature/meeting-minutes`

## 실패 시 처리

| 상황 | 대응 |
|------|------|
| pre-commit hook 실패 | 원인을 보고 **수정 → 재스테이징 → 새 커밋** 생성. `--amend` 사용 금지 |
| 원격 거절 (non-fast-forward) | `git pull --rebase` 여부를 사용자에게 확인, 독단 rebase/reset 금지 |
| 네트워크/인증 실패 | 에러 메시지 그대로 보고, 사용자 조치 대기 |
| 커밋할 변경사항 없음 | 빈 커밋 생성 금지, 바로 종료 보고 |

## 동작하지 않는 경우

- 저장소가 git 초기화되지 않았거나 원격이 없을 때 — 에러 메시지 보고 후 종료
- detached HEAD 상태 — 브랜치 체크아웃 필요함을 알리고 중단

## 의도적으로 하지 않는 것

- 테스트/린트/빌드 실행 (사용자가 이미 확인했다고 가정)
- 태그 생성 — 릴리즈 작업은 별도 workflow
- PR 생성 — `gh pr create` 는 사용자가 별도로 지시해야 함

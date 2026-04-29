# 사이트 이름 중복 방지 — DB UNIQUE 제약 + 무결성 보장

| 속성 | 값 |
|------|-----|
| 유형 | fix |
| 영역 | backend/routers, backend/main (schema), 운영 DB cleanup |
| 날짜 | 2026-04-27 |
| 상태 | 진행중 |
| 관련 | site_details, project_sites |

## 요청 내용

사이트 화면에 동일한 이름의 사이트("KBS") 가 두 행으로 표시됨. `site_details` 테이블 중복 정리 + 향후 재발 방지.

## Root cause 분석

운영 DB 조회 결과:

```
site_details
  82f2c7c3 | KBS | project_ids=[0742138d, a5f798c9] | 2026-04-23 06:24
  6915b738 | KBS | project_ids=[a5f798c9]           | 2026-04-27 02:34   ← DUP
```

두 행 모두 `name='KBS'`, length 3 (공백·대소문자 차이 없음).

`POST /api/site-details/` 와 `POST /api/project-sites/` 양쪽 모두 코드 레벨에서 `SELECT WHERE name=?` 후 `if existing: ...` 패턴의 dedup 을 수행하나:

- 동시 호출 시 race condition (둘 다 빈 결과 → 둘 다 INSERT)
- 한 트랜잭션의 SiteDetail 생성이 commit 실패 후 재시도되면 dedup check 가 스킵되는 경로 가능성
- 다른 코드 경로/마이그레이션이 직접 INSERT 하는 가능성

코드만으로 race 차단은 어려우므로 **DB UNIQUE 제약**이 정답.

## 해결 방향

### A. 운영 DB 즉시 정리

`6915b738-...` 행을 삭제. 해당 행의 project_ids `[a5f798c9-...]` 는 이미 `82f2c7c3-...` 행의 project_ids 에 포함되어 있어 데이터 손실 없음. tasks.site_tags 는 사이트 이름(string)으로 저장되어 id 참조 없음 — 안전.

### B. UNIQUE 제약 추가 (`ensure_*` 패턴)

`backend/app/main.py` 에:

```python
def ensure_site_details_name_unique() -> None:
    """site_details.name 에 UNIQUE INDEX 추가 (중복 행 방지)."""
    with engine.connect() as conn:
        conn.execute(text("""
            CREATE UNIQUE INDEX IF NOT EXISTS ux_site_details_name
                ON site_details(name);
        """))
        conn.commit()
```

### C. 코드 레벨 — IntegrityError 안전 처리

UNIQUE 제약 추가 후, race condition 으로 INSERT 가 실패할 수 있음. `create_site_detail` / `create_project_site` 의 INSERT 경로를 try/except IntegrityError 로 감싸서:
- 실패 시 롤백
- 같은 이름의 기존 row 재조회
- project_id 추가 후 반환

## 작업 결과

- [ ] A. 운영 DB 의 dup KBS 행 삭제
- [ ] B. `ensure_site_details_name_unique` 추가 + 호출
- [ ] C. `create_site_detail` / `create_project_site` 의 INSERT 분기를 IntegrityError 안전 처리
- [ ] backend-only 배포
- [ ] 사용자 확인 — 사이트 화면에 KBS 한 행만 보이는지

## 검증

1. 운영 DB 조회: `SELECT name, COUNT(*) FROM site_details GROUP BY name HAVING COUNT(*)>1;` 결과 0행
2. 중복 INSERT 시뮬레이션 (concurrent or 같은 이름 재요청) → 한 행만 유지
3. 사이트 화면에서 같은 이름 사이트가 한 번만 표시

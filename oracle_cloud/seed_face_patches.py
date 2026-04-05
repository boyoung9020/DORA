#!/usr/bin/env python3
"""
얼굴인식 프로젝트의 Face 컴포넌트 패치 히스토리를 DB에 삽입합니다.
서버에서 실행: python3 seed_face_patches.py
"""

import os
import sys
import uuid
from datetime import date

# 서버 환경에서 app 모듈 접근
sys.path.insert(0, "/home/ubuntu/app/backend")

from app.database import SessionLocal
from app.models.patch import ProjectPatch
from app.models.project import Project

FACE_PATCHES = [
    (date(2024, 11, 25), "1.0.0", "최초 배포"),
    (date(2025, 3, 4),   "1.1.0", "얼굴 분석 추가"),
    (date(2025, 3, 10),  "1.0.0", "/compare 추가"),
    (date(2025, 3, 13),  "1.0.0", "모든 인물에 대해서 pk추가"),
    (date(2025, 3, 25),  "1.2.1", "milvus 헬스 체크 적용"),
    (date(2025, 4, 2),   "1.2.2", "얼굴 검출 없을때에 204 리턴"),
    (date(2025, 4, 21),  "1.2.3", "유사도 0.4이상 인물 대표얼굴 조회 값 반환"),
    (date(2025, 6, 18),  "1.2.4", "메모리 해제 로직 추가"),
    (date(2025, 6, 26),  "1.2.5", "task_id 받아서 처리, 메모리 해제 로직 진짜 추가"),
    (date(2025, 7, 14),  "1.2.6", "인식 개선(대표얼굴 선정, blur 제외)"),
    (date(2025, 7, 16),  "1.2.7", "인물의 얼굴이 전부 black_ratio 일때 제외"),
    (date(2026, 1, 19),  "1.2.8", "redis ttl 옵션화 적용, 작업 스토리지 /media로 변경"),
    (date(2026, 2, 9),   "1.2.9", "메모리 사용 -> 실제 이미지로 변경 (옵션화)"),
]

def main():
    db = SessionLocal()
    try:
        # 얼굴인식 프로젝트 찾기
        project = db.query(Project).filter(Project.name == "얼굴인식").first()
        if not project:
            print("ERROR: '얼굴인식' 프로젝트를 찾을 수 없습니다.")
            print("현재 프로젝트 목록:")
            for p in db.query(Project).all():
                print(f"  - {p.name} (id: {p.id})")
            sys.exit(1)

        print(f"프로젝트 찾음: {project.name} (id: {project.id})")

        # 이미 삽입된 MBC 패치 확인
        existing = db.query(ProjectPatch).filter(
            ProjectPatch.project_id == project.id,
            ProjectPatch.site == "MBC"
        ).count()
        if existing > 0:
            print(f"이미 MBC 패치 {existing}건이 존재합니다. 중복 삽입을 건너뜁니다.")
            sys.exit(0)

        # 패치 삽입
        for patch_date, version, content in FACE_PATCHES:
            patch = ProjectPatch(
                id=str(uuid.uuid4()),
                project_id=project.id,
                site="MBC",
                patch_date=patch_date,
                version=version,
                content=content,
                status="done",
                steps=[],
                test_items=[],
                notes="",
                note_image_urls=[],
                created_by=None,
            )
            db.add(patch)
            print(f"  [{patch_date}] v{version} - {content}")

        db.commit()
        print(f"\n완료: MBC Face 패치 {len(FACE_PATCHES)}건 삽입됨")

    finally:
        db.close()

if __name__ == "__main__":
    main()

"""
MBC 사이트(site_details)의 servers / databases / services JSON을 아래 인프라 정보로 채웁니다.

사이트명이 정확히 "MBC"인 행을 갱신합니다. 없으면 안내 메시지 후 종료합니다.

Usage (backend 디렉터리에서):
  python scripts/seed_mbc_site_detail.py
"""

from __future__ import annotations

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.database import SessionLocal  # noqa: E402
from app.models.site_detail import SiteDetail  # noqa: E402
from app.mbc_site_default_data import (  # noqa: E402
    MBC_DATABASES,
    MBC_SERVERS,
    mbc_services_list,
)


def main() -> None:
    db = SessionLocal()
    try:
        site = db.query(SiteDetail).filter(SiteDetail.name == "MBC").first()
        if not site:
            print('site_details에 name="MBC"인 행이 없습니다. 앱에서 먼저 사이트를 만든 뒤 다시 실행하세요.')
            raise SystemExit(1)
        site.servers = MBC_SERVERS
        site.databases = MBC_DATABASES
        site.services = mbc_services_list()
        db.commit()
        print(f"갱신 완료: site id={site.id} (MBC)")
    finally:
        db.close()


if __name__ == "__main__":
    main()

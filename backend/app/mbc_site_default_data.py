"""MBC 사이트(site_details) 기본 인프라 JSON. startup 시드 및 수동 스크립트에서 공유.

원본 표와 동일한 값을 유지합니다.

접속정보
  ID / PASSWD / GPU / mount
  gemisoadmin / Nps@mbc!23 / A6000(50G) / /mnt/npsmain/root
  administrator / Nps@mbc!23 / 서버 당 2개 / (없음)

서버별 서비스 (server / service / workers / GPU 사용량)
  10.158.108.(111,112): Face 10 33734; milvus -; OCR 10 8905 / 42000
  10.158.108.(113,114): Scene x2 (4 / 41818)

Milvus DB: face_milvus_only / face_milvus_only / g3m1n120ft / 10.158.108.200 / 19530
"""

from __future__ import annotations

from typing import List

MBC_SERVERS: List[dict] = [
    {
        "ip": "",
        "username": "gemisoadmin",
        "password": "Nps@mbc!23",
        "gpu": "A6000(50G)",
        "mount": "/mnt/npsmain/root",
        "note": "MBC 접속 계정",
    },
    {
        "ip": "",
        "username": "administrator",
        "password": "Nps@mbc!23",
        "gpu": "서버 당 2개",
        "mount": "",
        "note": "MBC 접속 계정",
    },
]

MBC_DATABASES: List[dict] = [
    {
        "name": "face_milvus_only",
        "type": "Milvus",
        "user": "face_milvus_only",
        "password": "g3m1n120ft",
        "ip": "10.158.108.200",
        "port": "19530",
        "note": "",
    },
]


def _face_ocr_block(ip: str) -> List[dict]:
    return [
        {
            "name": "Face",
            "version": "",
            "serverIp": ip,
            "workers": "10",
            "gpuUsage": "33734",
            "note": "",
        },
        {
            "name": "milvus",
            "version": "",
            "serverIp": ip,
            "workers": "",
            "gpuUsage": "",
            "note": "",
        },
        {
            "name": "OCR",
            "version": "",
            "serverIp": ip,
            "workers": "10",
            "gpuUsage": "8905 / 42000",
            "note": "",
        },
    ]


def _scene_block(ip: str) -> List[dict]:
    return [
        {
            "name": "Scene",
            "version": "",
            "serverIp": ip,
            "workers": "4",
            "gpuUsage": "41818",
            "note": "",
        },
        {
            "name": "Scene",
            "version": "",
            "serverIp": ip,
            "workers": "4",
            "gpuUsage": "41818",
            "note": "동일 호스트 2번째",
        },
    ]


def mbc_services_list() -> List[dict]:
    out: List[dict] = []
    for ip in ("10.158.108.111", "10.158.108.112"):
        out.extend(_face_ocr_block(ip))
    for ip in ("10.158.108.113", "10.158.108.114"):
        out.extend(_scene_block(ip))
    return out

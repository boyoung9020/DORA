"""Pydantic schemas for site details."""

from datetime import datetime
from typing import Any, List, Optional
from pydantic import BaseModel


class ServerInfo(BaseModel):
    ip: str = ""
    username: str = ""
    password: str = ""
    gpu: str = ""
    mount: str = ""
    note: str = ""


class ServerRole(BaseModel):
    roleName: str = ""
    servers: List[Any] = []


class DatabaseInfo(BaseModel):
    name: str = ""
    type: str = ""
    user: str = ""
    password: str = ""
    ip: str = ""
    port: str = ""
    note: str = ""


class ServiceInfo(BaseModel):
    name: str = ""
    version: str = ""
    server_ip: str = ""
    workers: str = ""
    gpu_usage: str = ""
    note: str = ""


class SiteDetailCreate(BaseModel):
    project_id: str          # 추가할 프로젝트 ID (같은 이름 사이트 있으면 자동 연결)
    name: str
    description: str = ""
    servers: List[Any] = []
    databases: List[Any] = []
    services: List[Any] = []


class SiteDetailUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    servers: Optional[List[Any]] = None
    databases: Optional[List[Any]] = None
    services: Optional[List[Any]] = None
    project_ids: Optional[List[str]] = None


class SiteDetailResponse(BaseModel):
    id: str
    project_ids: List[str]
    name: str
    description: str
    servers: List[Any]
    databases: List[Any]
    services: List[Any]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

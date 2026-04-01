"""Pydantic schemas for site details."""

from datetime import datetime
from typing import Any, List, Optional
from pydantic import BaseModel


class ServerInfo(BaseModel):
    ip: str = ""
    username: str = ""
    note: str = ""


class DatabaseInfo(BaseModel):
    name: str = ""
    type: str = ""
    note: str = ""


class ServiceInfo(BaseModel):
    name: str = ""
    version: str = ""
    note: str = ""


class SiteDetailCreate(BaseModel):
    project_id: str
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


class SiteDetailResponse(BaseModel):
    id: str
    project_id: str
    name: str
    description: str
    servers: List[Any]
    databases: List[Any]
    services: List[Any]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

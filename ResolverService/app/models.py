from __future__ import annotations

from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field


class ResolveRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    video_id: str = Field(
        alias="videoId",
        min_length=11,
        max_length=11,
        pattern=r"^[A-Za-z0-9_-]{11}$",
    )


class ResolveResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)

    stream_url: str = Field(alias="streamURL")
    expires_at: datetime = Field(alias="expiresAt")
    content_type: str = Field(alias="contentType")
    cache_status: str = Field(alias="cacheStatus")


class HealthResponse(BaseModel):
    status: str = "ok"


class SearchResultItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True, serialize_by_alias=True)

    id: str
    kind: str = "video"
    title: str
    channel_title: str = Field(alias="channelTitle")
    thumbnail_url: str | None = Field(default=None, alias="thumbnailURL")


class SearchResponse(BaseModel):
    items: list[SearchResultItem]

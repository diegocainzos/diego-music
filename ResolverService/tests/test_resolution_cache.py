from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path

import pytest

from app.config import Settings
from app.resolution_cache import CachingAudioResolver
from app.resolver import ResolvedAudio, YTDLPResolver
from fake_binaries import fake_ytdlp


class CountingResolver:
    def __init__(self, delay: float = 0) -> None:
        self.delay = delay
        self.calls: list[str] = []

    async def resolve(self, video_id: str) -> ResolvedAudio:
        self.calls.append(video_id)
        if self.delay:
            await asyncio.sleep(self.delay)
        return ResolvedAudio(
            upstream_url=f"https://rr1.googlevideo.com/videoplayback?id={video_id}",
            headers={},
            content_type="audio/mp4",
        )


def cache(
    resolver: CountingResolver,
    now: list[datetime] | None = None,
    max_entries: int = 3,
    ttl: int = 300,
) -> CachingAudioResolver:
    return CachingAudioResolver(
        resolver=resolver,
        max_entries=max_entries,
        ttl_seconds=ttl,
        safety_margin_seconds=30,
        clock=(lambda: now[0]) if now is not None else None,
    )


@pytest.mark.asyncio
async def test_repeated_resolution_uses_cache() -> None:
    resolver = CountingResolver()
    subject = cache(resolver)

    first = await subject.resolve("M7lc1UVf-VE")
    second = await subject.resolve("M7lc1UVf-VE")

    assert resolver.calls == ["M7lc1UVf-VE"]
    assert first.cache_status == "miss"
    assert second.cache_status == "resolution"


@pytest.mark.asyncio
async def test_expired_resolution_is_refreshed() -> None:
    now = [datetime(2026, 1, 1, tzinfo=timezone.utc)]
    resolver = CountingResolver()
    subject = cache(resolver, now=now, ttl=60)

    await subject.resolve("M7lc1UVf-VE")
    now[0] += timedelta(seconds=61)
    refreshed = await subject.resolve("M7lc1UVf-VE")

    assert resolver.calls == ["M7lc1UVf-VE", "M7lc1UVf-VE"]
    assert refreshed.cache_status == "miss"


@pytest.mark.asyncio
async def test_lru_evicts_least_recently_used_entry() -> None:
    resolver = CountingResolver()
    subject = cache(resolver, max_entries=2)

    await subject.resolve("AAAAAAAAAAA")
    await subject.resolve("BBBBBBBBBBB")
    await subject.resolve("AAAAAAAAAAA")
    await subject.resolve("CCCCCCCCCCC")
    await subject.resolve("BBBBBBBBBBB")

    assert resolver.calls == ["AAAAAAAAAAA", "BBBBBBBBBBB", "CCCCCCCCCCC", "BBBBBBBBBBB"]


@pytest.mark.asyncio
async def test_concurrent_requests_share_single_resolution() -> None:
    resolver = CountingResolver(delay=0.03)
    subject = cache(resolver)

    results = await asyncio.gather(
        subject.resolve("M7lc1UVf-VE"),
        subject.resolve("M7lc1UVf-VE"),
        subject.resolve("M7lc1UVf-VE"),
    )

    assert resolver.calls == ["M7lc1UVf-VE"]
    assert sorted(result.cache_status for result in results) == ["miss", "resolution", "resolution"]


@pytest.mark.asyncio
async def test_upstream_expiration_limits_cache_entry() -> None:
    now = [datetime(2026, 1, 1, tzinfo=timezone.utc)]

    class ExpiringResolver(CountingResolver):
        async def resolve(self, video_id: str) -> ResolvedAudio:
            self.calls.append(video_id)
            return ResolvedAudio(
                upstream_url="https://rr1.googlevideo.com/videoplayback",
                headers={},
                content_type="audio/mp4",
                upstream_expires_at=now[0] + timedelta(seconds=40),
            )

    resolver = ExpiringResolver()
    subject = cache(resolver, now=now, ttl=300)
    await subject.resolve("M7lc1UVf-VE")
    now[0] += timedelta(seconds=11)
    await subject.resolve("M7lc1UVf-VE")

    assert resolver.calls == ["M7lc1UVf-VE", "M7lc1UVf-VE"]


@pytest.mark.asyncio
async def test_resolve_download_info_and_caching(tmp_path: Path) -> None:
    info_json = json.dumps({
        "url": "https://rr1.googlevideo.com/videoplayback?expire=1893456000",
        "ext": "m4a",
        "acodec": "mp4a.40.2",
        "vcodec": "none",
        "formats": [{"format_id": "140"}],
        "requested_formats": [{"format_id": "140"}],
        "thumbnails": [{"url": "https://example.com/thumb.jpg"}],
        "automatic_captions": {"en": []},
        "subtitles": {},
        "heatmap": [1, 2, 3],
        "description": "test description",
        "title": "Song Title",
    })
    ytdlp = fake_ytdlp(tmp_path / "bin", payload=None, stdout=info_json)
    base_resolver = YTDLPResolver(
        Settings(
            api_token="test-token-with-at-least-thirty-two-characters",
            public_base_url="https://audio.example.test",
            ytdlp_binary=str(ytdlp.path),
        )
    )
    subject = CachingAudioResolver(
        resolver=base_resolver,
        max_entries=5,
        ttl_seconds=300,
        safety_margin_seconds=30,
    )

    first = await subject.resolve("M7lc1UVf-VE")
    assert first.cache_status == "miss"
    assert first.download_info is not None
    parsed = json.loads(first.download_info)
    assert "formats" not in parsed
    assert "requested_formats" not in parsed
    assert "thumbnails" not in parsed
    assert "automatic_captions" not in parsed
    assert "subtitles" not in parsed
    assert "heatmap" not in parsed
    assert "description" not in parsed
    assert parsed.get("title") == "Song Title"
    assert parsed.get("url") == "https://rr1.googlevideo.com/videoplayback?expire=1893456000"

    second = await subject.resolve("M7lc1UVf-VE")
    assert second.cache_status == "resolution"
    assert second.download_info is None

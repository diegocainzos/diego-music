from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

import pytest

from app.resolution_cache import CachingAudioResolver
from app.resolver import ResolvedAudio


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

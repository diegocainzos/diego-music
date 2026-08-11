from __future__ import annotations

import asyncio
import os
from pathlib import Path

import httpx
import pytest

from app.audio_cache import PersistentAudioCache
from app.resolver import ResolvedAudio


VIDEO_ID = "M7lc1UVf-VE"
UPSTREAM = "https://rr1.googlevideo.com/videoplayback"


def upstream_audio() -> ResolvedAudio:
    return ResolvedAudio(
        upstream_url=UPSTREAM,
        headers={"User-Agent": "cache-test"},
        content_type="audio/mp4",
    )


@pytest.mark.asyncio
async def test_download_is_atomic_and_reused_after_restart(tmp_path: Path) -> None:
    requests = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal requests
        requests += 1
        assert request.headers["user-agent"] == "cache-test"
        if request.method == "HEAD":
            return httpx.Response(200, headers={"Content-Length": "8", "Content-Type": "audio/mp4"})
        assert request.headers["range"] == "bytes=0-7"
        return httpx.Response(
            206,
            headers={"Content-Length": "8", "Content-Range": "bytes 0-7/8"},
            stream=httpx.ByteStream(b"abcdefgh"),
        )

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    cache = PersistentAudioCache(tmp_path, max_bytes=100, max_file_bytes=50)
    await cache.initialize()
    cache.schedule(VIDEO_ID, upstream_audio(), client)
    await cache.wait_for_download(VIDEO_ID)

    result = await cache.get(VIDEO_ID)
    assert result is not None
    assert result.is_cached_file
    assert result.cache_status == "disk"
    assert result.content_length == 8
    assert result.cached_path is not None
    assert result.cached_path.read_bytes() == b"abcdefgh"
    assert list(tmp_path.glob("*.part")) == []

    restarted = PersistentAudioCache(tmp_path, max_bytes=100, max_file_bytes=50)
    await restarted.initialize()
    persisted = await restarted.get(VIDEO_ID)
    assert persisted is not None
    assert persisted.content_length == 8
    assert requests == 2
    await client.aclose()


@pytest.mark.asyncio
async def test_duplicate_schedules_share_one_download(tmp_path: Path) -> None:
    requests = 0

    async def delayed_stream() -> bytes:
        await asyncio.sleep(0.03)
        return b"audio"

    class DelayedStream(httpx.AsyncByteStream):
        async def __aiter__(self):
            yield await delayed_stream()

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal requests
        requests += 1
        if request.method == "HEAD":
            return httpx.Response(200, headers={"Content-Length": "5"})
        return httpx.Response(
            206,
            headers={"Content-Range": "bytes 0-4/5"},
            stream=DelayedStream(),
        )

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    cache = PersistentAudioCache(tmp_path, max_bytes=100, max_file_bytes=50)
    await cache.initialize()
    cache.schedule(VIDEO_ID, upstream_audio(), client)
    cache.schedule(VIDEO_ID, upstream_audio(), client)
    await cache.wait_for_download(VIDEO_ID)

    assert requests == 2
    assert (tmp_path / f"{VIDEO_ID}.m4a").read_bytes() == b"audio"
    await client.aclose()


@pytest.mark.asyncio
async def test_failed_download_leaves_no_partial_file(tmp_path: Path) -> None:
    client = httpx.AsyncClient(
        transport=httpx.MockTransport(lambda request: httpx.Response(403, content=b"forbidden"))
    )
    cache = PersistentAudioCache(tmp_path, max_bytes=100, max_file_bytes=50)
    await cache.initialize()
    cache.schedule(VIDEO_ID, upstream_audio(), client)
    await cache.wait_for_download(VIDEO_ID)

    assert not (tmp_path / f"{VIDEO_ID}.m4a").exists()
    assert list(tmp_path.glob("*.part")) == []
    await client.aclose()


@pytest.mark.asyncio
async def test_oversized_download_is_discarded(tmp_path: Path) -> None:
    client = httpx.AsyncClient(
        transport=httpx.MockTransport(
            lambda request: httpx.Response(200, headers={"Content-Length": "1000"})
        )
    )
    cache = PersistentAudioCache(tmp_path, max_bytes=100, max_file_bytes=50)
    await cache.initialize()
    cache.schedule(VIDEO_ID, upstream_audio(), client)
    await cache.wait_for_download(VIDEO_ID)

    assert await cache.get(VIDEO_ID) is None
    await client.aclose()


@pytest.mark.asyncio
async def test_initialization_removes_partials_and_evicts_lru(tmp_path: Path) -> None:
    oldest = tmp_path / "AAAAAAAAAAA.m4a"
    newest = tmp_path / "BBBBBBBBBBB.m4a"
    partial = tmp_path / ".AAAAAAAAAAA.deadbeef.part"
    oldest.write_bytes(b"aaaa")
    newest.write_bytes(b"bbbb")
    partial.write_bytes(b"partial")
    os.utime(oldest, ns=(1, 1))
    os.utime(newest, ns=(2, 2))

    cache = PersistentAudioCache(tmp_path, max_bytes=5, max_file_bytes=5)
    await cache.initialize()

    assert not oldest.exists()
    assert newest.exists()
    assert not partial.exists()
    assert await cache.total_bytes() == 4


@pytest.mark.asyncio
async def test_defragment_failure_falls_back_to_fragmented_file(tmp_path: Path) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "HEAD":
            return httpx.Response(200, headers={"Content-Length": "8"})
        return httpx.Response(
            206,
            headers={"Content-Range": "bytes 0-7/8"},
            stream=httpx.ByteStream(b"abcdefgh"),
        )

    client = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    cache = PersistentAudioCache(
        tmp_path, max_bytes=100, max_file_bytes=50, ffmpeg_binary="/nonexistent-ffmpeg"
    )
    await cache.initialize()
    cache.schedule(VIDEO_ID, upstream_audio(), client)
    await cache.wait_for_download(VIDEO_ID)

    result = await cache.get(VIDEO_ID)
    assert result is not None
    assert result.cached_path is not None
    assert result.cached_path.read_bytes() == b"abcdefgh"
    assert list(tmp_path.glob("*.part")) == []
    await client.aclose()


@pytest.mark.asyncio
async def test_zero_size_disables_cache(tmp_path: Path) -> None:
    cache = PersistentAudioCache(tmp_path, max_bytes=0, max_file_bytes=50)
    await cache.initialize()

    assert not cache.enabled
    assert await cache.get(VIDEO_ID) is None

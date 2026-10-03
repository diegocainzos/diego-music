from __future__ import annotations

import asyncio
import os
from pathlib import Path

import pytest

from app import audio_cache
from app.audio_cache import PersistentAudioCache
from fake_binaries import fake_ffmpeg, fake_ytdlp, process_exists


VIDEO_ID = "M7lc1UVf-VE"


def directory_listing(directory: Path) -> list[str]:
    return sorted(path.name for path in directory.iterdir())


def make_cache(
    tmp_path: Path,
    ytdlp: Path,
    ffmpeg: Path | None = None,
    max_bytes: int = 100,
    max_file_bytes: int = 50,
    cookies_file: Path | None = None,
) -> PersistentAudioCache:
    return PersistentAudioCache(
        tmp_path / "cache",
        max_bytes=max_bytes,
        max_file_bytes=max_file_bytes,
        ffmpeg_binary=str(ffmpeg) if ffmpeg is not None else "/nonexistent-ffmpeg",
        ytdlp_binary=str(ytdlp),
        cookies_file=cookies_file,
    )


@pytest.mark.asyncio
async def test_download_is_remuxed_atomic_and_reused_after_restart(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path / "bin", payload=b"abcdefgh")
    ffmpeg = fake_ffmpeg(tmp_path / "bin")
    cache = make_cache(tmp_path, ytdlp.path, ffmpeg.path)
    await cache.initialize()
    cache.schedule(VIDEO_ID)
    await cache.wait_for_download(VIDEO_ID)

    result = await cache.get(VIDEO_ID)
    assert result is not None
    assert result.cached_path is not None
    assert result.cache_status == "disk"
    assert result.cached_path.read_bytes() == b"progressive:abcdefgh"
    assert result.content_length == len(b"progressive:abcdefgh")
    # Sin temporales: solo queda el archivo final.
    assert directory_listing(tmp_path / "cache") == [f"{VIDEO_ID}.m4a"]

    restarted = make_cache(tmp_path, ytdlp.path, ffmpeg.path)
    await restarted.initialize()
    persisted = await restarted.get(VIDEO_ID)
    assert persisted is not None
    assert persisted.content_length == result.content_length
    assert len(ytdlp.calls) == 1


@pytest.mark.asyncio
async def test_ytdlp_runs_without_shell_using_a_fixed_url(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path / "bin")
    cookies = tmp_path / "cookies.txt"
    cookies.write_text("# cookies de prueba")
    cache = make_cache(tmp_path, ytdlp.path, cookies_file=cookies)
    await cache.initialize()
    cache.schedule(VIDEO_ID)
    await cache.wait_for_download(VIDEO_ID)

    (arguments,) = ytdlp.calls
    assert arguments[-2:] == ["--", f"https://www.youtube.com/watch?v={VIDEO_ID}"]
    assert "--no-playlist" in arguments
    assert "--no-cache-dir" in arguments
    assert arguments[arguments.index("--cookies") + 1] == str(cookies)
    output_template = Path(arguments[arguments.index("-o") + 1])
    assert output_template.parent == tmp_path / "cache"
    assert output_template.name.startswith(f".{VIDEO_ID}.")
    assert output_template.name.endswith(".%(ext)s")


@pytest.mark.asyncio
async def test_duplicate_schedules_share_one_download(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path / "bin", payload=b"audio", sleep=0.1)
    cache = make_cache(tmp_path, ytdlp.path)
    await cache.initialize()
    cache.schedule(VIDEO_ID)
    cache.schedule(VIDEO_ID)
    await cache.wait_for_download(VIDEO_ID)

    assert len(ytdlp.calls) == 1
    assert (tmp_path / "cache" / f"{VIDEO_ID}.m4a").read_bytes() == b"audio"


@pytest.mark.asyncio
async def test_failed_download_leaves_no_partial_file(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path / "bin", payload=b"partial", exit_code=1)
    cache = make_cache(tmp_path, ytdlp.path)
    await cache.initialize()
    cache.schedule(VIDEO_ID)
    await cache.wait_for_download(VIDEO_ID)

    assert len(ytdlp.calls) == 1
    assert await cache.get(VIDEO_ID) is None
    assert directory_listing(tmp_path / "cache") == []


@pytest.mark.asyncio
async def test_missing_ytdlp_binary_is_best_effort(tmp_path: Path) -> None:
    cache = make_cache(tmp_path, tmp_path / "bin" / "does-not-exist")
    await cache.initialize()
    cache.schedule(VIDEO_ID)
    await cache.wait_for_download(VIDEO_ID)

    assert await cache.get(VIDEO_ID) is None
    assert directory_listing(tmp_path / "cache") == []


@pytest.mark.asyncio
async def test_timeout_kills_ytdlp_and_discards_output(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(audio_cache, "_COMMAND_TIMEOUT_SECONDS", 1.0)
    ytdlp = fake_ytdlp(tmp_path / "bin", payload=b"partial", sleep=30)
    cache = make_cache(tmp_path, ytdlp.path)
    await cache.initialize()
    cache.schedule(VIDEO_ID)
    await cache.wait_for_download(VIDEO_ID)

    assert ytdlp.pid is not None
    assert not process_exists(ytdlp.pid)
    assert await cache.get(VIDEO_ID) is None
    assert directory_listing(tmp_path / "cache") == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("max_bytes", "max_file_bytes", "size", "cached"),
    [
        (100, 50, 50, True),  # justo en el límite por pista
        (100, 50, 51, False),  # supera max_file_bytes
        (20, 50, 30, False),  # supera max_bytes, que es el límite efectivo
        (100, 50, 0, False),  # salida vacía
    ],
)
async def test_download_size_is_validated(
    tmp_path: Path, max_bytes: int, max_file_bytes: int, size: int, cached: bool
) -> None:
    ytdlp = fake_ytdlp(tmp_path / "bin", payload=b"x" * size)
    cache = make_cache(tmp_path, ytdlp.path, max_bytes=max_bytes, max_file_bytes=max_file_bytes)
    await cache.initialize()
    cache.schedule(VIDEO_ID)
    await cache.wait_for_download(VIDEO_ID)

    expected = [f"{VIDEO_ID}.m4a"] if cached else []
    assert directory_listing(tmp_path / "cache") == expected
    assert (await cache.get(VIDEO_ID) is not None) is cached


@pytest.mark.asyncio
async def test_initialization_removes_partials_and_evicts_lru(tmp_path: Path) -> None:
    directory = tmp_path / "cache"
    directory.mkdir()
    oldest = directory / "AAAAAAAAAAA.m4a"
    newest = directory / "BBBBBBBBBBB.m4a"
    partial = directory / ".AAAAAAAAAAA.deadbeef.part"
    interrupted = directory / ".CCCCCCCCCCC.deadbeef.m4a"
    oldest.write_bytes(b"aaaa")
    newest.write_bytes(b"bbbb")
    partial.write_bytes(b"partial")
    interrupted.write_bytes(b"interrupted")
    os.utime(oldest, ns=(1, 1))
    os.utime(newest, ns=(2, 2))

    cache = PersistentAudioCache(directory, max_bytes=5, max_file_bytes=5)
    await cache.initialize()

    assert directory_listing(directory) == ["BBBBBBBBBBB.m4a"]


@pytest.mark.asyncio
async def test_eviction_ignores_downloads_in_progress(tmp_path: Path) -> None:
    directory = tmp_path / "cache"
    directory.mkdir()
    in_progress = directory / f".{VIDEO_ID}.deadbeef.m4a"
    in_progress.write_bytes(b"x" * 40)
    finished = directory / "AAAAAAAAAAA.m4a"
    finished.write_bytes(b"y" * 10)

    cache = PersistentAudioCache(directory, max_bytes=20, max_file_bytes=20)
    await cache._evict_if_needed()

    assert finished.exists()
    assert in_progress.exists()


@pytest.mark.asyncio
@pytest.mark.parametrize("failure", ["missing", "exit-code"])
async def test_defragment_failure_falls_back_to_fragmented_file(tmp_path: Path, failure: str) -> None:
    ytdlp = fake_ytdlp(tmp_path / "bin", payload=b"abcdefgh")
    ffmpeg = fake_ffmpeg(tmp_path / "bin", exit_code=1) if failure == "exit-code" else None
    cache = make_cache(tmp_path, ytdlp.path, ffmpeg.path if ffmpeg is not None else None)
    await cache.initialize()
    cache.schedule(VIDEO_ID)
    await cache.wait_for_download(VIDEO_ID)

    result = await cache.get(VIDEO_ID)
    assert result is not None
    assert result.cached_path is not None
    assert result.cached_path.read_bytes() == b"abcdefgh"
    assert directory_listing(tmp_path / "cache") == [f"{VIDEO_ID}.m4a"]


@pytest.mark.asyncio
async def test_defragmented_output_over_the_limit_falls_back_to_original(tmp_path: Path) -> None:
    # El remux antepone "progressive:" (12 bytes): 40 + 12 supera el límite de 50.
    ytdlp = fake_ytdlp(tmp_path / "bin", payload=b"x" * 40)
    ffmpeg = fake_ffmpeg(tmp_path / "bin")
    cache = make_cache(tmp_path, ytdlp.path, ffmpeg.path)
    await cache.initialize()
    cache.schedule(VIDEO_ID)
    await cache.wait_for_download(VIDEO_ID)

    result = await cache.get(VIDEO_ID)
    assert result is not None
    assert result.cached_path is not None
    assert result.cached_path.read_bytes() == b"x" * 40


@pytest.mark.asyncio
async def test_close_cancels_running_download_and_kills_process(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path / "bin", payload=b"partial", sleep=30)
    cache = make_cache(tmp_path, ytdlp.path)
    await cache.initialize()
    cache.schedule(VIDEO_ID)
    async with asyncio.timeout(10):
        while ytdlp.pid is None:  # esperar a que el proceso haya arrancado
            await asyncio.sleep(0.02)
    await cache.close()

    assert not process_exists(ytdlp.pid)
    assert directory_listing(tmp_path / "cache") == []


@pytest.mark.asyncio
async def test_zero_size_disables_cache(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path / "bin")
    cache = make_cache(tmp_path, ytdlp.path, max_bytes=0)
    await cache.initialize()
    cache.schedule(VIDEO_ID)

    assert not cache.enabled
    assert await cache.get(VIDEO_ID) is None
    assert ytdlp.calls == []

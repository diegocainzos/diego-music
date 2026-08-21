from __future__ import annotations

import asyncio
from pathlib import Path
import re
import secrets
from typing import Final

import anyio
import httpx

from .resolver import ResolvedAudio


_VIDEO_ID: Final[re.Pattern[str]] = re.compile(r"^[A-Za-z0-9_-]{11}$")
_CONTENT_RANGE: Final[re.Pattern[str]] = re.compile(r"^bytes\s+\d+-\d+/(\d+)$")
_DOWNLOAD_CHUNK_BYTES: Final[int] = 1_048_576


class PersistentAudioCache:
    """Caché M4A persistente, acotada y segura para un único worker."""

    def __init__(
        self,
        directory: Path | None,
        max_bytes: int,
        max_file_bytes: int,
        ffmpeg_binary: str = "ffmpeg",
        ytdlp_binary: str | None = None,
        cookies_file: Path | None = None,
    ) -> None:
        self.directory = directory
        self.max_bytes = max_bytes
        self.max_file_bytes = max_file_bytes
        self.ffmpeg_binary = ffmpeg_binary
        self.ytdlp_binary = ytdlp_binary
        self.cookies_file = cookies_file
        self._downloads: dict[str, asyncio.Task[None]] = {}
        self._maintenance_lock = asyncio.Lock()

    @property
    def enabled(self) -> bool:
        return self.directory is not None and self.max_bytes > 0

    async def initialize(self) -> None:
        if not self.enabled or self.directory is None:
            return
        await asyncio.to_thread(self.directory.mkdir, parents=True, exist_ok=True)
        await asyncio.to_thread(self._remove_partial_files)
        await self._evict_if_needed()

    async def close(self) -> None:
        tasks = list(self._downloads.values())
        for task in tasks:
            task.cancel()
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        self._downloads.clear()

    async def get(self, video_id: str) -> ResolvedAudio | None:
        path = self._path(video_id)
        if path is None:
            return None
        try:
            stat = await asyncio.to_thread(path.stat)
        except OSError:
            return None
        if not path.is_file() or stat.st_size <= 0:
            await asyncio.to_thread(path.unlink, missing_ok=True)
            return None
        await asyncio.to_thread(path.touch)
        return ResolvedAudio.from_cached_file(path=path, size=stat.st_size)

    def schedule(
        self,
        video_id: str,
        audio: ResolvedAudio | None = None,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        if not self.enabled or video_id in self._downloads:
            return
        path = self._path(video_id)
        if path is None or path.exists():
            return

        task = asyncio.create_task(self._download(video_id, audio, client))
        self._downloads[video_id] = task
        task.add_done_callback(lambda completed, key=video_id: self._finish_download(key, completed))

    def is_downloading(self, video_id: str) -> bool:
        return video_id in self._downloads

    async def wait_for_download(self, video_id: str) -> None:
        task = self._downloads.get(video_id)
        if task is not None:
            await asyncio.shield(task)

    async def total_bytes(self) -> int:
        if not self.enabled or self.directory is None:
            return 0
        return await asyncio.to_thread(
            lambda: sum(path.stat().st_size for path in self.directory.glob("*.m4a") if path.is_file())
        )

    async def _download(
        self,
        video_id: str,
        audio: ResolvedAudio | None = None,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        assert self.directory is not None
        destination = self.directory / f"{video_id}.m4a"
        temporary_prefix = self.directory / f".{video_id}.{secrets.token_hex(8)}"
        temporary_output = self.directory / f"{temporary_prefix.name}.%(ext)s"
        expected_part = self.directory / f"{temporary_prefix.name}.m4a"

        if self.ytdlp_binary is not None:
            cmd = [
                self.ytdlp_binary,
                "--no-playlist",
                "--no-warnings",
                "--quiet",
                "--no-cache-dir",
                "-f",
                "bestaudio[ext=m4a][acodec^=mp4a]/bestaudio[ext=m4a]/bestaudio",
                "--extractor-args",
                "youtube:player_client=web_embedded,android,web",
                "-x",
                "--audio-format",
                "m4a",
                "--ffmpeg-location",
                self.ffmpeg_binary,
                "-o",
                str(temporary_output),
                "--force-overwrites",
            ]
            if self.cookies_file is not None:
                cmd.extend(["--cookies", str(self.cookies_file)])
            cmd.extend(["--", f"https://www.youtube.com/watch?v={video_id}"])

            try:
                proc = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.DEVNULL,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                await asyncio.wait_for(proc.communicate(), timeout=60.0)
                if proc.returncode == 0 and expected_part.is_file() and expected_part.stat().st_size > 0:
                    final = await self._defragment(expected_part) or expected_part
                    await asyncio.to_thread(final.replace, destination)
                    await asyncio.to_thread(destination.touch)
                    await self._evict_if_needed()
                    return
            except (OSError, asyncio.TimeoutError):
                pass
            finally:
                for p in self.directory.glob(f"{temporary_prefix.name}.*"):
                    try:
                        p.unlink()
                    except OSError:
                        pass

        if client is not None and audio.upstream_url is not None:
            temporary = self.directory / f".{video_id}.{secrets.token_hex(8)}.part"
            effective_file_limit = min(self.max_file_bytes, self.max_bytes)
            headers = {
                name: value
                for name, value in audio.headers.items()
                if name.lower() != "accept-encoding"
            }

            try:
                content_length = await self._content_length(
                    client=client,
                    url=audio.upstream_url,
                    headers=headers,
                )
                if content_length is None or not 0 < content_length <= effective_file_limit:
                    return

                written = 0
                async with await anyio.open_file(temporary, "wb") as target:
                    while written < content_length:
                        end = min(written + _DOWNLOAD_CHUNK_BYTES, content_length) - 1
                        range_headers = {**headers, "Range": f"bytes={written}-{end}"}
                        async with client.stream("GET", audio.upstream_url, headers=range_headers) as response:
                            if response.status_code != 206:
                                return
                            expected = end - written + 1
                            range_written = 0
                            async for chunk in response.aiter_raw():
                                if not chunk:
                                    continue
                                range_written += len(chunk)
                                if range_written > expected:
                                    return
                                await target.write(chunk)
                            if range_written != expected:
                                return
                            written += range_written
                    await target.flush()

                if written != content_length:
                    return
                # Los fMP4 de YouTube declaran la duración en mvhd Y en los
                # fragmentos; AVFoundation los suma y muestra el doble. Remux a
                # MP4 progresivo (stream copy) para dejar una única fuente.
                final = await self._defragment(temporary) or temporary
                await asyncio.to_thread(final.replace, destination)
                await asyncio.to_thread(destination.touch)
                await self._evict_if_needed()
            except asyncio.CancelledError:
                raise
            except (OSError, httpx.HTTPError):
                return
            finally:
                await asyncio.to_thread(temporary.unlink, missing_ok=True)
                await asyncio.to_thread(self._defrag_temp_for(temporary).unlink, missing_ok=True)

    async def _defragment(self, source: Path) -> Path | None:
        """Remux fMP4 -> MP4 progresivo; None si falla (best-effort)."""
        target = self._defrag_temp_for(source)
        try:
            process = await asyncio.create_subprocess_exec(
                self.ffmpeg_binary,
                "-y", "-v", "error", "-i", str(source),
                "-c", "copy", "-movflags", "+faststart", "-f", "mp4", str(target),
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
            await asyncio.wait_for(process.communicate(), timeout=60)
            if process.returncode != 0:
                return None
            stat = await asyncio.to_thread(target.stat)
            return target if stat.st_size > 0 else None
        except (OSError, asyncio.TimeoutError):
            return None

    @staticmethod
    def _defrag_temp_for(source: Path) -> Path:
        return source.with_suffix(".mux.part")

    async def _content_length(
        self,
        client: httpx.AsyncClient,
        url: str,
        headers: dict[str, str],
    ) -> int | None:
        try:
            response = await client.head(url, headers=headers)
            if response.status_code == 200:
                declared = response.headers.get("content-length")
                if declared is not None:
                    return int(declared)
        except (ValueError, httpx.HTTPError):
            pass

        probe_headers = {**headers, "Range": "bytes=0-0"}
        try:
            async with client.stream("GET", url, headers=probe_headers) as response:
                if response.status_code != 206:
                    return None
                match = _CONTENT_RANGE.fullmatch(response.headers.get("content-range", ""))
                return int(match.group(1)) if match else None
        except (ValueError, httpx.HTTPError):
            return None

    async def _evict_if_needed(self) -> None:
        if not self.enabled or self.directory is None:
            return
        async with self._maintenance_lock:
            await asyncio.to_thread(self._evict_sync)

    def _evict_sync(self) -> None:
        assert self.directory is not None
        entries: list[tuple[int, int, Path]] = []
        for path in self.directory.glob("*.m4a"):
            try:
                stat = path.stat()
            except OSError:
                continue
            entries.append((stat.st_mtime_ns, stat.st_size, path))

        total = sum(size for _, size, _ in entries)
        for _, size, path in sorted(entries):
            if total <= self.max_bytes:
                break
            try:
                path.unlink()
            except OSError:
                continue
            total -= size

    def _remove_partial_files(self) -> None:
        assert self.directory is not None
        for path in self.directory.glob(".*.part"):
            try:
                path.unlink()
            except OSError:
                pass

    def _path(self, video_id: str) -> Path | None:
        if not self.enabled or self.directory is None:
            return None
        if _VIDEO_ID.fullmatch(video_id) is None:
            raise ValueError("videoId no válido para caché")
        return self.directory / f"{video_id}.m4a"

    def _finish_download(self, video_id: str, task: asyncio.Task[None]) -> None:
        current = self._downloads.get(video_id)
        if current is task:
            self._downloads.pop(video_id, None)
        try:
            task.exception()
        except (asyncio.CancelledError, asyncio.InvalidStateError):
            pass

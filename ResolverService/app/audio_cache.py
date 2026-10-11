from __future__ import annotations

import asyncio
from collections.abc import Sequence
import os
from pathlib import Path
import re
import secrets
import shutil
import tempfile
from typing import Final

from .resolver import ResolvedAudio


_VIDEO_ID: Final[re.Pattern[str]] = re.compile(r"^[A-Za-z0-9_-]{11}$")
_COMMAND_TIMEOUT_SECONDS: Final[float] = 60.0


class PersistentAudioCache:
    """Caché M4A persistente, acotada y segura para un único worker."""

    def __init__(
        self,
        directory: Path | None,
        max_bytes: int,
        max_file_bytes: int,
        ffmpeg_binary: str = "ffmpeg",
        ytdlp_binary: str = "yt-dlp",
        cookies_file: Path | None = None,
        info_directory: Path | None = None,
        max_concurrent_downloads: int = 2,
    ) -> None:
        self.directory = directory
        self.max_bytes = max_bytes
        self.max_file_bytes = max_file_bytes
        # yt-dlp trata `--ffmpeg-location ffmpeg` como ruta literal (no busca en PATH):
        # se resuelve aquí a ruta absoluta para no perder el postprocesado.
        self.ffmpeg_binary = shutil.which(ffmpeg_binary) or ffmpeg_binary
        self.ytdlp_binary = ytdlp_binary
        self.cookies_file = cookies_file
        self.info_directory = Path(tempfile.gettempdir()) if info_directory is None else info_directory
        self._download_slots = asyncio.Semaphore(max_concurrent_downloads)
        self._downloads: dict[str, asyncio.Task[None]] = {}
        self._maintenance_lock = asyncio.Lock()

    @property
    def enabled(self) -> bool:
        return self.directory is not None and self.max_bytes > 0

    async def initialize(self) -> None:
        if not self.enabled or self.directory is None:
            return
        await asyncio.to_thread(self.directory.mkdir, parents=True, exist_ok=True)
        await asyncio.to_thread(self.info_directory.mkdir, parents=True, exist_ok=True)
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

    def schedule(self, video_id: str, info: bytes | None = None) -> None:
        if not self.enabled or video_id in self._downloads:
            return
        path = self._path(video_id)
        if path is None or path.exists():
            return

        task = asyncio.create_task(self._download(video_id, info))
        self._downloads[video_id] = task
        task.add_done_callback(lambda completed, key=video_id: self._finish_download(key, completed))

    async def wait_for_download(self, video_id: str) -> None:
        task = self._downloads.get(video_id)
        if task is not None:
            await asyncio.shield(task)

    async def _download(self, video_id: str, info: bytes | None = None) -> None:
        """Descarga con yt-dlp a un temporal oculto y lo publica con un renombrado atómico."""
        assert self.directory is not None
        destination = self.directory / f"{video_id}.m4a"
        stem = f".{video_id}.{secrets.token_hex(8)}"
        downloaded = self.directory / f"{stem}.m4a"

        async with self._download_slots:
            info_path: Path | None = None
            try:
                if info is not None:
                    def _write_info() -> str:
                        self.info_directory.mkdir(parents=True, exist_ok=True)
                        fd, path_str = tempfile.mkstemp(
                            prefix=".info-",
                            suffix=".json",
                            dir=str(self.info_directory),
                        )
                        try:
                            os.write(fd, info)
                        finally:
                            os.close(fd)
                        return path_str

                    info_path = Path(await asyncio.to_thread(_write_info))

                returncode = await self._run(
                    self._ytdlp_command(
                        video_id,
                        self.directory / f"{stem}.%(ext)s",
                        info_path=info_path,
                    )
                )
                if returncode != 0 or not await asyncio.to_thread(self._is_within_limits, downloaded):
                    return
                # Los fMP4 de YouTube declaran la duración en mvhd Y en los
                # fragmentos; AVFoundation los suma y muestra el doble. Remux a
                # MP4 progresivo (stream copy) para dejar una única fuente.
                final = await self._defragment(downloaded)
                if final is None or not await asyncio.to_thread(self._is_within_limits, final):
                    final = downloaded
                await asyncio.to_thread(final.replace, destination)
                await asyncio.to_thread(destination.touch)
                await self._evict_if_needed()
            except OSError:
                return  # el calentamiento es best-effort: la reproducción upstream continúa
            finally:
                if info_path is not None:
                    try:
                        os.unlink(info_path)
                    except OSError:
                        pass
                for leftover in self.directory.glob(f"{stem}.*"):
                    try:
                        leftover.unlink()
                    except OSError:
                        pass

    def _ytdlp_command(
        self,
        video_id: str,
        output_template: Path,
        info_path: Path | None = None,
    ) -> list[str]:
        common = [
            self.ytdlp_binary,
            "--no-warnings",
            "--quiet",
            "--no-cache-dir",
            "--fixup",
            "never",
            "-o",
            str(output_template),
            "--force-overwrites",
        ]
        if info_path is not None:
            return common + ["--load-info-json", str(info_path)]

        command = common + [
            "--no-playlist",
            "-f",
            "bestaudio[ext=m4a][acodec^=mp4a]/bestaudio[ext=m4a]",
            "--extractor-args",
            "youtube:player_client=ios,web,mweb,web_embedded",
        ]
        if self.cookies_file is not None:
            command.extend(["--cookies", str(self.cookies_file)])
        command.extend(["--", f"https://www.youtube.com/watch?v={video_id}"])
        return command

    async def _defragment(self, source: Path) -> Path | None:
        """Remux fMP4 -> MP4 progresivo; None si falla (best-effort)."""
        target = source.with_suffix(".mux.part")
        returncode = await self._run(
            [
                self.ffmpeg_binary,
                "-y", "-v", "error", "-i", str(source),
                "-c", "copy", "-movflags", "+faststart", "-f", "mp4", str(target),
            ]
        )
        return target if returncode == 0 else None

    @staticmethod
    async def _run(command: Sequence[str]) -> int | None:
        """Ejecuta sin shell ni salida y lo mata si expira. None si no arranca o expira."""
        try:
            process = await asyncio.create_subprocess_exec(
                *command,
                stdin=asyncio.subprocess.DEVNULL,
                stdout=asyncio.subprocess.DEVNULL,
                stderr=asyncio.subprocess.DEVNULL,
            )
        except OSError:
            return None
        try:
            await asyncio.wait_for(process.wait(), timeout=_COMMAND_TIMEOUT_SECONDS)
        except asyncio.TimeoutError:
            return None
        finally:
            if process.returncode is None:
                process.kill()
                await process.wait()
        return process.returncode

    def _is_within_limits(self, path: Path) -> bool:
        try:
            size = path.stat().st_size
        except OSError:
            return False
        return 0 < size <= min(self.max_file_bytes, self.max_bytes)

    async def _evict_if_needed(self) -> None:
        if not self.enabled or self.directory is None:
            return
        async with self._maintenance_lock:
            await asyncio.to_thread(self._evict_sync)

    def _evict_sync(self) -> None:
        assert self.directory is not None
        entries: list[tuple[int, int, Path]] = []
        for path in self.directory.glob("*.m4a"):
            if path.name.startswith("."):
                continue  # descarga en curso
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
        """Elimina los temporales ocultos que dejó una descarga interrumpida."""
        assert self.directory is not None
        for path in self.directory.glob(".*"):
            if not path.is_file():
                continue
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

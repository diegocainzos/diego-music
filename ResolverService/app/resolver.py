from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import datetime, timezone
import json
from pathlib import Path
import re
from typing import Any, Literal, Mapping, Protocol
from urllib.parse import parse_qs, urlsplit

from .config import Settings


_ALLOWED_UPSTREAM_HEADERS = {
    "accept",
    "accept-encoding",
    "accept-language",
    "cookie",
    "origin",
    "referer",
    "user-agent",
}

_VIDEO_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{11}$")


class AudioResolutionError(RuntimeError):
    def __init__(self, public_message: str = "No se pudo resolver una pista de audio compatible.") -> None:
        super().__init__(public_message)
        self.public_message = public_message


@dataclass(frozen=True, slots=True)
class ResolvedAudio:
    upstream_url: str | None
    headers: Mapping[str, str]
    content_type: str
    upstream_expires_at: datetime | None = None
    cached_path: Path | None = None
    content_length: int | None = None
    cache_status: Literal["miss", "resolution", "disk"] = "miss"

    @classmethod
    def from_cached_file(cls, path: Path, size: int) -> "ResolvedAudio":
        return cls(
            upstream_url=None,
            headers={},
            content_type="audio/mp4",
            cached_path=path,
            content_length=size,
            cache_status="disk",
        )


class AudioResolving(Protocol):
    async def resolve(self, video_id: str) -> ResolvedAudio: ...


class YTDLPResolver:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def resolve(self, video_id: str) -> ResolvedAudio:
        arguments = self._arguments(video_id)
        try:
            process = await asyncio.create_subprocess_exec(
                *arguments,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
        except OSError as error:
            raise AudioResolutionError("El ejecutable del resolutor no está disponible.") from error

        try:
            stdout, _ = await asyncio.wait_for(
                process.communicate(),
                timeout=self.settings.resolve_timeout_seconds,
            )
        except TimeoutError as error:
            process.kill()
            await process.communicate()
            raise AudioResolutionError("La resolución de la pista agotó el tiempo disponible.") from error

        if process.returncode != 0:
            raise AudioResolutionError()
        if len(stdout) > 5_000_000:
            raise AudioResolutionError("El resolutor devolvió una respuesta inesperada.")

        try:
            info = json.loads(stdout)
        except (json.JSONDecodeError, UnicodeDecodeError) as error:
            raise AudioResolutionError("El resolutor devolvió una respuesta inválida.") from error

        return self._parse_info(info)

    async def search(self, query: str, limit: int = 15) -> list[dict[str, str]]:
        arguments = [
            self.settings.ytdlp_binary,
            "--dump-single-json",
            "--no-warnings",
            "--quiet",
            "--no-cache-dir",
            "--skip-download",
            "--flat-playlist",
            "--extractor-args",
            "youtube:player_client=ios,web,mweb,web_embedded",
            f"ytsearch{limit}:{query}",
        ]
        if self.settings.cookies_file is not None:
            arguments.extend(["--cookies", str(self.settings.cookies_file)])

        try:
            process = await asyncio.create_subprocess_exec(
                *arguments,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await asyncio.wait_for(
                process.communicate(),
                timeout=self.settings.resolve_timeout_seconds,
            )
        except (OSError, TimeoutError) as error:
            raise AudioResolutionError("No se pudo realizar la búsqueda alternativa.") from error

        if process.returncode != 0 or not stdout:
            return []

        try:
            info = json.loads(stdout)
        except (json.JSONDecodeError, UnicodeDecodeError):
            return []

        entries = info.get("entries", [])
        results: list[dict[str, str]] = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            video_id = entry.get("id")
            title = entry.get("title")
            if not video_id or not title:
                continue
            channel = entry.get("uploader") or entry.get("channel") or entry.get("uploader_id") or "Desconocido"
            thumbnail = f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"
            results.append({
                "id": str(video_id),
                "kind": "video",
                "title": str(title),
                "channelTitle": str(channel),
                "thumbnailURL": thumbnail,
            })
        return results

    async def radio(self, video_id: str, limit: int = 30) -> list[dict[str, str | int | None]]:
        arguments = [
            self.settings.ytdlp_binary,
            "--dump-single-json",
            "--no-warnings",
            "--quiet",
            "--no-cache-dir",
            "--skip-download",
            "--flat-playlist",
            "--playlist-end",
            str(limit),
            "--extractor-args",
            "youtube:player_client=ios,web,mweb,web_embedded",
            f"https://www.youtube.com/watch?v={video_id}&list=RD{video_id}",
        ]
        if self.settings.cookies_file is not None:
            arguments.extend(["--cookies", str(self.settings.cookies_file)])

        process: asyncio.subprocess.Process | None = None
        try:
            process = await asyncio.create_subprocess_exec(
                *arguments,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await asyncio.wait_for(
                process.communicate(),
                timeout=self.settings.resolve_timeout_seconds,
            )
        except TimeoutError as error:
            if process is not None:
                process.kill()
                await process.communicate()
            raise AudioResolutionError("No se pudo generar la radio.") from error
        except OSError as error:
            raise AudioResolutionError("No se pudo generar la radio.") from error

        if process.returncode != 0 or not stdout:
            return []

        try:
            info = json.loads(stdout)
        except (json.JSONDecodeError, UnicodeDecodeError):
            return []

        if not isinstance(info, dict):
            return []

        entries = info.get("entries", [])
        if not isinstance(entries, list):
            return []

        results: list[dict[str, str | int | None]] = []
        seen_ids: set[str] = set()
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            entry_id = entry.get("id")
            if (
                not isinstance(entry_id, str)
                or not _VIDEO_ID_PATTERN.match(entry_id)
                or entry_id == video_id
            ):
                continue
            if entry_id in seen_ids:
                continue
            seen_ids.add(entry_id)

            raw_duration = entry.get("duration") if entry.get("duration") is not None else entry.get("duration_seconds")
            duration_seconds: int | None = None
            if raw_duration is not None:
                try:
                    duration_seconds = int(raw_duration)
                except (ValueError, TypeError):
                    duration_seconds = None

            channel = entry.get("channel") or entry.get("uploader") or ""
            results.append({
                "id": entry_id,
                "title": str(entry.get("title") or ""),
                "channel": str(channel),
                "duration_seconds": duration_seconds,
            })
            if len(results) >= limit:
                break

        return results

    async def get_artist_detail(self, artist_id: str) -> dict[str, Any]:
        top_tracks = await self.search(f"{artist_id} tracks", limit=15)
        related = await self.search(f"{artist_id} radio", limit=8)

        return {
            "artist": {
                "id": artist_id,
                "title": artist_id,
                "bio": "Perfil de artista del servicio VPS",
                "thumbnailURL": top_tracks[0]["thumbnailURL"] if top_tracks else None,
            },
            "topTracks": top_tracks,
            "related": related,
        }

    def _arguments(self, video_id: str) -> list[str]:
        arguments = [
            self.settings.ytdlp_binary,
            "--dump-single-json",
            "--no-playlist",
            "--no-warnings",
            "--quiet",
            "--no-cache-dir",
            "--skip-download",
            "--format",
            "bestaudio[ext=m4a][acodec^=mp4a]/bestaudio[ext=m4a]",
            "--extractor-args",
            "youtube:player_client=ios,web,mweb,web_embedded",
        ]
        if self.settings.cookies_file is not None:
            arguments.extend(["--cookies", str(self.settings.cookies_file)])
        arguments.extend(["--", f"https://www.youtube.com/watch?v={video_id}"])
        return arguments

    def _parse_info(self, info: object) -> ResolvedAudio:
        if not isinstance(info, dict):
            raise AudioResolutionError("El resolutor devolvió una respuesta inválida.")

        upstream_url = info.get("url")
        extension = info.get("ext")
        audio_codec = info.get("acodec")
        video_codec = info.get("vcodec")
        if (
            not isinstance(upstream_url, str)
            or extension != "m4a"
            or not isinstance(audio_codec, str)
            or not audio_codec.startswith("mp4a")
            or video_codec not in (None, "none")
        ):
            raise AudioResolutionError("Este contenido no ofrece una pista M4A/AAC compatible.")

        parsed = urlsplit(upstream_url)
        hostname = (parsed.hostname or "").lower()
        if parsed.scheme != "https" or not (hostname == "googlevideo.com" or hostname.endswith(".googlevideo.com")):
            raise AudioResolutionError("El resolutor devolvió un origen multimedia no permitido.")

        raw_headers = info.get("http_headers")
        headers: dict[str, str] = {}
        if isinstance(raw_headers, dict):
            for name, value in raw_headers.items():
                if isinstance(name, str) and isinstance(value, str) and name.lower() in _ALLOWED_UPSTREAM_HEADERS:
                    headers[name] = value

        return ResolvedAudio(
            upstream_url=upstream_url,
            headers=headers,
            content_type="audio/mp4",
            upstream_expires_at=_expiration_from_url(upstream_url),
        )


def _expiration_from_url(url: str) -> datetime | None:
    values = parse_qs(urlsplit(url).query).get("expire")
    if not values:
        return None
    try:
        return datetime.fromtimestamp(int(values[0]), tz=timezone.utc)
    except (ValueError, OverflowError):
        return None

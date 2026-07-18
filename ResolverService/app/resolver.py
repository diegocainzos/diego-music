from __future__ import annotations

import asyncio
from dataclasses import dataclass
from datetime import datetime, timezone
import json
from pathlib import Path
from typing import Mapping, Protocol
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


class AudioResolutionError(RuntimeError):
    def __init__(self, public_message: str = "No se pudo resolver una pista de audio compatible.") -> None:
        super().__init__(public_message)
        self.public_message = public_message


@dataclass(frozen=True, slots=True)
class ResolvedAudio:
    upstream_url: str
    headers: Mapping[str, str]
    content_type: str
    upstream_expires_at: datetime | None = None


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

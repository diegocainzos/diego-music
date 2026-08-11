from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
from urllib.parse import urlsplit


class ConfigurationError(RuntimeError):
    """Configuración inválida sin incluir valores sensibles en el mensaje."""


@dataclass(frozen=True, slots=True)
class Settings:
    api_token: str
    public_base_url: str
    session_ttl_seconds: int = 14_400
    resolve_timeout_seconds: float = 35.0
    upstream_timeout_seconds: float = 30.0
    ytdlp_binary: str = "yt-dlp"
    cookies_file: Path | None = None
    resolution_cache_max_entries: int = 500
    resolution_cache_ttl_seconds: int = 10_800
    resolution_cache_safety_margin_seconds: int = 300
    audio_cache_directory: Path | None = None
    audio_cache_max_bytes: int = 0
    audio_cache_max_file_bytes: int = 268_435_456
    artist_cache_max_entries: int = 1000
    artist_cache_ttl_seconds: int = 86_400

    def __post_init__(self) -> None:
        if len(self.api_token) < 32:
            raise ConfigurationError("DIEGOMUSIC_API_TOKEN debe tener al menos 32 caracteres.")

        parsed = urlsplit(self.public_base_url)
        if parsed.scheme != "https" or not parsed.netloc or parsed.query or parsed.fragment:
            raise ConfigurationError("PUBLIC_BASE_URL debe ser una URL HTTPS sin query ni fragmento.")

        if not 60 <= self.session_ttl_seconds <= 21_600:
            raise ConfigurationError("SESSION_TTL_SECONDS debe estar entre 60 y 21600.")
        if self.resolve_timeout_seconds <= 0 or self.upstream_timeout_seconds <= 0:
            raise ConfigurationError("Los timeouts deben ser positivos.")
        if self.cookies_file is not None and not self.cookies_file.is_file():
            raise ConfigurationError("YTDLP_COOKIES_FILE no apunta a un archivo legible.")
        if not 0 <= self.resolution_cache_max_entries <= 10_000:
            raise ConfigurationError("RESOLUTION_CACHE_MAX_ENTRIES debe estar entre 0 y 10000.")
        if not 60 <= self.resolution_cache_ttl_seconds <= 21_600:
            raise ConfigurationError("RESOLUTION_CACHE_TTL_SECONDS debe estar entre 60 y 21600.")
        if not 0 <= self.resolution_cache_safety_margin_seconds <= 3_600:
            raise ConfigurationError("RESOLUTION_CACHE_SAFETY_MARGIN_SECONDS debe estar entre 0 y 3600.")
        if not 0 <= self.artist_cache_max_entries <= 10_000:
            raise ConfigurationError("ARTIST_CACHE_MAX_ENTRIES debe estar entre 0 y 10000.")
        if not 60 <= self.artist_cache_ttl_seconds <= 604_800:
            raise ConfigurationError("ARTIST_CACHE_TTL_SECONDS debe estar entre 60 y 604800.")
        if self.audio_cache_max_bytes < 0 or self.audio_cache_max_file_bytes <= 0:
            raise ConfigurationError("Los límites de AUDIO_CACHE deben ser positivos.")
        if self.audio_cache_max_bytes > 0 and self.audio_cache_directory is None:
            raise ConfigurationError("AUDIO_CACHE_DIR es obligatorio cuando la caché persistente está activa.")

        object.__setattr__(self, "public_base_url", self.public_base_url.rstrip("/"))

    @classmethod
    def from_environment(cls) -> "Settings":
        token = os.getenv("DIEGOMUSIC_API_TOKEN", "")
        public_base_url = os.getenv("PUBLIC_BASE_URL", "")
        cookies_value = os.getenv("YTDLP_COOKIES_FILE", "").strip()
        audio_cache_value = os.getenv("AUDIO_CACHE_DIR", "/var/cache/diegomusic").strip()

        try:
            ttl = int(os.getenv("SESSION_TTL_SECONDS", "14400"))
            resolve_timeout = float(os.getenv("RESOLVE_TIMEOUT_SECONDS", "35"))
            upstream_timeout = float(os.getenv("UPSTREAM_TIMEOUT_SECONDS", "30"))
            resolution_entries = int(os.getenv("RESOLUTION_CACHE_MAX_ENTRIES", "500"))
            resolution_ttl = int(os.getenv("RESOLUTION_CACHE_TTL_SECONDS", "10800"))
            resolution_margin = int(os.getenv("RESOLUTION_CACHE_SAFETY_MARGIN_SECONDS", "300"))
            audio_cache_max = int(os.getenv("AUDIO_CACHE_MAX_BYTES", "5368709120"))
            audio_cache_file_max = int(os.getenv("AUDIO_CACHE_MAX_FILE_BYTES", "268435456"))
            artist_entries = int(os.getenv("ARTIST_CACHE_MAX_ENTRIES", "1000"))
            artist_ttl = int(os.getenv("ARTIST_CACHE_TTL_SECONDS", "86400"))
        except ValueError as error:
            raise ConfigurationError("Una variable numérica del servicio no es válida.") from error

        return cls(
            api_token=token,
            public_base_url=public_base_url,
            session_ttl_seconds=ttl,
            resolve_timeout_seconds=resolve_timeout,
            upstream_timeout_seconds=upstream_timeout,
            ytdlp_binary=os.getenv("YTDLP_BINARY", "yt-dlp"),
            cookies_file=Path(cookies_value) if cookies_value else None,
            resolution_cache_max_entries=resolution_entries,
            resolution_cache_ttl_seconds=resolution_ttl,
            resolution_cache_safety_margin_seconds=resolution_margin,
            audio_cache_directory=Path(audio_cache_value) if audio_cache_value else None,
            audio_cache_max_bytes=audio_cache_max,
            audio_cache_max_file_bytes=audio_cache_file_max,
            artist_cache_max_entries=artist_entries,
            artist_cache_ttl_seconds=artist_ttl,
        )

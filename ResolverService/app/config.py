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

        object.__setattr__(self, "public_base_url", self.public_base_url.rstrip("/"))

    @classmethod
    def from_environment(cls) -> "Settings":
        token = os.getenv("DIEGOMUSIC_API_TOKEN", "")
        public_base_url = os.getenv("PUBLIC_BASE_URL", "")
        cookies_value = os.getenv("YTDLP_COOKIES_FILE", "").strip()

        try:
            ttl = int(os.getenv("SESSION_TTL_SECONDS", "14400"))
            resolve_timeout = float(os.getenv("RESOLVE_TIMEOUT_SECONDS", "35"))
            upstream_timeout = float(os.getenv("UPSTREAM_TIMEOUT_SECONDS", "30"))
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
        )

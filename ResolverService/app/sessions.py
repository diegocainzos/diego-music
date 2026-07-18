from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import secrets

from .resolver import ResolvedAudio


@dataclass(frozen=True, slots=True)
class AudioSession:
    token: str
    audio: ResolvedAudio
    expires_at: datetime


class SessionNotFoundError(LookupError):
    pass


class SessionExpiredError(LookupError):
    pass


class SessionStore:
    def __init__(
        self,
        ttl_seconds: int,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        self.ttl_seconds = ttl_seconds
        self.clock = clock or (lambda: datetime.now(timezone.utc))
        self._sessions: dict[str, AudioSession] = {}

    def create(self, audio: ResolvedAudio) -> AudioSession:
        now = self.clock()
        expires_at = now + timedelta(seconds=self.ttl_seconds)
        if audio.upstream_expires_at is not None:
            safe_upstream_expiration = audio.upstream_expires_at - timedelta(seconds=60)
            expires_at = min(expires_at, safe_upstream_expiration)
        if expires_at <= now:
            raise SessionExpiredError("El origen ya está expirado.")

        token = secrets.token_urlsafe(32)
        session = AudioSession(token=token, audio=audio, expires_at=expires_at)
        self._sessions[token] = session
        self._remove_expired(excluding=token)
        return session

    def get(self, token: str) -> AudioSession:
        session = self._sessions.get(token)
        if session is None:
            raise SessionNotFoundError
        if session.expires_at <= self.clock():
            self._sessions.pop(token, None)
            raise SessionExpiredError
        return session

    def _remove_expired(self, excluding: str) -> None:
        now = self.clock()
        expired = [
            token
            for token, session in self._sessions.items()
            if token != excluding and session.expires_at <= now
        ]
        for token in expired:
            self._sessions.pop(token, None)

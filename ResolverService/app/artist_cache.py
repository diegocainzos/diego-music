from __future__ import annotations

from collections import OrderedDict
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any


@dataclass(frozen=True, slots=True)
class ArtistCacheEntry:
    data: dict[str, Any]
    expires_at: datetime


class ArtistCache:
    """Caché LRU en memoria del servidor para detalles y perfiles de artistas."""

    def __init__(
        self,
        max_entries: int = 1000,
        ttl_seconds: int = 86_400,
        clock: Any = None,
    ) -> None:
        self.max_entries = max_entries
        self.ttl_seconds = ttl_seconds
        self.clock = clock or (lambda: datetime.now(timezone.utc))
        self._entries: OrderedDict[str, ArtistCacheEntry] = OrderedDict()

    def get(self, key: str) -> dict[str, Any] | None:
        if self.max_entries <= 0:
            return None
        norm_key = key.strip().lower()
        entry = self._entries.get(norm_key)
        if entry is None:
            return None
        if entry.expires_at <= self.clock():
            self._entries.pop(norm_key, None)
            return None
        self._entries.move_to_end(norm_key)
        return entry.data

    def set(self, key: str, data: dict[str, Any]) -> None:
        if self.max_entries <= 0:
            return
        norm_key = key.strip().lower()
        now = self.clock()
        expires_at = now + timedelta(seconds=self.ttl_seconds)

        self._entries[norm_key] = ArtistCacheEntry(
            data=data,
            expires_at=expires_at,
        )
        self._entries.move_to_end(norm_key)
        while len(self._entries) > self.max_entries:
            self._entries.popitem(last=False)

    def invalidate(self, key: str) -> None:
        norm_key = key.strip().lower()
        self._entries.pop(norm_key, None)

    def clear(self) -> None:
        self._entries.clear()

    @property
    def entry_count(self) -> int:
        self._remove_expired()
        return len(self._entries)

    def _remove_expired(self) -> None:
        now = self.clock()
        expired = [k for k, entry in self._entries.items() if entry.expires_at <= now]
        for k in expired:
            self._entries.pop(k, None)

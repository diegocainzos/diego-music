from __future__ import annotations

import asyncio
from collections import OrderedDict
from collections.abc import Callable
from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone
import weakref

from .resolver import AudioResolving, ResolvedAudio


@dataclass(frozen=True, slots=True)
class ResolutionCacheEntry:
    audio: ResolvedAudio
    expires_at: datetime


class CachingAudioResolver:
    """LRU temporal con un único resolve simultáneo por videoId."""

    def __init__(
        self,
        resolver: AudioResolving,
        max_entries: int,
        ttl_seconds: int,
        safety_margin_seconds: int,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        self.resolver = resolver
        self.max_entries = max_entries
        self.ttl_seconds = ttl_seconds
        self.safety_margin_seconds = safety_margin_seconds
        self.clock = clock or (lambda: datetime.now(timezone.utc))
        self._entries: OrderedDict[str, ResolutionCacheEntry] = OrderedDict()
        self._locks: weakref.WeakValueDictionary[str, asyncio.Lock] = weakref.WeakValueDictionary()

    async def resolve(self, video_id: str) -> ResolvedAudio:
        if self.max_entries == 0:
            return await self.resolver.resolve(video_id)

        if cached := self._get(video_id):
            return cached

        lock = self._locks.get(video_id)
        if lock is None:
            lock = asyncio.Lock()
            self._locks[video_id] = lock

        async with lock:
            if cached := self._get(video_id):
                return cached

            audio = await self.resolver.resolve(video_id)
            self._put(video_id, audio)
            return replace(audio, cache_status="miss")

    def invalidate(self, video_id: str) -> None:
        self._entries.pop(video_id, None)

    @property
    def entry_count(self) -> int:
        self._remove_expired()
        return len(self._entries)

    def _get(self, video_id: str) -> ResolvedAudio | None:
        entry = self._entries.get(video_id)
        if entry is None:
            return None
        if entry.expires_at <= self.clock():
            self._entries.pop(video_id, None)
            return None
        self._entries.move_to_end(video_id)
        return replace(entry.audio, cache_status="resolution")

    def _put(self, video_id: str, audio: ResolvedAudio) -> None:
        if audio.is_cached_file:
            return
        now = self.clock()
        expires_at = now + timedelta(seconds=self.ttl_seconds)
        if audio.upstream_expires_at is not None:
            expires_at = min(
                expires_at,
                audio.upstream_expires_at - timedelta(seconds=self.safety_margin_seconds),
            )
        if expires_at <= now:
            return

        self._entries[video_id] = ResolutionCacheEntry(
            audio=replace(audio, cache_status="resolution"),
            expires_at=expires_at,
        )
        self._entries.move_to_end(video_id)
        while len(self._entries) > self.max_entries:
            self._entries.popitem(last=False)

    def _remove_expired(self) -> None:
        now = self.clock()
        expired = [key for key, entry in self._entries.items() if entry.expires_at <= now]
        for key in expired:
            self._entries.pop(key, None)

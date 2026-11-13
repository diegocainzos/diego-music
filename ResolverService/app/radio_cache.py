from __future__ import annotations

import asyncio
from collections import OrderedDict
from collections.abc import Awaitable, Callable
from datetime import datetime, timedelta, timezone
from typing import Any


class RadioCache:
    """Caché LRU+TTL en memoria de Mixes de radio, con single-flight por video."""

    def __init__(self, max_entries: int = 500, ttl_seconds: int = 21_600, clock: Any = None) -> None:
        self.max_entries = max_entries
        self.ttl_seconds = ttl_seconds
        self.clock = clock or (lambda: datetime.now(timezone.utc))
        self._entries: OrderedDict[str, tuple[list[dict], datetime]] = OrderedDict()
        self._inflight: dict[str, asyncio.Task[list[dict]]] = {}

    async def get(self, video_id: str, fetch: Callable[[], Awaitable[list[dict]]]) -> list[dict]:
        entry = self._entries.get(video_id)
        if entry is not None:
            if entry[1] > self.clock():
                self._entries.move_to_end(video_id)
                return entry[0]
            del self._entries[video_id]
        task = self._inflight.get(video_id)
        if task is None:
            task = asyncio.ensure_future(self._load(video_id, fetch))
            self._inflight[video_id] = task
        return await asyncio.shield(task)

    async def _load(self, video_id: str, fetch: Callable[[], Awaitable[list[dict]]]) -> list[dict]:
        try:
            items = await fetch()
            if items and self.max_entries > 0:
                self._entries[video_id] = (items, self.clock() + timedelta(seconds=self.ttl_seconds))
                self._entries.move_to_end(video_id)
                while len(self._entries) > self.max_entries:
                    self._entries.popitem(last=False)
            return items
        finally:
            self._inflight.pop(video_id, None)

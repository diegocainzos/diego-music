from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.radio_cache import RadioCache
from test_api import RadioResolver, authorization, settings


ITEMS = [{"id": "11111111111", "title": "Track 1", "channel": "Artist 1", "duration_seconds": 180}]


class CountingFetch:
    def __init__(self, result: list[dict] | Exception, delay: float = 0.0) -> None:
        self.result = result
        self.delay = delay
        self.calls = 0

    async def __call__(self) -> list[dict]:
        self.calls += 1
        if self.delay:
            await asyncio.sleep(self.delay)
        if isinstance(self.result, Exception):
            raise self.result
        return list(self.result)


class Clock:
    def __init__(self) -> None:
        self.now = datetime(2026, 1, 1, 12, 0, 0, tzinfo=timezone.utc)

    def __call__(self) -> datetime:
        return self.now


def test_segunda_peticion_desde_cache() -> None:
    async def scenario() -> None:
        cache = RadioCache(max_entries=10, ttl_seconds=60)
        fetch = CountingFetch(ITEMS)
        first = await cache.get("M7lc1UVf-VE", fetch)
        second = await cache.get("M7lc1UVf-VE", fetch)
        assert first == ITEMS
        assert second == ITEMS
        assert fetch.calls == 1

    asyncio.run(scenario())


def test_peticiones_simultaneas_una_sola_extraccion() -> None:
    async def scenario() -> None:
        cache = RadioCache(max_entries=10, ttl_seconds=60)
        fetch = CountingFetch(ITEMS, delay=0.05)
        results = await asyncio.gather(*(cache.get("M7lc1UVf-VE", fetch) for _ in range(5)))
        assert results == [ITEMS] * 5
        assert fetch.calls == 1

    asyncio.run(scenario())


def test_caducidad_vuelve_a_extraer() -> None:
    async def scenario() -> None:
        clock = Clock()
        cache = RadioCache(max_entries=10, ttl_seconds=10, clock=clock)
        fetch = CountingFetch(ITEMS)
        await cache.get("M7lc1UVf-VE", fetch)
        clock.now += timedelta(seconds=5)
        await cache.get("M7lc1UVf-VE", fetch)
        assert fetch.calls == 1
        clock.now += timedelta(seconds=10)
        assert await cache.get("M7lc1UVf-VE", fetch) == ITEMS
        assert fetch.calls == 2

    asyncio.run(scenario())


def test_fallo_no_cacheado_y_propaga_a_todos() -> None:
    async def scenario() -> None:
        cache = RadioCache(max_entries=10, ttl_seconds=60)
        failing = CountingFetch(RuntimeError("boom"), delay=0.05)
        results = await asyncio.gather(
            *(cache.get("M7lc1UVf-VE", failing) for _ in range(3)), return_exceptions=True
        )
        assert failing.calls == 1
        assert len(results) == 3
        assert all(isinstance(r, RuntimeError) for r in results)

        ok = CountingFetch(ITEMS)
        assert await cache.get("M7lc1UVf-VE", ok) == ITEMS
        assert ok.calls == 1

    asyncio.run(scenario())


def test_fallo_no_cacheado_lista_vacia() -> None:
    async def scenario() -> None:
        cache = RadioCache(max_entries=10, ttl_seconds=60)
        empty = CountingFetch([])
        assert await cache.get("M7lc1UVf-VE", empty) == []
        assert await cache.get("M7lc1UVf-VE", empty) == []
        assert empty.calls == 2

    asyncio.run(scenario())


def test_claves_distinguen_mayusculas() -> None:
    async def scenario() -> None:
        cache = RadioCache(max_entries=10, ttl_seconds=60)
        upper_items = [{"id": "22222222222", "title": "Upper"}]
        upper = CountingFetch(upper_items)
        lower = CountingFetch(ITEMS)
        assert await cache.get("abcDEFghiJK", upper) == upper_items
        assert await cache.get("abcdefghijk", lower) == ITEMS
        assert upper.calls == 1
        assert lower.calls == 1

    asyncio.run(scenario())


def test_create_app_expone_radio_cache_y_endpoint_usa_cache() -> None:
    resolver = RadioResolver(ITEMS)
    app = create_app(settings(), resolver=resolver)
    assert isinstance(app.state.radio_cache, RadioCache)
    with TestClient(app) as client:
        first = client.get("/v1/radio/M7lc1UVf-VE", headers=authorization())
        second = client.get("/v1/radio/M7lc1UVf-VE", headers=authorization())

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json() == {"items": ITEMS}
    assert second.json() == {"items": ITEMS}
    assert resolver.radio_calls == ["M7lc1UVf-VE"]


def test_endpoint_fallo_no_cacheado() -> None:
    resolver = RadioResolver(RuntimeError("boom"))
    with TestClient(create_app(settings(), resolver=resolver)) as client:
        assert client.get("/v1/radio/M7lc1UVf-VE", headers=authorization()).status_code == 502
        resolver.radio_items = ITEMS
        second = client.get("/v1/radio/M7lc1UVf-VE", headers=authorization())

    assert second.json() == {"items": ITEMS}
    assert resolver.radio_calls == ["M7lc1UVf-VE", "M7lc1UVf-VE"]

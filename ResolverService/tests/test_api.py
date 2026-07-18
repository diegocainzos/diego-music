from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
from fastapi.testclient import TestClient

from app.audio_cache import PersistentAudioCache
from app.config import Settings
from app.main import create_app
from app.resolver import AudioResolutionError, ResolvedAudio
from app.sessions import SessionStore


API_TOKEN = "test-token-with-at-least-thirty-two-characters"
UPSTREAM_URL = "https://rr1.googlevideo.com/videoplayback?expire=4102444800"


class FakeResolver:
    def __init__(self, result: ResolvedAudio | Exception) -> None:
        self.result = result
        self.calls: list[str] = []

    async def resolve(self, video_id: str) -> ResolvedAudio:
        self.calls.append(video_id)
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


def settings(ttl: int = 300) -> Settings:
    return Settings(
        api_token=API_TOKEN,
        public_base_url="https://audio.example.test",
        session_ttl_seconds=ttl,
    )


def audio() -> ResolvedAudio:
    return ResolvedAudio(
        upstream_url=UPSTREAM_URL,
        headers={"User-Agent": "DiegoMusic-test"},
        content_type="audio/mp4",
    )


def authorization() -> dict[str, str]:
    return {"Authorization": f"Bearer {API_TOKEN}"}


def test_health_does_not_require_authentication() -> None:
    resolver = FakeResolver(audio())
    with TestClient(create_app(settings(), resolver=resolver)) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert resolver.calls == []


def test_resolve_requires_valid_bearer_before_invoking_resolver() -> None:
    resolver = FakeResolver(audio())
    with TestClient(create_app(settings(), resolver=resolver)) as client:
        response = client.post("/v1/audio/resolve", json={"videoId": "M7lc1UVf-VE"})

    assert response.status_code == 401
    assert resolver.calls == []


def test_resolve_rejects_invalid_video_id_before_invoking_resolver() -> None:
    resolver = FakeResolver(audio())
    with TestClient(create_app(settings(), resolver=resolver)) as client:
        response = client.post(
            "/v1/audio/resolve",
            json={"videoId": "https://example.test/audio"},
            headers=authorization(),
        )

    assert response.status_code == 422
    assert resolver.calls == []


def test_resolve_returns_only_opaque_stream_information() -> None:
    resolver = FakeResolver(audio())
    with TestClient(create_app(settings(), resolver=resolver)) as client:
        response = client.post(
            "/v1/audio/resolve",
            json={"videoId": "M7lc1UVf-VE"},
            headers=authorization(),
        )

    assert response.status_code == 200
    body = response.json()
    assert body["contentType"] == "audio/mp4"
    assert body["streamURL"].startswith("https://audio.example.test/v1/audio/stream/")
    assert "googlevideo" not in response.text
    assert "User-Agent" not in response.text
    assert resolver.calls == ["M7lc1UVf-VE"]


def test_repeated_resolve_uses_resolution_cache() -> None:
    resolver = FakeResolver(audio())
    with TestClient(create_app(settings(), resolver=resolver)) as client:
        first = client.post(
            "/v1/audio/resolve",
            json={"videoId": "M7lc1UVf-VE"},
            headers=authorization(),
        )
        second = client.post(
            "/v1/audio/resolve",
            json={"videoId": "M7lc1UVf-VE"},
            headers=authorization(),
        )

    assert first.json()["cacheStatus"] == "miss"
    assert second.json()["cacheStatus"] == "resolution"
    assert resolver.calls == ["M7lc1UVf-VE"]


def test_resolution_error_is_sanitized() -> None:
    resolver = FakeResolver(AudioResolutionError("Este contenido no ofrece audio compatible."))
    with TestClient(create_app(settings(), resolver=resolver)) as client:
        response = client.post(
            "/v1/audio/resolve",
            json={"videoId": "M7lc1UVf-VE"},
            headers=authorization(),
        )

    assert response.status_code == 422
    assert response.json() == {"detail": "Este contenido no ofrece audio compatible."}
    assert "googlevideo" not in response.text


def test_stream_forwards_range_and_selected_headers() -> None:
    resolver = FakeResolver(audio())
    captured: dict[str, str] = {}

    def upstream(request: httpx.Request) -> httpx.Response:
        captured["method"] = request.method
        captured["range"] = request.headers.get("range", "")
        captured["user-agent"] = request.headers.get("user-agent", "")
        return httpx.Response(
            206,
            headers={
                "Content-Type": "audio/mp4",
                "Content-Length": "4",
                "Content-Range": "bytes 2-5/10",
                "Accept-Ranges": "bytes",
                "X-Upstream-Secret": "never-forward",
            },
            stream=httpx.ByteStream(b"2345"),
        )

    upstream_client = httpx.AsyncClient(transport=httpx.MockTransport(upstream))
    app = create_app(settings(), resolver=resolver, upstream_client=upstream_client)
    with TestClient(app) as client:
        resolved = client.post(
            "/v1/audio/resolve",
            json={"videoId": "M7lc1UVf-VE"},
            headers=authorization(),
        ).json()
        path = resolved["streamURL"].removeprefix("https://audio.example.test")
        response = client.get(path, headers={"Range": "bytes=2-5"})

    assert response.status_code == 206
    assert response.content == b"2345"
    assert response.headers["content-range"] == "bytes 2-5/10"
    assert "x-upstream-secret" not in response.headers
    assert captured == {
        "method": "GET",
        "range": "bytes=2-5",
        "user-agent": "DiegoMusic-test",
    }


def test_head_returns_metadata_without_body() -> None:
    resolver = FakeResolver(audio())

    def upstream(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, headers={"Content-Type": "audio/mp4", "Content-Length": "10"})

    upstream_client = httpx.AsyncClient(transport=httpx.MockTransport(upstream))
    with TestClient(create_app(settings(), resolver=resolver, upstream_client=upstream_client)) as client:
        resolved = client.post(
            "/v1/audio/resolve",
            json={"videoId": "M7lc1UVf-VE"},
            headers=authorization(),
        ).json()
        path = resolved["streamURL"].removeprefix("https://audio.example.test")
        response = client.head(path)

    assert response.status_code == 200
    assert response.content == b""
    assert response.headers["content-length"] == "10"


def test_existing_session_switches_to_disk_when_background_cache_finishes(tmp_path: Path) -> None:
    resolver = FakeResolver(audio())
    cache = PersistentAudioCache(tmp_path, max_bytes=100, max_file_bytes=50)
    upstream_client = httpx.AsyncClient(
        transport=httpx.MockTransport(lambda request: httpx.Response(403))
    )

    with TestClient(
        create_app(
            settings(),
            resolver=resolver,
            audio_cache=cache,
            upstream_client=upstream_client,
        )
    ) as client:
        resolved = client.post(
            "/v1/audio/resolve",
            json={"videoId": "M7lc1UVf-VE"},
            headers=authorization(),
        ).json()
        (tmp_path / "M7lc1UVf-VE.m4a").write_bytes(b"0123456789")
        path = resolved["streamURL"].removeprefix("https://audio.example.test")
        ranged = client.get(path, headers={"Range": "bytes=4-7"})

    assert resolved["cacheStatus"] == "miss"
    assert ranged.status_code == 206
    assert ranged.content == b"4567"
    assert resolver.calls == ["M7lc1UVf-VE"]


def test_cached_file_bypasses_resolver_and_supports_range(tmp_path: Path) -> None:
    cached_file = tmp_path / "M7lc1UVf-VE.m4a"
    cached_file.write_bytes(b"0123456789")
    resolver = FakeResolver(audio())
    cache = PersistentAudioCache(tmp_path, max_bytes=100, max_file_bytes=50)

    with TestClient(create_app(settings(), resolver=resolver, audio_cache=cache)) as client:
        resolved = client.post(
            "/v1/audio/resolve",
            json={"videoId": "M7lc1UVf-VE"},
            headers=authorization(),
        ).json()
        path = resolved["streamURL"].removeprefix("https://audio.example.test")
        ranged = client.get(path, headers={"Range": "bytes=2-5"})
        inspected = client.head(path)
        invalid = client.get(path, headers={"Range": "bytes=99-100"})

    assert resolved["cacheStatus"] == "disk"
    assert resolver.calls == []
    assert ranged.status_code == 206
    assert ranged.content == b"2345"
    assert ranged.headers["content-range"] == "bytes 2-5/10"
    assert inspected.status_code == 200
    assert inspected.headers["content-length"] == "10"
    assert invalid.status_code == 416
    assert invalid.headers["content-range"] == "bytes */10"


def test_expired_session_returns_gone() -> None:
    now = [datetime(2026, 1, 1, tzinfo=timezone.utc)]
    store = SessionStore(ttl_seconds=60, clock=lambda: now[0])
    resolver = FakeResolver(audio())

    with TestClient(create_app(settings(ttl=60), resolver=resolver, store=store)) as client:
        resolved = client.post(
            "/v1/audio/resolve",
            json={"videoId": "M7lc1UVf-VE"},
            headers=authorization(),
        ).json()
        now[0] += timedelta(seconds=61)
        path = resolved["streamURL"].removeprefix("https://audio.example.test")
        response = client.get(path)

    assert response.status_code == 410
    assert "expiró" in response.json()["detail"]

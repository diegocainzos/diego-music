from __future__ import annotations

from dataclasses import replace
import json

from fastapi.testclient import TestClient
import httpx

from app.main import create_app
from app.recommendations import parse_queries
from tests.test_api import FakeResolver, audio, authorization, settings


class SearchResolver(FakeResolver):
    def __init__(self) -> None:
        super().__init__(audio())
        self.queries: list[str] = []

    async def search(self, query: str, limit: int = 15) -> list[dict[str, str]]:
        self.queries.append(query)
        video_id = "AAAAAAAAAAA" if "Radiohead" in query else "BBBBBBBBBBB"
        return [{"id": video_id, "kind": "video", "title": query, "channelTitle": "X", "thumbnailURL": None}]


def llm_transport(content: str) -> httpx.AsyncClient:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.host == "openrouter.ai"
        assert json.loads(request.content)["model"] == "openrouter/free"
        return httpx.Response(200, json={"choices": [{"message": {"content": content}}]})

    return httpx.AsyncClient(transport=httpx.MockTransport(handler))


def test_parse_queries_accepts_fenced_json_and_skips_bad_items() -> None:
    content = '```json\n{"recommendations": [{"artist": "Radiohead", "title": "Reckoner"}, {"artist": "x"}, 3]}\n```'
    assert parse_queries(content) == ["Radiohead - Reckoner"]


def test_recommendations_without_key_returns_503() -> None:
    with TestClient(create_app(settings(), resolver=SearchResolver())) as client:
        response = client.post("/v1/recommendations", json={"tracks": [{"title": "Song"}]}, headers=authorization())
    assert response.status_code == 503


def test_recommendations_maps_llm_answers_to_unique_videos() -> None:
    resolver = SearchResolver()
    content = json.dumps({"recommendations": [
        {"artist": "Radiohead", "title": "Reckoner"},
        {"artist": "Radiohead", "title": "Nude"},
        {"artist": "Portishead", "title": "Roads"},
    ]})
    app = create_app(
        replace(settings(), openrouter_api_key="k" * 10),
        resolver=resolver,
        upstream_client=llm_transport(content),
    )
    with TestClient(app) as client:
        response = client.post(
            "/v1/recommendations",
            json={"tracks": [{"title": "Karma Police", "channel": "Radiohead"}]},
            headers=authorization(),
        )
    assert response.status_code == 200
    assert [item["id"] for item in response.json()["items"]] == ["AAAAAAAAAAA", "BBBBBBBBBBB"]
    assert len(resolver.queries) == 3


def test_recommendations_llm_failure_is_sanitized() -> None:
    app = create_app(
        replace(settings(), openrouter_api_key="k" * 10),
        resolver=SearchResolver(),
        upstream_client=llm_transport("no json here"),
    )
    with TestClient(app) as client:
        response = client.post("/v1/recommendations", json={"tracks": [{"title": "Song"}]}, headers=authorization())
    assert response.status_code == 502
    assert response.json() == {"detail": "Recomendaciones no disponibles."}

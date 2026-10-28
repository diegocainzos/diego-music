from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import create_app
from tests.test_api import FakeResolver, audio, authorization, settings


def test_endpoint_retirado() -> None:
    """Endpoint retirado: POST /v1/recommendations autenticado responde 404 o 405."""
    with TestClient(create_app(settings(), resolver=FakeResolver(audio()))) as client:
        response = client.post(
            "/v1/recommendations",
            json={"tracks": [{"title": "Song", "channel": "Artist"}]},
            headers=authorization(),
        )
    assert response.status_code in (404, 405)

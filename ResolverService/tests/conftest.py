"""Configuración compartida de las pruebas.

`backend_app.config` exige `SECRET_KEY` al importarse y `backend_app.database` crea su motor
con `DATABASE_URL`, así que ambas variables se fijan aquí antes de importar nada del backend.
"""
from __future__ import annotations

from collections.abc import Iterator
import os
import tempfile

from fastapi.testclient import TestClient
import pytest

API_TOKEN = "test-token-with-at-least-thirty-two-characters"
TEST_SECRET_KEY = "test-only-secret-key-with-at-least-32-characters"

os.environ["SECRET_KEY"] = TEST_SECRET_KEY
_database_dir = tempfile.TemporaryDirectory(prefix="diegomusic-tests-", ignore_cleanup_errors=True)
os.environ["DATABASE_URL"] = f"sqlite:///{_database_dir.name}/backend.db"


def pytest_sessionfinish(session: pytest.Session, exitstatus: int) -> None:
    _database_dir.cleanup()


@pytest.fixture
def backend_client() -> Iterator[TestClient]:
    """App completa construida con `create_app` sobre una base SQLite temporal vacía."""
    from app.config import Settings
    from app.main import create_app
    from backend_app.database import Base, engine

    settings = Settings(api_token=API_TOKEN, public_base_url="https://audio.example.test")
    with TestClient(create_app(settings)) as client:  # el arranque crea las tablas
        yield client
    Base.metadata.drop_all(bind=engine)


def register_user(client: TestClient, email: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "Password1234", "full_name": "Test User"},
    )
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.fixture
def auth_headers(backend_client: TestClient) -> dict[str, str]:
    return register_user(backend_client, "user@diegomusic.app")


@pytest.fixture
def other_headers(backend_client: TestClient) -> dict[str, str]:
    return register_user(backend_client, "other@diegomusic.app")

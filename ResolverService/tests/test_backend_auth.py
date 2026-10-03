from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient
import jwt
import pytest
from sqlalchemy import text

from backend_app.config import settings
from backend_app.database import engine
from conftest import API_TOKEN, TEST_SECRET_KEY

# Clave por defecto que existía en el código antes de hacer obligatoria SECRET_KEY.
RETIRED_DEFAULT_KEY = "diegomusic-super-secret-jwt-key-2026-change-in-production"
OTHER_KEY = "another-signing-key-with-at-least-32-characters"


def forged_token(key: str, **claims: object) -> str:
    payload = {"sub": "1", "exp": datetime.now(timezone.utc) + timedelta(minutes=5), **claims}
    return jwt.encode({k: v for k, v in payload.items() if v is not None}, key, algorithm=settings.ALGORITHM)


def bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_sqlite_wal_mode() -> None:
    with engine.connect() as connection:
        assert str(connection.execute(text("PRAGMA journal_mode;")).scalar()).lower() == "wal"


def test_settings_use_the_key_defined_by_the_environment() -> None:
    assert settings.SECRET_KEY == TEST_SECRET_KEY


def test_user_registration_and_login(backend_client: TestClient) -> None:
    registration = {
        "email": "testuser@diegomusic.app",
        "password": "Password1234",
        "full_name": "Test User",
    }
    response = backend_client.post("/api/v1/auth/register", json=registration)
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == registration["email"]
    token = data["access_token"]

    for email, password in [
        ("short@diegomusic.app", "Pass1"),  # menos de 10 caracteres
        ("noupper@diegomusic.app", "password1234"),  # sin mayúscula
        ("long@diegomusic.app", "Password12345678901234567890"),  # más de 25 caracteres
    ]:
        rejected = backend_client.post(
            "/api/v1/auth/register",
            json={"email": email, "password": password, "full_name": "Rejected"},
        )
        assert rejected.status_code == 422, email

    assert backend_client.post("/api/v1/auth/register", json=registration).status_code == 400

    login = backend_client.post(
        "/api/v1/auth/login",
        data={"username": registration["email"], "password": registration["password"]},
    )
    assert login.status_code == 200
    assert "access_token" in login.json()

    wrong_password = backend_client.post(
        "/api/v1/auth/login",
        data={"username": registration["email"], "password": "WrongPassword1234"},
    )
    assert wrong_password.status_code == 401

    me = backend_client.get("/api/v1/auth/me", headers=bearer(token))
    assert me.status_code == 200
    assert me.json()["full_name"] == "Test User"


def test_profile_update(backend_client: TestClient, auth_headers: dict[str, str]) -> None:
    response = backend_client.put(
        "/api/v1/auth/me",
        json={"full_name": "Nuevo Nombre", "avatar_url": "https://example.test/a.png"},
        headers=auth_headers,
    )

    assert response.status_code == 200
    assert response.json()["full_name"] == "Nuevo Nombre"
    assert backend_client.get("/api/v1/auth/me", headers=auth_headers).json()["avatar_url"] == "https://example.test/a.png"


def test_schema_contains_no_tables_of_removed_features(backend_client: TestClient) -> None:
    with engine.connect() as connection:
        tables = {row[0] for row in connection.execute(text("SELECT name FROM sqlite_master WHERE type='table'"))}

    assert {"users", "playlists", "playlist_tracks", "user_favorites", "play_history"} <= tables
    assert tables.isdisjoint({"user_settings", "user_player_states", "user_follows", "user_downloads", "user_activity_logs"})


@pytest.mark.parametrize("key", [OTHER_KEY, RETIRED_DEFAULT_KEY])
def test_jwt_signed_with_another_key_is_rejected(
    backend_client: TestClient, auth_headers: dict[str, str], key: str
) -> None:
    assert backend_client.get("/api/v1/auth/me", headers=auth_headers).status_code == 200
    token = forged_token(key)

    assert backend_client.get("/api/v1/auth/me", headers=bearer(token)).status_code == 401
    assert backend_client.get("/v1/search", params={"q": " "}, headers=bearer(token)).status_code == 401


MALFORMED_OR_EXPIRED_CLAIMS = [
    {"sub": None},  # sin sub
    {"exp": datetime.now(timezone.utc) - timedelta(minutes=1)},  # caducado
]


@pytest.mark.parametrize("claims", [*MALFORMED_OR_EXPIRED_CLAIMS, {"sub": "no-es-un-id"}])
def test_malformed_or_expired_jwt_is_rejected_by_get_current_user(
    backend_client: TestClient, auth_headers: dict[str, str], claims: dict[str, object]
) -> None:
    token = forged_token(TEST_SECRET_KEY, **claims)

    assert backend_client.get("/api/v1/auth/me", headers=bearer(token)).status_code == 401


@pytest.mark.parametrize("claims", MALFORMED_OR_EXPIRED_CLAIMS)
def test_subjectless_or_expired_jwt_is_rejected_by_api_token(
    backend_client: TestClient, claims: dict[str, object]
) -> None:
    token = forged_token(TEST_SECRET_KEY, **claims)

    assert backend_client.get("/v1/search", params={"q": " "}, headers=bearer(token)).status_code == 401


def test_require_api_token_accepts_static_token_and_user_jwt(
    backend_client: TestClient, auth_headers: dict[str, str]
) -> None:
    params = {"q": " "}  # consulta vacía: responde sin invocar a yt-dlp

    assert backend_client.get("/v1/search", params=params).status_code == 401
    assert backend_client.get("/v1/search", params=params, headers=bearer("token-incorrecto")).status_code == 401
    assert backend_client.get("/v1/search", params=params, headers=bearer(API_TOKEN)).status_code == 200
    assert backend_client.get("/v1/search", params=params, headers=auth_headers).status_code == 200

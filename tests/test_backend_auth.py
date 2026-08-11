import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# Configurar base de datos SQLite temporal en memoria para pruebas
os.environ["DATABASE_URL"] = "sqlite:///./test_diegomusic.db"

from app.main import app
from app.database import Base, get_db, engine
from app.seed import seed_database

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

@pytest.fixture(scope="module", autouse=True)
def setup_test_db():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    seed_database(db)
    db.close()
    yield
    Base.metadata.drop_all(bind=engine)
    if os.path.exists("./test_diegomusic.db"):
        try:
            os.remove("./test_diegomusic.db")
        except PermissionError:
            pass

@pytest.fixture
def client():
    return TestClient(app)

# 1. Test SQLite WAL Mode PRAGMAs
def test_sqlite_wal_mode():
    with engine.connect() as conn:
        result = conn.execute(text("PRAGMA journal_mode;")).scalar()
        assert str(result).lower() == "wal"

# 2. Test Autenticación (Registro, Login, Me)
def test_user_registration_and_login(client):
    # Registro de usuario
    reg_payload = {
        "email": "testuser@diegomusic.app",
        "password": "Password123!",
        "full_name": "Test User"
    }
    response = client.post("/api/v1/auth/register", json=reg_payload)
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert data["email"] == reg_payload["email"]
    token = data["access_token"]

    # Duplicado debe fallar con 400
    dup_res = client.post("/api/v1/auth/register", json=reg_payload)
    assert dup_res.status_code == 400

    # Login exitoso
    login_res = client.post("/api/v1/auth/login", data={"username": reg_payload["email"], "password": reg_payload["password"]})
    assert login_res.status_code == 200
    assert "access_token" in login_res.json()

    # Login con clave errónea
    bad_login = client.post("/api/v1/auth/login", data={"username": reg_payload["email"], "password": "WrongPassword"})
    assert bad_login.status_code == 401

    # /auth/me
    headers = {"Authorization": f"Bearer {token}"}
    me_res = client.get("/api/v1/auth/me", headers=headers)
    assert me_res.status_code == 200
    assert me_res.json()["full_name"] == "Test User"

# 3. Test Preferencias y Ajustes
def test_user_settings(client):
    login_res = client.post("/api/v1/auth/login", data={"username": "demo@diegomusic.app", "password": "DiegoMusic2026!"})
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # GET Settings
    res = client.get("/api/v1/users/me/settings", headers=headers)
    assert res.status_code == 200
    assert res.json()["audio_quality"] == "high"

    # PATCH Settings
    patch_res = client.patch("/api/v1/users/me/settings", json={"audio_quality": "lossless", "crossfade_seconds": 5}, headers=headers)
    assert patch_res.status_code == 200
    assert patch_res.json()["audio_quality"] == "lossless"
    assert patch_res.json()["crossfade_seconds"] == 5

# 4. Test Player State y Queue Sync
def test_player_state_sync(client):
    login_res = client.post("/api/v1/auth/login", data={"username": "demo@diegomusic.app", "password": "DiegoMusic2026!"})
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # PUT Player State
    state_payload = {
        "current_track_id": 1,
        "position_seconds": 45.5,
        "playback_status": "playing",
        "shuffle_enabled": True,
        "queue": [1, 2, 3]
    }
    put_res = client.put("/api/v1/users/me/player-state", json=state_payload, headers=headers)
    assert put_res.status_code == 200
    data = put_res.json()
    assert data["position_seconds"] == 45.5
    assert data["queue"] == [1, 2, 3]

# 5. Test Historial y Telemetría
def test_history_and_telemetry(client):
    login_res = client.post("/api/v1/auth/login", data={"username": "demo@diegomusic.app", "password": "DiegoMusic2026!"})
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Record Play History
    hist_payload = {
        "track_id": 1,
        "played_seconds": 120.0,
        "completed": False,
        "skipped": True,
        "context": "search"
    }
    res = client.post("/api/v1/users/me/history", json=hist_payload, headers=headers)
    assert res.status_code == 201

    # Record Telemetry Event
    telem_payload = {
        "event_type": "view_artist",
        "event_data": {"artist_id": 1}
    }
    t_res = client.post("/api/v1/telemetry/events", json=telem_payload, headers=headers)
    assert t_res.status_code == 201

# 6. Test Catálogo Musical
def test_catalog_endpoints(client):
    # Artists
    res = client.get("/api/v1/catalog/artists")
    assert res.status_code == 200
    assert len(res.json()) >= 1

    # Albums
    al_res = client.get("/api/v1/catalog/albums")
    assert al_res.status_code == 200

    # Search
    s_res = client.get("/api/v1/catalog/search?q=Lucky")
    assert s_res.status_code == 200
    assert len(s_res.json()["tracks"]) >= 1

# 7. Test Playlists y Favoritos
def test_playlists_and_favorites(client):
    login_res = client.post("/api/v1/auth/login", data={"username": "demo@diegomusic.app", "password": "DiegoMusic2026!"})
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Crear Playlist
    p_res = client.post("/api/v1/playlists", json={"name": "Mis Favoritas 2026", "is_public": True}, headers=headers)
    assert p_res.status_code == 201
    playlist_id = p_res.json()["id"]

    # Agregar Canción a Playlist
    add_tr = client.post(f"/api/v1/playlists/{playlist_id}/tracks", json={"track_id": 1, "order": 1}, headers=headers)
    assert add_tr.status_code == 200

    # Agregar Favorito
    fav_res = client.post("/api/v1/users/me/favorites", json={"entity_type": "track", "entity_id": 1}, headers=headers)
    assert fav_res.status_code == 201

import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker

os.environ["DATABASE_URL"] = "sqlite:///./test_playlists.db"

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
    if os.path.exists("./test_playlists.db"):
        try:
            os.remove("./test_playlists.db")
        except PermissionError:
            pass

@pytest.fixture
def client():
    return TestClient(app)

@pytest.fixture
def auth_headers(client):
    login_res = client.post("/api/v1/auth/login", data={"username": "demo@diegomusic.app", "password": "DiegoMusic2026!"})
    token = login_res.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

def test_playlist_crud_and_reorder(client, auth_headers):
    # 1. Crear playlist
    create_res = client.post(
        "/api/v1/playlists/",
        json={"name": "Mi Lista de Prueba", "description": "Descripción inicial", "is_public": False},
        headers=auth_headers
    )
    assert create_res.status_code == 201
    playlist_id = create_res.json()["id"]

    # 2. Añadir canciones (IDs 1 y 2 creados por seed)
    add1 = client.post(f"/api/v1/playlists/{playlist_id}/tracks", json={"track_id": 1, "order": 0}, headers=auth_headers)
    assert add1.status_code == 200
    add2 = client.post(f"/api/v1/playlists/{playlist_id}/tracks", json={"track_id": 2, "order": 1}, headers=auth_headers)
    assert add2.status_code == 200

    # 3. Editar playlist (PUT)
    update_res = client.put(
        f"/api/v1/playlists/{playlist_id}",
        json={"name": "Mi Lista Editada", "description": "Descripción editada"},
        headers=auth_headers
    )
    assert update_res.status_code == 200
    assert update_res.json()["name"] == "Mi Lista Editada"
    assert update_res.json()["description"] == "Descripción editada"

    # 4. Reordenar canciones (PUT reorder)
    reorder_res = client.put(
        f"/api/v1/playlists/{playlist_id}/tracks/reorder",
        json={"track_ids": [2, 1]},
        headers=auth_headers
    )
    assert reorder_res.status_code == 200

    # 5. Obtener detalle y verificar orden
    get_res = client.get(f"/api/v1/playlists/{playlist_id}", headers=auth_headers)
    assert get_res.status_code == 200
    tracks = get_res.json()["tracks"]
    assert len(tracks) == 2
    assert tracks[0]["track_id"] == 2
    assert tracks[1]["track_id"] == 1

    # 6. Eliminar canción
    del_track = client.delete(f"/api/v1/playlists/{playlist_id}/tracks/1", headers=auth_headers)
    assert del_track.status_code == 204

    # 7. Eliminar playlist
    del_pl = client.delete(f"/api/v1/playlists/{playlist_id}", headers=auth_headers)
    assert del_pl.status_code == 204

def test_telemetry_activity_logging(client, auth_headers):
    # Registrar evento de actividad
    log_res = client.post(
        "/api/v1/telemetry/events",
        json={"event_type": "track_play", "event_data": {"track_id": 1, "action": "play"}},
        headers=auth_headers
    )
    assert log_res.status_code == 201
    data = log_res.json()
    assert data["event_type"] == "track_play"
    assert data["user_id"] is not None

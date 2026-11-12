"""Nombres con tildes: crear dos veces devuelve la misma playlist (sin 500)."""
from tests.conftest import register_user
def test_accented(backend_client):
    h = register_user(backend_client, "acc@diegomusic.app")
    a = backend_client.post("/api/v1/playlists/", json={"name": "Éxitos"}, headers=h)
    b = backend_client.post("/api/v1/playlists/", json={"name": "ÉXITOS"}, headers=h)
    assert (a.status_code, b.status_code) == (201, 200) and a.json()["id"] == b.json()["id"]

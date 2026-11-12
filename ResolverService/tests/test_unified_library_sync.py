"""Criterios de `openspec/changes/unified-library-sync` (backend): nombres únicos y pistas ordenadas."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from tests.conftest import register_user

PLAYLISTS = "/api/v1/playlists/"


def youtube_track(video_id: str) -> dict[str, object]:
    # Sin `order`: el backend debe añadir al final.
    return {"youtube_video_id": video_id, "title": f"Pista {video_id}", "channel_title": "Canal", "duration_seconds": 200}


def my_playlists(client: TestClient, headers: dict[str, str]) -> list[dict]:
    response = client.get("/api/v1/playlists/me", headers=headers)
    assert response.status_code == 200
    return response.json()


def named(client: TestClient, headers: dict[str, str], name: str) -> list[dict]:
    return [p for p in my_playlists(client, headers) if p["name"].lower() == name.lower()]


def add(client: TestClient, headers: dict[str, str], playlist_id: int, video_id: str) -> dict:
    response = client.post(f"/api/v1/playlists/{playlist_id}/tracks", json=youtube_track(video_id), headers=headers)
    assert response.status_code == 200
    return response.json()


def video_ids(playlist: dict) -> list[str]:
    return [item["track"]["youtube_video_id"] for item in playlist["tracks"]]


def test_creating_an_existing_name_returns_the_existing_playlist(backend_client: TestClient) -> None:
    headers = register_user(backend_client, "existing-name@diegomusic.app")
    first = backend_client.post(PLAYLISTS, json={"name": "Gym"}, headers=headers)
    assert first.status_code == 201

    second = backend_client.post(PLAYLISTS, json={"name": "gym"}, headers=headers)

    assert second.status_code == 200
    assert second.json()["id"] == first.json()["id"]
    assert len(my_playlists(backend_client, headers)) == 1


def test_concurrent_creates_with_the_same_name(backend_client: TestClient) -> None:
    headers = register_user(backend_client, "concurrent@diegomusic.app")

    def create(_: int):
        return backend_client.post(PLAYLISTS, json={"name": "Gym"}, headers=headers)

    with ThreadPoolExecutor(max_workers=4) as pool:
        responses = list(pool.map(create, range(4)))

    assert all(r.status_code in (200, 201) for r in responses), [r.status_code for r in responses]
    stored = named(backend_client, headers, "Gym")
    assert len(stored) == 1
    assert {r.json()["id"] for r in responses} == {stored[0]["id"]}


def test_renaming_to_a_taken_name_is_rejected(backend_client: TestClient) -> None:
    headers = register_user(backend_client, "rename-taken@diegomusic.app")
    gym = backend_client.post(PLAYLISTS, json={"name": "Gym"}, headers=headers).json()
    chill = backend_client.post(PLAYLISTS, json={"name": "Chill"}, headers=headers).json()

    response = backend_client.put(f"/api/v1/playlists/{chill['id']}", json={"name": "GYM"}, headers=headers)

    assert response.status_code == 409
    assert response.json()["detail"] == "Ya existe una playlist con ese nombre."
    names = {p["id"]: p["name"] for p in my_playlists(backend_client, headers)}
    assert names == {gym["id"]: "Gym", chill["id"]: "Chill"}


def test_different_accounts_may_reuse_a_name(backend_client: TestClient) -> None:
    alice = register_user(backend_client, "alice-reuse@diegomusic.app")
    bob = register_user(backend_client, "bob-reuse@diegomusic.app")

    a = backend_client.post(PLAYLISTS, json={"name": "Gym"}, headers=alice)
    b = backend_client.post(PLAYLISTS, json={"name": "Gym"}, headers=bob)

    assert (a.status_code, b.status_code) == (201, 201)
    assert a.json()["id"] != b.json()["id"]
    assert [p["id"] for p in named(backend_client, alice, "Gym")] == [a.json()["id"]]
    assert [p["id"] for p in named(backend_client, bob, "Gym")] == [b.json()["id"]]


def test_tracks_keep_insertion_order(backend_client: TestClient) -> None:
    headers = register_user(backend_client, "order@diegomusic.app")
    playlist_id = backend_client.post(PLAYLISTS, json={"name": "Orden"}, headers=headers).json()["id"]

    for video_id in ("ord_A", "ord_B", "ord_C"):
        add(backend_client, headers, playlist_id, video_id)

    detail = backend_client.get(f"/api/v1/playlists/{playlist_id}", headers=headers).json()
    assert video_ids(detail) == ["ord_A", "ord_B", "ord_C"]
    orders = [item["order"] for item in detail["tracks"]]
    assert orders == sorted(set(orders)), f"order debe ser estrictamente creciente: {orders}"


def test_adding_a_track_twice_keeps_one_copy(backend_client: TestClient) -> None:
    headers = register_user(backend_client, "twice@diegomusic.app")
    playlist_id = backend_client.post(PLAYLISTS, json={"name": "Doble"}, headers=headers).json()["id"]
    for video_id in ("dup_A", "dup_B"):
        add(backend_client, headers, playlist_id, video_id)

    detail = add(backend_client, headers, playlist_id, "dup_A")

    assert video_ids(detail) == ["dup_A", "dup_B"]
    orders = [item["order"] for item in detail["tracks"]]
    assert orders == sorted(set(orders)), f"order debe ser estrictamente creciente: {orders}"


def test_duplicates_from_older_clients_collapse_into_one(backend_client: TestClient) -> None:
    from sqlalchemy import text

    from backend_app.database import SessionLocal
    from backend_app.models import Playlist, PlaylistTrack
    from backend_app.playlist_maintenance import merge_duplicate_playlists

    headers = register_user(backend_client, "merge@diegomusic.app")
    # Crea las pistas A y B por la API para no fabricar artistas/álbumes a mano.
    seed = backend_client.post(PLAYLISTS, json={"name": "Semilla"}, headers=headers).json()["id"]
    add(backend_client, headers, seed, "mrg_A")
    seed_detail = add(backend_client, headers, seed, "mrg_B")
    track_a, track_b = (item["track_id"] for item in seed_detail["tracks"])
    user_id = seed_detail["user_id"]

    db = SessionLocal()
    try:
        # Simula una base anterior al cambio: sin índice único, con tres "Gym".
        db.execute(text("DROP INDEX IF EXISTS ux_playlists_user_name"))
        db.commit()
        base = datetime(2025, 1, 1, tzinfo=timezone.utc)
        rows = [Playlist(name="Gym", user_id=user_id, created_at=base + timedelta(days=i), updated_at=base + timedelta(days=i)) for i in range(3)]
        db.add_all(rows)
        db.flush()
        oldest_id = rows[0].id
        db.add_all([
            PlaylistTrack(playlist_id=rows[0].id, track_id=track_a, order=0),
            PlaylistTrack(playlist_id=rows[2].id, track_id=track_b, order=0),
            PlaylistTrack(playlist_id=rows[2].id, track_id=track_a, order=1),
        ])
        db.commit()

        merge_duplicate_playlists(db)
    finally:
        db.close()

    gyms = named(backend_client, headers, "Gym")
    assert [p["id"] for p in gyms] == [oldest_id]
    detail = backend_client.get(f"/api/v1/playlists/{oldest_id}", headers=headers).json()
    assert video_ids(detail) == ["mrg_A", "mrg_B"]


def test_unique_names_and_ordered_tracks_flow(backend_client: TestClient) -> None:
    """Flujo compuesto: crear, recrear (idempotente), añadir en orden, repetir pista y renombrar."""
    headers = register_user(backend_client, "flow@diegomusic.app")
    created = backend_client.post(PLAYLISTS, json={"name": "Chill"}, headers=headers)
    assert created.status_code == 201
    playlist_id = created.json()["id"]

    for video_id in ("flow_A", "flow_B"):
        add(backend_client, headers, playlist_id, video_id)
    again = backend_client.post(PLAYLISTS, json={"name": "CHILL"}, headers=headers)
    assert (again.status_code, again.json()["id"]) == (200, playlist_id)
    assert video_ids(again.json()) == ["flow_A", "flow_B"]

    add(backend_client, headers, again.json()["id"], "flow_C")
    add(backend_client, headers, again.json()["id"], "flow_A")

    renamed = backend_client.put(f"/api/v1/playlists/{playlist_id}", json={"name": "Noche"}, headers=headers)
    assert renamed.status_code == 200
    assert named(backend_client, headers, "Chill") == []
    noche = named(backend_client, headers, "Noche")
    assert [p["id"] for p in noche] == [playlist_id]
    detail = backend_client.get(f"/api/v1/playlists/{playlist_id}", headers=headers).json()
    assert video_ids(detail) == ["flow_A", "flow_B", "flow_C"]
    # El nombre liberado vuelve a poder usarse y crea una playlist nueva.
    reused = backend_client.post(PLAYLISTS, json={"name": "Chill"}, headers=headers)
    assert reused.status_code == 201 and reused.json()["id"] != playlist_id

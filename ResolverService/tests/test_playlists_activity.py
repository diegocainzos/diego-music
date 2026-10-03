from __future__ import annotations

from fastapi.testclient import TestClient
import pytest

EXPECTED_API_PATHS = {
    "/api/v1/auth/register",
    "/api/v1/auth/login",
    "/api/v1/auth/me",
    "/api/v1/playlists/",
    "/api/v1/playlists/me",
    "/api/v1/playlists/{playlist_id}",
    "/api/v1/playlists/{playlist_id}/tracks",
    "/api/v1/playlists/{playlist_id}/tracks/{track_id}",
    "/api/v1/users/me/history",
    "/api/v1/users/me/favorites",
    "/api/v1/users/me/favorites/{entity_type}/{entity_id}",
}


def youtube_track(video_id: str, **extra: object) -> dict[str, object]:
    return {
        "youtube_video_id": video_id,
        "title": f"Pista {video_id}",
        "channel_title": "Canal de prueba",
        "duration_seconds": 200,
        **extra,
    }


def create_playlist(client: TestClient, headers: dict[str, str], **fields: object) -> int:
    response = client.post("/api/v1/playlists/", json={"name": "Lista", **fields}, headers=headers)
    assert response.status_code == 201
    return response.json()["id"]


def add_track(client: TestClient, headers: dict[str, str], playlist_id: int, video_id: str, order: int = 0) -> dict:
    response = client.post(
        f"/api/v1/playlists/{playlist_id}/tracks",
        json=youtube_track(video_id, order=order),
        headers=headers,
    )
    assert response.status_code == 200
    return response.json()


def test_api_surface_is_limited_to_what_clients_use(backend_client: TestClient, auth_headers: dict[str, str]) -> None:
    paths = {path for path in backend_client.get("/openapi.json").json()["paths"] if path.startswith("/api/")}

    assert paths == EXPECTED_API_PATHS
    assert backend_client.get("/api/v1/catalog/search", params={"q": "rock"}, headers=auth_headers).status_code == 404


@pytest.mark.parametrize(
    ("method", "path"),
    [
        ("GET", "/api/v1/catalog/artists"),
        ("GET", "/api/v1/users/me/settings"),
        ("PATCH", "/api/v1/users/me/settings"),
        ("GET", "/api/v1/users/me/player-state"),
        ("PUT", "/api/v1/users/me/player-state"),
        ("GET", "/api/v1/users/me/following"),
        ("POST", "/api/v1/users/me/following/1"),
        ("POST", "/api/v1/telemetry/events"),
        ("PUT", "/api/v1/playlists/1/tracks/reorder"),
    ],
)
def test_removed_routes_are_not_served(
    backend_client: TestClient, auth_headers: dict[str, str], method: str, path: str
) -> None:
    response = backend_client.request(method, path, json={}, headers=auth_headers)

    assert response.status_code in (404, 405)


def test_playlist_endpoints_require_authentication(backend_client: TestClient) -> None:
    assert backend_client.get("/api/v1/playlists/me").status_code == 401
    assert backend_client.post("/api/v1/playlists/", json={"name": "x"}).status_code == 401


def test_playlist_crud_and_track_management(backend_client: TestClient, auth_headers: dict[str, str]) -> None:
    playlist_id = create_playlist(backend_client, auth_headers, description="Descripción inicial")

    add_track(backend_client, auth_headers, playlist_id, "yt_pl_bridge_1", order=1)
    detail = add_track(backend_client, auth_headers, playlist_id, "yt_pl_bridge_2", order=0)
    # Se ordena por el campo `order` que envía el cliente.
    assert [item["track"]["youtube_video_id"] for item in detail["tracks"]] == ["yt_pl_bridge_2", "yt_pl_bridge_1"]

    updated = backend_client.put(
        f"/api/v1/playlists/{playlist_id}",
        json={"name": "Lista editada", "description": "Descripción editada"},
        headers=auth_headers,
    )
    assert updated.status_code == 200
    assert updated.json()["name"] == "Lista editada"
    assert updated.json()["description"] == "Descripción editada"

    mine = backend_client.get("/api/v1/playlists/me", headers=auth_headers).json()
    assert [playlist["id"] for playlist in mine] == [playlist_id]

    first_track_id = detail["tracks"][1]["track_id"]
    removed_by_id = backend_client.delete(f"/api/v1/playlists/{playlist_id}/tracks/{first_track_id}", headers=auth_headers)
    removed_by_video = backend_client.delete(f"/api/v1/playlists/{playlist_id}/tracks/yt_pl_bridge_2", headers=auth_headers)
    removed_again = backend_client.delete(f"/api/v1/playlists/{playlist_id}/tracks/yt_pl_bridge_2", headers=auth_headers)
    assert (removed_by_id.status_code, removed_by_video.status_code, removed_again.status_code) == (204, 204, 204)
    assert backend_client.get(f"/api/v1/playlists/{playlist_id}", headers=auth_headers).json()["tracks"] == []

    assert backend_client.delete(f"/api/v1/playlists/{playlist_id}", headers=auth_headers).status_code == 204
    assert backend_client.get(f"/api/v1/playlists/{playlist_id}", headers=auth_headers).status_code == 404


def test_add_track_is_idempotent_and_needs_a_reference(backend_client: TestClient, auth_headers: dict[str, str]) -> None:
    playlist_id = create_playlist(backend_client, auth_headers)

    add_track(backend_client, auth_headers, playlist_id, "yt_pl_bridge_1")
    detail = add_track(backend_client, auth_headers, playlist_id, "yt_pl_bridge_1")
    assert len(detail["tracks"]) == 1

    by_id = backend_client.post(
        f"/api/v1/playlists/{playlist_id}/tracks",
        json={"track_id": detail["tracks"][0]["track_id"]},
        headers=auth_headers,
    )
    assert by_id.status_code == 200
    assert len(by_id.json()["tracks"]) == 1

    url = f"/api/v1/playlists/{playlist_id}/tracks"
    assert backend_client.post(url, json={}, headers=auth_headers).status_code == 400
    assert backend_client.post(url, json={"track_id": 9999}, headers=auth_headers).status_code == 404


def test_playlist_ownership_is_enforced(
    backend_client: TestClient, auth_headers: dict[str, str], other_headers: dict[str, str]
) -> None:
    private_id = create_playlist(backend_client, auth_headers, is_public=False)
    public_id = create_playlist(backend_client, auth_headers, is_public=True)

    modify = "No tienes permisos para modificar esta playlist"
    for playlist_id in (private_id, public_id):
        update = backend_client.put(f"/api/v1/playlists/{playlist_id}", json={"name": "x"}, headers=other_headers)
        add = backend_client.post(
            f"/api/v1/playlists/{playlist_id}/tracks", json=youtube_track("yt_pl_bridge_1"), headers=other_headers
        )
        remove = backend_client.delete(f"/api/v1/playlists/{playlist_id}/tracks/yt_pl_bridge_1", headers=other_headers)
        delete = backend_client.delete(f"/api/v1/playlists/{playlist_id}", headers=other_headers)
        assert [r.status_code for r in (update, add, remove, delete)] == [403, 403, 403, 403]
        assert update.json()["detail"] == add.json()["detail"] == remove.json()["detail"] == modify
        assert delete.json()["detail"] == "No tienes permisos para eliminar esta playlist"

    assert backend_client.get(f"/api/v1/playlists/{private_id}", headers=other_headers).status_code == 403
    assert backend_client.get(f"/api/v1/playlists/{public_id}", headers=other_headers).status_code == 200

    missing = 9999
    assert backend_client.put(f"/api/v1/playlists/{missing}", json={"name": "x"}, headers=auth_headers).status_code == 404
    assert backend_client.post(
        f"/api/v1/playlists/{missing}/tracks", json=youtube_track("yt_pl_bridge_1"), headers=auth_headers
    ).status_code == 404
    assert backend_client.delete(f"/api/v1/playlists/{missing}/tracks/1", headers=auth_headers).status_code == 404
    assert backend_client.delete(f"/api/v1/playlists/{missing}", headers=auth_headers).status_code == 404
    # El propietario conserva su playlist tras los intentos ajenos.
    assert backend_client.get(f"/api/v1/playlists/{private_id}", headers=auth_headers).status_code == 200


def test_favorites_by_youtube_video_id_and_entity_id(backend_client: TestClient, auth_headers: dict[str, str]) -> None:
    created = backend_client.post(
        "/api/v1/users/me/favorites",
        json={"entity_type": "track", **youtube_track("yt_fav_bridge_1")},
        headers=auth_headers,
    )
    assert created.status_code == 201
    favorite = created.json()
    assert favorite["track"]["youtube_video_id"] == "yt_fav_bridge_1"
    assert favorite["track"]["artist"]["name"] == "Canal de prueba"

    # Repetirlo devuelve el mismo favorito.
    again = backend_client.post(
        "/api/v1/users/me/favorites",
        json={"entity_type": "track", "entity_id": favorite["entity_id"]},
        headers=auth_headers,
    )
    assert again.status_code == 201
    assert again.json()["id"] == favorite["id"]

    album = backend_client.post(
        "/api/v1/users/me/favorites", json={"entity_type": "album", "entity_id": 5}, headers=auth_headers
    )
    assert album.status_code == 201
    assert album.json()["track"] is None

    tracks_only = backend_client.get("/api/v1/users/me/favorites", params={"entity_type": "track"}, headers=auth_headers)
    assert [item["entity_id"] for item in tracks_only.json()] == [favorite["entity_id"]]
    assert len(backend_client.get("/api/v1/users/me/favorites", headers=auth_headers).json()) == 2

    delete_by_video = backend_client.delete("/api/v1/users/me/favorites/track/yt_fav_bridge_1", headers=auth_headers)
    delete_album = backend_client.delete("/api/v1/users/me/favorites/album/5", headers=auth_headers)
    delete_missing = backend_client.delete("/api/v1/users/me/favorites/track/unknown", headers=auth_headers)
    assert (delete_by_video.status_code, delete_album.status_code, delete_missing.status_code) == (204, 204, 204)
    assert backend_client.get("/api/v1/users/me/favorites", headers=auth_headers).json() == []


def test_favorites_validate_input(backend_client: TestClient, auth_headers: dict[str, str]) -> None:
    invalid_type = backend_client.post(
        "/api/v1/users/me/favorites", json={"entity_type": "genre", "entity_id": 1}, headers=auth_headers
    )
    missing_reference = backend_client.post(
        "/api/v1/users/me/favorites", json={"entity_type": "track"}, headers=auth_headers
    )

    assert invalid_type.status_code == 400
    assert missing_reference.status_code == 400


def test_favorites_are_private_to_each_user(
    backend_client: TestClient, auth_headers: dict[str, str], other_headers: dict[str, str]
) -> None:
    body = {"entity_type": "track", **youtube_track("yt_fav_bridge_1")}
    backend_client.post("/api/v1/users/me/favorites", json=body, headers=auth_headers)

    assert backend_client.get("/api/v1/users/me/favorites", headers=other_headers).json() == []
    backend_client.delete("/api/v1/users/me/favorites/track/yt_fav_bridge_1", headers=other_headers)
    assert len(backend_client.get("/api/v1/users/me/favorites", headers=auth_headers).json()) == 1


def test_play_history_by_video_id_and_track_id(backend_client: TestClient, auth_headers: dict[str, str]) -> None:
    by_video = backend_client.post(
        "/api/v1/users/me/history",
        json=youtube_track("yt_hist_bridge_1", played_seconds=60.0),
        headers=auth_headers,
    )
    assert by_video.status_code == 201
    track_id = by_video.json()["track_id"]

    by_id = backend_client.post(
        "/api/v1/users/me/history",
        json={"track_id": track_id, "played_seconds": 120.0, "skipped": True, "context": "search"},
        headers=auth_headers,
    )
    assert by_id.status_code == 201

    history = backend_client.get("/api/v1/users/me/history", params={"limit": 10}, headers=auth_headers).json()
    assert [item["played_seconds"] for item in history] == [120.0, 60.0]
    assert history[0]["track"]["youtube_video_id"] == "yt_hist_bridge_1"
    assert len(backend_client.get("/api/v1/users/me/history", params={"limit": 1}, headers=auth_headers).json()) == 1

    missing_reference = backend_client.post("/api/v1/users/me/history", json={"played_seconds": 1.0}, headers=auth_headers)
    assert missing_reference.status_code == 400

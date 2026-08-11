# OpenSpec 01: Especificación del Backend, Autenticación y Registro de Preferencias / Telemetría del Usuario

## 1. Visión General
Esta especificación define el diseño completo para el **Módulo 1: Backend, Autenticación y Registro de Actividad/Preferencias** de la plataforma musical DiegoMusic.

El backend gestiona:
- Autenticación segura de usuarios (JWT + Argon2id/Bcrypt).
- Catálogo musical completo (Artistas, Álbumes, Canciones, Letras).
- Preferencias detalladas del usuario (Audio quality, Crossfade, Volume normalization, Privacy, Notifications).
- Estado del reproductor y Cola de reproducción en tiempo real ("Up Next Queue").
- Historial de reproducción, métricas de escucha y registro de eventos de actividad/telemetría.
- Colección del usuario: Playlists, Favoritos (Tracks, Albums, Artists, Playlists), Descargas y Artistas seguidos.

---

## 2. Esquema de Base de Datos (SQLAlchemy 2.0 Models)

### 2.1 Entidades Principales

#### `User`
- `id`: `int` (PK, autoincrement)
- `email`: `str` (unique, indexed, not null)
- `hashed_password`: `str` (not null)
- `full_name`: `str` (not null)
- `avatar_url`: `str` (optional)
- `is_active`: `bool` (default `True`)
- `is_admin`: `bool` (default `False`)
- `created_at`: `datetime` (UTC, default `now`)
- `last_login_at`: `datetime` (optional)

#### `UserSettings`
- `id`: `int` (PK)
- `user_id`: `int` (FK `User.id`, unique, indexed, `ondelete="CASCADE"`)
- `audio_quality`: `str` (default `"high"`, options: `"lossless"`, `"high"`, `"standard"`, `"data_saver"`)
- `download_quality`: `str` (default `"high"`)
- `download_over_cellular`: `bool` (default `False`)
- `crossfade_seconds`: `int` (default `0`, range `0-12`)
- `enable_volume_normalization`: `bool` (default `True`)
- `target_lufs`: `float` (default `-14.0`)
- `allow_explicit`: `bool` (default `True`)
- `theme_mode`: `str` (default `"system"`, options: `"system"`, `"dark"`, `"light"`)
- `accent_color`: `str` (default `"bauhaus_red"`)
- `share_listening_history`: `bool` (default `True`)
- `allow_friend_activity`: `bool` (default `True`)
- `notify_new_releases`: `bool` (default `True`)
- `notify_playlist_updates`: `bool` (default `True`)
- `updated_at`: `datetime` (UTC, default `now`, on update `now`)

#### `UserPlayerState`
- `id`: `int` (PK)
- `user_id`: `int` (FK `User.id`, unique, indexed, `ondelete="CASCADE"`)
- `current_track_id`: `int` (FK `Track.id`, optional)
- `position_seconds`: `float` (default `0.0`)
- `playback_status`: `str` (default `"stopped"`, options: `"playing"`, `"paused"`, `"stopped"`)
- `shuffle_enabled`: `bool` (default `False`)
- `repeat_mode`: `str` (default `"off"`, options: `"off"`, `"one"`, `"all"`)
- `queue_json`: `str` (JSON string list of track IDs in queue, default `"[]"`)
- `history_queue_json`: `str` (JSON string list of recently played track IDs in current session, default `"[]"`)
- `device_info`: `str` (optional)
- `updated_at`: `datetime` (UTC, default `now`)

#### `Artist`
- `id`: `int` (PK)
- `name`: `str` (indexed, not null)
- `bio`: `str` (optional)
- `image_url`: `str` (optional)
- `banner_url`: `str` (optional)
- `genre`: `str` (indexed, optional)
- `is_verified`: `bool` (default `True`)
- `created_at`: `datetime` (UTC, default `now`)

#### `Album`
- `id`: `int` (PK)
- `title`: `str` (indexed, not null)
- `cover_url`: `str` (optional)
- `release_year`: `int` (optional)
- `release_type`: `str` (default `"album"`, options: `"album"`, `"single"`, `"ep"`)
- `genre`: `str` (optional)
- `artist_id`: `int` (FK `Artist.id`, indexed, `ondelete="CASCADE"`)
- `created_at`: `datetime` (UTC, default `now`)

#### `Track`
- `id`: `int` (PK)
- `title`: `str` (indexed, not null)
- `duration_seconds`: `int` (not null)
- `audio_url`: `str` (optional)
- `youtube_video_id`: `str` (indexed, optional)
- `track_number`: `int` (default `1`)
- `disc_number`: `int` (default `1`)
- `is_explicit`: `bool` (default `False`)
- `lyrics`: `str` (optional)
- `album_id`: `int` (FK `Album.id`, indexed, `ondelete="CASCADE"`)
- `artist_id`: `int` (FK `Artist.id`, indexed, `ondelete="CASCADE"`)
- `created_at`: `datetime` (UTC, default `now`)

#### `Playlist`
- `id`: `int` (PK)
- `name`: `str` (not null)
- `description`: `str` (optional)
- `cover_url`: `str` (optional)
- `is_public`: `bool` (default `False`)
- `user_id`: `int` (FK `User.id`, indexed, `ondelete="CASCADE"`)
- `created_at`: `datetime` (UTC, default `now`)
- `updated_at`: `datetime` (UTC, default `now`)

#### `PlaylistTrack`
- `playlist_id`: `int` (FK `Playlist.id`, PK, `ondelete="CASCADE"`)
- `track_id`: `int` (FK `Track.id`, PK, `ondelete="CASCADE"`)
- `order`: `int` (default `0`)
- `added_by_user_id`: `int` (FK `User.id`, optional)
- `added_at`: `datetime` (UTC, default `now`)

#### `UserFavorite`
- `id`: `int` (PK)
- `user_id`: `int` (FK `User.id`, indexed, `ondelete="CASCADE"`)
- `entity_type`: `str` (not null, options: `"track"`, `"album"`, `"artist"`, `"playlist"`)
- `entity_id`: `int` (not null)
- `created_at`: `datetime` (UTC, default `now`)

#### `UserFollow`
- `user_id`: `int` (FK `User.id`, PK, `ondelete="CASCADE"`)
- `artist_id`: `int` (FK `Artist.id`, PK, `ondelete="CASCADE"`)
- `created_at`: `datetime` (UTC, default `now`)

#### `PlayHistory`
- `id`: `int` (PK)
- `user_id`: `int` (FK `User.id`, indexed, `ondelete="CASCADE"`)
- `track_id`: `int` (FK `Track.id`, indexed, `ondelete="CASCADE"`)
- `played_seconds`: `float` (default `0.0`)
- `completed`: `bool` (default `False`)
- `skipped`: `bool` (default `False`)
- `context`: `str` (optional, e.g. `"playlist:12"`, `"album:5"`, `"search"`, `"queue"`)
- `device`: `str` (optional, e.g. `"iPhone 15 Pro"`, `"macOS Air"`)
- `network_type`: `str` (optional, e.g. `"wifi"`, `"cellular"`)
- `played_at`: `datetime` (UTC, default `now`, indexed)

#### `UserActivityLog` (Telemetría de Eventos)
- `id`: `int` (PK)
- `user_id`: `int` (FK `User.id`, indexed, `ondelete="CASCADE"`)
- `event_type`: `str` (indexed, e.g. `"search"`, `"view_artist"`, `"view_album"`, `"share"`, `"download"`, `"setting_change"`)
- `event_data_json`: `str` (optional JSON string)
- `timestamp`: `datetime` (UTC, default `now`, indexed)

#### `UserDownload`
- `id`: `int` (PK)
- `user_id`: `int` (FK `User.id`, indexed, `ondelete="CASCADE"`)
- `track_id`: `int` (FK `Track.id`, indexed, `ondelete="CASCADE"`)
- `quality`: `str` (default `"high"`)
- `file_size_bytes`: `int` (default `0`)
- `downloaded_at`: `datetime` (UTC, default `now`)

---

## 3. Contrato de Endpoints REST API (`/api/v1/`)

### 3.1 Autenticación (`/api/v1/auth`)
- `POST /api/v1/auth/register` — Registro con `email`, `password`, `full_name`. Retorna token JWT + datos del usuario.
- `POST /api/v1/auth/login` — Autenticación con OAuth2 Form data (`username`=email, `password`). Retorna `Token`.
- `GET /api/v1/auth/me` — Retorna perfil del usuario autenticado.
- `PUT /api/v1/auth/me` — Actualiza perfil (`full_name`, `avatar_url`).

### 3.2 Ajustes y Preferencias (`/api/v1/users/me/settings`)
- `GET /api/v1/users/me/settings` — Retorna `UserSettings`.
- `PATCH /api/v1/users/me/settings` — Actualización parcial de ajustes de audio, fundido, tema y privacidad.

### 3.3 Reproductor y Estado de Cola (`/api/v1/users/me/player-state`)
- `GET /api/v1/users/me/player-state` — Obtiene el estado actual del reproductor y la cola ("Up Next").
- `PUT /api/v1/users/me/player-state` — Sincroniza estado del reproductor (canción actual, posición, cola, shuffle/repeat).

### 3.4 Historial y Telemetría (`/api/v1/users/me/history` & `/telemetry`)
- `POST /api/v1/users/me/history` — Registra un evento de reproducción (`track_id`, `played_seconds`, `completed`, `skipped`, `context`, `device`).
- `GET /api/v1/users/me/history` — Consulta el historial paginado del usuario.
- `POST /api/v1/telemetry/events` — Registra un evento de actividad de la app (`event_type`, `event_data`).

### 3.5 Favoritos y Colección (`/api/v1/users/me/favorites`)
- `GET /api/v1/users/me/favorites` — Lista favoritos filtrables por `entity_type` (`track`, `album`, `artist`, `playlist`).
- `POST /api/v1/users/me/favorites` — Agrega un favorito (`entity_type`, `entity_id`).
- `DELETE /api/v1/users/me/favorites/{entity_type}/{entity_id}` — Elimina un favorito.
- `POST /api/v1/users/me/following/{artist_id}` & `DELETE /api/v1/users/me/following/{artist_id}` — Seguir/Dejar de seguir artista.
- `GET /api/v1/users/me/following` — Lista de artistas seguidos.

### 3.6 Catálogo (`/api/v1/catalog`)
- `GET /api/v1/catalog/artists` & `GET /api/v1/catalog/artists/{id}`
- `GET /api/v1/catalog/albums` & `GET /api/v1/catalog/albums/{id}`
- `GET /api/v1/catalog/tracks` & `GET /api/v1/catalog/tracks/{id}`
- `GET /api/v1/catalog/search?q={query}` — Búsqueda unificada en artistas, álbumes y canciones.

### 3.7 Playlists (`/api/v1/playlists`)
- `POST /api/v1/playlists` — Crear playlist.
- `GET /api/v1/playlists/me` — Consultar mis playlists.
- `GET /api/v1/playlists/{id}` — Consultar playlist por ID con sus pistas ordenadas.
- `POST /api/v1/playlists/{id}/tracks` — Añadir canción a la playlist (`track_id`, `order`).
- `DELETE /api/v1/playlists/{id}/tracks/{track_id}` — Eliminar canción de la playlist.
- `DELETE /api/v1/playlists/{id}` — Eliminar playlist.

---

## 4. Requisitos de Rendimiento y Concurrencia (SQLite WAL)
- Inicialización de SQLite con PRAGMAs optimizados:
  ```python
  @event.listens_for(Engine, "connect")
  def set_sqlite_pragma(dbapi_connection, connection_record):
      cursor = dbapi_connection.cursor()
      cursor.execute("PRAGMA journal_mode=WAL;")
      cursor.execute("PRAGMA synchronous=NORMAL;")
      cursor.execute("PRAGMA foreign_keys=ON;")
      cursor.close()
  ```
- Single-flight read locking & conexionalidad limpia por request vía FastAPI Dependency Injection (`get_db`).

---

## 5. Checklist de Verificación y Auditoría
- [ ] 100% de los modelos definidos en SQLAlchemy 2.0 con tipos `Mapped[...]`.
- [ ] 100% de las preferencias y estados del reproductor sincronizables por API.
- [ ] Hashing seguro con Argon2id / Bcrypt (`pwdlib`).
- [ ] Swagger interactivo en `/docs` validado.
- [ ] Suite de pruebas con `pytest` pasando al 100%.

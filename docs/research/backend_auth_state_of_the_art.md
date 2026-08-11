# Estado del Arte: Backend FastAPI, SQLAlchemy 2.0, SQLite WAL & Autenticación de Plataforma Musical

## 1. Resumen Ejecutivo
Este documento sintetiza la arquitectura del backend para una plataforma de streaming de música (estilo Apple Music). El objetivo es ofrecer un servicio pragmático, de altísimo rendimiento local y sin sobre-ingeniería, utilizando **FastAPI**, **SQLAlchemy 2.0** (estilo Mapped/mapped_column), **SQLite en modo WAL** (Write-Ahead Logging) y autenticación JWT segura mediante `pwdlib` (Argon2id/Bcrypt).

---

## 2. Autenticación y Seguridad
- **Hashing de Contraseñas:** `passlib` está obsoleto y presenta problemas de compatibilidad con Python 3.13+. Se adopta `pwdlib` con algoritmos `argon2id` y `bcrypt`.
- **JWT (JSON Web Tokens):** Emisión de access tokens firmados con HMAC-SHA256 (`HS256`). Tiempos de expiración explícitos vía `ACCESS_TOKEN_EXPIRE_MINUTES`.
- **OAuth2 Password Bearer:** Integración directa con Swagger UI (`/docs`) mediante el flujo `OAuth2PasswordBearer` y esquema `HTTPBearer`.

---

## 3. Base de Datos SQLite & SQLAlchemy 2.0
- **Modo WAL (Write-Ahead Logging):** Configuración de `PRAGMA journal_mode=WAL;` y `PRAGMA synchronous=NORMAL;` al iniciar las conexiones SQLite. Esto elimina bloqueos en lecturas concurrentes y maximiza la velocidad de escritura local.
- **Foreign Keys Reales:** SQLite desactiva Foreign Keys por defecto. Se activa explícitamente `PRAGMA foreign_keys=ON;` en el evento `connect` de SQLAlchemy.
- **SQLAlchemy 2.0 Modern Syntax:**
  - Uso de `DeclarativeBase`.
  - Atributos declarados con `Mapped[T] = mapped_column(...)`.
  - Relaciones fuertemente tipadas con `relationship(...)` y reglas `cascade="all, delete-orphan"`.

---

## 4. Registro Completo de Uso, Preferencias y Telemetría del Usuario
Para que la plataforma funcione como un servicio musical moderno, no basta con autenticación básica. Toda interacción debe ser registrada en la base de datos:
1. **Preferencias del Usuario (`UserSettings`):** Calidad de audio (Lossless/High/Saver), fundido cruzado (crossfade), normalización de volumen (LUFS), reproducción explícita, temas visuales y ajustes de privacidad.
2. **Estado de Reproducción Sincronizado (`UserPlayerState`):** Guardado de pista actual, posición en segundos, estado de reproducción, shuffle, repeat mode y la cola de reproducción ("Up Next Queue").
3. **Historial Detallado y Telemetría (`PlayHistory` & `UserActivityLog`):** Registro de cada escucha con duración real, porcentaje completado, evento de salto (skip), contexto de reproducción (lista, álbum, búsqueda) y dispositivo/red.
4. **Colecciones y Favoritos Polimórficos (`UserFavorite`):** Soporte unificado de me gusta para canciones, álbumes, artistas y listas de reproducción.
5. **Seguimiento a Artistas (`UserFollow`):** Registro de artistas seguidos para generación de novedades.
6. **Gestión de Descargas Locales (`UserDownload`):** Registro de pistas descargadas para modo offline con metadatos de almacenamiento.

---

## 5. Estrategia de Pruebas e Integración Continua
- Pruebas unitarias e integración con `pytest` y `httpx.AsyncClient` / `TestClient`.
- Base de datos SQLite temporal en memoria o archivo efímero para ejecución de tests aislados.
- Verificación estática con `ruff` / `mypy`.

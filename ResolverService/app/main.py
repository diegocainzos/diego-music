from __future__ import annotations

from contextlib import asynccontextmanager
import hmac
from typing import AsyncIterator

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from starlette.background import BackgroundTask

from .audio_cache import PersistentAudioCache
from .config import Settings
from .models import HealthResponse, ResolveRequest, ResolveResponse, SearchResponse, SearchResultItem
from .resolution_cache import CachingAudioResolver
from .resolver import AudioResolutionError, AudioResolving, YTDLPResolver
from .sessions import SessionExpiredError, SessionNotFoundError, SessionStore


_FORWARDED_REQUEST_HEADERS = {"range", "if-range"}
_FORWARDED_RESPONSE_HEADERS = {
    "accept-ranges",
    "cache-control",
    "content-encoding",
    "content-length",
    "content-range",
    "content-type",
    "etag",
    "last-modified",
}


def create_app(
    settings: Settings | None = None,
    resolver: AudioResolving | None = None,
    store: SessionStore | None = None,
    upstream_client: httpx.AsyncClient | None = None,
    audio_cache: PersistentAudioCache | None = None,
) -> FastAPI:
    service_settings = settings or Settings.from_environment()
    base_resolver = resolver or YTDLPResolver(service_settings)
    service_resolver = CachingAudioResolver(
        resolver=base_resolver,
        max_entries=service_settings.resolution_cache_max_entries,
        ttl_seconds=service_settings.resolution_cache_ttl_seconds,
        safety_margin_seconds=service_settings.resolution_cache_safety_margin_seconds,
    )
    session_store = store or SessionStore(service_settings.session_ttl_seconds)
    persistent_cache = audio_cache or PersistentAudioCache(
        directory=service_settings.audio_cache_directory,
        max_bytes=service_settings.audio_cache_max_bytes,
        max_file_bytes=service_settings.audio_cache_max_file_bytes,
    )
    owns_upstream_client = upstream_client is None

    @asynccontextmanager
    async def lifespan(application: FastAPI) -> AsyncIterator[None]:
        application.state.upstream_client = upstream_client or httpx.AsyncClient(
            timeout=httpx.Timeout(service_settings.upstream_timeout_seconds),
            follow_redirects=True,
        )
        await persistent_cache.initialize()
        yield
        await persistent_cache.close()
        if owns_upstream_client:
            await application.state.upstream_client.aclose()

    app = FastAPI(
        title="DiegoMusic Private Audio Resolver",
        version="1.0.0",
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
        lifespan=lifespan,
    )
    bearer = HTTPBearer(auto_error=False)

    async def require_api_token(
        credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    ) -> None:
        valid = (
            credentials is not None
            and credentials.scheme.lower() == "bearer"
            and hmac.compare_digest(credentials.credentials, service_settings.api_token)
        )
        if not valid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credencial no válida.",
                headers={"WWW-Authenticate": "Bearer"},
            )

    @app.get("/health", response_model=HealthResponse)
    async def health() -> HealthResponse:
        return HealthResponse()

    @app.post(
        "/v1/audio/resolve",
        response_model=ResolveResponse,
        dependencies=[Depends(require_api_token)],
    )
    async def resolve_audio(payload: ResolveRequest, request: Request) -> ResolveResponse:
        try:
            audio = await persistent_cache.get(payload.video_id)
            if audio is None:
                audio = await service_resolver.resolve(payload.video_id)
                persistent_cache.schedule(
                    payload.video_id,
                    audio,
                    request.app.state.upstream_client,
                )
            session = session_store.create(payload.video_id, audio)
        except AudioResolutionError as error:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=error.public_message) from error
        except SessionExpiredError as error:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="El origen devolvió una sesión expirada.") from error

        return ResolveResponse(
            streamURL=f"{service_settings.public_base_url}/v1/audio/stream/{session.token}",
            expiresAt=session.expires_at,
            contentType=session.audio.content_type,
            cacheStatus=session.audio.cache_status,
        )

    @app.get(
        "/v1/search",
        response_model=SearchResponse,
        dependencies=[Depends(require_api_token)],
    )
    async def search_fallback(q: str) -> SearchResponse:
        query = q.strip()
        if not query:
            return SearchResponse(items=[])
        try:
            raw_results = await base_resolver.search(query)
            items = [
                SearchResultItem(
                    id=item["id"],
                    kind="video",
                    title=item["title"],
                    channelTitle=item["channelTitle"],
                    thumbnailURL=item.get("thumbnailURL"),
                )
                for item in raw_results
            ]
            return SearchResponse(items=items)
        except Exception as error:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Error al realizar búsqueda alternativa en VPS.",
            ) from error

    async def proxy_audio(request: Request, token: str, head_only: bool) -> Response:
        try:
            session = session_store.get(token)
        except SessionExpiredError as error:
            raise HTTPException(status_code=status.HTTP_410_GONE, detail="La sesión de audio expiró.") from error
        except SessionNotFoundError as error:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="La sesión de audio no existe.") from error

        audio = await persistent_cache.get(session.video_id) or session.audio
        if audio.cached_path is not None:
            if not audio.cached_path.is_file():
                raise HTTPException(status_code=status.HTTP_410_GONE, detail="El archivo cacheado ya no está disponible.")
            return FileResponse(
                audio.cached_path,
                media_type=audio.content_type,
            )

        if audio.upstream_url is None:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="La fuente de audio no es válida.")

        headers = dict(audio.headers)
        for name in _FORWARDED_REQUEST_HEADERS:
            if value := request.headers.get(name):
                headers[name] = value

        client: httpx.AsyncClient = request.app.state.upstream_client
        upstream_request = client.build_request(
            "HEAD" if head_only else "GET",
            audio.upstream_url,
            headers=headers,
        )
        try:
            upstream = await client.send(upstream_request, stream=True)
        except httpx.RequestError as error:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="El origen de audio no respondió.") from error

        response_headers = {
            name: value
            for name, value in upstream.headers.items()
            if name.lower() in _FORWARDED_RESPONSE_HEADERS
        }
        response_headers.setdefault("content-type", audio.content_type)

        if upstream.status_code not in (200, 206, 416):
            await upstream.aclose()
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="El origen rechazó la reproducción.")

        if head_only:
            await upstream.aclose()
            return Response(status_code=upstream.status_code, headers=response_headers)

        return StreamingResponse(
            upstream.aiter_raw(),
            status_code=upstream.status_code,
            headers=response_headers,
            background=BackgroundTask(upstream.aclose),
        )

    @app.get("/v1/audio/stream/{token}")
    async def stream_audio(request: Request, token: str) -> Response:
        return await proxy_audio(request, token, head_only=False)

    @app.head("/v1/audio/stream/{token}")
    async def inspect_audio(request: Request, token: str) -> Response:
        return await proxy_audio(request, token, head_only=True)

    return app

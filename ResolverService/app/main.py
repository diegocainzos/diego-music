from __future__ import annotations

from contextlib import asynccontextmanager
import hmac
from typing import AsyncIterator

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, Response, status
from fastapi.responses import StreamingResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from starlette.background import BackgroundTask

from .config import Settings
from .models import HealthResponse, ResolveRequest, ResolveResponse
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
) -> FastAPI:
    service_settings = settings or Settings.from_environment()
    service_resolver = resolver or YTDLPResolver(service_settings)
    session_store = store or SessionStore(service_settings.session_ttl_seconds)
    owns_upstream_client = upstream_client is None

    @asynccontextmanager
    async def lifespan(application: FastAPI) -> AsyncIterator[None]:
        application.state.upstream_client = upstream_client or httpx.AsyncClient(
            timeout=httpx.Timeout(service_settings.upstream_timeout_seconds),
            follow_redirects=True,
        )
        yield
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
    async def resolve_audio(payload: ResolveRequest) -> ResolveResponse:
        try:
            audio = await service_resolver.resolve(payload.video_id)
            session = session_store.create(audio)
        except AudioResolutionError as error:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_CONTENT, detail=error.public_message) from error
        except SessionExpiredError as error:
            raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="El origen devolvió una sesión expirada.") from error

        return ResolveResponse(
            streamURL=f"{service_settings.public_base_url}/v1/audio/stream/{session.token}",
            expiresAt=session.expires_at,
            contentType=session.audio.content_type,
        )

    async def proxy_audio(request: Request, token: str, head_only: bool) -> Response:
        try:
            session = session_store.get(token)
        except SessionExpiredError as error:
            raise HTTPException(status_code=status.HTTP_410_GONE, detail="La sesión de audio expiró.") from error
        except SessionNotFoundError as error:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="La sesión de audio no existe.") from error

        headers = dict(session.audio.headers)
        for name in _FORWARDED_REQUEST_HEADERS:
            if value := request.headers.get(name):
                headers[name] = value

        client: httpx.AsyncClient = request.app.state.upstream_client
        upstream_request = client.build_request(
            "HEAD" if head_only else "GET",
            session.audio.upstream_url,
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
        response_headers.setdefault("content-type", session.audio.content_type)

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

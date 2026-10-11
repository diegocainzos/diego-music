from __future__ import annotations

from datetime import timezone
import json
from pathlib import Path

import pytest

from app.config import Settings
from app.models import ArtistDetailResponse
from app.resolver import AudioResolutionError, YTDLPResolver
from fake_binaries import fake_ytdlp


@pytest.fixture
def resolver() -> YTDLPResolver:
    return YTDLPResolver(
        Settings(
            api_token="test-token-with-at-least-thirty-two-characters",
            public_base_url="https://audio.example.test",
        )
    )


def test_arguments_use_fixed_youtube_url_and_no_shell(resolver: YTDLPResolver) -> None:
    arguments = resolver._arguments("M7lc1UVf-VE")

    assert arguments[-2:] == ["--", "https://www.youtube.com/watch?v=M7lc1UVf-VE"]
    assert "--no-playlist" in arguments
    assert "--no-cache-dir" in arguments
    assert "bestaudio[ext=m4a][acodec^=mp4a]/bestaudio[ext=m4a]" in arguments
    assert "--extractor-args" in arguments
    assert "youtube:player_client=ios,web,mweb,web_embedded" in arguments


def test_parse_info_accepts_audio_only_m4a(resolver: YTDLPResolver) -> None:
    result = resolver._parse_info(
        {
            "url": "https://rr1.googlevideo.com/videoplayback?expire=1893456000",
            "ext": "m4a",
            "acodec": "mp4a.40.2",
            "vcodec": "none",
            "http_headers": {
                "User-Agent": "allowed",
                "X-Internal": "discarded",
            },
        }
    )

    assert result.content_type == "audio/mp4"
    assert result.headers == {"User-Agent": "allowed"}
    assert result.upstream_expires_at is not None
    assert result.upstream_expires_at.tzinfo == timezone.utc


@pytest.mark.parametrize(
    "changes",
    [
        {"url": "https://attacker.example/audio.m4a"},
        {"ext": "webm", "acodec": "opus"},
        {"vcodec": "avc1.640028"},
    ],
)
def test_parse_info_rejects_incompatible_or_untrusted_formats(
    resolver: YTDLPResolver,
    changes: dict[str, str],
) -> None:
    info = {
        "url": "https://rr1.googlevideo.com/videoplayback?expire=1893456000",
        "ext": "m4a",
        "acodec": "mp4a.40.2",
        "vcodec": "none",
    }
    info.update(changes)

    with pytest.raises(AudioResolutionError):
        resolver._parse_info(info)


SEARCH_OUTPUT = json.dumps(
    {
        "entries": [
            {"id": "M7lc1UVf-VE", "title": "Primera", "uploader": "Canal A"},
            {"id": "AAAAAAAAAAA", "title": "Segunda", "channel": "Canal B"},
            {"id": "BBBBBBBBBBB"},  # sin título: se descarta
            "no es un diccionario",
        ]
    }
)


def resolver_using(binary: Path) -> YTDLPResolver:
    return YTDLPResolver(
        Settings(
            api_token="test-token-with-at-least-thirty-two-characters",
            public_base_url="https://audio.example.test",
            ytdlp_binary=str(binary),
        )
    )


@pytest.mark.asyncio
async def test_search_returns_items_in_the_public_shape(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path, payload=None, stdout=SEARCH_OUTPUT)
    resolver = resolver_using(ytdlp.path)

    items = await resolver.search("coldplay", limit=2)

    assert items == [
        {
            "id": "M7lc1UVf-VE",
            "kind": "video",
            "title": "Primera",
            "channelTitle": "Canal A",
            "thumbnailURL": "https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg",
        },
        {
            "id": "AAAAAAAAAAA",
            "kind": "video",
            "title": "Segunda",
            "channelTitle": "Canal B",
            "thumbnailURL": "https://i.ytimg.com/vi/AAAAAAAAAAA/hqdefault.jpg",
        },
    ]
    (arguments,) = ytdlp.calls
    assert arguments[-1] == "ytsearch2:coldplay"


@pytest.mark.asyncio
async def test_artist_detail_reuses_search_items_without_copies(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path, payload=None, stdout=SEARCH_OUTPUT)
    resolver = resolver_using(ytdlp.path)

    detail = await resolver.get_artist_detail("Coldplay")
    response = ArtistDetailResponse(**detail)

    assert [call[-1] for call in ytdlp.calls] == ["ytsearch15:Coldplay tracks", "ytsearch8:Coldplay radio"]
    assert response.artist.id == "Coldplay"
    assert response.artist.title == "Coldplay"
    assert response.artist.thumbnail_url == "https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg"
    assert [item.id for item in response.top_tracks] == ["M7lc1UVf-VE", "AAAAAAAAAAA"]
    assert [item.id for item in response.related] == ["M7lc1UVf-VE", "AAAAAAAAAAA"]


RADIO_OUTPUT = json.dumps(
    {
        "entries": [
            {
                "id": "M7lc1UVf-VE",
                "title": "Pista semilla",
                "uploader": "Artista semilla",
                "duration": 200,
            },
            {
                "id": "short",
                "title": "Id corto",
                "channel": "Canal",
            },
            {
                "id": "toolongvideoid",
                "title": "Id largo",
                "channel": "Canal",
            },
            {
                "id": "invalid!char",
                "title": "Caracteres inválidos",
                "channel": "Canal",
            },
            {
                "id": "11111111111",
                "title": "Primera radio",
                "channel": "Canal 1",
                "duration": 180,
            },
            {
                "id": "11111111111",
                "title": "Primera radio dupe",
                "channel": "Canal 1",
            },
            {
                "id": "22222222222",
                "title": "Segunda radio",
                "uploader": "Subidor 2",
                "duration": 240.8,
            },
            {
                "id": "33333333333",
                "title": "Tercera radio",
            },
            "no es un diccionario",
        ]
    }
)


@pytest.mark.asyncio
async def test_radio_arguments_use_flat_playlist_and_seed_mix(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path, payload=None, stdout=RADIO_OUTPUT)
    resolver = resolver_using(ytdlp.path)

    items = await resolver.radio("M7lc1UVf-VE", limit=30)

    assert len(items) == 3
    (arguments,) = ytdlp.calls
    assert arguments[-1] == "https://www.youtube.com/watch?v=M7lc1UVf-VE&list=RDM7lc1UVf-VE"
    assert "--flat-playlist" in arguments
    assert "--playlist-end" in arguments
    assert arguments[arguments.index("--playlist-end") + 1] == "30"
    assert "--dump-single-json" in arguments
    assert "--no-warnings" in arguments
    assert "--quiet" in arguments
    assert "--no-cache-dir" in arguments
    assert "--skip-download" in arguments


@pytest.mark.asyncio
async def test_radio_filters_seed_invalid_ids_and_deduplicates(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path, payload=None, stdout=RADIO_OUTPUT)
    resolver = resolver_using(ytdlp.path)

    items = await resolver.radio("M7lc1UVf-VE", limit=30)

    assert items == [
        {
            "id": "11111111111",
            "title": "Primera radio",
            "channel": "Canal 1",
            "duration_seconds": 180,
        },
        {
            "id": "22222222222",
            "title": "Segunda radio",
            "channel": "Subidor 2",
            "duration_seconds": 240,
        },
        {
            "id": "33333333333",
            "title": "Tercera radio",
            "channel": "",
            "duration_seconds": None,
        },
    ]


@pytest.mark.asyncio
async def test_radio_caps_at_limit(tmp_path: Path) -> None:
    ytdlp = fake_ytdlp(tmp_path, payload=None, stdout=RADIO_OUTPUT)
    resolver = resolver_using(ytdlp.path)

    items = await resolver.radio("M7lc1UVf-VE", limit=2)

    assert len(items) == 2
    assert [item["id"] for item in items] == ["11111111111", "22222222222"]


@pytest.mark.asyncio
async def test_radio_returns_empty_list_on_nonzero_exit_or_bad_json(tmp_path: Path) -> None:
    failing_ytdlp = fake_ytdlp(tmp_path / "fail", payload=None, exit_code=1)
    bad_json_ytdlp = fake_ytdlp(tmp_path / "bad", payload=None, stdout="{malformed json")

    assert await resolver_using(failing_ytdlp.path).radio("M7lc1UVf-VE") == []
    assert await resolver_using(bad_json_ytdlp.path).radio("M7lc1UVf-VE") == []


@pytest.mark.asyncio
async def test_radio_timeout_raises_audio_resolution_error(tmp_path: Path) -> None:
    slow_ytdlp = fake_ytdlp(tmp_path, payload=None, sleep=0.5)
    resolver = YTDLPResolver(
        Settings(
            api_token="test-token-with-at-least-thirty-two-characters",
            public_base_url="https://audio.example.test",
            ytdlp_binary=str(slow_ytdlp.path),
            resolve_timeout_seconds=0.05,
        )
    )

    with pytest.raises(AudioResolutionError, match="No se pudo generar la radio."):
        await resolver.radio("M7lc1UVf-VE")


@pytest.mark.asyncio
async def test_radio_oserror_raises_audio_resolution_error() -> None:
    resolver = YTDLPResolver(
        Settings(
            api_token="test-token-with-at-least-thirty-two-characters",
            public_base_url="https://audio.example.test",
            ytdlp_binary="/nonexistent/path/to/yt-dlp",
        )
    )

    with pytest.raises(AudioResolutionError, match="No se pudo generar la radio."):
        await resolver.radio("M7lc1UVf-VE")

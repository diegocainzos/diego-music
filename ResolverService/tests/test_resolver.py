from __future__ import annotations

from datetime import timezone

import pytest

from app.config import Settings
from app.resolver import AudioResolutionError, YTDLPResolver


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
    assert "youtube:player_client=web_embedded,android,web" in arguments


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

from __future__ import annotations

import pytest

from app.config import ConfigurationError, Settings


def test_settings_require_long_token() -> None:
    with pytest.raises(ConfigurationError, match="32"):
        Settings(api_token="short", public_base_url="https://audio.example.test")


def test_settings_require_https_public_url() -> None:
    with pytest.raises(ConfigurationError, match="HTTPS"):
        Settings(
            api_token="test-token-with-at-least-thirty-two-characters",
            public_base_url="http://audio.example.test",
        )


def test_settings_reject_invalid_cache_limits() -> None:
    with pytest.raises(ConfigurationError, match="RESOLUTION_CACHE_MAX_ENTRIES"):
        Settings(
            api_token="test-token-with-at-least-thirty-two-characters",
            public_base_url="https://audio.example.test",
            resolution_cache_max_entries=-1,
        )

    with pytest.raises(ConfigurationError, match="AUDIO_CACHE_DIR"):
        Settings(
            api_token="test-token-with-at-least-thirty-two-characters",
            public_base_url="https://audio.example.test",
            audio_cache_directory=None,
            audio_cache_max_bytes=100,
        )


def test_environment_enables_persistent_cache(monkeypatch: pytest.MonkeyPatch, tmp_path) -> None:
    monkeypatch.setenv("DIEGOMUSIC_API_TOKEN", "test-token-with-at-least-thirty-two-characters")
    monkeypatch.setenv("PUBLIC_BASE_URL", "https://audio.example.test")
    monkeypatch.setenv("AUDIO_CACHE_DIR", str(tmp_path))
    monkeypatch.setenv("AUDIO_CACHE_MAX_BYTES", "12345")
    monkeypatch.setenv("RESOLUTION_CACHE_MAX_ENTRIES", "42")

    value = Settings.from_environment()

    assert value.audio_cache_directory == tmp_path
    assert value.audio_cache_max_bytes == 12345
    assert value.resolution_cache_max_entries == 42


def test_settings_normalize_trailing_slash() -> None:
    value = Settings(
        api_token="test-token-with-at-least-thirty-two-characters",
        public_base_url="https://audio.example.test/",
    )

    assert value.public_base_url == "https://audio.example.test"

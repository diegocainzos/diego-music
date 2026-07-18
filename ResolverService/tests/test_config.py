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


def test_settings_normalize_trailing_slash() -> None:
    value = Settings(
        api_token="test-token-with-at-least-thirty-two-characters",
        public_base_url="https://audio.example.test/",
    )

    assert value.public_base_url == "https://audio.example.test"

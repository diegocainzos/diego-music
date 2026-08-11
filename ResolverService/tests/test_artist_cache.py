from datetime import datetime, timezone
import pytest

from app.artist_cache import ArtistCache


def test_artist_cache_set_and_get():
    cache = ArtistCache(max_entries=10, ttl_seconds=60)
    data = {
        "artist": {"id": "Coldplay", "title": "Coldplay"},
        "topTracks": [],
        "related": [],
    }

    cache.set("Coldplay", data)
    retrieved = cache.get("Coldplay")

    assert retrieved is not None
    assert retrieved["artist"]["id"] == "Coldplay"


def test_artist_cache_case_insensitive():
    cache = ArtistCache(max_entries=10, ttl_seconds=60)
    data = {"artist": {"id": "coldplay", "title": "Coldplay"}}

    cache.set("COLDPLAY", data)
    assert cache.get("coldplay") == data


def test_artist_cache_expiration():
    now = datetime(2026, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
    cache = ArtistCache(max_entries=10, ttl_seconds=10, clock=lambda: now)

    cache.set("artist1", {"id": "1"})
    assert cache.get("artist1") is not None

    # Advance time beyond TTL
    now = datetime(2026, 1, 1, 12, 0, 15, tzinfo=timezone.utc)
    assert cache.get("artist1") is None

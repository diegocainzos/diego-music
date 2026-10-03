from __future__ import annotations

import traceback

from fastapi.testclient import TestClient
import pytest
from sqlalchemy import func, select

from app.config import Settings
from app.main import create_app
from backend_app.config import ConfigurationError, Settings as BackendSettings, load_settings
from backend_app.database import Base, SessionLocal, engine
from backend_app.models import Artist, Track, User
from backend_app.seed import seed_database

SECRET_SENTINEL = "super-secret-sentinel-value"  # menos de 32 caracteres
DATABASE_SENTINEL = "sqlite:///sentinel-database-path.db"


def full_traceback(error: BaseException) -> str:
    return "".join(traceback.format_exception(error))


def test_secret_key_has_no_default() -> None:
    assert BackendSettings.model_fields["SECRET_KEY"].is_required()


def test_missing_secret_key_fails_with_a_sanitized_error(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("SECRET_KEY", raising=False)
    monkeypatch.setenv("DATABASE_URL", DATABASE_SENTINEL)

    with pytest.raises(ConfigurationError, match="SECRET_KEY") as raised:
        load_settings()

    assert DATABASE_SENTINEL not in str(raised.value)
    assert DATABASE_SENTINEL not in full_traceback(raised.value)


def test_short_secret_key_is_rejected_without_printing_it(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SECRET_KEY", SECRET_SENTINEL)
    monkeypatch.setenv("DATABASE_URL", DATABASE_SENTINEL)

    with pytest.raises(ConfigurationError, match="SECRET_KEY") as raised:
        load_settings()

    for output in (str(raised.value), repr(raised.value), full_traceback(raised.value)):
        assert SECRET_SENTINEL not in output
        assert DATABASE_SENTINEL not in output


def test_secret_key_of_32_characters_is_accepted(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SECRET_KEY", "k" * 32)

    assert load_settings().SECRET_KEY == "k" * 32


def count(model: type) -> int:
    with SessionLocal() as db:
        return db.scalar(select(func.count()).select_from(model)) or 0


@pytest.fixture
def empty_database():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


def start_app(**overrides: object) -> None:
    settings = Settings(
        api_token="test-token-with-at-least-thirty-two-characters",
        public_base_url="https://audio.example.test",
        **overrides,
    )
    with TestClient(create_app(settings)):
        pass


def test_startup_creates_no_users_by_default(empty_database: None) -> None:
    start_app()

    assert count(User) == 0


def test_startup_seeds_only_the_demo_user_when_enabled(empty_database: None) -> None:
    start_app(seed_demo_data=True)

    assert count(User) == 1
    assert count(Artist) == 0
    assert count(Track) == 0
    with SessionLocal() as db:
        demo = db.scalars(select(User)).one()
    assert demo.email == "demo@diegomusic.app"


def test_seed_is_idempotent(empty_database: None) -> None:
    with SessionLocal() as db:
        seed_database(db)
        seed_database(db)

    assert count(User) == 1


def test_seed_does_nothing_when_users_already_exist(empty_database: None) -> None:
    with SessionLocal() as db:
        db.add(User(email="real@diegomusic.app", full_name="Real", hashed_password="x"))
        db.commit()
        seed_database(db)

    assert count(User) == 1
    with SessionLocal() as db:
        assert db.scalars(select(User)).one().email == "real@diegomusic.app"

from datetime import datetime, timezone
from typing import Optional, List
from sqlalchemy import (
    String, Integer, Float, Boolean, DateTime, ForeignKey, Text, UniqueConstraint, PrimaryKeyConstraint
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .database import Base

def utc_now() -> datetime:
    return datetime.now(timezone.utc)

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    avatar_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    last_login_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relaciones
    settings: Mapped[Optional["UserSettings"]] = relationship("UserSettings", back_populates="user", uselist=False, cascade="all, delete-orphan")
    player_state: Mapped[Optional["UserPlayerState"]] = relationship("UserPlayerState", back_populates="user", uselist=False, cascade="all, delete-orphan")
    playlists: Mapped[List["Playlist"]] = relationship("Playlist", back_populates="user", cascade="all, delete-orphan")
    favorites: Mapped[List["UserFavorite"]] = relationship("UserFavorite", back_populates="user", cascade="all, delete-orphan")
    followed_artists: Mapped[List["UserFollow"]] = relationship("UserFollow", back_populates="user", cascade="all, delete-orphan")
    play_history: Mapped[List["PlayHistory"]] = relationship("PlayHistory", back_populates="user", cascade="all, delete-orphan")
    activity_logs: Mapped[List["UserActivityLog"]] = relationship("UserActivityLog", back_populates="user", cascade="all, delete-orphan")
    downloads: Mapped[List["UserDownload"]] = relationship("UserDownload", back_populates="user", cascade="all, delete-orphan")


class UserSettings(Base):
    __tablename__ = "user_settings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True, nullable=False)
    audio_quality: Mapped[str] = mapped_column(String(32), default="high", nullable=False)  # lossless, high, standard, data_saver
    download_quality: Mapped[str] = mapped_column(String(32), default="high", nullable=False)
    download_over_cellular: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    crossfade_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    enable_volume_normalization: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    target_lufs: Mapped[float] = mapped_column(Float, default=-14.0, nullable=False)
    allow_explicit: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    theme_mode: Mapped[str] = mapped_column(String(32), default="system", nullable=False)  # system, dark, light
    accent_color: Mapped[str] = mapped_column(String(32), default="bauhaus_red", nullable=False)
    share_listening_history: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    allow_friend_activity: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notify_new_releases: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notify_playlist_updates: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="settings")


class UserPlayerState(Base):
    __tablename__ = "user_player_states"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True, nullable=False)
    current_track_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("tracks.id", ondelete="SET NULL"), nullable=True)
    position_seconds: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    playback_status: Mapped[str] = mapped_column(String(32), default="stopped", nullable=False)  # playing, paused, stopped
    shuffle_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    repeat_mode: Mapped[str] = mapped_column(String(32), default="off", nullable=False)  # off, one, all
    queue_json: Mapped[str] = mapped_column(Text, default="[]", nullable=False)  # Lista de IDs en formato JSON
    history_queue_json: Mapped[str] = mapped_column(Text, default="[]", nullable=False)
    device_info: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="player_state")
    current_track: Mapped[Optional["Track"]] = relationship("Track")


class Artist(Base):
    __tablename__ = "artists"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), index=True, nullable=False)
    bio: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    banner_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    genre: Mapped[Optional[str]] = mapped_column(String(100), index=True, nullable=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    albums: Mapped[List["Album"]] = relationship("Album", back_populates="artist", cascade="all, delete-orphan")
    tracks: Mapped[List["Track"]] = relationship("Track", back_populates="artist", cascade="all, delete-orphan")
    followers: Mapped[List["UserFollow"]] = relationship("UserFollow", back_populates="artist", cascade="all, delete-orphan")


class Album(Base):
    __tablename__ = "albums"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255), index=True, nullable=False)
    cover_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    release_year: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    release_type: Mapped[str] = mapped_column(String(32), default="album", nullable=False)  # album, single, ep
    genre: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    artist_id: Mapped[int] = mapped_column(Integer, ForeignKey("artists.id", ondelete="CASCADE"), index=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    artist: Mapped["Artist"] = relationship("Artist", back_populates="albums")
    tracks: Mapped[List["Track"]] = relationship("Track", back_populates="album", cascade="all, delete-orphan")


class Track(Base):
    __tablename__ = "tracks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255), index=True, nullable=False)
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    audio_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    youtube_video_id: Mapped[Optional[str]] = mapped_column(String(64), index=True, nullable=True)
    track_number: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    disc_number: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_explicit: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    lyrics: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    album_id: Mapped[int] = mapped_column(Integer, ForeignKey("albums.id", ondelete="CASCADE"), index=True, nullable=False)
    artist_id: Mapped[int] = mapped_column(Integer, ForeignKey("artists.id", ondelete="CASCADE"), index=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    album: Mapped["Album"] = relationship("Album", back_populates="tracks")
    artist: Mapped["Artist"] = relationship("Artist", back_populates="tracks")


class Playlist(Base):
    __tablename__ = "playlists"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    cover_url: Mapped[Optional[str]] = mapped_column(String(512), nullable=True)
    is_public: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, onupdate=utc_now, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="playlists")
    playlist_tracks: Mapped[List["PlaylistTrack"]] = relationship("PlaylistTrack", back_populates="playlist", cascade="all, delete-orphan", order_by="PlaylistTrack.order")


class PlaylistTrack(Base):
    __tablename__ = "playlist_tracks"

    playlist_id: Mapped[int] = mapped_column(Integer, ForeignKey("playlists.id", ondelete="CASCADE"), primary_key=True)
    track_id: Mapped[int] = mapped_column(Integer, ForeignKey("tracks.id", ondelete="CASCADE"), primary_key=True)
    order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    added_by_user_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    added_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    playlist: Mapped["Playlist"] = relationship("Playlist", back_populates="playlist_tracks")
    track: Mapped["Track"] = relationship("Track")


class UserFavorite(Base):
    __tablename__ = "user_favorites"
    __table_args__ = (
        UniqueConstraint("user_id", "entity_type", "entity_id", name="uq_user_favorite_entity"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    entity_type: Mapped[str] = mapped_column(String(32), nullable=False)  # track, album, artist, playlist
    entity_id: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="favorites")


class UserFollow(Base):
    __tablename__ = "user_follows"

    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    artist_id: Mapped[int] = mapped_column(Integer, ForeignKey("artists.id", ondelete="CASCADE"), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="followed_artists")
    artist: Mapped["Artist"] = relationship("Artist", back_populates="followers")


class PlayHistory(Base):
    __tablename__ = "play_history"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    track_id: Mapped[int] = mapped_column(Integer, ForeignKey("tracks.id", ondelete="CASCADE"), index=True, nullable=False)
    played_seconds: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    skipped: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    context: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    device: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)
    network_type: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)
    played_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="play_history")
    track: Mapped["Track"] = relationship("Track")


class UserActivityLog(Base):
    __tablename__ = "user_activity_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    event_type: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    event_data_json: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, index=True, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="activity_logs")


class UserDownload(Base):
    __tablename__ = "user_downloads"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    track_id: Mapped[int] = mapped_column(Integer, ForeignKey("tracks.id", ondelete="CASCADE"), index=True, nullable=False)
    quality: Mapped[str] = mapped_column(String(32), default="high", nullable=False)
    file_size_bytes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    downloaded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now, nullable=False)

    user: Mapped["User"] = relationship("User", back_populates="downloads")
    track: Mapped["Track"] = relationship("Track")

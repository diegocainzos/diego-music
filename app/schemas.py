from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, EmailStr, Field, ConfigDict, field_validator

# Token Schemas
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    email: str

# User Schemas
class UserBase(BaseModel):
    email: EmailStr
    full_name: str
    avatar_url: Optional[str] = None

class UserCreate(UserBase):
    password: str = Field(..., min_length=10, max_length=25)

    @field_validator("password")
    @classmethod
    def validate_password_complexity(cls, v: str) -> str:
        if not any(c.isupper() for c in v):
            raise ValueError("La contraseña debe contener al menos una letra mayúscula")
        return v

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None

class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    is_active: bool
    is_admin: bool
    created_at: datetime
    last_login_at: Optional[datetime] = None

# Track Schemas (artista y álbum se anidan en TrackResponse)
class ArtistBase(BaseModel):
    name: str
    bio: Optional[str] = None
    image_url: Optional[str] = None
    banner_url: Optional[str] = None
    genre: Optional[str] = None
    is_verified: bool = True

class ArtistResponse(ArtistBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime

class AlbumBase(BaseModel):
    title: str
    cover_url: Optional[str] = None
    release_year: Optional[int] = None
    release_type: str = "album"
    genre: Optional[str] = None
    artist_id: int

class AlbumResponse(AlbumBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    artist: Optional[ArtistResponse] = None
    created_at: datetime

class TrackBase(BaseModel):
    title: str
    duration_seconds: int
    audio_url: Optional[str] = None
    youtube_video_id: Optional[str] = None
    track_number: int = 1
    disc_number: int = 1
    is_explicit: bool = False
    lyrics: Optional[str] = None
    album_id: int
    artist_id: int

class TrackResponse(TrackBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    artist: Optional[ArtistResponse] = None
    album: Optional[AlbumResponse] = None
    created_at: datetime

class YouTubeTrackRef(BaseModel):
    """Metadatos de YouTube que el cliente envía en lugar de un track_id."""
    youtube_video_id: Optional[str] = None
    title: Optional[str] = None
    channel_title: Optional[str] = None
    thumbnail_url: Optional[str] = None
    duration_seconds: Optional[int] = None

# Playlist Schemas
class PlaylistCreate(BaseModel):
    name: str
    description: Optional[str] = None
    cover_url: Optional[str] = None
    is_public: bool = False

class PlaylistUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    cover_url: Optional[str] = None
    is_public: Optional[bool] = None

class PlaylistTrackAdd(YouTubeTrackRef):
    track_id: Optional[int] = None
    order: Optional[int] = 0

class PlaylistTrackResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    playlist_id: int
    track_id: int
    order: int
    added_at: datetime
    track: Optional[TrackResponse] = None

class PlaylistResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    description: Optional[str] = None
    cover_url: Optional[str] = None
    is_public: bool
    user_id: int
    created_at: datetime
    updated_at: datetime
    tracks: List[PlaylistTrackResponse] = []

# Favorites
class FavoriteCreate(YouTubeTrackRef):
    entity_type: str  # track, album, artist, playlist
    entity_id: Optional[int] = None

class FavoriteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    entity_type: str
    entity_id: int
    created_at: datetime
    track: Optional[TrackResponse] = None

# History
class PlayHistoryCreate(YouTubeTrackRef):
    track_id: Optional[int] = None
    played_seconds: float = 0.0
    completed: bool = False
    skipped: bool = False
    context: Optional[str] = None
    device: Optional[str] = None
    network_type: Optional[str] = None

class PlayHistoryResponse(PlayHistoryCreate):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    played_at: datetime
    track: Optional[TrackResponse] = None

from datetime import datetime
from typing import Optional, List, Any
from pydantic import BaseModel, EmailStr, Field, ConfigDict

# Token Schemas
class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    email: str

class TokenData(BaseModel):
    user_id: Optional[int] = None
    email: Optional[str] = None

# User Schemas
class UserBase(BaseModel):
    email: EmailStr
    full_name: str
    avatar_url: Optional[str] = None

class UserCreate(UserBase):
    password: str = Field(..., min_length=6)

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

# UserSettings Schemas
class UserSettingsBase(BaseModel):
    audio_quality: str = "high"
    download_quality: str = "high"
    download_over_cellular: bool = False
    crossfade_seconds: int = Field(0, ge=0, le=12)
    enable_volume_normalization: bool = True
    target_lufs: float = -14.0
    allow_explicit: bool = True
    theme_mode: str = "system"
    accent_color: str = "bauhaus_red"
    share_listening_history: bool = True
    allow_friend_activity: bool = True
    notify_new_releases: bool = True
    notify_playlist_updates: bool = True

class UserSettingsUpdate(BaseModel):
    audio_quality: Optional[str] = None
    download_quality: Optional[str] = None
    download_over_cellular: Optional[bool] = None
    crossfade_seconds: Optional[int] = Field(None, ge=0, le=12)
    enable_volume_normalization: Optional[bool] = None
    target_lufs: Optional[float] = None
    allow_explicit: Optional[bool] = None
    theme_mode: Optional[str] = None
    accent_color: Optional[str] = None
    share_listening_history: Optional[bool] = None
    allow_friend_activity: Optional[bool] = None
    notify_new_releases: Optional[bool] = None
    notify_playlist_updates: Optional[bool] = None

class UserSettingsResponse(UserSettingsBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    updated_at: datetime

# UserPlayerState Schemas
class UserPlayerStateUpdate(BaseModel):
    current_track_id: Optional[int] = None
    position_seconds: Optional[float] = 0.0
    playback_status: Optional[str] = "stopped"
    shuffle_enabled: Optional[bool] = False
    repeat_mode: Optional[str] = "off"
    queue: Optional[List[int]] = []
    history_queue: Optional[List[int]] = []
    device_info: Optional[str] = None

class UserPlayerStateResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    current_track_id: Optional[int] = None
    position_seconds: float
    playback_status: str
    shuffle_enabled: bool
    repeat_mode: str
    queue: List[int] = []
    history_queue: List[int] = []
    device_info: Optional[str] = None
    updated_at: datetime

# Catalog Schemas
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

class PlaylistTrackAdd(BaseModel):
    track_id: int
    order: Optional[int] = 0

class PlaylistTrackReorder(BaseModel):
    track_ids: List[int]

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

# Favorites & Follows
class FavoriteCreate(BaseModel):
    entity_type: str  # track, album, artist, playlist
    entity_id: int

class FavoriteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    entity_type: str
    entity_id: int
    created_at: datetime
    track: Optional[TrackResponse] = None

# History & Telemetry
class PlayHistoryCreate(BaseModel):
    track_id: int
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

class TelemetryEventCreate(BaseModel):
    event_type: str
    event_data: Optional[dict[str, Any]] = None

class TelemetryEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    event_type: str
    event_data_json: Optional[str] = None
    timestamp: datetime

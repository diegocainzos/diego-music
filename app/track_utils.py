from typing import Optional
from sqlalchemy.orm import Session
from .models import Artist, Album, Track

def get_or_create_youtube_track(
    db: Session,
    youtube_video_id: str,
    title: Optional[str] = None,
    channel_title: Optional[str] = None,
    thumbnail_url: Optional[str] = None,
    duration_seconds: Optional[int] = None
) -> Track:
    """Busca o crea una pista asociada a un youtube_video_id."""
    existing = db.query(Track).filter(Track.youtube_video_id == youtube_video_id).first()
    if existing:
        # Actualizar campos si se proporcionan nuevos
        updated = False
        if title and existing.title != title:
            existing.title = title
            updated = True
        if duration_seconds and duration_seconds > 0 and existing.duration_seconds != duration_seconds:
            existing.duration_seconds = duration_seconds
            updated = True
        if updated:
            db.commit()
            db.refresh(existing)
        return existing

    # Crear o encontrar artista
    artist_name = (channel_title or "").strip() or "YouTube Artist"
    artist = db.query(Artist).filter(Artist.name == artist_name).first()
    if not artist:
        artist = Artist(
            name=artist_name,
            image_url=thumbnail_url,
            is_verified=False
        )
        db.add(artist)
        db.flush()

    # Crear o encontrar álbum
    album_title = f"{artist_name} Tracks"
    album = db.query(Album).filter(Album.title == album_title, Album.artist_id == artist.id).first()
    if not album:
        album = Album(
            title=album_title,
            cover_url=thumbnail_url,
            release_type="single",
            artist_id=artist.id
        )
        db.add(album)
        db.flush()

    track = Track(
        title=(title or f"Track {youtube_video_id}").strip(),
        duration_seconds=duration_seconds or 0,
        youtube_video_id=youtube_video_id,
        album_id=album.id,
        artist_id=artist.id,
        is_explicit=False
    )
    db.add(track)
    db.commit()
    db.refresh(track)
    return track

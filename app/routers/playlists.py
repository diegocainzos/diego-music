from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..models import User, Playlist, PlaylistTrack, Track, utc_now
from ..track_utils import resolve_track_id, track_id_candidates
from ..schemas import PlaylistCreate, PlaylistUpdate, PlaylistResponse, PlaylistTrackAdd
from ..auth import get_current_user

router = APIRouter(prefix="/playlists", tags=["Listas de Reproducción (Playlists)"])


def _owned_playlist(db: Session, playlist_id: int, user: User, action: str = "modificar") -> Playlist:
    """Devuelve la playlist si pertenece al usuario; 404 si no existe y 403 si es de otro usuario."""
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist no encontrada")
    if playlist.user_id != user.id:
        raise HTTPException(status_code=403, detail=f"No tienes permisos para {action} esta playlist")
    return playlist


def _named_playlist(db: Session, user: User, name: str) -> Playlist | None:
    return db.query(Playlist).filter(Playlist.user_id == user.id, func.lower(Playlist.name) == func.lower(name)).first()  # mismo lower() que el índice único (ASCII en SQLite)


def _existing(playlist: Playlist) -> JSONResponse:
    return JSONResponse(jsonable_encoder(PlaylistResponse.model_validate(playlist)), status_code=status.HTTP_200_OK)


@router.post("/", response_model=PlaylistResponse, status_code=status.HTTP_201_CREATED)
def create_playlist(playlist_in: PlaylistCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Crea la playlist o, si la cuenta ya tiene una con ese nombre (sin mayúsculas), devuelve esa con 200."""
    existing = _named_playlist(db, current_user, playlist_in.name)
    if existing:
        return _existing(existing)
    playlist = Playlist(
        name=playlist_in.name,
        description=playlist_in.description,
        cover_url=playlist_in.cover_url,
        is_public=playlist_in.is_public,
        user_id=current_user.id
    )
    db.add(playlist)
    try:
        db.commit()
    except IntegrityError:  # otra petición simultánea la creó primero (índice único)
        db.rollback()
        existing = _named_playlist(db, current_user, playlist_in.name)
        if existing is None:
            raise HTTPException(status_code=409, detail="Ya existe una playlist con ese nombre.")
        return _existing(existing)
    db.refresh(playlist)
    return playlist

@router.get("/me", response_model=List[PlaylistResponse])
def get_my_playlists(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Obtiene las playlists creadas por el usuario autenticado."""
    return db.query(Playlist).filter(Playlist.user_id == current_user.id).order_by(Playlist.updated_at.desc()).all()

@router.get("/{playlist_id}", response_model=PlaylistResponse)
def get_playlist_by_id(playlist_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Obtiene una playlist con sus pistas ordenadas."""
    playlist = db.query(Playlist)\
        .options(joinedload(Playlist.playlist_tracks).joinedload(PlaylistTrack.track).joinedload(Track.artist))\
        .filter(Playlist.id == playlist_id).first()

    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist no encontrada")

    if not playlist.is_public and playlist.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acceso denegado a esta playlist privada")

    return playlist

@router.put("/{playlist_id}", response_model=PlaylistResponse)
def update_playlist(
    playlist_id: int,
    playlist_in: PlaylistUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Actualiza metadatos (nombre, descripción, portada, visibilidad) de una playlist."""
    playlist = _owned_playlist(db, playlist_id, current_user)

    update_data = playlist_in.model_dump(exclude_unset=True)
    new_name = update_data.get("name")
    if new_name:
        clash = _named_playlist(db, current_user, new_name)
        if clash and clash.id != playlist.id:
            raise HTTPException(status_code=409, detail="Ya existe una playlist con ese nombre.")
    for field, value in update_data.items():
        setattr(playlist, field, value)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Ya existe una playlist con ese nombre.")
    db.refresh(playlist)
    return playlist

@router.post("/{playlist_id}/tracks", response_model=PlaylistResponse)
def add_track_to_playlist(
    playlist_id: int,
    track_in: PlaylistTrackAdd,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Añade una canción a la playlist respetando el orden."""
    playlist = _owned_playlist(db, playlist_id, current_user)

    target_track_id = resolve_track_id(db, track_in.track_id, track_in)
    if target_track_id is None:
        raise HTTPException(status_code=400, detail="track_id o youtube_video_id requerido")

    track = db.query(Track).filter(Track.id == target_track_id).first()
    if not track:
        raise HTTPException(status_code=404, detail="Canción no encontrada")

    # Verificar si ya existe en la playlist
    existing = db.query(PlaylistTrack).filter(PlaylistTrack.playlist_id == playlist_id, PlaylistTrack.track_id == target_track_id).first()
    if not existing:
        last = db.query(func.max(PlaylistTrack.order)).filter(PlaylistTrack.playlist_id == playlist_id).scalar()
        pt = PlaylistTrack(
            playlist_id=playlist_id,
            track_id=target_track_id,
            order=track_in.order if "order" in track_in.model_fields_set and track_in.order is not None else (-1 if last is None else last) + 1,
            added_by_user_id=current_user.id
        )
        db.add(pt)
        playlist.updated_at = utc_now()
        db.commit()

    db.refresh(playlist)
    return playlist

@router.delete("/{playlist_id}/tracks/{track_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_track_from_playlist(
    playlist_id: int,
    track_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Elimina una canción de la playlist (por id numérico o youtube_video_id)."""
    _owned_playlist(db, playlist_id, current_user)

    for candidate in track_id_candidates(db, track_id):
        pt = db.query(PlaylistTrack).filter(PlaylistTrack.playlist_id == playlist_id, PlaylistTrack.track_id == candidate).first()
        if pt:
            db.delete(pt)
            db.commit()
            break
    return None

@router.delete("/{playlist_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_playlist(playlist_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Elimina una playlist."""
    playlist = _owned_playlist(db, playlist_id, current_user, action="eliminar")
    db.delete(playlist)
    db.commit()
    return None

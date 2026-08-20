from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..models import User, Playlist, PlaylistTrack, Track
from ..track_utils import get_or_create_youtube_track
from ..schemas import PlaylistCreate, PlaylistUpdate, PlaylistResponse, PlaylistTrackAdd, PlaylistTrackReorder
from ..auth import get_current_user

router = APIRouter(prefix="/playlists", tags=["Listas de Reproducción (Playlists)"])

@router.post("/", response_model=PlaylistResponse, status_code=status.HTTP_201_CREATED)
def create_playlist(playlist_in: PlaylistCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Crea una nueva playlist asociada al usuario autenticado."""
    playlist = Playlist(
        name=playlist_in.name,
        description=playlist_in.description,
        cover_url=playlist_in.cover_url,
        is_public=playlist_in.is_public,
        user_id=current_user.id
    )
    db.add(playlist)
    db.commit()
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
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist no encontrada")
    if playlist.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="No tienes permisos para modificar esta playlist")

    update_data = playlist_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(playlist, field, value)

    db.commit()
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
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist no encontrada")
    if playlist.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="No tienes permisos para modificar esta playlist")

    target_track_id = track_in.track_id
    if target_track_id is None and track_in.youtube_video_id:
        track = get_or_create_youtube_track(
            db=db,
            youtube_video_id=track_in.youtube_video_id,
            title=track_in.title,
            channel_title=track_in.channel_title,
            thumbnail_url=track_in.thumbnail_url,
            duration_seconds=track_in.duration_seconds
        )
        target_track_id = track.id

    if target_track_id is None:
        raise HTTPException(status_code=400, detail="track_id o youtube_video_id requerido")

    track = db.query(Track).filter(Track.id == target_track_id).first()
    if not track:
        raise HTTPException(status_code=404, detail="Canción no encontrada")

    # Verificar si ya existe en la playlist
    existing = db.query(PlaylistTrack).filter(PlaylistTrack.playlist_id == playlist_id, PlaylistTrack.track_id == target_track_id).first()
    if not existing:
        pt = PlaylistTrack(
            playlist_id=playlist_id,
            track_id=target_track_id,
            order=track_in.order or 0,
            added_by_user_id=current_user.id
        )
        db.add(pt)
        db.commit()

    db.refresh(playlist)
    return playlist

@router.put("/{playlist_id}/tracks/reorder", response_model=PlaylistResponse)
def reorder_playlist_tracks(
    playlist_id: int,
    reorder_in: PlaylistTrackReorder,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Reordena la lista de canciones en la playlist según la lista de IDs proporcionada."""
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist no encontrada")
    if playlist.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="No tienes permisos para modificar esta playlist")

    pts = db.query(PlaylistTrack).filter(PlaylistTrack.playlist_id == playlist_id).all()
    pt_map = {pt.track_id: pt for pt in pts}

    for index, track_id in enumerate(reorder_in.track_ids):
        if track_id in pt_map:
            pt_map[track_id].order = index

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
    """Elimina una canción de la playlist."""
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist no encontrada")
    if playlist.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="No tienes permisos para modificar esta playlist")

    pt = None
    if track_id.isdigit():
        pt = db.query(PlaylistTrack).filter(PlaylistTrack.playlist_id == playlist_id, PlaylistTrack.track_id == int(track_id)).first()

    if not pt:
        track = db.query(Track).filter(Track.youtube_video_id == track_id).first()
        if track:
            pt = db.query(PlaylistTrack).filter(PlaylistTrack.playlist_id == playlist_id, PlaylistTrack.track_id == track.id).first()

    if pt:
        db.delete(pt)
        db.commit()
    return None

@router.delete("/{playlist_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_playlist(playlist_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Elimina una playlist."""
    playlist = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not playlist:
        raise HTTPException(status_code=404, detail="Playlist no encontrada")
    if playlist.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="No tienes permisos para eliminar esta playlist")

    db.delete(playlist)
    db.commit()
    return None

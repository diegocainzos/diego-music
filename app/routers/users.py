from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..models import User, PlayHistory, UserFavorite, Track
from ..track_utils import resolve_track_id, track_id_candidates
from ..schemas import (
    PlayHistoryCreate, PlayHistoryResponse,
    FavoriteCreate, FavoriteResponse, TrackResponse
)
from ..auth import get_current_user

router = APIRouter(prefix="/users/me", tags=["Usuario: favoritos e historial"])

# --- 1. Historial de Reproducción ---
@router.post("/history", response_model=PlayHistoryResponse, status_code=status.HTTP_201_CREATED)
def record_play_history(history_in: PlayHistoryCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Registra una sesión de reproducción de canción en el historial."""
    target_track_id = resolve_track_id(db, history_in.track_id, history_in)
    if target_track_id is None:
        raise HTTPException(status_code=400, detail="track_id o youtube_video_id requerido")

    history = PlayHistory(
        user_id=current_user.id,
        track_id=target_track_id,
        played_seconds=history_in.played_seconds,
        completed=history_in.completed,
        skipped=history_in.skipped,
        context=history_in.context,
        device=history_in.device,
        network_type=history_in.network_type
    )
    db.add(history)
    db.commit()
    db.refresh(history)
    return history

@router.get("/history", response_model=List[PlayHistoryResponse])
def get_play_history(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Consulta el historial paginado de canciones escuchadas."""
    history_list = db.query(PlayHistory)\
        .options(
            joinedload(PlayHistory.track).joinedload(Track.artist),
            joinedload(PlayHistory.track).joinedload(Track.album)
        )\
        .filter(PlayHistory.user_id == current_user.id)\
        .order_by(PlayHistory.played_at.desc())\
        .offset(offset)\
        .limit(limit)\
        .all()
    return history_list

# --- 2. Favoritos y Colección ---
def _favorite_response(db: Session, favorite: UserFavorite) -> FavoriteResponse:
    """Construye la respuesta de un favorito, anidando la pista cuando es de tipo track."""
    track_resp = None
    if favorite.entity_type == "track":
        track = db.query(Track).options(joinedload(Track.artist), joinedload(Track.album)).filter(Track.id == favorite.entity_id).first()
        if track:
            track_resp = TrackResponse.model_validate(track)
    return FavoriteResponse(
        id=favorite.id,
        user_id=favorite.user_id,
        entity_type=favorite.entity_type,
        entity_id=favorite.entity_id,
        created_at=favorite.created_at,
        track=track_resp
    )

@router.get("/favorites", response_model=List[FavoriteResponse])
def get_favorites(
    entity_type: Optional[str] = Query(None, description="Filtrar por track, album, artist o playlist"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Obtiene los elementos guardados en favoritos del usuario."""
    query = db.query(UserFavorite).filter(UserFavorite.user_id == current_user.id)
    if entity_type:
        query = query.filter(UserFavorite.entity_type == entity_type)
    favs = query.order_by(UserFavorite.created_at.desc()).all()
    return [_favorite_response(db, fav) for fav in favs]

@router.post("/favorites", response_model=FavoriteResponse, status_code=status.HTTP_201_CREATED)
def add_favorite(fav_in: FavoriteCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Agrega un elemento a favoritos."""
    if fav_in.entity_type not in ["track", "album", "artist", "playlist"]:
        raise HTTPException(status_code=400, detail="entity_type inválido. Debe ser: track, album, artist, playlist.")

    target_entity_id = fav_in.entity_id
    if fav_in.entity_type == "track":
        target_entity_id = resolve_track_id(db, fav_in.entity_id, fav_in)

    if target_entity_id is None:
        raise HTTPException(status_code=400, detail="entity_id o youtube_video_id requerido")

    favorite = db.query(UserFavorite).filter(
        UserFavorite.user_id == current_user.id,
        UserFavorite.entity_type == fav_in.entity_type,
        UserFavorite.entity_id == target_entity_id
    ).first()

    if favorite is None:
        favorite = UserFavorite(
            user_id=current_user.id,
            entity_type=fav_in.entity_type,
            entity_id=target_entity_id
        )
        db.add(favorite)
        db.commit()
        db.refresh(favorite)

    return _favorite_response(db, favorite)

@router.delete("/favorites/{entity_type}/{entity_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_favorite(entity_type: str, entity_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Elimina un elemento de favoritos (por id numérico o, para pistas, por youtube_video_id)."""
    if entity_type == "track":
        candidates = track_id_candidates(db, entity_id)
    else:
        candidates = [int(entity_id)] if entity_id.isdecimal() else []
    for candidate in candidates:
        favorite = db.query(UserFavorite).filter(
            UserFavorite.user_id == current_user.id,
            UserFavorite.entity_type == entity_type,
            UserFavorite.entity_id == candidate
        ).first()
        if favorite:
            db.delete(favorite)
            db.commit()
            break
    return None

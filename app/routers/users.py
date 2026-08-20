import json
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session, joinedload

from ..database import get_db
from ..models import (
    User, UserSettings, UserPlayerState, PlayHistory, UserFavorite, UserFollow, Artist, Track
)
from ..track_utils import get_or_create_youtube_track
from ..schemas import (
    UserSettingsResponse, UserSettingsUpdate,
    UserPlayerStateResponse, UserPlayerStateUpdate,
    PlayHistoryCreate, PlayHistoryResponse,
    FavoriteCreate, FavoriteResponse, ArtistResponse, TrackResponse
)
from ..auth import get_current_user

router = APIRouter(prefix="/users/me", tags=["Usuario, Preferencias y Reproductor"])

# --- 1. Ajustes y Preferencias ---
@router.get("/settings", response_model=UserSettingsResponse)
def get_settings(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Consulta las preferencias y configuraciones del usuario."""
    settings = db.query(UserSettings).filter(UserSettings.user_id == current_user.id).first()
    if not settings:
        settings = UserSettings(user_id=current_user.id)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings

@router.patch("/settings", response_model=UserSettingsResponse)
def update_settings(settings_in: UserSettingsUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Actualiza parcialmente las preferencias del usuario."""
    settings = db.query(UserSettings).filter(UserSettings.user_id == current_user.id).first()
    if not settings:
        settings = UserSettings(user_id=current_user.id)
        db.add(settings)
    
    update_data = settings_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(settings, field, value)
    
    db.commit()
    db.refresh(settings)
    return settings

# --- 2. Estado del Reproductor y Cola ---
@router.get("/player-state", response_model=UserPlayerStateResponse)
def get_player_state(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Obtiene el estado actual del reproductor y la cola de reproducción."""
    player_state = db.query(UserPlayerState).filter(UserPlayerState.user_id == current_user.id).first()
    if not player_state:
        player_state = UserPlayerState(user_id=current_user.id)
        db.add(player_state)
        db.commit()
        db.refresh(player_state)
    
    queue_list = json.loads(player_state.queue_json) if player_state.queue_json else []
    history_queue_list = json.loads(player_state.history_queue_json) if player_state.history_queue_json else []

    return UserPlayerStateResponse(
        id=player_state.id,
        user_id=player_state.user_id,
        current_track_id=player_state.current_track_id,
        position_seconds=player_state.position_seconds,
        playback_status=player_state.playback_status,
        shuffle_enabled=player_state.shuffle_enabled,
        repeat_mode=player_state.repeat_mode,
        queue=queue_list,
        history_queue=history_queue_list,
        device_info=player_state.device_info,
        updated_at=player_state.updated_at
    )

@router.put("/player-state", response_model=UserPlayerStateResponse)
def update_player_state(state_in: UserPlayerStateUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Sincroniza el estado del reproductor y la cola de canciones en tiempo real."""
    player_state = db.query(UserPlayerState).filter(UserPlayerState.user_id == current_user.id).first()
    if not player_state:
        player_state = UserPlayerState(user_id=current_user.id)
        db.add(player_state)

    if state_in.current_track_id is not None:
        player_state.current_track_id = state_in.current_track_id
    if state_in.position_seconds is not None:
        player_state.position_seconds = state_in.position_seconds
    if state_in.playback_status is not None:
        player_state.playback_status = state_in.playback_status
    if state_in.shuffle_enabled is not None:
        player_state.shuffle_enabled = state_in.shuffle_enabled
    if state_in.repeat_mode is not None:
        player_state.repeat_mode = state_in.repeat_mode
    if state_in.queue is not None:
        player_state.queue_json = json.dumps(state_in.queue)
    if state_in.history_queue is not None:
        player_state.history_queue_json = json.dumps(state_in.history_queue)
    if state_in.device_info is not None:
        player_state.device_info = state_in.device_info

    db.commit()
    db.refresh(player_state)

    queue_list = json.loads(player_state.queue_json) if player_state.queue_json else []
    history_queue_list = json.loads(player_state.history_queue_json) if player_state.history_queue_json else []

    return UserPlayerStateResponse(
        id=player_state.id,
        user_id=player_state.user_id,
        current_track_id=player_state.current_track_id,
        position_seconds=player_state.position_seconds,
        playback_status=player_state.playback_status,
        shuffle_enabled=player_state.shuffle_enabled,
        repeat_mode=player_state.repeat_mode,
        queue=queue_list,
        history_queue=history_queue_list,
        device_info=player_state.device_info,
        updated_at=player_state.updated_at
    )

# --- 3. Historial de Reproducción ---
@router.post("/history", response_model=PlayHistoryResponse, status_code=status.HTTP_201_CREATED)
def record_play_history(history_in: PlayHistoryCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Registra una sesión de reproducción de canción en el historial."""
    target_track_id = history_in.track_id
    if target_track_id is None and history_in.youtube_video_id:
        track = get_or_create_youtube_track(
            db=db,
            youtube_video_id=history_in.youtube_video_id,
            title=history_in.title,
            channel_title=history_in.channel_title,
            thumbnail_url=history_in.thumbnail_url,
            duration_seconds=history_in.duration_seconds
        )
        target_track_id = track.id

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

# --- 4. Favoritos y Colección ---
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

    result = []
    for fav in favs:
        track_resp = None
        if fav.entity_type == "track":
            t = db.query(Track).options(joinedload(Track.artist), joinedload(Track.album)).filter(Track.id == fav.entity_id).first()
            if t:
                track_resp = TrackResponse.model_validate(t)
        result.append(FavoriteResponse(
            id=fav.id,
            user_id=fav.user_id,
            entity_type=fav.entity_type,
            entity_id=fav.entity_id,
            created_at=fav.created_at,
            track=track_resp
        ))
    return result

@router.post("/favorites", response_model=FavoriteResponse, status_code=status.HTTP_201_CREATED)
def add_favorite(fav_in: FavoriteCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Agrega un elemento a favoritos."""
    if fav_in.entity_type not in ["track", "album", "artist", "playlist"]:
        raise HTTPException(status_code=400, detail="entity_type inválido. Debe ser: track, album, artist, playlist.")
    
    target_entity_id = fav_in.entity_id
    if fav_in.entity_type == "track" and target_entity_id is None and fav_in.youtube_video_id:
        track = get_or_create_youtube_track(
            db=db,
            youtube_video_id=fav_in.youtube_video_id,
            title=fav_in.title,
            channel_title=fav_in.channel_title,
            thumbnail_url=fav_in.thumbnail_url,
            duration_seconds=fav_in.duration_seconds
        )
        target_entity_id = track.id

    if target_entity_id is None:
        raise HTTPException(status_code=400, detail="entity_id o youtube_video_id requerido")

    existing = db.query(UserFavorite).filter(
        UserFavorite.user_id == current_user.id,
        UserFavorite.entity_type == fav_in.entity_type,
        UserFavorite.entity_id == target_entity_id
    ).first()

    if existing:
        track_resp = None
        if existing.entity_type == "track":
            t = db.query(Track).options(joinedload(Track.artist), joinedload(Track.album)).filter(Track.id == existing.entity_id).first()
            if t:
                track_resp = TrackResponse.model_validate(t)
        return FavoriteResponse(
            id=existing.id,
            user_id=existing.user_id,
            entity_type=existing.entity_type,
            entity_id=existing.entity_id,
            created_at=existing.created_at,
            track=track_resp
        )

    favorite = UserFavorite(
        user_id=current_user.id,
        entity_type=fav_in.entity_type,
        entity_id=target_entity_id
    )
    db.add(favorite)
    db.commit()
    db.refresh(favorite)

    track_resp = None
    if favorite.entity_type == "track":
        t = db.query(Track).options(joinedload(Track.artist), joinedload(Track.album)).filter(Track.id == favorite.entity_id).first()
        if t:
            track_resp = TrackResponse.model_validate(t)

    return FavoriteResponse(
        id=favorite.id,
        user_id=favorite.user_id,
        entity_type=favorite.entity_type,
        entity_id=favorite.entity_id,
        created_at=favorite.created_at,
        track=track_resp
    )

@router.delete("/favorites/{entity_type}/{entity_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_favorite(entity_type: str, entity_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Elimina un elemento de favoritos."""
    target_id: Optional[int] = None
    if entity_id.isdigit():
        target_id = int(entity_id)

    favorite = None
    if target_id is not None:
        favorite = db.query(UserFavorite).filter(
            UserFavorite.user_id == current_user.id,
            UserFavorite.entity_type == entity_type,
            UserFavorite.entity_id == target_id
        ).first()

    if not favorite and entity_type == "track":
        track = db.query(Track).filter(Track.youtube_video_id == entity_id).first()
        if track:
            favorite = db.query(UserFavorite).filter(
                UserFavorite.user_id == current_user.id,
                UserFavorite.entity_type == entity_type,
                UserFavorite.entity_id == track.id
            ).first()

    if favorite:
        db.delete(favorite)
        db.commit()
    return None

# --- 5. Seguir Artistas ---
@router.post("/following/{artist_id}", status_code=status.HTTP_201_CREATED)
def follow_artist(artist_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Sigue a un artista."""
    artist = db.query(Artist).filter(Artist.id == artist_id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artista no encontrado")

    existing = db.query(UserFollow).filter(UserFollow.user_id == current_user.id, UserFollow.artist_id == artist_id).first()
    if not existing:
        follow = UserFollow(user_id=current_user.id, artist_id=artist_id)
        db.add(follow)
        db.commit()
    return {"message": f"Ahora sigues a {artist.name}"}

@router.delete("/following/{artist_id}", status_code=status.HTTP_204_NO_CONTENT)
def unfollow_artist(artist_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Deja de seguir a un artista."""
    follow = db.query(UserFollow).filter(UserFollow.user_id == current_user.id, UserFollow.artist_id == artist_id).first()
    if follow:
        db.delete(follow)
        db.commit()
    return None

@router.get("/following", response_model=List[ArtistResponse])
def get_followed_artists(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Lista los artistas que sigue el usuario."""
    follows = db.query(UserFollow).filter(UserFollow.user_id == current_user.id).all()
    artist_ids = [f.artist_id for f in follows]
    return db.query(Artist).filter(Artist.id.in_(artist_ids)).all() if artist_ids else []

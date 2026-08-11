from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import or_

from app.database import get_db
from app.models import Artist, Album, Track
from app.schemas import ArtistResponse, AlbumResponse, TrackResponse

router = APIRouter(prefix="/catalog", tags=["Catálogo Musical"])

@router.get("/artists", response_model=List[ArtistResponse])
def get_artists(
    genre: Optional[str] = Query(None, description="Filtrar por género"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """Consulta catálogo de artistas con paginación y filtro de género."""
    query = db.query(Artist)
    if genre:
        query = query.filter(Artist.genre.ilike(f"%{genre}%"))
    return query.offset(offset).limit(limit).all()

@router.get("/artists/{artist_id}", response_model=ArtistResponse)
def get_artist_by_id(artist_id: int, db: Session = Depends(get_db)):
    """Obtiene detalle de un artista por ID."""
    artist = db.query(Artist).filter(Artist.id == artist_id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artista no encontrado")
    return artist

@router.get("/albums", response_model=List[AlbumResponse])
def get_albums(
    artist_id: Optional[int] = Query(None, description="Filtrar por ID de artista"),
    genre: Optional[str] = Query(None, description="Filtrar por género"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """Consulta catálogo de álbumes con carga de artista relacionado."""
    query = db.query(Album).options(joinedload(Album.artist))
    if artist_id:
        query = query.filter(Album.artist_id == artist_id)
    if genre:
        query = query.filter(Album.genre.ilike(f"%{genre}%"))
    return query.offset(offset).limit(limit).all()

@router.get("/albums/{album_id}", response_model=AlbumResponse)
def get_album_by_id(album_id: int, db: Session = Depends(get_db)):
    """Obtiene detalle de un álbum por ID."""
    album = db.query(Album).options(joinedload(Album.artist)).filter(Album.id == album_id).first()
    if not album:
        raise HTTPException(status_code=404, detail="Álbum no encontrado")
    return album

@router.get("/tracks", response_model=List[TrackResponse])
def get_tracks(
    album_id: Optional[int] = Query(None),
    artist_id: Optional[int] = Query(None),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
):
    """Consulta lista de canciones del catálogo."""
    query = db.query(Track).options(joinedload(Track.artist), joinedload(Track.album))
    if album_id:
        query = query.filter(Track.album_id == album_id)
    if artist_id:
        query = query.filter(Track.artist_id == artist_id)
    return query.order_by(Track.track_number.asc()).offset(offset).limit(limit).all()

@router.get("/tracks/{track_id}", response_model=TrackResponse)
def get_track_by_id(track_id: int, db: Session = Depends(get_db)):
    """Obtiene detalle de una canción."""
    track = db.query(Track).options(joinedload(Track.artist), joinedload(Track.album)).filter(Track.id == track_id).first()
    if not track:
        raise HTTPException(status_code=404, detail="Canción no encontrada")
    return track

@router.get("/search")
def global_search(q: str = Query(..., min_length=1), db: Session = Depends(get_db)):
    """Búsqueda global unificada en artistas, álbumes y canciones."""
    search_term = f"%{q}%"
    
    artists = db.query(Artist).filter(Artist.name.ilike(search_term)).limit(10).all()
    albums = db.query(Album).options(joinedload(Album.artist)).filter(Album.title.ilike(search_term)).limit(10).all()
    tracks = db.query(Track).options(joinedload(Track.artist), joinedload(Track.album)).filter(
        or_(Track.title.ilike(search_term), Track.lyrics.ilike(search_term))
    ).limit(20).all()

    return {
        "query": q,
        "artists": [ArtistResponse.model_validate(a) for a in artists],
        "albums": [AlbumResponse.model_validate(a) for a in albums],
        "tracks": [TrackResponse.model_validate(t) for t in tracks]
    }

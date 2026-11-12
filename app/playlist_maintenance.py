"""Fusión de playlists con el mismo nombre (sin mayúsculas) en una misma cuenta."""
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from .models import Playlist, PlaylistTrack


def merge_duplicate_playlists(db: Session) -> None:
    """Deja una playlist por (usuario, nombre): la de menor id, con la unión de pistas. Idempotente."""
    groups = (
        db.query(Playlist.user_id, func.lower(Playlist.name))
        .group_by(Playlist.user_id, func.lower(Playlist.name))
        .having(func.count(Playlist.id) > 1)
        .all()
    )
    for user_id, lowered in groups:
        playlists = (
            db.query(Playlist)
            .filter(Playlist.user_id == user_id, func.lower(Playlist.name) == lowered)
            .order_by(Playlist.id)
            .all()
        )
        survivor, *others = playlists
        present = {pt.track_id for pt in survivor.playlist_tracks}
        next_order = max((pt.order for pt in survivor.playlist_tracks), default=-1) + 1
        for other in others:
            for pt in sorted(other.playlist_tracks, key=lambda item: item.order):
                if pt.track_id not in present:
                    db.add(PlaylistTrack(playlist_id=survivor.id, track_id=pt.track_id, order=next_order,
                                         added_by_user_id=pt.added_by_user_id, added_at=pt.added_at))
                    present.add(pt.track_id)
                    next_order += 1
            db.delete(other)
        db.flush()
    db.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ux_playlists_user_name ON playlists(user_id, lower(name))"))
    db.commit()

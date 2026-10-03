from sqlalchemy.orm import Session
from .models import User
from .auth import hash_password

def seed_database(db: Session):
    """Crea el usuario demo si la base no tiene usuarios. Solo se invoca con SEED_DEMO_DATA activo."""
    if db.query(User).first():
        return

    db.add(User(
        email="demo@diegomusic.app",
        full_name="Diego Cainzos",
        hashed_password=hash_password("DiegoMusic2026!"),
        avatar_url="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400",
        is_active=True,
        is_admin=True
    ))
    db.commit()

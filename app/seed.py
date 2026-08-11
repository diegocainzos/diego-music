from sqlalchemy.orm import Session
from .models import User, UserSettings, UserPlayerState, Artist, Album, Track
from .auth import hash_password

def seed_database(db: Session):
    """Inicializa la base de datos con datos semilla si está vacía."""
    # Verificar si ya existen usuarios
    if db.query(User).first():
        return

    print("🌱 Poblando base de datos con datos de prueba...")

    # 1. Crear Usuario Demo
    demo_user = User(
        email="demo@diegomusic.app",
        full_name="Diego Cainzos",
        hashed_password=hash_password("DiegoMusic2026!"),
        avatar_url="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400",
        is_active=True,
        is_admin=True
    )
    db.add(demo_user)
    db.flush()

    # Inicializar ajustes y reproductor del usuario demo
    demo_settings = UserSettings(user_id=demo_user.id)
    demo_player = UserPlayerState(user_id=demo_user.id)
    db.add(demo_settings)
    db.add(demo_player)

    # 2. Crear Artistas
    artist1 = Artist(
        name="Daft Punk",
        bio="Dúo francés de música electrónica formado en París en 1993.",
        image_url="https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800",
        genre="Electronic",
        is_verified=True
    )
    artist2 = Artist(
        name="Miles Davis",
        bio="Trompetista y compositor estadounidense de jazz, considerado una de las figuras más influyentes del siglo XX.",
        image_url="https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800",
        genre="Jazz",
        is_verified=True
    )
    artist3 = Artist(
        name="Kavinsky",
        bio="Productor francés de synthwave y house.",
        image_url="https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800",
        genre="Synthwave",
        is_verified=True
    )
    db.add_all([artist1, artist2, artist3])
    db.flush()

    # 3. Crear Álbumes
    album1 = Album(
        title="Random Access Memories",
        cover_url="https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?w=600",
        release_year=2013,
        release_type="album",
        genre="Electronic",
        artist_id=artist1.id
    )
    album2 = Album(
        title="Kind of Blue",
        cover_url="https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=600",
        release_year=1959,
        release_type="album",
        genre="Jazz",
        artist_id=artist2.id
    )
    album3 = Album(
        title="OutRun",
        cover_url="https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600",
        release_year=2013,
        release_type="album",
        genre="Synthwave",
        artist_id=artist3.id
    )
    db.add_all([album1, album2, album3])
    db.flush()

    # 4. Crear Canciones (Tracks)
    tracks = [
        Track(
            title="Get Lucky",
            duration_seconds=248,
            audio_url="https://stream.diegomusic.app/v1/audio/stream/56829103",
            youtube_video_id="5NV6Rdv1a3I",
            track_number=1,
            album_id=album1.id,
            artist_id=artist1.id,
            is_explicit=False
        ),
        Track(
            title="Instant Crush",
            duration_seconds=337,
            audio_url="https://stream.diegomusic.app/v1/audio/stream/56829104",
            youtube_video_id="a5uQMWj3Uzo",
            track_number=2,
            album_id=album1.id,
            artist_id=artist1.id,
            is_explicit=False
        ),
        Track(
            title="So What",
            duration_seconds=562,
            audio_url="https://stream.diegomusic.app/v1/audio/stream/56829105",
            youtube_video_id="ylXk1LBvIqU",
            track_number=1,
            album_id=album2.id,
            artist_id=artist2.id,
            is_explicit=False
        ),
        Track(
            title="Nightcall",
            duration_seconds=259,
            audio_url="https://stream.diegomusic.app/v1/audio/stream/56829106",
            youtube_video_id="MV_3Dpw-BRY",
            track_number=1,
            album_id=album3.id,
            artist_id=artist3.id,
            is_explicit=False
        )
    ]
    db.add_all(tracks)
    db.commit()
    print("✅ Datos de prueba insertados con éxito.")

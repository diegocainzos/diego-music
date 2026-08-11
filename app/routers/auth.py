from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User, UserSettings, UserPlayerState
from app.schemas import UserCreate, UserResponse, UserUpdate, Token
from app.auth import hash_password, verify_password, create_access_token, get_current_user

router = APIRouter(prefix="/auth", tags=["Autenticación"])

@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(user_in: UserCreate, db: Session = Depends(get_db)):
    """Registra un nuevo usuario y emite un JWT access token."""
    existing_user = db.query(User).filter(User.email == user_in.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El correo electrónico ya está registrado."
        )
    
    db_user = User(
        email=user_in.email,
        full_name=user_in.full_name,
        hashed_password=hash_password(user_in.password),
        avatar_url=user_in.avatar_url,
        is_active=True
    )
    db.add(db_user)
    db.flush()

    # Inicializar preferencias y reproductor por defecto
    user_settings = UserSettings(user_id=db_user.id)
    user_player = UserPlayerState(user_id=db_user.id)
    db.add(user_settings)
    db.add(user_player)
    db.commit()
    db.refresh(db_user)

    access_token = create_access_token(data={"sub": str(db_user.id), "email": db_user.email})
    return Token(access_token=access_token, token_type="bearer", user_id=db_user.id, email=db_user.email)

@router.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Autenticación mediante OAuth2 Form (username=email, password)."""
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo electrónico o contraseña incorrectos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Usuario inactivo"
        )
    
    # Actualizar fecha de último login
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()

    access_token = create_access_token(data={"sub": str(user.id), "email": user.email})
    return Token(access_token=access_token, token_type="bearer", user_id=user.id, email=user.email)

@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    """Obtiene los datos del usuario autenticado."""
    return current_user

@router.put("/me", response_model=UserResponse)
def update_me(user_in: UserUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Actualiza datos del perfil del usuario (nombre, avatar)."""
    if user_in.full_name is not None:
        current_user.full_name = user_in.full_name
    if user_in.avatar_url is not None:
        current_user.avatar_url = user_in.avatar_url
    
    db.commit()
    db.refresh(current_user)
    return current_user

import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(case_sensitive=True)

    PROJECT_NAME: str = "DiegoMusic API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Base de datos SQLite
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./diegomusic.db")
    
    # JWT & Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "diegomusic-super-secret-jwt-key-2026-change-in-production")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 días

settings = Settings()

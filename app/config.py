from pydantic import Field, ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict


class ConfigurationError(RuntimeError):
    """Configuración inválida sin incluir valores sensibles en el mensaje."""


class Settings(BaseSettings):
    model_config = SettingsConfigDict(case_sensitive=True)

    API_V1_STR: str = "/api/v1"

    # Base de datos SQLite
    DATABASE_URL: str = "sqlite:///./diegomusic.db"

    # JWT & Security: sin valor por defecto; el servicio no arranca sin SECRET_KEY.
    SECRET_KEY: str = Field(min_length=32)
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 días


def load_settings() -> Settings:
    """Carga la configuración; ante un error nombra las variables sin mostrar valores."""
    try:
        return Settings()
    except ValidationError as error:
        # error.errors() incluye los valores recibidos: solo se conservan los nombres.
        names = sorted({str(issue["loc"][0]) for issue in error.errors() if issue["loc"]})
        message = f"Configuración del backend inválida: {', '.join(names)}."
        if "SECRET_KEY" in names:
            message += " SECRET_KEY es obligatoria y debe tener al menos 32 caracteres."
        raise ConfigurationError(message) from None


settings = load_settings()

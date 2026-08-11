import json
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User, UserActivityLog
from app.schemas import TelemetryEventCreate, TelemetryEventResponse
from app.auth import get_current_user

router = APIRouter(prefix="/telemetry", tags=["Telemetría y Registro de Uso"])

@router.post("/events", response_model=TelemetryEventResponse, status_code=status.HTTP_201_CREATED)
def record_event(
    event_in: TelemetryEventCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Registra un evento de actividad/uso del usuario para analítica y personalización."""
    data_json = json.dumps(event_in.event_data) if event_in.event_data is not None else None
    
    activity_log = UserActivityLog(
        user_id=current_user.id,
        event_type=event_in.event_type,
        event_data_json=data_json
    )
    db.add(activity_log)
    db.commit()
    db.refresh(activity_log)
    return activity_log

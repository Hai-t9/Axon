from fastapi import Depends, FastAPI
from sqlalchemy import text
from sqlalchemy.orm import Session

import app.models
from app.core.database import Base, engine
from app.dependencies import get_db
from app.services.cleaner.controller import router as cleaner_router
from app.services.competition.controller import router as competition_router
from app.services.dashboard.controller import router as dashboard_router
from app.services.image.controller import router as image_router
from app.services.label.controller import router as label_router
from app.services.leaderboard.controller import router as leaderboard_router
from app.services.model_submission.controller import router as model_submission_router
from app.services.phase.controller import router as phase_router
from app.services.register.controller import router as register_router
from app.services.team.controller import router as team_router
from app.services.validation.controller import router as validation_router

app = FastAPI()


@app.get("/health")
def health_check(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {"status": "ok", "database": "connected"}


@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)


API_PREFIX = "/api/v1"

app.include_router(register_router, prefix=API_PREFIX)
app.include_router(competition_router, prefix=API_PREFIX)
app.include_router(dashboard_router, prefix=API_PREFIX)
app.include_router(label_router, prefix=API_PREFIX)
app.include_router(leaderboard_router, prefix=API_PREFIX)
app.include_router(team_router, prefix=API_PREFIX)
app.include_router(phase_router, prefix=API_PREFIX)
app.include_router(validation_router, prefix=API_PREFIX)
app.include_router(model_submission_router, prefix=API_PREFIX)

app.include_router(image_router, prefix=API_PREFIX)
app.include_router(cleaner_router, prefix=API_PREFIX)

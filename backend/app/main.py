"""
FILE: backend/app/main.py   (REPLACE existing file)
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.database import Base, engine
import app.models  # noqa: F401 — registers all ORM models with Base

# Existing service routers
from app.services.competition.controller import router as competition_router
from app.services.dashboard.controller import router as dashboard_router
from app.services.label.controller import router as label_router
from app.services.leaderboard.controller import router as leaderboard_router
from app.services.phase.controller import router as phase_router
from app.services.register.controller import router as register_router
from app.services.team.controller import router as team_router
from app.services.validation.controller import router as validation_router
from app.services.image.controller import router as image_router
from app.services.cleaner.controller import router as cleaner_router

# New service routers
from app.services.model_submission.controller import router as model_submission_router
from app.services.evaluation.controller import router as evaluation_router
from app.services.invitation.controller import router as invitation_router

app = FastAPI(
    title="Axon API",
    description="Data-centric AI competition platform for AgrI Challenge 2026",
    version="1.0.0",
)

# ---------------------------------------------------------------------------
# CORS — allow the web portal and mobile app to call the API.
# Tighten allowed_origins in production.
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Startup: create all tables (SQLite dev / migrations handle production).
# ---------------------------------------------------------------------------
@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------
@app.get("/health", tags=["meta"])
def health():
    return {"status": "ok"}


# ---------------------------------------------------------------------------
# Register all routers under /api/v1
# ---------------------------------------------------------------------------
API_PREFIX = "/api/v1"

# Auth & Registration
app.include_router(register_router, prefix=API_PREFIX)

# Competition management
app.include_router(competition_router, prefix=API_PREFIX)
app.include_router(phase_router, prefix=API_PREFIX)
app.include_router(team_router, prefix=API_PREFIX)

# Invitation / join flow
app.include_router(invitation_router, prefix=API_PREFIX)

# Data collection (Mobile App)
app.include_router(image_router, prefix=API_PREFIX)
app.include_router(label_router, prefix=API_PREFIX)
app.include_router(validation_router, prefix=API_PREFIX)
app.include_router(cleaner_router, prefix=API_PREFIX)

# Model evaluation pipeline (Web Portal)
app.include_router(model_submission_router, prefix=API_PREFIX)
app.include_router(evaluation_router, prefix=API_PREFIX)

# Read-only aggregation
app.include_router(dashboard_router, prefix=API_PREFIX)
app.include_router(leaderboard_router, prefix=API_PREFIX)
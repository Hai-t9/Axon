import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.core.gateway import (
    RateLimitMiddleware,
    RequestIDMiddleware,
    RequestLoggingMiddleware,
    SecurityHeadersMiddleware,
)
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
from app.services.evaluation_orchestration.controller import router as evaluation_router
from app.services.model_submission.controller import router as model_submission_router
from app.core.database import engine, Base
import app.models

_start_time = time.time()


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(lifespan=lifespan)

# ------------------------------------------------------------------ #
#  Middleware Stack (outermost runs first on request)                  #
#  Order: RequestID → RequestLogging → RateLimit → SecurityHeaders → CORS
# ------------------------------------------------------------------ #

app.add_middleware(CORSMiddleware,                                           # 5th: innermost middlewares
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(SecurityHeadersMiddleware)                                # 4th
app.add_middleware(RateLimitMiddleware)                                      # 3rd
app.add_middleware(RequestLoggingMiddleware)                                 # 2nd
app.add_middleware(RequestIDMiddleware)                                      # 1st: outermost (runs first)

# ------------------------------------------------------------------ #


@app.get("/health")
def health():
    db_ok = False
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
            db_ok = True
    except Exception:
        db_ok = False

    status = "ok" if db_ok else "degraded"
    return {
        "status": status,
        "version": "1.0.0",
        "uptime_seconds": int(time.time() - _start_time),
        "database": "connected" if db_ok else "error",
    }


API_PREFIX = "/api/v1"

app.include_router(register_router, prefix=API_PREFIX)
app.include_router(competition_router, prefix=API_PREFIX)
app.include_router(dashboard_router, prefix=API_PREFIX)
app.include_router(label_router, prefix=API_PREFIX)
app.include_router(leaderboard_router, prefix=API_PREFIX)
app.include_router(team_router, prefix=API_PREFIX)
app.include_router(phase_router, prefix=API_PREFIX)
app.include_router(validation_router, prefix=API_PREFIX)

app.include_router(image_router, prefix=API_PREFIX)
app.include_router(cleaner_router, prefix=API_PREFIX)
app.include_router(evaluation_router, prefix=API_PREFIX)
app.include_router(model_submission_router, prefix=API_PREFIX)

import os
from fastapi.staticfiles import StaticFiles

# Create uploads directory if it doesn't exist
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

import logging
import os
import time
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, Response

load_dotenv()  # must run before any os.getenv(...); database.py also calls it but too late

# Replace uvicorn's root handlers with our own so that child loggers
# (model_submission.service, workers.executor, etc.) inherit
# the correct level and output format regardless of uvicorn's dictConfig.
_log_level_name = os.getenv("LOG_LEVEL", "INFO").upper()
_log_level = getattr(logging, _log_level_name, logging.INFO)
_root = logging.getLogger()
_root.setLevel(_log_level)
for h in _root.handlers[:]:
    _root.removeHandler(h)
_h = logging.StreamHandler()
_h.setLevel(_log_level)
_h.setFormatter(logging.Formatter("%(asctime)s [%(name)s] %(levelname)s %(message)s"))
_root.addHandler(_h)

# Suppress verbose third-party loggers when app debug is on
if _log_level <= logging.DEBUG:
    for noisy in ("botocore", "urllib3", "s3transfer", "boto3", "httpx"):
        logging.getLogger(noisy).setLevel(logging.WARNING)
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
from app.services.export.controller import router as export_router
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
#  Order: CORS → RequestID → RequestLogging → RateLimit → SecurityHeaders
# ------------------------------------------------------------------ #
# CORS must be outermost so preflight OPTIONS requests get CORS headers
# before any middleware (e.g. RateLimit) can short-circuit them.

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestIDMiddleware)
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(RateLimitMiddleware)
app.add_middleware(SecurityHeadersMiddleware)

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
app.include_router(export_router, prefix=API_PREFIX)
from fastapi.responses import Response

from app.storage.minio_client import storage_service
import os


MIME_MAP = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".gif": "image/gif",
    ".zip": "application/zip",
    ".h5": "application/x-hdf5",
}


@app.get("/uploads/{path:path}")
async def serve_upload(path: str):
    """Serve uploaded files from storage (local or S3 fallback)."""
    content = storage_service.get_file(path)
    if not content:
        return Response(status_code=404)
    ext = os.path.splitext(path)[1].lower()
    media_type = MIME_MAP.get(ext, "application/octet-stream")
    return Response(content=content, media_type=media_type)

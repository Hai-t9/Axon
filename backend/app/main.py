from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware

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
from app.core.database import engine, Base
import app.models

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_cors_headers(request: Request, call_next):
    if request.method == "OPTIONS":
        response = Response(status_code=200)
    else:
        response = await call_next(request)

    response.headers.setdefault("Access-Control-Allow-Origin", "*")
    response.headers.setdefault("Access-Control-Allow-Methods", "*")
    response.headers.setdefault("Access-Control-Allow-Headers", "*")
    return response

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

app.include_router(image_router, prefix=API_PREFIX)
app.include_router(cleaner_router, prefix=API_PREFIX)

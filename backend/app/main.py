from fastapi import FastAPI

from app.services.competition.controller import router as competition_router
from app.services.phase.controller import router as phase_router
from app.services.register.controller import router as register_router
from app.services.team.controller import router as team_router

app = FastAPI()

API_PREFIX = "/api/v1"

app.include_router(register_router, prefix=API_PREFIX)
app.include_router(competition_router, prefix=API_PREFIX)
app.include_router(team_router, prefix=API_PREFIX)
app.include_router(phase_router, prefix=API_PREFIX)


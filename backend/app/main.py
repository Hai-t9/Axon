from fastapi import FastAPI
from app.services.cleaner.controller import router as cleaner_router
from app.services.image.controller import router as image_router
from app.core.database import Base, engine
from app.models.image import Image, ImageMetadata

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Axon Internal Cleaner API")

# Register the router you built in day 1
app.include_router(cleaner_router)
app.include_router(image_router)

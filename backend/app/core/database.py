"""
Database Configuration Module

ARCHITECTURE:
- Mobile App (Flutter): Uses local SQLite database for offline-first functionality
- Backend (FastAPI): Uses remote PostgreSQL on Supabase for data persistence
- Sync Strategy: Mobile app syncs with Supabase backend when connection is available

DATABASES:
1. Remote (Production): PostgreSQL on Supabase (DATABASE_URL in .env)
2. Local (Development/Offline): SQLite (fallback if DATABASE_URL not set)
"""
import os
from dotenv import load_dotenv

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

# Load environment variables from .env file
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./axon.db")

engine_options = {"pool_pre_ping": True}
if DATABASE_URL.startswith("sqlite"):
    engine_options["connect_args"] = {"check_same_thread": False}

engine = create_engine(DATABASE_URL, **engine_options)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


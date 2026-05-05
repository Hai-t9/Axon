# Backend Application Structure

## Overview
The `app/` folder is the heart of the FastAPI backend. It contains all the business logic, database models, API schemas, and domain services for the Axon competition platform.

## Architecture

This folder is organized using a **hybrid MVC + Service-Oriented Architecture**:

```
app/
├── main.py              # FastAPI entry point
├── config.py            # Environment & configuration
├── dependencies.py      # Dependency injection
├── core/               # Shared infrastructure
├── models/             # Database ORM models (centralized)
├── schemas/            # API request/response validation (centralized)
├── storage/            # External storage abstraction (MinIO)
├── workers/            # Background tasks (Celery)
└── services/           # Domain services (11 microservice-like modules)
```

## Layer Breakdown

### **1. Core Infrastructure** (`core/`)
Shared utilities used across all services:
- `auth.py` - JWT token management
- `security.py` - Password hashing & verification
- `middleware.py` - CORS, rate limiting, logging
- `exceptions.py` - Global error definitions
- `database.py` - SQLAlchemy setup

### **2. Models** (`models/`)
SQLAlchemy ORM models (database schema layer):
- One file per entity (user.py, team.py, competition.py, etc.)
- **Single source of truth** for all database structures
- NO business logic here - only columns, relationships, indexes

### **3. Schemas** (`schemas/`)
Pydantic validation models (API contract layer):
- Request schemas for POST/PATCH endpoints
- Response schemas for GET endpoints
- Separate from models to hide sensitive data
- One file per domain (user.py, team.py, etc.)

### **4. Storage** (`storage/`)
Abstraction layer for MinIO (S3-compatible storage):
- `minio_client.py` - Connection & configuration
- `image_store.py` - Image upload/download operations
- `model_store.py` - ML model file operations
- Allows easy switching between storage providers later

### **5. Workers** (`workers/`)
Background task queue using Celery + Redis:
- `celery_app.py` - Celery configuration
- `evaluation_worker.py` - ML model evaluation tasks
- `executor.py` - Task execution logic
- `validator_worker.py` - Data validation tasks

### **6. Services** (`services/`)
**11 domain services**, each handling one major feature. See `services/README.md` for details.

## Data Flow

```
HTTP Request
    ↓
Controller (FastAPI route handler)
    ↓
Schema (validate request)
    ↓
Service (business logic)
    ↓
Repository (database queries)
    ↓
Model (ORM returns data)
    ↓
Service (process results)
    ↓
Schema (format response)
    ↓
Controller (return HTTP response)
```

## Key Files

- **main.py** - Initialize FastAPI app, register routers, setup middleware
- **config.py** - Load environment variables, define settings
- **dependencies.py** - Setup dependency injection (database sessions, services)

## Important Rules

1. **Models** - Database schema only, no business logic
2. **Schemas** - Validate & shape API data, separate from models
3. **Repositories** - Only database CRUD operations
4. **Services** - Business logic, validation, orchestration
5. **Controllers** - HTTP route handlers, delegate to services

## Example Service Structure

Each service in `services/` follows this pattern:
```
services/auth/
├── repository.py   # Database queries for auth
├── service.py      # Authentication business logic
└── controller.py   # /login, /register routes
```

Services use models from `models/` and schemas from `schemas/` - centralized!

## Getting Started

1. Define ORM models in `models/` (e.g., `models/user.py`)
2. Define Pydantic schemas in `schemas/` (e.g., `schemas/user.py`)
3. Create repositories in `services/auth/repository.py` (query operations)
4. Implement business logic in `services/auth/service.py`
5. Create FastAPI routes in `services/auth/controller.py`
6. Register routes in `main.py`

## Dependencies

- FastAPI - Web framework
- SQLAlchemy - ORM for database
- Pydantic - Data validation
- python-jose - JWT tokens
- bcrypt - Password hashing
- Celery + Redis - Background tasks
- Minio SDK - S3-compatible storage

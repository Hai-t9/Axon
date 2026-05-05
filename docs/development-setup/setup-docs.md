---
sidebar_position: 1
---

# Development & Setup

## How to run locally

(To be filled)

## Installation steps

(To be filled)

## Environment variables

(To be filled)

## Project structure

### Directory Tree

```
Axon/
│
├── backend/                          # FastAPI Backend (Python)
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                   # FastAPI application entry point
│   │   ├── config.py                 # Configuration & environment variables
│   │   ├── dependencies.py           # Dependency injection setup
│   │   │
│   │   ├── core/                     # Core infrastructure
│   │   │   ├── __init__.py
│   │   │   ├── auth.py               # JWT token creation/verification
│   │   │   ├── security.py           # Password hashing (bcrypt)
│   │   │   ├── middleware.py         # CORS, rate limiting, logging
│   │   │   ├── exceptions.py         # Global exception definitions
│   │   │   └── database.py           # SQLAlchemy engine, SessionLocal
│   │   │
│   │   ├── models/                   # 🆕 Centralized ORM Models
│   │   │   ├── __init__.py           # Exports all models
│   │   │   ├── user.py               # User & Role models
│   │   │   ├── team.py               # Team & TeamMember models
│   │   │   ├── competition.py        # Competition model
│   │   │   ├── phase.py              # Phase model
│   │   │   ├── dataset.py            # Dataset model (data ingestion)
│   │   │   ├── label.py              # Label model
│   │   │   ├── submission.py         # Submission model
│   │   │   ├── evaluation.py         # Evaluation & Result models
│   │   │   └── leaderboard.py        # LeaderboardEntry model
│   │   │
│   │   ├── schemas/                  # 🆕 Centralized Pydantic Schemas
│   │   │   ├── __init__.py           # Exports all schemas
│   │   │   ├── user.py               # User request/response schemas
│   │   │   ├── team.py               # Team schemas
│   │   │   ├── competition.py        # Competition schemas
│   │   │   ├── phase.py              # Phase schemas
│   │   │   ├── dataset.py            # Dataset schemas
│   │   │   ├── label.py              # Label schemas
│   │   │   ├── submission.py         # Submission schemas
│   │   │   ├── evaluation.py         # Evaluation schemas
│   │   │   └── leaderboard.py        # Leaderboard schemas
│   │   │
│   │   ├── storage/                  # Storage abstraction layer
│   │   │   ├── __init__.py
│   │   │   ├── minio_client.py       # MinIO S3-compatible storage
│   │   │   ├── image_store.py        # Image storage operations
│   │   │   └── model_store.py        # Model file storage operations
│   │   │
│   │   ├── workers/                  # Background task queue (Celery)
│   │   │   ├── __init__.py
│   │   │   ├── celery_app.py         # Celery configuration
│   │   │   ├── evaluation_worker.py  # Model evaluation tasks
│   │   │   ├── executor.py           # Task execution logic
│   │   │   └── validator_worker.py   # Data validation tasks
│   │   │
│   │   └── services/                 # Domain services (slim MVC pattern)
│   │       ├── __init__.py
│   │       │
│   │       ├── auth/                 # Authentication Service
│   │       │   ├── __init__.py
│   │       │   ├── repository.py     # imports from models.user
│   │       │   ├── service.py        # Business logic
│   │       │   └── controller.py     # FastAPI route handlers
│   │       │
│   │       ├── competition/          # Competition Management Service
│   │       │   ├── __init__.py
│   │       │   ├── repository.py
│   │       │   ├── service.py
│   │       │   └── controller.py
│   │       │
│   │       ├── phase/                # Phase Management Service
│   │       │   ├── __init__.py
│   │       │   ├── repository.py
│   │       │   ├── service.py
│   │       │   └── controller.py
│   │       │
│   │       ├── team/                 # Team Management Service
│   │       │   ├── __init__.py
│   │       │   ├── repository.py
│   │       │   ├── service.py
│   │       │   └── controller.py
│   │       │
│   │       ├── data_ingestion/       # Data Upload Service
│   │       │   ├── __init__.py
│   │       │   ├── repository.py
│   │       │   ├── service.py
│   │       │   └── controller.py
│   │       │
│   │       ├── label/                # Label Management Service
│   │       │   ├── __init__.py
│   │       │   ├── repository.py
│   │       │   ├── service.py
│   │       │   └── controller.py
│   │       │
│   │       ├── cleaner/              # Data Cleaning Service
│   │       │   ├── __init__.py
│   │       │   ├── repository.py
│   │       │   ├── service.py
│   │       │   └── controller.py
│   │       │
│   │       ├── validation/           # Data Validation Service
│   │       │   ├── __init__.py
│   │       │   ├── repository.py
│   │       │   ├── service.py
│   │       │   └── controller.py
│   │       │
│   │       ├── model_submission/     # Model Submission Service
│   │       │   ├── __init__.py
│   │       │   ├── repository.py
│   │       │   ├── service.py
│   │       │   └── controller.py
│   │       │
│   │       ├── evaluation/           # Evaluation Orchestration Service
│   │       │   ├── __init__.py
│   │       │   ├── repository.py
│   │       │   ├── service.py
│   │       │   └── controller.py
│   │       │
│   │       └── leaderboard/          # Leaderboard Service
│   │           ├── __init__.py
│   │           ├── repository.py
│   │           ├── service.py
│   │           └── controller.py
│   │
│   ├── tests/                        # Test suite
│   │   ├── __init__.py
│   │   ├── conftest.py               # Pytest fixtures
│   │   └── services/                 # Tests mirror service structure
│   │       ├── __init__.py
│   │       ├── auth/
│   │       ├── competition/
│   │       ├── phase/
│   │       ├── team/
│   │       ├── data_ingestion/
│   │       ├── label/
│   │       ├── cleaner/
│   │       ├── validation/
│   │       ├── model_submission/
│   │       ├── evaluation/
│   │       └── leaderboard/
│   │
│   ├── alembic/                      # Database migrations
│   │   ├── __init__.py
│   │   ├── env.py
│   │   ├── script.py.mako
│   │   └── versions/                 # Migration files
│   │       ├── __init__.py
│   │       └── (migration files here)
│   │
│   ├── requirements.txt              # Python dependencies
│   ├── Dockerfile
│   └── .env.example
│
├── frontend/                         # Flutter/Dart Frontend
│   ├── lib/
│   │   ├── main.dart                 # App entry point
│   │   │
│   │   ├── app/                      # App configuration
│   │   │   ├── .gitkeep
│   │   │   ├── router.dart           # go_router navigation
│   │   │   └── theme.dart            # Material Design theme
│   │   │
│   │   ├── core/                     # Core infrastructure
│   │   │   ├── api/
│   │   │   │   ├── .gitkeep
│   │   │   │   ├── api_client.dart   # Dio HTTP client with JWT interceptor
│   │   │   │   └── endpoints.dart    # API base URLs & constants
│   │   │   │
│   │   │   ├── auth/
│   │   │   │   ├── .gitkeep
│   │   │   │   ├── auth_provider.dart  # Riverpod auth state
│   │   │   │   └── token_storage.dart  # Secure local storage
│   │   │   │
│   │   │   └── utils/
│   │   │       ├── .gitkeep
│   │   │       ├── validators.dart
│   │   │       └── helpers.dart
│   │   │
│   │   ├── features/                 # Feature modules (Clean Architecture)
│   │   │   ├── competitions/
│   │   │   │   ├── data/
│   │   │   │   │   ├── .gitkeep
│   │   │   │   │   ├── datasource.dart
│   │   │   │   │   └── repository.dart
│   │   │   │   ├── domain/
│   │   │   │   │   ├── .gitkeep
│   │   │   │   │   ├── entity.dart
│   │   │   │   │   └── usecase.dart
│   │   │   │   └── presentation/
│   │   │   │       ├── .gitkeep
│   │   │   │       ├── provider.dart
│   │   │   │       └── screens/
│   │   │   │
│   │   │   ├── teams/
│   │   │   ├── datasets/
│   │   │   ├── labeling/
│   │   │   ├── model_submission/
│   │   │   ├── evaluation/
│   │   │   └── leaderboard/
│   │   │       (same structure as competitions)
│   │   │
│   │   └── shared/                   # Reusable components
│   │       ├── .gitkeep
│   │       ├── widgets/
│   │       ├── constants/
│   │       └── utilities/
│   │
│   ├── ios/                          # iOS build files
│   ├── android/                      # Android build files
│   ├── web/                          # Web build files
│   ├── test/                         # Widget & integration tests
│   ├── pubspec.yaml                  # Flutter dependencies
│   └── Dockerfile
│
├── infra/                            # Infrastructure & Deployment
│   ├── nginx/
│   │   ├── .gitkeep
│   │   └── nginx.conf                # Reverse proxy config
│   │
│   ├── minio/
│   │   ├── .gitkeep
│   │   └── init-buckets.sh           # MinIO bucket initialization
│   │
│   └── redis/
│       ├── .gitkeep
│       └── redis.conf                # Redis caching & broker config
│
├── docker-compose.yml                # Orchestrate all services
├── .gitignore
├── README.md
└── docs/                             # Documentation
    └── system-architecture/
        └── architecture-overview.md  # Tech stack details
```

---

### Updated MVC Pattern (Simplified)

With centralized `models/` and `schemas/`, the pattern is now **4-layer instead of 5**:

#### **Layer 1: Model (`models/` folder)**
- **Location:** `backend/app/models/user.py`
- **Purpose:** SQLAlchemy ORM definitions
- **Single source of truth** for database schema
```python
from sqlalchemy import Column, Integer, String
from core.database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    email = Column(String, unique=True)
    password_hash = Column(String)
```

---

#### **Layer 2: Schema (`schemas/` folder)**
- **Location:** `backend/app/schemas/user.py`
- **Purpose:** Pydantic validation models
- **Separate request/response** concerns from ORM
```python
from pydantic import BaseModel

class UserCreate(BaseModel):
    email: str
    password: str

class UserResponse(BaseModel):
    id: int
    email: str
```

---

#### **Layer 3: Repository (`services/{service}/repository.py`)**
- **Location:** `backend/app/services/auth/repository.py`
- **Purpose:** Database queries (CRUD)
- **Imports:** `from models.user import User`
```python
from models.user import User

class UserRepository:
    def get_by_id(self, user_id: int) -> User:
        return self.db.query(User).filter(User.id == user_id).first()
```

---

#### **Layer 4: Service + Controller**
- **Service Location:** `backend/app/services/auth/service.py`
- **Purpose:** Business logic
- **Controller Location:** `backend/app/services/auth/controller.py`
- **Purpose:** FastAPI routes

---

### Data Flow Example: User Login

```
POST /auth/login  (HTTP Request)
        ↓
  Controller receives request
        ↓
  Schema validates input
  (schemas/user.py → LoginSchema)
        ↓
  Service executes logic
  (services/auth/service.py → authenticate_user())
        ↓
  Repository queries database
  (services/auth/repository.py → queries models.user.User)
        ↓
  Model returns from database
  (models/user.py → User ORM object)
        ↓
  Service generates token
        ↓
  Schema formats response
  (schemas/user.py → UserResponse)
        ↓
  Controller returns 200 OK + token
```

---

### Why Centralized Models/Schemas?

| Aspect | Benefit |
|--------|---------|
| **Single Source of Truth** | All User data is in one place, no duplication |
| **No Circular Imports** | Models don't import from services |
| **Easy Relationships** | See how User relates to Team immediately |
| **Team Collaboration** | Designers/backend team can review all entities together |
| **Scalability** | Add new models without refactoring service structure |
| **Database Normalization** | Aligns with PostgreSQL design principles |

---

### Technology Stack Summary

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Backend | FastAPI (Python) | REST API for all 11 services |
| Frontend | Flutter/Dart | Cross-platform web + mobile |
| Database | PostgreSQL | Relational data storage |
| Auth | JWT + bcrypt | Authentication & authorization |
| Storage | MinIO | S3-compatible image/model storage |
| Cache | Redis | Session caching & Celery broker |
| Task Queue | Celery + Redis | Async evaluation jobs |
| ORM | SQLAlchemy | Python-to-database mapping |
| Validation | Pydantic | Request/response schemas |
| State Management | Riverpod | Flutter reactive state |
| HTTP Client | Dio | Flutter API calls |
| Routing | go_router | Flutter navigation |
| Deployment | Docker Compose | Development & production |

# Domain Services

## Overview
The `services/` folder contains **11 independent domain services**, each responsible for one major feature of the Axon platform. Each service follows the **Repository-Service-Controller pattern**.

## Architecture

```
services/
├── auth/                # Authentication & User Management
├── competition/         # Competition Lifecycle Management
├── phase/               # Phase Management & Scheduling
├── team/                # Team Management & Membership
├── data_ingestion/      # Image Upload & Dataset Management
├── label/               # Label Management
├── cleaner/             # Data Cleaning & Deduplication
├── validation/          # Data Quality Validation
├── model_submission/    # Model Upload & Versioning
├── evaluation/          # Evaluation Orchestration
└── leaderboard/         # Rankings & Leaderboard
```

## Service Pattern

Each service follows the same **3-layer structure**:

```
services/auth/
├── __init__.py
├── repository.py       # Database queries (CRUD)
├── service.py          # Business logic
└── controller.py       # FastAPI routes
```

### **Layer 1: Repository** (`repository.py`)
**Purpose:** Database access layer (CRUD operations)

**Responsibilities:**
- Query/filter data from database
- Insert/update/delete records
- Build complex queries
- No business logic!

**Example:**
```python
# services/auth/repository.py
from models import User

class UserRepository:
    def __init__(self, db):
        self.db = db
    
    def get_by_email(self, email: str) -> User:
        return self.db.query(User).filter(User.email == email).first()
    
    def create(self, user_data: dict) -> User:
        user = User(**user_data)
        self.db.add(user)
        self.db.commit()
        return user
```

### **Layer 2: Service** (`service.py`)
**Purpose:** Business logic layer

**Responsibilities:**
- Implement business rules
- Validate data
- Orchestrate between repositories
- Call external services
- Handle errors

**Example:**
```python
# services/auth/service.py
from core.security import hash_password, verify_password
from core.auth import create_access_token
from schemas.user import UserCreate

class AuthService:
    def __init__(self, repository):
        self.repository = repository
    
    def create_user(self, user_data: UserCreate) -> User:
        # Check if user already exists
        if self.repository.get_by_email(user_data.email):
            raise ValueError("Email already registered")
        
        # Hash password
        hashed = hash_password(user_data.password)
        
        # Save to database
        user = self.repository.create({
            "email": user_data.email,
            "password_hash": hashed
        })
        return user
    
    def authenticate(self, email: str, password: str) -> str:
        user = self.repository.get_by_email(email)
        if not user or not verify_password(password, user.password_hash):
            raise ValueError("Invalid credentials")
        
        # Generate JWT token
        token = create_access_token(user.id)
        return token
```

### **Layer 3: Controller** (`controller.py`)
**Purpose:** HTTP request handling (FastAPI routes)

**Responsibilities:**
- Define API endpoints
- Validate request schemas
- Call service methods
- Return response schemas
- Handle HTTP errors

**Example:**
```python
# services/auth/controller.py
from fastapi import APIRouter, HTTPException
from schemas.user import UserCreate, UserResponse, LoginRequest, LoginResponse

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=UserResponse)
async def register(user_data: UserCreate, service: AuthService = Depends()):
    try:
        user = service.create_user(user_data)
        return user
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/login", response_model=LoginResponse)
async def login(credentials: LoginRequest, service: AuthService = Depends()):
    try:
        token = service.authenticate(credentials.email, credentials.password)
        return LoginResponse(access_token=token)
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid credentials")
```

## How Services Interact

### **Within a Service** (auth service)
```
Controller receives request
    ↓
Schema validates request
    ↓
Service processes business logic
    ↓
Repository queries database
    ↓
Service returns result
    ↓
Schema formats response
    ↓
Controller returns to client
```

### **Between Services** (team service using auth)
```
Team Service needs to verify user permission
    ↓
Calls AuthService.verify_token(token)
    ↓
AuthService.repository.get_by_id(user_id)
    ↓
Returns user object
    ↓
Team Service continues logic
```

Services communicate through dependency injection in `main.py`.

## The 11 Services

### **1. Auth Service**
**Manages:** User registration, login, JWT tokens, roles

**Key Operations:**
- `register(email, password)` - Create new user
- `authenticate(email, password)` - Generate JWT token
- `verify_token(token)` - Validate JWT
- `get_user(user_id)` - Retrieve user profile

**Database:** Users table

---

### **2. Competition Service**
**Manages:** Competition creation, lifecycle, phases

**Key Operations:**
- `create_competition(name, description)`
- `get_competition(id)`
- `list_competitions()`
- `update_status(id, status)`

**Database:** Competitions table

---

### **3. Phase Service**
**Manages:** Phase schedules, transitions, deadlines

**Key Operations:**
- `create_phase(competition_id, name, start, end)`
- `get_phase(id)`
- `transition_phase(id, new_status)`

**Database:** Phases table

---

### **4. Team Service**
**Manages:** Team creation, membership, permissions

**Key Operations:**
- `create_team(name, user_id)`
- `add_member(team_id, user_id)`
- `remove_member(team_id, user_id)`
- `get_team_members(team_id)`

**Database:** Teams, TeamMembers tables

---

### **5. Data Ingestion Service**
**Manages:** Image uploads, dataset creation

**Key Operations:**
- `upload_images(dataset_id, files[])`
- `create_dataset(competition_id, name)`
- `get_dataset_images(dataset_id)`

**Database:** Datasets, Images tables
**Storage:** MinIO (image files)

---

### **6. Label Service**
**Manages:** Label definitions, assignments

**Key Operations:**
- `create_label(name, description)`
- `assign_label(image_id, label_id)`
- `get_image_labels(image_id)`

**Database:** Labels, ImageLabels tables

---

### **7. Cleaner Service**
**Manages:** Data deduplication, cleaning

**Key Operations:**
- `find_duplicates(dataset_id)`
- `remove_duplicates(dataset_id, duplicate_ids[])`
- `clean_data(dataset_id)`

**Database:** Datasets table (mark as cleaned)

---

### **8. Validation Service**
**Manages:** Data quality checks, validation workflows

**Key Operations:**
- `validate_dataset(dataset_id)`
- `get_validation_report(dataset_id)`
- `approve_dataset(dataset_id)`

**Database:** ValidationReports table

---

### **9. Model Submission Service**
**Manages:** Model file uploads, versioning

**Key Operations:**
- `submit_model(submission_id, model_file)`
- `get_model_version(id)`
- `list_submissions(competition_id)`

**Database:** Submissions table
**Storage:** MinIO (model files)

---

### **10. Evaluation Service**
**Manages:** Model evaluation orchestration, results

**Key Operations:**
- `queue_evaluation(submission_id)`
- `get_evaluation_status(task_id)`
- `get_results(submission_id)`

**Database:** Evaluations, Results tables
**Workers:** Calls Celery evaluation_worker

---

### **11. Leaderboard Service**
**Manages:** Rankings, score calculations, caching

**Key Operations:**
- `calculate_rankings(competition_id)`
- `get_leaderboard(competition_id)`
- `cache_rankings(competition_id)`

**Database:** LeaderboardEntry table
**Cache:** Redis (frequent reads)

---

## Registering Services in main.py

```python
# app/main.py
from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from core.database import SessionLocal

# Import all controllers
from services.auth.controller import router as auth_router
from services.team.controller import router as team_router
from services.competition.controller import router as competition_router
# ... etc

app = FastAPI()

# Register routers
app.include_router(auth_router)
app.include_router(team_router)
app.include_router(competition_router)
# ... etc

# Dependency injection
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

## Service Dependencies

Services are injected with:
- **Database session** - For repository access
- **Other services** - For inter-service calls
- **Storage** - For file operations (image_store, model_store)
- **Workers** - For async tasks (Celery)

```python
# services/evaluation/controller.py
@router.post("/evaluate/{submission_id}")
async def start_evaluation(
    submission_id: int,
    evaluation_service: EvaluationService = Depends(),
    db: Session = Depends(get_db),
):
    return evaluation_service.queue_evaluation(submission_id)
```

## Cross-Service Communication

When one service needs data from another:

```python
# Team service needs to verify if user is admin
class TeamService:
    def __init__(self, auth_service: AuthService):
        self.auth_service = auth_service
    
    def create_team(self, name: str, user_id: int):
        # Verify user exists
        user = self.auth_service.get_user(user_id)
        if not user:
            raise ValueError("User not found")
        
        # Create team...
```

## Testing Services

Each service has corresponding tests:

```
tests/services/
├── auth/
│   ├── test_repository.py
│   ├── test_service.py
│   └── test_controller.py
├── team/
│   ├── test_repository.py
│   ├── test_service.py
│   └── test_controller.py
└── ...
```

## Adding a New Service

1. Create folder: `services/my_service/`
2. Create `repository.py` with CRUD operations
3. Create `service.py` with business logic
4. Create `controller.py` with FastAPI routes
5. Import and register router in `main.py`
6. Add tests in `tests/services/my_service/`

## Best Practices

- ✅ Keep services independent
- ✅ Use dependency injection
- ✅ Repositories only do CRUD
- ✅ Services contain business logic
- ✅ Controllers handle HTTP only
- ✅ Use schemas for validation
- ✅ Handle errors gracefully
- ✅ Write tests for each layer

## Service Scalability

As the platform grows:
- ✅ Services can move to separate microservices
- ✅ Each service could have its own database
- ✅ Services can communicate via message queue
- ✅ Services can be deployed independently

Current architecture supports easy migration!

Services = Domain-Driven Features 🎯

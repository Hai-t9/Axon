# Domain Services

## Overview
The `services/` folder contains **12 independent domain services**, each responsible for one major feature of the Axon platform. Each service follows the **Repository-Service-Controller pattern**.

## Architecture

```
services/
├── auth/                # Authentication middleware utilities
├── register/            # Signup & Login (public)
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
services/register/
├── __init__.py
├── repository.py       # Database queries (CRUD)
├── service.py          # Business logic
└── controller.py       # /register/* endpoints
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
# services/register/repository.py
from models import User

class RegisterRepository:
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
# services/register/service.py
from core.security import hash_password, verify_password
from core.auth import create_access_token
from schemas.user import LoginRequest, SignupRequest

class RegisterService:
    def __init__(self, repository):
        self.repository = repository
    
    def signup(self, payload: SignupRequest) -> dict:
        if self.repository.get_by_email(payload.email):
            raise ValueError("Email already registered")
        
        user = self.repository.create({
            "email": payload.email,
            "password": hash_password(payload.password),
            "fullname": payload.full_name or payload.email.split("@", 1)[0]
        })
        token = create_access_token(user.id)
        return {"access_token": token, "token_type": "bearer", "user": user}
    
    def login(self, payload: LoginRequest) -> dict:
        user = self.repository.get_by_email(payload.email)
        if not user or not verify_password(payload.password, user.password):
            raise ValueError("Invalid credentials")
        
        token = create_access_token(user.id)
        return {"access_token": token, "token_type": "bearer", "user": user}
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
# services/register/controller.py
from fastapi import APIRouter, HTTPException
from schemas.user import AuthResponse, LoginRequest, SignupRequest

router = APIRouter(prefix="/register", tags=["register"])

@router.post("/signup", response_model=AuthResponse)
async def register(payload: SignupRequest, service: RegisterService = Depends()):
    try:
        return service.signup(payload)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/login", response_model=AuthResponse)
async def login(payload: LoginRequest, service: RegisterService = Depends()):
    try:
        return service.login(payload)
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
Calls AuthService.get_current_user(token)
    ↓
AuthService.repository.get_user_by_id(user_id)
    ↓
Returns user object
    ↓
Team Service continues logic
```

Services communicate through dependency injection in `main.py`.

## The Services

### **1. Auth Service (Middleware)**
**Manages:** Token verification and role enforcement for protected routes

**Key Operations:**
- `verify_token(token)` - Validate JWT
- `get_user(user_id)` - Retrieve user profile
- `require_roles(token, competition_id, roles)` - Enforce role permissions

**Register Service (public endpoints):** Handles signup/login and JWT issuance at `/register/*`.

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
from services.register.controller import router as register_router
from services.team.controller import router as team_router
from services.competition.controller import router as competition_router
# ... etc

app = FastAPI()

# Register routers
app.include_router(register_router)
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
├── register/
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

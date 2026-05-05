# Auth Service - Example Service Implementation

## Overview
The Auth service handles user authentication, JWT tokens, and user management. It's a good example of the **Repository-Service-Controller pattern** used across all services.

## File Structure

```
auth/
├── __init__.py
├── repository.py       # User database operations
├── service.py          # Authentication business logic
└── controller.py       # /auth/* endpoints
```

## Layer Breakdown

### **1. Repository** (`repository.py`)
Handles all database queries for users:

```python
from sqlalchemy.orm import Session
from models import User

class UserRepository:
    def __init__(self, db: Session):
        self.db = db
    
    def get_by_id(self, user_id: int) -> User:
        return self.db.query(User).filter(User.id == user_id).first()
    
    def get_by_email(self, email: str) -> User:
        return self.db.query(User).filter(User.email == email).first()
    
    def create(self, user_data: dict) -> User:
        user = User(**user_data)
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user
    
    def update(self, user_id: int, updates: dict) -> User:
        user = self.get_by_id(user_id)
        for key, value in updates.items():
            setattr(user, key, value)
        self.db.commit()
        return user
```

**Key Rule:** No business logic here, only CRUD!

---

### **2. Service** (`service.py`)
Contains authentication business logic:

```python
from core.security import hash_password, verify_password
from core.auth import create_access_token, verify_access_token
from core.exceptions import AuthenticationError, ValidationError
from schemas.user import UserCreate, UserUpdate

class AuthService:
    def __init__(self, repository: UserRepository):
        self.repository = repository
    
    # Register new user
    def register(self, user_data: UserCreate) -> User:
        # Check if email already exists
        existing = self.repository.get_by_email(user_data.email)
        if existing:
            raise ValidationError("Email already registered")
        
        # Hash password
        hashed_password = hash_password(user_data.password)
        
        # Create user
        user = self.repository.create({
            "email": user_data.email,
            "password_hash": hashed_password,
            "full_name": user_data.full_name
        })
        return user
    
    # Authenticate user and generate token
    def login(self, email: str, password: str) -> dict:
        user = self.repository.get_by_email(email)
        
        # Verify user exists and password matches
        if not user or not verify_password(password, user.password_hash):
            raise AuthenticationError("Invalid email or password")
        
        # Generate JWT token
        token = create_access_token(user_id=user.id)
        
        return {
            "access_token": token,
            "token_type": "bearer",
            "user_id": user.id
        }
    
    # Verify token and get current user
    def get_current_user(self, token: str) -> User:
        user_id = verify_access_token(token)
        if not user_id:
            raise AuthenticationError("Invalid or expired token")
        
        user = self.repository.get_by_id(user_id)
        if not user:
            raise AuthenticationError("User not found")
        
        return user
    
    # Update user profile
    def update_profile(self, user_id: int, updates: UserUpdate) -> User:
        user = self.repository.update(user_id, updates.dict(exclude_unset=True))
        return user
```

**Key Rule:** All business logic here, no HTTP handling!

---

### **3. Controller** (`controller.py`)
FastAPI routes for authentication:

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from core.database import SessionLocal
from schemas.user import UserCreate, UserResponse, LoginRequest, LoginResponse

router = APIRouter(prefix="/auth", tags=["auth"])

# Dependency: Get database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Dependency: Get auth service
def get_auth_service(db: Session = Depends(get_db)):
    repository = UserRepository(db)
    return AuthService(repository)

# GET /auth/me - Get current user
@router.get("/me", response_model=UserResponse)
async def get_me(
    token: str = Header(...),
    service: AuthService = Depends(get_auth_service)
):
    try:
        user = service.get_current_user(token)
        return user
    except AuthenticationError as e:
        raise HTTPException(status_code=401, detail=str(e))

# POST /auth/register - Register new user
@router.post("/register", response_model=UserResponse)
async def register(
    user_data: UserCreate,
    service: AuthService = Depends(get_auth_service)
):
    try:
        user = service.register(user_data)
        return user
    except ValidationError as e:
        raise HTTPException(status_code=400, detail=str(e))

# POST /auth/login - Login and get token
@router.post("/login", response_model=LoginResponse)
async def login(
    credentials: LoginRequest,
    service: AuthService = Depends(get_auth_service)
):
    try:
        result = service.login(credentials.email, credentials.password)
        return result
    except AuthenticationError as e:
        raise HTTPException(status_code=401, detail=str(e))

# PATCH /auth/profile - Update profile
@router.patch("/profile", response_model=UserResponse)
async def update_profile(
    updates: UserUpdate,
    token: str = Header(...),
    service: AuthService = Depends(get_auth_service)
):
    try:
        user = service.get_current_user(token)
        updated_user = service.update_profile(user.id, updates)
        return updated_user
    except (AuthenticationError, ValidationError) as e:
        raise HTTPException(status_code=400, detail=str(e))
```

**Key Rule:** Only handle HTTP, delegate to service!

---

## Data Flow Example: User Registration

```
1. Frontend sends POST /auth/register
   {
     "email": "user@example.com",
     "password": "secret123",
     "full_name": "John Doe"
   }

2. FastAPI validates with UserCreate schema
   ✓ email: valid format
   ✓ password: >8 chars
   ✓ full_name: required

3. Controller calls service.register(user_data)

4. Service checks business logic:
   - Is email already registered? (queries repository)
   - Hash password
   - Prepare user data

5. Service calls repository.create(user_dict)

6. Repository executes:
   INSERT INTO users (email, password_hash, full_name) VALUES (...)

7. Service receives User object from database

8. Controller returns UserResponse schema:
   {
     "id": 1,
     "email": "user@example.com",
     "full_name": "John Doe"
     // NO password_hash!
   }

9. Frontend receives successful response
```

---

## Using Auth in Other Services

Other services can authenticate requests:

```python
# services/team/controller.py
from services.auth.service import AuthService

@router.post("/teams")
async def create_team(
    team_data: TeamCreate,
    token: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
    team_service: TeamService = Depends(get_team_service)
):
    # Verify user is authenticated
    user = auth_service.get_current_user(token)
    
    # Create team with verified user
    team = team_service.create_team(team_data, user.id)
    return team
```

---

## Testing Auth Service

```python
# tests/services/auth/test_service.py
import pytest
from services.auth.service import AuthService
from core.exceptions import ValidationError, AuthenticationError

def test_register_success(auth_service):
    user = auth_service.register({
        "email": "test@example.com",
        "password": "secure123"
    })
    assert user.email == "test@example.com"

def test_register_duplicate_email(auth_service):
    auth_service.register({
        "email": "test@example.com",
        "password": "secure123"
    })
    
    with pytest.raises(ValidationError):
        auth_service.register({
            "email": "test@example.com",
            "password": "secure123"
        })

def test_login_success(auth_service):
    auth_service.register({
        "email": "test@example.com",
        "password": "secure123"
    })
    
    result = auth_service.login("test@example.com", "secure123")
    assert "access_token" in result

def test_login_wrong_password(auth_service):
    auth_service.register({
        "email": "test@example.com",
        "password": "secure123"
    })
    
    with pytest.raises(AuthenticationError):
        auth_service.login("test@example.com", "wrongpassword")
```

---

## Key Takeaways

| Layer | Responsibility | Location |
|-------|---|---|
| **Repository** | CRUD queries only | `repository.py` |
| **Service** | Business logic | `service.py` |
| **Controller** | HTTP routes | `controller.py` |

This pattern is replicated across all 11 services!

Auth Service = Pattern Template 🔐

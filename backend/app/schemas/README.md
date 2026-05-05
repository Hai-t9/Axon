# API Request/Response Schemas

## Overview
The `schemas/` folder contains all Pydantic models that validate and shape API data. This is the **API contract layer** between frontend and backend.

## Purpose

Schemas are responsible for:
- ✅ Validating incoming API requests
- ✅ Formatting outgoing API responses
- ✅ Hiding sensitive database fields
- ✅ Type checking and error messages
- ✅ Auto-generating OpenAPI (Swagger) documentation

## Architecture

```
schemas/
├── __init__.py
├── user.py              # User request/response schemas
├── team.py              # Team schemas
├── competition.py       # Competition schemas
├── phase.py             # Phase schemas
├── dataset.py           # Dataset schemas
├── label.py             # Label schemas
├── submission.py        # Submission schemas
├── evaluation.py        # Evaluation schemas
└── leaderboard.py       # Leaderboard schemas
```

## Schemas vs Models

### **Models** (ORM)
```python
# What's in the DATABASE
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    email = Column(String)
    password_hash = Column(String)      # ← Sensitive!
    created_at = Column(DateTime)       # ← Internal field
    is_active = Column(Boolean)
```

### **Schemas** (API)
```python
# What CLIENT SEES
class UserResponse(BaseModel):
    id: int
    email: str
    # password_hash ← NOT exposed!
    # created_at ← NOT exposed!
    # is_active ← NOT exposed!

class UserCreate(BaseModel):
    email: str
    password: str  # Client sends password, we hash it
```

## Schema Types

### **1. Create Schema (POST)**
Used when creating new records:
```python
# schemas/team.py
class TeamCreate(BaseModel):
    name: str
    description: str
```

### **2. Update Schema (PATCH/PUT)**
Used when updating records:
```python
class TeamUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
```

### **3. Response Schema (GET/POST response)**
What the API returns to the client:
```python
class TeamResponse(BaseModel):
    id: int
    name: str
    description: str
    # Internal fields NOT included
    # created_by NOT exposed
    # created_at NOT exposed
    
    class Config:
        from_attributes = True  # Convert ORM to schema
```

### **4. List Schema (GET all)**
For paginated list responses:
```python
class TeamListResponse(BaseModel):
    total: int
    page: int
    limit: int
    items: List[TeamResponse]
```

## Example File: user.py

```python
from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime

# CREATE schema - what client sends on POST /users/
class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    full_name: str

# UPDATE schema - what client sends on PATCH /users/{id}
class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None

# RESPONSE schema - what API returns
class UserResponse(BaseModel):
    id: int
    email: str
    full_name: str
    role: str
    # NO password_hash!
    # NO created_at!
    
    class Config:
        from_attributes = True

# LOGIN schema
class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
```

## Using Schemas in Controllers

```python
# services/register/controller.py
from fastapi import APIRouter
from schemas.user import SignupRequest, UserResponse, LoginRequest, AuthResponse

router = APIRouter(prefix="/register")

# POST /register/signup - Create user
@router.post("/signup", response_model=AuthResponse)
async def signup(payload: SignupRequest):  # ← Schema validates request
    result = register_service.signup(payload)
    return result  # ← Response formatted by AuthResponse schema

# POST /register/login - Login
@router.post("/login", response_model=AuthResponse)
async def login(credentials: LoginRequest):  # ← Schema validates
    result = register_service.login(credentials)
    return result

# GET /users/{id} - Get user
@router.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int):
    user = user_service.get_user(user_id)
    return user  # ← Formatted by UserResponse
```

## Validation Features

Pydantic automatically validates:

```python
class UserCreate(BaseModel):
    email: EmailStr              # Must be valid email
    password: str = Field(..., min_length=8)   # At least 8 chars
    age: int = Field(..., ge=0, le=150)  # 0-150 range
    full_name: str = Field(..., max_length=100)  # Max 100 chars
```

## Security Best Practices

### ✅ Expose only what's needed
```python
class UserResponse(BaseModel):
    id: int
    email: str
    # Hide: password_hash, is_active, created_at
```

### ✅ Use separate schemas for different purposes
```python
class AdminUserResponse(BaseModel):
    id: int
    email: str
    is_active: bool  # ← Only admins see this

class PublicUserResponse(BaseModel):
    id: int
    full_name: str   # ← Only public info
```

### ✅ Validate sensitive input
```python
class PasswordChange(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=8)
    confirm_password: str
    
    @validator('new_password')
    def password_complexity(cls, v):
        if not any(c.isupper() for c in v):
            raise ValueError('Password must have uppercase')
        return v
```

## File Organization Tips

Keep schemas organized by domain:
```
schemas/
├── user.py           # UserCreate, UserResponse, LoginSchema
├── team.py           # TeamCreate, TeamResponse
├── competition.py    # CompetitionCreate, CompetitionResponse
└── ...
```

## Exporting Schemas

In `schemas/__init__.py`:
```python
from .user import UserCreate, UserResponse, LoginRequest
from .team import TeamCreate, TeamResponse
from .competition import CompetitionCreate, CompetitionResponse
# ... etc

__all__ = [
    "UserCreate", "UserResponse", "LoginRequest",
    "TeamCreate", "TeamResponse",
    "CompetitionCreate", "CompetitionResponse",
]
```

## Common Patterns

### **Optional fields on update**
```python
class UpdateSchema(BaseModel):
    field1: Optional[str] = None
    field2: Optional[int] = None
```

### **Nested schemas**
```python
class AddressSchema(BaseModel):
    street: str
    city: str
    country: str

class UserWithAddress(BaseModel):
    email: str
    address: AddressSchema  # Nested validation
```

### **Pagination response**
```python
class PaginatedResponse(BaseModel):
    total: int
    page: int
    limit: int
    items: List[ItemResponse]
```

## Key Rules

1. **Never expose password_hash** - Convert/hash in service, not schema
2. **Use EmailStr** - Auto-validates email format
3. **Use Field()** - Add min/max constraints, descriptions
4. **Separate concerns** - Different schemas for different purposes
5. **Keep updated** - Schema changes = API contract changes

## Performance

Add `orm_mode = True` to response schemas to automatically convert ORM models:

```python
class UserResponse(BaseModel):
    id: int
    email: str
    
    class Config:
        from_attributes = True  # Auto-convert ORM to schema
```

Schemas = API Contract Only 📝

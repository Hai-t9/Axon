# Core Infrastructure

## Overview
The `core/` folder contains shared infrastructure code used by all services. Think of it as the "backbone" of the application.

## Contents

### **auth.py**
**Purpose:** JWT token management

**Responsibilities:**
- Create JWT access tokens
- Verify & decode JWT tokens
- Refresh token logic
- Token expiration handling

**Used by:** All services that need authentication

**Example:**
```python
token = create_access_token(user_id=42, expires_in=3600)
user_id = verify_access_token(token)
```

---

### **security.py**
**Purpose:** Password security operations

**Responsibilities:**
- Hash passwords using bcrypt
- Verify passwords
- Generate secure tokens
- Password validation rules

**Used by:** Auth service, user management

**Example:**
```python
hashed = hash_password("user_password")
is_valid = verify_password("user_password", hashed)
```

---

### **middleware.py**
**Purpose:** HTTP middleware for all requests

**Responsibilities:**
- CORS (Cross-Origin Resource Sharing)
- Rate limiting
- Request logging
- Security headers
- Error handling

**Used by:** Registered globally in `main.py`

---

### **exceptions.py**
**Purpose:** Global exception definitions

**Responsibilities:**
- Custom exception classes
- Standard error responses
- Error codes & messages

**Example:**
```python
class AuthenticationError(Exception):
    pass

class ValidationError(Exception):
    pass
```

**Used by:** All services for consistent error handling

---

### **database.py**
**Purpose:** SQLAlchemy database setup

**Responsibilities:**
- SQLAlchemy engine configuration
- Session factory (SessionLocal)
- Base model for all ORM models
- Database URL from environment

**Example:**
```python
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()  # All models inherit from Base
```

**Used by:** All ORM models and repositories

---

## File Organization

```
core/
├── __init__.py
├── auth.py           # JWT token creation/verification
├── security.py       # Password hashing & verification
├── middleware.py     # CORS, rate limiting, logging
├── exceptions.py     # Custom exception classes
└── database.py       # SQLAlchemy setup & configuration
```

## Data Flow

```
Request arrives
    ↓
middleware.py (CORS, logging, rate limit)
    ↓
Route handler in controller.py
    ↓
Service needs database session
    ↓
database.py provides SessionLocal
    ↓
Service calls repository
    ↓
Repository executes ORM query
    ↓
Response
    ↓
middleware.py (add security headers)
    ↓
Return to client
```

## Key Imports Used

- **FastAPI services** → `from core.database import SessionLocal`
- **Auth routes** → `from core.auth import create_access_token`
- **Password validation** → `from core.security import hash_password`
- **Error handling** → `from core.exceptions import ValidationError`

## Adding New Core Utilities

If you need new shared infrastructure:

1. Add to appropriate file (security.py, auth.py, etc.)
2. OR create new file if it's a separate concern
3. Import in services via `from core.xyz import ...`
4. Register middleware in `main.py` if needed

## No Business Logic Here!

Core is for **infrastructure only**:
- ✅ Database connection
- ✅ Password hashing
- ✅ Token management
- ✅ Middleware
- ❌ NO business logic (use services/)
- ❌ NO domain-specific operations

Keep it generic and reusable! 🔧

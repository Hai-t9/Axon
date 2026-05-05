# Backend Tests

## Overview
The `tests/` folder contains all automated tests for the backend. Tests are organized to mirror the `app/services/` structure for easy navigation.

## Purpose

- ✅ Verify business logic correctness
- ✅ Catch bugs before deployment
- ✅ Ensure API contracts work
- ✅ Regression testing
- ✅ Documentation through examples

## Test Structure

```
tests/
├── conftest.py              # Pytest fixtures & configuration
└── services/
    ├── auth/
    │   ├── test_repository.py     # Test database queries
    │   ├── test_service.py        # Test business logic
    │   └── test_controller.py     # Test API endpoints
    ├── team/
    │   ├── test_repository.py
    │   ├── test_service.py
    │   └── test_controller.py
    ├── competition/
    │   ├── test_repository.py
    │   ├── test_service.py
    │   └── test_controller.py
    └── ... (11 services total)
```

## Test Types

### **1. Unit Tests** (test_service.py)
Test business logic in isolation:

```python
# tests/services/auth/test_service.py
import pytest
from services.auth.service import AuthService
from core.exceptions import ValidationError

def test_register_user_success(auth_service):
    user = auth_service.register({
        "email": "test@example.com",
        "password": "secure123"
    })
    assert user.email == "test@example.com"

def test_register_duplicate_email_fails(auth_service):
    auth_service.register({
        "email": "test@example.com",
        "password": "secure123"
    })
    
    with pytest.raises(ValidationError):
        auth_service.register({
            "email": "test@example.com",
            "password": "secure123"
        })
```

### **2. Repository Tests** (test_repository.py)
Test database operations:

```python
# tests/services/auth/test_repository.py
import pytest
from services.auth.repository import UserRepository
from models import User

def test_create_user(user_repository):
    user = user_repository.create({
        "email": "test@example.com",
        "password_hash": "hashed_password"
    })
    assert user.id is not None
    assert user.email == "test@example.com"

def test_get_user_by_email(user_repository):
    user_repository.create({
        "email": "test@example.com",
        "password_hash": "hashed"
    })
    
    found = user_repository.get_by_email("test@example.com")
    assert found is not None
```

### **3. Integration Tests** (test_controller.py)
Test complete API endpoints:

```python
# tests/services/auth/test_controller.py
import pytest
from fastapi.testclient import TestClient

def test_register_endpoint(client):
    response = client.post("/auth/register", json={
        "email": "test@example.com",
        "password": "secure123",
        "full_name": "John Doe"
    })
    assert response.status_code == 200
    assert response.json()["email"] == "test@example.com"

def test_login_endpoint(client, user):
    response = client.post("/auth/login", json={
        "email": user.email,
        "password": "secure123"
    })
    assert response.status_code == 200
    assert "access_token" in response.json()
```

## Pytest Fixtures

Define reusable test setup in `conftest.py`:

```python
# tests/conftest.py
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
from app.main import app
from core.database import Base
from services.auth.repository import UserRepository
from services.auth.service import AuthService

# Use in-memory SQLite for tests
TEST_DATABASE_URL = "sqlite:///./test.db"

@pytest.fixture(scope="function")
def db():
    """Create test database"""
    engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    
    db_instance = SessionLocal()
    yield db_instance
    db_instance.close()
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def user_repository(db):
    """User repository with test database"""
    return UserRepository(db)

@pytest.fixture
def auth_service(user_repository):
    """Auth service with test repository"""
    return AuthService(user_repository)

@pytest.fixture
def client():
    """FastAPI test client"""
    return TestClient(app)

@pytest.fixture
def user(auth_service):
    """Create a test user"""
    return auth_service.register({
        "email": "test@example.com",
        "password": "secure123",
        "full_name": "Test User"
    })
```

## Running Tests

```bash
# Run all tests
pytest

# Run specific test file
pytest tests/services/auth/test_service.py

# Run specific test
pytest tests/services/auth/test_service.py::test_register_user_success

# Run with verbose output
pytest -v

# Run with coverage
pytest --cov=app

# Run in watch mode (requires pytest-watch)
ptw
```

## Test Organization Best Practices

### ✅ Group related tests
```python
# Good
class TestUserRegistration:
    def test_register_success(self):
        pass
    
    def test_register_duplicate_email(self):
        pass
    
    def test_register_invalid_email(self):
        pass

# Bad
def test_register_1():
    pass
def test_register_2():
    pass
```

### ✅ Use descriptive names
```python
# Good
def test_register_user_with_valid_email_succeeds():
    pass

# Bad
def test_register():
    pass
```

### ✅ Follow AAA pattern (Arrange, Act, Assert)
```python
def test_login_with_correct_password():
    # Arrange
    user = create_test_user("test@example.com", "password123")
    
    # Act
    result = auth_service.login("test@example.com", "password123")
    
    # Assert
    assert result["access_token"] is not None
```

### ✅ Mock external services
```python
from unittest.mock import patch

@patch('storage.image_store.upload_image')
def test_data_ingestion_uploads_image(mock_upload):
    mock_upload.return_value = {"image_id": 1}
    
    result = data_service.ingest_image(image_file)
    assert result["image_id"] == 1
```

## Test Coverage

Aim for high coverage:

```bash
# Generate coverage report
pytest --cov=app --cov-report=html

# Check coverage
pytest --cov=app --cov-report=term-missing
```

**Target:** 80%+ code coverage

## Common Test Patterns

### **Test validation**
```python
def test_password_too_short_fails(auth_service):
    with pytest.raises(ValidationError):
        auth_service.register({
            "email": "test@example.com",
            "password": "short"  # < 8 chars
        })
```

### **Test database constraints**
```python
def test_duplicate_email_fails(user_repository):
    user_repository.create({
        "email": "test@example.com",
        "password_hash": "hash1"
    })
    
    with pytest.raises(Exception):  # Database constraint
        user_repository.create({
            "email": "test@example.com",  # Duplicate
            "password_hash": "hash2"
        })
```

### **Test API response codes**
```python
def test_login_with_invalid_credentials(client):
    response = client.post("/auth/login", json={
        "email": "wrong@example.com",
        "password": "wrong"
    })
    assert response.status_code == 401
    assert "Invalid credentials" in response.json()["detail"]
```

## Test Database

Use separate test database:
- **Development:** PostgreSQL
- **Testing:** SQLite (in-memory, fast)

SQLite is perfect for tests because:
- ✅ No external dependency
- ✅ Fast in-memory operations
- ✅ Isolated (fresh DB per test)
- ✅ Easy cleanup

## CI/CD Integration

Tests run automatically on:
- Pull requests
- Before merge
- Before deployment

```yaml
# .github/workflows/tests.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run tests
        run: pytest --cov=app
```

## Test Maintenance

- ✅ Update tests when API changes
- ✅ Add test for every bug fix
- ✅ Keep fixtures DRY (reusable)
- ✅ Remove obsolete tests
- ✅ Keep tests fast (<1 second each)

## When NOT to Test

- ❌ Library code (pytest, FastAPI)
- ❌ Simple getters/setters
- ❌ Framework-generated code

Focus on your business logic!

Tests = Quality Assurance 🧪

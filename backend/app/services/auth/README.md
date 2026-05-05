# Auth Service - Middleware Utilities

## Overview
The Auth service provides token verification and role enforcement for protected routes. Login and signup live in the Register service (`/register/*`).

## File Structure

```
auth/
├── __init__.py
├── repository.py       # User + role lookups
└── service.py          # Token validation + role enforcement
```

## Repository (repository.py)

```python
from typing import Optional

from sqlalchemy.orm import Session
from models import Role, User

class AuthRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_user_by_id(self, user_id: int) -> Optional[User]:
        return self.db.query(User).filter(User.id == user_id).first()

    def get_role(self, user_id: int, competition_id: int) -> Optional[Role]:
        return (
            self.db.query(Role)
            .filter(Role.user_id == user_id, Role.competition_id == competition_id)
            .first()
        )
```

## Service (service.py)

```python
from typing import Set

from core.auth import verify_access_token
from core.exceptions import AuthenticationError, AuthorizationError
from models import RoleType

class AuthService:
    def __init__(self, repository):
        self.repository = repository

    def get_current_user(self, token: str):
        user_id = verify_access_token(token)
        if not user_id:
            raise AuthenticationError("Invalid or expired token")
        user = self.repository.get_user_by_id(user_id)
        if not user:
            raise AuthenticationError("User not found")
        return user

    def require_roles(self, token: str, competition_id: int, allowed_roles: Set[RoleType]):
        user = self.get_current_user(token)
        role = self.repository.get_role(user.id, competition_id)
        if not role or role.role not in allowed_roles:
            raise AuthorizationError("Insufficient permissions")
        return user
```

## Usage in Other Services

```python
from fastapi import Header, HTTPException
from core.auth import extract_bearer_token
from core.exceptions import AuthenticationError
from services.auth.service import AuthService

@router.get("/competitions")
async def list_competitions(
    authorization: str = Header(...),
    auth_service: AuthService = Depends(get_auth_service),
):
    try:
        token = extract_bearer_token(authorization)
        auth_service.get_current_user(token)
        # Continue with business logic
    except AuthenticationError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
```

## Notes

- Use the Register service for public endpoints: `/register/signup` and `/register/login`.
- The Auth service has no controller; it is injected as middleware utilities.

# Centralized ORM Models

## Overview
The `models/` folder contains all SQLAlchemy ORM models. This is the **single source of truth** for your database schema across the entire application.

## Purpose

Instead of having models scattered in each service folder (which causes circular imports and duplication), all models are defined here and imported by services.

## Architecture

```
models/
├── __init__.py
├── model_enums.py       # Enum definitions
├── model_user.py        # User & Role models
├── model_team.py        # Team model
├── model_competition.py # Competition & Config models
├── model_phase.py       # PhaseLog model
├── model_dataset.py     # Dataset model
├── model_label.py       # Label & LabelValidation models
├── model_image.py       # Image & ImageMetadata models
├── model_model.py       # Model submission model
└── model_evaluation.py  # Evaluation model
```

## What Goes Here

### **File Organization**
- One file per major entity
- Related entities can be in the same file (User + Role)
- Keep files focused and readable (~100-200 lines each)

### **Example: model_user.py**
```python
from sqlalchemy import Column, Integer, String, DateTime, Boolean
from core.database import Base
from datetime import datetime

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)
    role = Column(String)  # "host", "staff", "participant"
    created_at = Column(DateTime, default=datetime.now)
    
    # Optional: Simple utility method
    def __repr__(self):
        return f"<User(id={self.id}, email={self.email})>"

class Role(Base):
    __tablename__ = "roles"
    
    id = Column(Integer, primary_key=True)
    name = Column(String, unique=True)
```

## What NOT to Put Here

❌ Business logic methods
❌ Database save() methods
❌ API validation logic
❌ External service calls
❌ Password verification
❌ Email sending

All of ↑ goes in **services/** instead!

## How Models Are Used

### **In Repositories**
```python
# services/register/repository.py
from models import User

class RegisterRepository:
    def get_by_email(self, email: str) -> User:
        return self.db.query(User).filter(User.email == email).first()
```

### **In Alembic Migrations**
```python
# alembic/env.py
from models import Team, User
# All models imported for auto-migration detection
```

## Key Rules

1. **Inherit from Base** - All models must inherit from `Base` (defined in `core/database.py`)
2. **Define __tablename__** - Must specify database table name
3. **Use Column() for fields** - Define all database columns
4. **Keep it simple** - No complex methods or business logic
5. **Document relationships** - Use ForeignKey and relationships() clearly

## Relationships Example

```python
# models/model_team.py
from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from core.database import Base

class Team(Base):
    __tablename__ = "teams"
    
    id = Column(Integer, primary_key=True)
    name = Column(String, unique=True)
    created_by = Column(Integer, ForeignKey("users.id"))
    
    # Relationship to User
    creator = relationship("User")
    
    # Relationship to TeamMembers
    members = relationship("TeamMember", back_populates="team")

class TeamMember(Base):
    __tablename__ = "team_members"
    
    id = Column(Integer, primary_key=True)
    team_id = Column(Integer, ForeignKey("teams.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    
    # Relationship back to Team
    team = relationship("Team", back_populates="members")
```

## Importing Models

In `__init__.py`, export all models for easy access:

```python
# models/__init__.py
from .model_user import User, Role
from .model_team import Team
from .model_competition import Competition
from .model_phase import PhaseLog
from .model_dataset import Dataset
from .model_label import Label, LabelValidation
from .model_image import Image, ImageMetadata
from .model_model import Model
from .model_evaluation import Evaluation

__all__ = [
    "User", "Role",
    "Team",
    "Competition",
    "PhaseLog",
    "Dataset",
    "Label", "LabelValidation",
    "Image", "ImageMetadata",
    "Model",
    "Evaluation",
]
```

Then import anywhere:
```python
from models import User, Team, Competition
```

## Database Relationships

Map the entity relationships:

```
User
├── creates Teams
├── submits Models
└── has Role

Team
├── has Members (User)
└── participates in Competition

Competition
├── has Phases
└── has Leaderboard

Phase
├── has Datasets
└── has Submissions

Dataset
└── has Labels

Submission
└── has Evaluations

Evaluation
└── generates Results
```

## Adding New Models

1. Create new file: `models/model_my_entity.py`
2. Define ORM class inheriting from Base
3. Add relationships as needed
4. Import in `models/__init__.py`
5. Run Alembic migration: `alembic revision --autogenerate`
6. Apply migration: `alembic upgrade head`

## Performance Tips

- ✅ Add `index=True` to frequently searched columns
- ✅ Use `lazy="joined"` for relationships accessed together
- ✅ Use `lazy="select"` for relationships loaded on demand
- ✅ Keep models focused, split if >250 lines

## Validation Note

Data validation happens in `schemas/`, NOT here:
```python
# ❌ WRONG
class User(Base):
    def validate_email(self):
        pass

# ✅ CORRECT - Put validation in schemas/user.py
class UserCreate(BaseModel):
    email: EmailStr  # Pydantic validates
```

Models = Database Structure Only 🗄️

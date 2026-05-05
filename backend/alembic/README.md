# Database Migrations

## Overview
The `alembic/` folder manages database schema version control. It tracks all changes to your PostgreSQL database structure.

## Purpose

- ✅ Version control for database schema
- ✅ Migrate up/down through versions
- ✅ Share schema changes with team
- ✅ Automate schema deployment
- ✅ Track schema history

## How It Works

Alembic detects changes to your ORM models and generates migration files:

```
1. You modify models/ (e.g., add new column to User)
   ↓
2. Run: alembic revision --autogenerate -m "Add new column"
   ↓
3. Migration file generated: versions/001_add_new_column.py
   ↓
4. Run: alembic upgrade head
   ↓
5. Database schema updated ✓
   ↓
6. Commit migration to Git
```

## File Structure

```
alembic/
├── __init__.py
├── env.py                 # Alembic configuration
├── script.py.mako         # Migration template
├── alembic.ini            # Settings file
└── versions/
    ├── __init__.py
    ├── 001_initial_schema.py
    ├── 002_add_user_role.py
    ├── 003_create_team_table.py
    └── ... (one per schema change)
```

## Workflow

### **Step 1: Modify ORM Model**
```python
# app/models/user.py
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    email = Column(String)
    password_hash = Column(String)
    role = Column(String)  # ← NEW FIELD
```

### **Step 2: Generate Migration**
```bash
alembic revision --autogenerate -m "Add user role column"
```

Creates new file: `versions/004_add_user_role_column.py`

### **Step 3: Review Migration**
```python
# versions/004_add_user_role_column.py
def upgrade():
    op.add_column('users', sa.Column('role', sa.String(), nullable=True))

def downgrade():
    op.drop_column('users', 'role')
```

### **Step 4: Apply Migration**
```bash
alembic upgrade head
```

Schema updated in database!

### **Step 5: Commit to Git**
```bash
git add alembic/versions/004_add_user_role_column.py
git commit -m "Add user role column"
git push
```

Team gets migration and runs locally!

## Common Commands

```bash
# Generate migration for model changes
alembic revision --autogenerate -m "Description"

# Apply all pending migrations
alembic upgrade head

# Downgrade one version
alembic downgrade -1

# Downgrade to specific version
alembic downgrade 002_create_team_table

# View current database version
alembic current

# View migration history
alembic history

# Mark database as current without running
alembic stamp head
```

## Migration File Example

```python
# versions/005_create_team_table.py
from alembic import op
import sqlalchemy as sa

revision = '005'
down_revision = '004'

def upgrade():
    op.create_table(
        'teams',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('name')
    )

def downgrade():
    op.drop_table('teams')
```

## Handling Migrations

### **Manual Edits**
Sometimes auto-generated migrations need fixes:

```python
# Auto-generated (might be incomplete)
def upgrade():
    op.add_column('users', sa.Column('role', sa.String(), nullable=True))

# Manual fix
def upgrade():
    op.add_column('users', sa.Column('role', sa.String(), nullable=False, server_default='user'))
    op.execute("UPDATE users SET role = 'user' WHERE role IS NULL")
    op.alter_column('users', 'role', nullable=False)
```

### **Data Migrations**
When you need to transform data:

```python
# Rename column + migrate data
def upgrade():
    op.add_column('users', sa.Column('full_name', sa.String()))
    op.execute("""
        UPDATE users SET full_name = CONCAT(first_name, ' ', last_name)
    """)
    op.drop_column('users', 'first_name')
    op.drop_column('users', 'last_name')
```

## In Production

### **Before Deployment:**
1. Generate migration
2. Test locally
3. Review with team
4. Commit to version control
5. Merge to main branch

### **During Deployment:**
1. Pull latest code
2. Run: `alembic upgrade head`
3. Database updates automatically
4. Deploy application code
5. No downtime!

## Preventing Problems

### ✅ Always generate migrations
```bash
alembic revision --autogenerate -m "description"
# Don't manually edit database!
```

### ✅ Write descriptive messages
```bash
# Good
alembic revision --autogenerate -m "Add user role and permissions fields"

# Bad
alembic revision --autogenerate -m "Update"
```

### ✅ Test migrations locally
```bash
# Upgrade
alembic upgrade head

# Verify schema
\d users  # In psql

# Downgrade to test rollback
alembic downgrade -1

# Upgrade again
alembic upgrade head
```

### ✅ Never modify old migrations
Old migrations are immutable - write new ones!

```bash
# Wrong - don't edit 001_initial.py
# Right - write new 003_fix_schema.py
```

## Team Workflow

### **Developer A**
1. Creates new model
2. Generates migration: `002_add_product_table.py`
3. Commits to Git

### **Developer B (pulling changes)**
1. Gets `002_add_product_table.py`
2. Runs `alembic upgrade head`
3. Database updated locally
4. Can now use Product model

### **No Conflicts!**
Migrations are sequential, always safe.

## Common Errors

### **"Target database is not up to date"**
```bash
# Your code expects a newer schema
# Solution:
alembic upgrade head
```

### **"New migration file generated but not the expected one"**
```bash
# Models changed after last migration
# Solution: Generate new migration
alembic revision --autogenerate -m "description"
```

### **"Downgrade failed"**
```bash
# Migration didn't have proper downgrade logic
# Solution: Fix downgrade() function in migration file
```

## Database Schema Tracking

Alembic maintains version info:

```python
# PostgreSQL: alembic_version table
SELECT * FROM alembic_version;
# Shows current schema version

# Example output:
# version_num
# 005
```

## Initial Setup

For new project:

```bash
# Initialize Alembic
alembic init -t async alembic

# Generate initial schema from models
alembic revision --autogenerate -m "Initial schema"

# Apply
alembic upgrade head

# Commit to Git
git add alembic/
git commit -m "Initial database schema"
```

## Best Practices

- ✅ Generate migrations early and often
- ✅ Test migrations before committing
- ✅ Write clear migration messages
- ✅ Never manually edit old migrations
- ✅ Always have downgrade logic
- ✅ Review migrations as code
- ✅ Keep migrations small (one change per migration)

Migrations = Schema Version Control 📋

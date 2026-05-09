---
sidebar_position: 14
---

# Authentication & Registration

## Overview

The Authentication service handles user login and signup, issues JWTs for protected routes, and provides helpers that enforce identity and roles across modules. Registration endpoints are public and bypass auth/role checks.

---

### Responsibility

Provides a consistent authentication layer for all protected requests, issues JWTs on successful login and signup, and enforces role-based access (host, staff, participant).

### Auth Enforcement

Auth is enforced **per-route** via `AuthService` calls (not middleware):

```
Request → Route Handler → AuthService.require_roles() → Module
```

**AuthService methods:**
- `get_current_user(token)` — verifies JWT, returns User
- `require_roles(token, competition_id, {RoleType})` — verifies JWT + role
- `get_user_role(competition_id, user_id)` — returns role for a user

### Registration Module

```
Controller (register/controller.py)
  |-- handleLogin()     → POST /api/v1/register/login
  |-- handleSignup()    → POST /api/v1/register/signup
  |-- handleGetMe()     → GET /api/v1/register/me

Service (register/service.py)
  |-- login()
  |     |-- findByEmail()
  |     |-- verifyPassword()   // PBKDF2-SHA256
  |     |-- generateJWT()
  |-- signup()
        |-- checkEmailExists()
        |-- hashPassword()     // PBKDF2-SHA256
        |-- createUser()
        |-- generateJWT()

Repository
  |-- findByEmail()
  |-- create()
```

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `login` | `email`, `password` | `{ access_token, token_type, user }` |
| `signup` | `email`, `password`, `full_name?`, `phone?` | `{ access_token, token_type, user }` |

### APIs

#### `POST /api/v1/register/login`
**Description:** Login with credentials and return a JWT  
**Auth:** false

| Field | Type | Required | Description |
|---|---|---|---|
| `email` | string | yes | User email address |
| `password` | string | yes | Plaintext password |

**Output:** `access_token` (string JWT), `token_type` ("bearer"), `user` (object: `id`, `fullname`, `email`, `phone`, `created_at`)

---

#### `POST /api/v1/register/signup`
**Description:** Register a new user and return a JWT  
**Auth:** false

| Field | Type | Required | Description |
|---|---|---|---|
| `email` | string | yes | User email address |
| `password` | string | yes | Plaintext password (min 8 chars) |
| `full_name` | string | no | Display name (defaults to email local-part) |
| `phone` | string | no | Phone number |

**Output:** `access_token` (string JWT), `token_type` ("bearer"), `user` (object: `id`, `fullname`, `email`, `phone`, `created_at`)

---

#### `GET /api/v1/register/me`
**Description:** Get current authenticated user's profile  
**Auth:** true

**Headers:** `Authorization: Bearer <token>`

**Output:** `id`, `fullname`, `email`, `phone`, `created_at`

**Controller** (`register/controller.py`)
- `handleLogin()`
- `handleSignup()`
- `handleGetMe()`

**Service** (`register/service.py`)
- `login()`
  - → `findByEmail()`
  - → `verifyPassword()`
  - → `generateJWT()`
- `signup()`
  - → `checkEmailExists()`
  - → `hashPassword()`
  - → `createUser()`
  - → `generateJWT()`

**Repository** (`register/repository.py`)
- `getByEmail()`
- `create()`

### Dependencies

- `user` table
- PBKDF2-SHA256 (password hashing, see `core/security.py`)
- Custom JWT signing (see `core/auth.py` — HMAC-SHA256, no python-jose dependency)
- JWT signing secret and token config
- Role definitions: host, staff, participant

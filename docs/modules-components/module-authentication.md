---
sidebar_position: 14
---

# Authentication & Registration

## Overview

The Authentication service handles user login and signup, issues JWTs for protected routes, and provides middleware that enforces identity and roles across modules. Registration endpoints are public and bypass auth/role middleware.

---

### Responsibility

Provides a consistent authentication layer for all protected requests, issues JWTs on successful login and signup, and enforces role-based access (host, staff, participant).

### Middleware Pipeline

```
Request -> AuthMiddleware -> RoleMiddleware -> Module
```

**AuthMiddleware**
- `verifyJWT()`
- `extractUser()`
- `attachUserToRequest()`

**RoleMiddleware**
- `checkUserRole()` // host / staff / participant
- `blockIfUnauthorized()`

### Registration Module

```
Controller
  |-- handleLogin()
  |-- handleSignup()

Service
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

Middleware applied: none (registration is public).

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `login` | `email`, `password` | `{ token, user }` |
| `signup` | `email`, `password`, `name?` | `{ token, user }` |

### APIs

#### `POST /auth/login`
**Description:** Login with credentials and return a JWT
**Auth:** false

| Field | Type | Required | Description |
|---|---|---|---|
| `email` | string | yes | User email address |
| `password` | string | yes | Plaintext password |

**Output:** `token` (string JWT), `user` (object: `id`, `email`, `role`, `created_at`)

---

#### `POST /auth/signup`
**Description:** Register a new user and return a JWT
**Auth:** false

| Field | Type | Required | Description |
|---|---|---|---|
| `email` | string | yes | User email address |
| `password` | string | yes | Plaintext password |
| `name` | string | no | Display name (if provided by client) |

**Output:** `token` (string JWT), `user` (object: `id`, `email`, `role`, `created_at`)

**Controller**
- `handleLogin()`
- `handleSignup()`

**Service**
- `login()`
  - -> `findByEmail()`
  - -> `verifyPassword()`
  - -> `generateJWT()`
- `signup()`
  - -> `checkEmailExists()`
  - -> `hashPassword()`
  - -> `createUser()`
  - -> `generateJWT()`

**Repository**
- `findByEmail()`
- `create()`

### Dependencies

- `user` table
- PBKDF2-SHA256 (password hashing, see `core/security.py`)
- JWT signing secret and token config
- Role definitions: host, staff, participant

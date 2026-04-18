---
sidebar_position: 1
title: Database Schema
---

# Database Schema

The following ER diagram models core identity, authorization, and documentation lifecycle records.

```mermaid
erDiagram
  USER ||--o{ USER_ROLE : assigned_to
  ROLE ||--o{ USER_ROLE : includes
  ROLE ||--o{ ROLE_PERMISSION : grants
  PERMISSION ||--o{ ROLE_PERMISSION : maps_to
  USER ||--o{ SESSION : starts
  USER ||--o{ DOCUMENT : authors
  DOCUMENT ||--o{ DOCUMENT_VERSION : tracks
  DOCUMENT_VERSION ||--o{ REVIEW : receives

  USER {
    uuid id PK
    string email
    string display_name
    string status
    datetime created_at
  }

  ROLE {
    uuid id PK
    string name
    string description
  }

  PERMISSION {
    uuid id PK
    string code
    string description
  }

  USER_ROLE {
    uuid user_id FK
    uuid role_id FK
    datetime granted_at
  }

  ROLE_PERMISSION {
    uuid role_id FK
    uuid permission_id FK
  }

  SESSION {
    uuid id PK
    uuid user_id FK
    datetime created_at
    datetime expires_at
    string ip_address
  }

  DOCUMENT {
    uuid id PK
    uuid author_id FK
    string slug
    string title
    string visibility
    datetime created_at
  }

  DOCUMENT_VERSION {
    uuid id PK
    uuid document_id FK
    string semver
    string status
    datetime published_at
  }

  REVIEW {
    uuid id PK
    uuid version_id FK
    uuid reviewer_id FK
    string decision
    datetime reviewed_at
  }
```

## Notes

- Treat this as a living schema contract.
- Keep entity names aligned with actual table names in migrations.
- Add indexes and uniqueness rules in implementation notes as needed.

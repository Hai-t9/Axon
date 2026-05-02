---
sidebar_position: 1
title: Database Schema
---

# Database Schema

This ER diagram is generated to match the canonical DBML in `static/schema/schema.db.txt` (source-controlled). It reflects core tables used by competitions, teams, images, labels, models and evaluations.

```mermaid
%%{init: {'themeVariables': { 'fontSize':'20px', 'fontFamily':'Inter, Arial, sans-serif' }}}%%
erDiagram
  USER ||--o{ ROLE : has
  COMPETITION ||--o{ ROLE : includes
  COMPETITION ||--|| CONFIG : has_config
  COMPETITION ||--o{ TEAM : has
  TEAM ||--o{ IMAGE : has
  USER ||--o{ IMAGE : authors
  IMAGE ||--|| IMAGE_METADATA : has_metadata
  IMAGE ||--o{ LABEL : has_label
  LABEL ||--o{ LABEL_VALIDATIONS : validated_by
  TEAM ||--o{ DATASET : owns
  TEAM ||--o{ MODEL : submits
  MODEL ||--o{ EVALUATION : evaluated_by
  COMPETITION ||--o{ PHASE_LOG : logs

  USER {
    int id PK
    varchar fullname
    varchar email
    varchar password
    varchar phone
    timestamp created_at
  }

  ROLE {
    int user_id FK
    int competition_id FK
    enum role
  }

  COMPETITION {
    int id PK
    varchar name
    text description
    date launch_date
    json configjson
    varchar invitation_link
  }

  CONFIG {
    int id PK
    int competition_id FK
    json labels
    varchar data_ex
    varchar scoring_ex
    varchar overview
    varchar terms_conditions
    varchar data_md
    varchar data_format
    varchar evaluation
    float duplicate_threshhold
  }

  TEAM {
    int id PK
    varchar name
    int comp_id FK
    json user_ids
  }

  PHASE_LOG {
    int id PK
    int competition_id FK
    json phase_dates
    varchar current_phase
  }

  IMAGE {
    int id PK
    int team_id FK
    int author_id FK
    timestamp time
    varchar label
    varchar filepath
    enum status
    varchar original_filename
    varchar old_extension
    varchar image_hash
    float old_size_mb
    float old_width
    float old_height
    varchar device
  }

  IMAGE_METADATA {
    int id PK
    int image_id FK
    varchar GPSInfo
    float ImageWidth
    float ImageLength
    varchar ResolutionUnit
    varchar Make
    varchar Model
    varchar Software
    datetime DateTime
    float XResolution
    float YResolution
    float New_width
    float New_height
    float New_size_mb
    varchar Extra_subfolder
  }

  LABEL {
    int id PK
    int image_id FK
    varchar label
    bool validated
  }

  LABEL_VALIDATIONS {
    int id PK
    int label_id FK
    int validator_id FK
    varchar label
    timestamp validated_at
  }

  DATASET {
    int id PK
    int team_id FK
    varchar team_folderpath
  }

  MODEL {
    int id PK
    int team_id FK
    int competition_id FK
    varchar docker_img_filepath
    timestamp submitted_at
  }

  EVALUATION {
    int id PK
    int model_id FK
    float score
    timestamp evaluated_at
  }
```

## Notes

- Treat this as a living schema contract.
- Keep entity names aligned with actual table names in migrations.
- Add indexes and uniqueness rules in implementation notes as needed.

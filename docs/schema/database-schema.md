---
sidebar_position: 1
title: Database Schema
---

# Database Schema

Database engine: PostgreSQL. Model artifacts and datasets are stored in object storage and referenced by URI.

This ER diagram is generated to match the canonical DBML in `static/schema/schema.db.txt` (source-controlled). It reflects core tables used by competitions, teams, images, labels, models and evaluations, including teams, submissions, evaluation jobs, and leaderboard ranking.

```mermaid
%%{init: {'themeVariables': { 'fontSize':'20px', 'fontFamily':'Inter, Arial, sans-serif' }}}%%
erDiagram
<<<<<<< Updated upstream
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
=======
  TEAM ||--o{ TEAM_MEMBER : includes
  USER ||--o{ TEAM_MEMBER : joins
  DATASET ||--o{ DATASET_VERSION : versions
  PHASE ||--o{ SUBMISSION : accepts
  DATASET_VERSION ||--o{ SUBMISSION : evaluated_on
  TEAM ||--o{ SUBMISSION : submits
  SUBMISSION ||--|| MODEL_ARTIFACT : contains
  SUBMISSION ||--o{ EVALUATION_JOB : schedules
  EVALUATION_JOB ||--|| EVALUATION_RESULT : produces
  EVALUATION_RESULT ||--o{ METRIC : reports
  SUBMISSION ||--o{ LEADERBOARD_ENTRY : ranks
  PHASE ||--o{ LEADERBOARD_ENTRY : groups
  TEAM ||--o{ LEADERBOARD_ENTRY : earns

  TEAM {
    uuid id PK
    string name
    string organization
    string status
    datetime created_at
  }
>>>>>>> Stashed changes

  USER {
    int id PK
    varchar fullname
    varchar email
    varchar password
    varchar phone
    timestamp created_at
  }

<<<<<<< Updated upstream
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
=======
  TEAM_MEMBER {
    uuid team_id FK
    uuid user_id FK
    string role
    datetime joined_at
  }

  PHASE {
    uuid id PK
    string name
    string description
    datetime start_at
    datetime end_at
    string status
  }

  DATASET {
    uuid id PK
    string name
    string description
    string modality
    datetime created_at
  }

  DATASET_VERSION {
    uuid id PK
    uuid dataset_id FK
    string version
    string checksum
    string storage_uri
    datetime created_at
  }

  SUBMISSION {
    uuid id PK
    uuid team_id FK
    uuid phase_id FK
    uuid dataset_version_id FK
    string status
    datetime created_at
  }

  MODEL_ARTIFACT {
    uuid id PK
    uuid submission_id FK
    string storage_uri
    string sha256
    string runtime
    datetime created_at
  }

  EVALUATION_JOB {
    uuid id PK
    uuid submission_id FK
    string status
    datetime queued_at
    datetime started_at
    datetime finished_at
  }

  EVALUATION_RESULT {
    uuid id PK
    uuid job_id FK
    decimal score
    jsonb metrics_json
    datetime created_at
  }

  METRIC {
    uuid id PK
    uuid result_id FK
    string name
    decimal value
  }

  LEADERBOARD_ENTRY {
    uuid id PK
    uuid phase_id FK
    uuid team_id FK
    uuid submission_id FK
    int rank
    decimal score
    datetime created_at
>>>>>>> Stashed changes
  }
```

## Notes

- Treat this as a living schema contract.
- Keep entity names aligned with actual table names in migrations.
- Add indexes and uniqueness rules in implementation notes as needed.

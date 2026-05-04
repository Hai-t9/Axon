---
sidebar_position: 1
---

# Architecture Overview

Axon is designed as a modular, scalable platform to handle end-to-end data-centric AI competition workflows. The architecture follows a **layered approach** with clear separation between client applications, API services, processing layers, and data persistence.

## Architecture Diagram

```mermaid
graph TB
    subgraph Client["Client Applications"]
        MA["📱 Mobile App"]
        WP["🌐 Web Portal"]
    end
    
    subgraph API["API & Orchestration Layer"]
        GW["API Gateway"]
        AUTH["Authentication & Authorization"]
        COMPETITION_API["Competition Service"]
        PHASE_API["Phase Service"]
        TEAMS_API["Teams Service"]
        DATA_API["Data Ingestion Service"]
        LABEL_API["Label Service"]
        CLEANER_API["Cleaner Service"]
        VALIDATION_API["Data Validation Service"]
        MODELS_API["Model Submission Service"]
        EVAL_API["Evaluation Orchestration Service"]
        LEADERBOARD_API["Leaderboard Service"]
    end
    
    subgraph Processing["Processing & Evaluation Layer"]
        VALIDATOR["Data Validator & Label Manager"]
        QUEUE["Task Queue/Message Broker"]
        WORKERS["Evaluation Workers"]
        EXECUTOR["Model Executor"]
    end
    
    subgraph Data["Data & Storage Layer"]
        DB["Primary Database"]
        IMAGES["Image Storage"]
        MODELS["Model Storage"]
        CACHE["Cache Layer"]
    end
    
    MA -->|Image Upload| GW
    WP -->|Model Submit| GW
    GW -->|Route Requests| AUTH
    AUTH -->|Validated| COMPETITION_API & PHASE_API & TEAMS_API & DATA_API & LABEL_API & CLEANER_API & MODELS_API & EVAL_API & LEADERBOARD_API & VALIDATION_API
    
    DATA_API -->|Store Images| IMAGES
    DATA_API -->|Queue for Review| VALIDATION_API
    
    VALIDATION_API -->|Display to Team| WP
    VALIDATION_API -->|Manage Labels| LABEL_API
    LABEL_API -->|Store Labels| DB
    
    CLEANER_API -->|Analyze & Clean| IMAGES
    CLEANER_API -->|Update Metadata| DB
    
    MODELS_API -->|Store Models| MODELS
    MODELS_API -->|Schedule| QUEUE
    
    QUEUE -->|Dispatch Tasks| WORKERS
    WORKERS -->|Retrieve Data| IMAGES
    WORKERS -->|Load Model| MODELS
    WORKERS -->|Execute| EXECUTOR
    EXECUTOR -->|Update Results| DB
    
    EVAL_API -->|Query Results| DB
    EVAL_API -->|Generate| LEADERBOARD_API
    
    LEADERBOARD_API -->|Fetch Rankings| WP
    LEADERBOARD_API -->|Cache| CACHE
    
    COMPETITION_API -->|Persist| DB
    PHASE_API -->|Persist| DB
    LABEL_API -->|Persist| DB
    CLEANER_API -->|Persist| DB
    TEAMS_API -->|Persist| DB
    EVAL_API -->|Persist| DB
    VALIDATOR -->|Validate Quality| DB
```

## System Components

### 1. **Client Layer**

#### Mobile Application
- **Purpose:** Field data collection from agricultural environments
- **Responsibilities:**
  - Capture images with device metadata (camera model, sensors)
  - Collect environmental metadata (GPS, timestamp, weather conditions)
  - Automatic metadata pre-filling to ensure data quality
  - Direct upload to backend with offline queueing support
- **Technologies:** Cross-platform (iOS/Android)
- **API Interactions:** Image upload endpoint, metadata validation, progress tracking

#### Web Portal
- **Purpose:** Model submission and competition management interface
- **Responsibilities:**
  - Team registration and profile management
  - Model file upload
  - Real-time leaderboard visualization
  - Cross-team validation protocol selection
  - Data validation interface for teams
  - Administrative dashboards for hosts and staff
- **Technologies:** React/TypeScript frontend
- **API Interactions:** Model submission, leaderboard queries, team management, data validation

### 2. **API & Orchestration Layer**

#### API Gateway
- **Purpose:** Single entry point for all client requests
- **Responsibilities:**
  - Request routing to appropriate services
  - Rate limiting and throttling
  - Request/response logging and monitoring
  - CORS handling
- **Protocol:** REST/GraphQL

#### Authentication & Authorization Service
- **Purpose:** Secure access control
- **Responsibilities:**
  - User authentication (JWT/OAuth)
  - Role-based access control (RBAC): Hosts, Staff, Participants
  - Token management and refresh
  - Audit logging for security events
- **Roles:**
  - **Hosts (Organizers):** Full platform configuration and competition management
  - **Staff:** Data quality monitoring, team approvals, moderation
  - **Participants:** Data submission and model management

#### Competition Service
- **Purpose:** Manage competition lifecycle and configuration
- **Responsibilities:**
  - Create and configure competitions
  - Manage competition protocols and parameters
  - Update and delete competitions
  - Store competition metadata and configuration
- **Access Control:** Host role only for create, update, delete operations
- **Data Model:** Competitions, competition configuration

#### Phase Service
- **Purpose:** Manage competition phase lifecycle and transitions
- **Responsibilities:**
  - Track current competition phase (creation → active → evaluation → complete)
  - Handle automatic and manual phase transitions
  - Adjust phase deadlines as needed
  - Configure transition mode (automatic or manual)
  - Maintain immutable audit logs of all phase changes
  - Support manual phase overrides with documented reasons
  - Handle backward transitions when needed
- **Access Control:** Host role only for phase transitions and deadline adjustments
- **Data Model:** Phases, phase transition config, phase audit logs

#### Teams Service
- **Purpose:** Manage competition participants
- **Responsibilities:**
  - Team registration and profile management
  - Member management within teams
  - Team metadata storage (organization, contact info, etc.)
  - Participation tracking across competition seasons
- **Data Model:** Teams, team members, team metadata

#### Data Ingestion Service
- **Purpose:** Manage field image data collection
- **Responsibilities:**
  - Receive image uploads from mobile app
  - Validate metadata completeness and format
  - Store images in distributed file storage
  - Track image lineage and versioning
  - Ensure standardized format and resolution
  - Queue images for team validation
- **Validation Rules:**
  - Device information completeness (no metadata loss)
  - Image format standardization (JPEG/PNG)
  - Resolution requirements
  - Timestamp consistency

#### Label Service
- **Purpose:** Manage image labels throughout competition lifecycle
- **Responsibilities:**
  - Create initial (unvalidated) labels for images
  - Retrieve label information by image
  - Update labels (called by teams and Validation module)
  - Validate labels (restrict to staff/host)
  - Track label validation status and history
  - Support label corrections and feedback
  - Ensure label-image integrity
- **Access Control:** 
  - All authenticated users can create/read/update labels
  - Staff and hosts only can validate labels
- **Integration:** Called by Data Validation Service and Validation module
- **Data Model:** Labels, label validation status, label history

#### Cleaner Service
- **Purpose:** Maintain dataset integrity through automated cleaning and deduplication
- **Responsibilities:**
  - Detect and remove duplicate images (via hash comparison)
  - Identify and flag corrupted files
  - Normalize image formats and sizes
  - Sanitize metadata (remove sensitive information)
  - Enforce dataset quality rules (missing labels, invalid formats, imbalance)
  - Optimize storage (compression, removal of unused files)
  - Generate cleaning reports and statistics
  - Rebuild affected datasets after cleaning operations
- **Access Control:** Host and staff roles only
- **Operation Levels:** Competition-wide and team-level cleaning
- **Integration:** Works with Image module, updates database metadata
- **Data Model:** Cleaning jobs, duplicate groups, cleaning reports

#### Data Validation Service
- **Purpose:** Enable teams to review and correct image labels
- **Responsibilities:**
  - Display collected images to respective teams with initial labels
  - Provide intuitive UI for label review and correction
  - Coordinate voting workflow for label finalization
  - Ensure validation deadlines are respected
  - Generate validation completion reports
  - Call Label Service to persist label updates
- **Workflow:**
  - System automatically assigns images to collecting team
  - Team reviews images and associated labels
  - Team confirms label accuracy or provides corrections
  - Delegates to Label Service for label updates
  - Validates and locks finalized labels for evaluation phase
  - Staff monitors validation completion rates
- **Integration:** Calls Label Service for all label CRUD operations
- **Output:** Validated, human-reviewed dataset ready for model evaluation

#### Model Submission Service
- **Purpose:** Handle participant model submissions
- **Responsibilities:**
  - Receive model files from teams
  - Validate model format and structure
  - Store model versions
  - Track submission timestamps and versioning
  - Schedule model for evaluation
- **Supported Formats:** Standard model files compatible with evaluation framework

#### Evaluation Orchestration Service
- **Purpose:** Coordinate model evaluation across multiple protocols
- **Responsibilities:**
  - Schedule evaluations based on protocol type (LOTO, TOTO, standard fold)
  - Distribute evaluation tasks to worker queue
  - Track evaluation progress and status
  - Aggregate results from multiple evaluation runs
  - Handle failed evaluations with retry logic
- **Protocols:**
  - **Standard K-Fold:** Train on k-1 folds, test on fold k
  - **LOTO (Leave-One-Team-Out):** Generalization across teams (test on unseen team domain)
  - **TOTO (Train-On-One-Team-Only):** Assess single team's data collection strategy

#### Leaderboard Service
- **Purpose:** Rank teams based on evaluation results
- **Responsibilities:**
  - Calculate team rankings from evaluation results
  - Handle tie-breaking logic
  - Maintain historical snapshots of leaderboards
  - Provide real-time updates to web portal
  - Cache leaderboard data for performance
  - Support multi-protocol leaderboard views

### 3. **Processing & Evaluation Layer**

#### Task Queue / Message Broker
- **Purpose:** Decouple request processing from long-running evaluation tasks
- **Responsibilities:**
  - Accept evaluation jobs from orchestration service
  - Ensure reliable task delivery and retry logic
  - Load-balance tasks across worker pool
  - Maintain job status and history
- **Technology:** RabbitMQ, Apache Kafka, or AWS SQS
- **Rationale:** Prevents UI blocking during computationally expensive model evaluations

#### Evaluation Workers
- **Purpose:** Execute model evaluations in parallel
- **Responsibilities:**
  - Consume evaluation tasks from queue
  - Fetch model and dataset for evaluation
  - Execute model inference on assigned fold
  - Collect prediction results and metrics
  - Handle GPU/resource management
  - Report results back to database
- **Scalability:** Horizontally scalable worker pool based on queue depth
- **Resource Allocation:** GPU cluster, compute optimized instances

#### Data Validator & Label Manager
- **Purpose:** Manage data quality and team label validations
- **Responsibilities:**
  - Pre-process images before evaluation
  - Check image format and integrity
  - Verify file structure before processing
  - Manage label validation workflows
  - Track which labels have been validated by teams
  - Generate data quality reports
  - Flag inconsistencies for manual review

#### Model Executor
- **Purpose:** Execute model inference safely and efficiently
- **Responsibilities:**
  - Load model from storage
  - Prepare input data in correct format
  - Execute inference with specified hardware (CPU/GPU)
  - Capture predictions and confidence scores
  - Handle timeout and resource constraints
  - Log execution details for debugging

### 4. **Data & Storage Layer**

#### Primary Database
- **Purpose:** Store structured data and metadata
- **Core Entities:**
  - **Teams:** Competition participants (team_id, organization, metadata)
  - **Images:** Field images with metadata (image_id, team_id, device_info, resolution, storage_path)
  - **Models:** Participant submissions (model_id, team_id, framework, version, submission_date)
  - **Evaluations:** Model performance records (evaluation_id, model_id, dataset_fold, protocol_type, accuracy, timestamp)
  - **Leaderboards:** Real-time rankings (leaderboard_id, evaluation_fold, team_rankings, updated_at)
- **Technology:** PostgreSQL or similar RDBMS
- **Relationships:**
  ```
  Teams (1) ──→ (N) Images
  Teams (1) ──→ (N) Models
  Models (1) ──→ (N) Evaluations
  Evaluations → Leaderboards
  ```

#### Image Storage
- **Purpose:** Distributed storage for field images
- **Characteristics:**
  - High volume, immutable data
  - Access pattern: Write-once, read-many
  - Organize by team_id and timestamp for retrieval optimization
  - Support versioning and archival
- **Technology:** Object storage (AWS S3, Azure Blob, Google Cloud Storage)

#### Model Storage
- **Purpose:** Store submitted model files
- **Characteristics:**
  - Version control for each model submission
  - Enable model lineage tracking
  - Immutable storage for evaluation reproducibility
- **Technology:** Object storage with versioning enabled

#### Cache Layer
- **Purpose:** Reduce database load for frequently accessed data
- **Cached Data:**
  - Leaderboard snapshots
  - Team profile information
  - Evaluation metadata
  - Authentication tokens
- **Technology:** Redis or similar in-memory store
- **TTL:** Strategy depends on data freshness requirements

## Data Flow

### 1. **Image Collection & Ingestion Flow**
```
Participant (Field)
    ↓
Mobile App (Capture: image + device metadata)
    ↓
API Gateway (Authentication)
    ↓
Data Ingestion Service
    ├→ Validate metadata completeness
    ├→ Standardize format/resolution
    ↓
Image Storage (S3/Blob)
    ↓
Primary Database (Record metadata + storage path)
    ↓
Data Validation Service (Queue for team review)
```

### 2. **Data Validation & Label Correction Flow**
```
Data Validation Service
    ↓
Display to Team via Web Portal
    ├→ Show image + initial label
    ↓
Team Reviews & Corrects Labels
    ├→ Confirms label OR modifies it
    ↓
Store Validated Labels in Database
    ├→ Mark as validated
    ├→ Track corrections made
    ↓
Validated Dataset Ready for Evaluation
```

### 3. **Model Submission & Evaluation Flow**
```
Participant (Web Portal)
    ↓
Submit Model File + Metadata
    ↓
API Gateway (Authentication)
    ↓
Model Submission Service
    ├→ Validate model format
    ├→ Extract dependencies
    ↓
Model Storage (Versioned)
    ↓
Primary Database (Track submission)
    ↓
Evaluation Orchestration Service
    ├→ Determine evaluation protocol (LOTO/TOTO/K-Fold)
    ├→ Create evaluation tasks
    ↓
Task Queue (Message Broker)
    ↓
Evaluation Workers (Parallel execution)
    ├→ Load model from storage
    ├→ Fetch dataset fold
    ├→ Execute inference
    ├→ Collect metrics
    ↓
Primary Database (Store results)
    ↓
Leaderboard Service
    ├→ Calculate rankings
    ├→ Update cache
    ↓
Web Portal (Real-time update)
```

### 3. **Leaderboard Update Flow**
```
Evaluation Results Stored
    ↓
Leaderboard Service
    ├→ Query all team results
    ├→ Calculate rankings (by accuracy)
    ├→ Apply tie-breaking rules
    ├→ Generate historical snapshot
    ↓
Cache Layer (Redis)
    ↓
Web Portal (Fetch and display)
    ↓
Participants View Live Rankings
```

## Tech Stack Decisions

### Backend API Framework
- **Choice:** Node.js/Express or Python/FastAPI
- **Rationale:**
  - Type safety with TypeScript
  - Strong ecosystem for REST APIs
  - Good integration with evaluation workers
  - Horizontal scalability via containerization

### Message Queue / Broker
- **Choice:** RabbitMQ or Apache Kafka
- **Rationale:**
  - Decouple long-running evaluations from API requests
  - Enable horizontal scaling of workers
  - Reliable job persistence
  - Priority queuing for urgent evaluations

### Evaluation Environment
- **Choice:** Docker containers for model execution
- **Rationale:**
  - Isolate model execution environments
  - Version control of dependencies
  - Support multiple frameworks (PyTorch, TensorFlow)
  - GPU support via docker-compose/Kubernetes

### Database
- **Choice:** PostgreSQL for primary data
- **Rationale:**
  - ACID compliance for consistency
  - Strong JSON support for flexible metadata
  - Full-text search for team/image discovery
  - Proven performance at scale

### Caching
- **Choice:** Redis for session and leaderboard caching
- **Rationale:**
  - Sub-millisecond read latency
  - Atomic operations for rankings
  - Pub/Sub for real-time updates
  - Easy horizontal scaling

### Object Storage
- **Choice:** S3-compatible (AWS S3, MinIO, Azure Blob)
- **Rationale:**
  - Infinite scalability for images
  - Versioning built-in
  - Cost-effective for large files
  - CDN integration for fast retrieval

### Deployment & Orchestration
- **Choice:** Kubernetes or Docker Swarm
- **Rationale:**
  - Manage multiple services (API, workers, etc.)
  - Auto-scaling based on queue depth
  - Rolling updates without downtime
  - Health checks and self-healing

## Key Architectural Principles

1. **Separation of Concerns:** Each service has a single, well-defined responsibility
2. **Scalability:** Stateless API services and horizontally scalable worker pool
3. **Reliability:** Message queue ensures no evaluation task is lost
4. **Data Quality First:** Validation at ingestion point, not downstream
5. **Asynchronous Processing:** UI-blocking operations handled via task queue
6. **Real-time Updates:** Cache layer and pub/sub for instant leaderboard updates
7. **Modularity:** Services can be developed, deployed, and scaled independently

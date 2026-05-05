# Day 1 Progress Report & Next Steps

## 1. What was done so far
- **Project Structure setup:** We successfully created the architectural foundation for the FastAPI application in the `backend/app` directory. 
- **Module Implementation:** The initial skeleton and basic logic for multiple core modules were laid down. Specifically, for the **Cleaner module**, we've structured:
  - `schemas/cleaner.py`: Pydantic models for validation (Response models for cleaner runs, scans, and storage optimization).
  - `services/cleaner/repository.py`: SQLAlchemy methods for fetching, checking duplicates, finding corrupted labels, and doing bulk updates/deletions.
  - `services/cleaner/service.py`: Business logic and orchestration for the cleanup pipeline.
  - `services/cleaner/controller.py`: FastAPI endpoints/routes built out to execute tasks for cleaning.
- Similar foundational setups are present for **image** and **auth** modules.

## 2. Current Task Status 🚧 
- **Database & Models:** Models are partially defined (`models/image.py`).
- **Endpoints:** The controllers are structured, but mock out actual actions, particularly in `CleanDatasetResponse` and `scan_for_duplicates`. Actual logic parsing real images needs further refinement.
- **Entry point:** We currently have the underlying code logic laid out, but lack the central `main.py` to bootstrap the FastAPI instance and include the routers we built.

## 3. Next Tasks (In Detail) 🚀

### Task 1: Complete the Core FastAPI App Initialization (`main.py`)
- We need a `main.py` file to act as the central entry point.
- **Details:** 
  - Initialize the `FastAPI()` app.
  - Configure CORS middleware.
  - Wire up the database connection module (using `core/database.py` or similar).
  - Use `app.include_router()` to register the `cleaner` router (from `backend.app.services.cleaner.controller`) and other modules.

### Task 2: Mock Database Seeding for Local Testing
- Before being able to test the API properly, we'll need test data!
- **Details:**
  - Create a script that creates dummy records in the `Image` and `ImageMetadata` tables.
  - Make sure some images duplicate the same hash or have missing values (corrupted/0 bytes) to actually test the `run_cleaning_pipeline` endpoint's effects.

### Task 3: Flesh out Service Business Logic & Remove Mocks
- Replace the mocked methods in `services/cleaner/service.py`.
- **Details:**
  - Add logic in `get_duplicate_candidates()` to group images logically.
  - Replace dummy mock values like `{"freed_mb": 15.5, "files_removed": 5}` in `optimize_storage()` with actual database logic and storage queries. 
  - Wire up the controller's `/teams/{team_id}/cleaner/clean` route so it runs the actual service logic instead of directly returning a mocked dictionary.

### Task 4: Introduce Background Tasks / Workers (Celery)
- Since scanning and cleaning image repositories can take time, the endpoints shouldn't block.
- **Details:**
  - Route the heavy service methods into the `workers/` directory to run asynchronously (e.g. leveraging Celery + Redis). Ensure endpoints only dispatch a job and return a job ID to the client.

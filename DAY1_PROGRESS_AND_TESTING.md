# Day 1 Progress Summary - Image & Cleaner Modules

## What You Did So Far
- **Framework Migration**: Successfully transitioned the Node.js/Prisma backend architecture entirely to **Python, FastAPI, and SQLAlchemy**.
- **Model Refactoring**: Re-mapped all the database tables leveraging Pydantic schemas and SQLAlchemy models, ensuring exact 1:1 parity with the initial DBML specification.
- **Repository Pattern Implementation**: Set up the database data-access layer (`repository.py`) which acts as the intermediary executing exact logic such as fetching and writing data for images and cleaner tasks.
- **Service Layer Transformation**: Rewrote the business logic functions (`service.py`) for handling image hashing (deduplication) and metadata.
- **API Mapping**: Wired FastAPI routers (`controller.py`) mirroring the old Node.js endpoints strictly per the team contracts.
- **Metadata Extraction Hookup**: Installed and implemented `Pillow` and `exifread` for real device/camera hardware extraction on raw binary blobs, gracefully falling back to basic dimensions calculation for uploaded screenshots.
- **Import Error Resolutions**: Realigned absolute path modules starting with `backend.app...` into correct local `app...` imports ensuring the Uvicorn local server bootups smoothly. Wait, actually we also appended both routers in `main.py`!

## How Are Your Tasks Going?
You are perfectly on track! You completed your core logic conversion. The backend runs without raising circular `ModuleNotFoundError` errors, and the image deduplication alongside pixel width/height metadata extraction executes reliably via raw bytes.

## Next Tasks Details (Day 2 Focus)
Now that your core domain is functioning under Python, you should transition into implementing the Cleaner System flow and file management pipelines:
1. **Develop the Clean Processing Pipeline**: Connect actual image processing behaviors via `Pillow` (to replace the Javascript `sharp` package). E.g. Downscaling oversized images based on the thresholds defined in `cleaner.py`.
2. **Setup Background Queue Workers (Celery/Redis)**: Long-running cleaner tasks should not block the FastAPI thread. Look into establishing background task queues via Celery or FastAPI `BackgroundTasks`.
3. **Storage Strategy (MinIO/S3)**: Currently images accumulate physically in the `uploads/` dir. Plan out mapping a python `boto3` integration with the `infra/minio` bucket containers since saving locally won't scale across pods.
4. **Integration Testing**: Perform robust unit and E2E integration tests connecting Postman directly to the local dev db SQL setup to trace cleaner status updates.

---

## Guide: How to Test via Postman

Now that everything is mapped properly under the FastAPI domain, execute testing with your server up and running.

**Start the Local Server**:
Ensure you are in the `backend` folder containing `main.py`, then run Server via:
```sh
cd backend
uvicorn app.main:app --reload
```

### 1. Test the Upload Endpoint (Image Module)
- **Method**: `POST`
- **URL**: `http://127.0.0.1:8000/teams/1/images` (Assuming prefix `/teams/{team_id}/images`) *Check your exact configured prefix based on the main route includes*.
- **Body**: Select `form-data`
  - **Key**: `file` | **Type**: `File` | **Value**: *Attach a `.jpg` or `.png` file*
  - **Key**: `label` | **Type**: `Text` | **Value**: `Oak`
  - **Key**: `user_id` | **Type**: `Text` | **Value**: `123`

**Expected Outcome**: 
A JSON object returns the DB created payload exactly matching the DBML: e.g., properly parsed `old_width`, `old_height`, extracted hardware metadata `device`, `original_filename` alongside the assigned generated server path.

### 2. Test Fetching Images (Image Module)
- **Method**: `GET`
- **URL**: `http://127.0.0.1:8000/images/1` (Assuming ID = 1)
**Expected Outcome**: 
Return a dictionary of the DB metadata saved from the upload.

### 3. Test the Cleaner Trigger (Cleaner Module)
- **Method**: `POST`
- **URL**: `http://127.0.0.1:8000/cleaner/run`
- **Body**: `raw` -> `JSON`
```json
{
  "comp_id": 1,
  "config": {
    "blur_threshold": 0.5
  }
}
```
**Expected Outcome**: 
Returns a `CleanerResponse` indicating the pipeline started or queued, generating a new run tracking ID.


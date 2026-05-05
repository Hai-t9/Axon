# External Storage Abstraction Layer

## Overview
The `storage/` folder provides an abstraction layer for MinIO (S3-compatible object storage). This allows you to store images, models, and other large files outside the database.

## Purpose

- ✅ Upload and manage image files
- ✅ Store ML model files
- ✅ Retrieve files by key/path
- ✅ Delete files when needed
- ✅ Generate signed URLs for direct download
- ✅ Easy to swap storage providers later (AWS S3, GCS, etc.)

## Architecture

```
storage/
├── __init__.py
├── minio_client.py       # MinIO connection & configuration
├── image_store.py        # Image upload/download operations
└── model_store.py        # ML model file operations
```

## Files & Responsibilities

### **minio_client.py**
**Purpose:** MinIO connection and low-level operations

**Responsibilities:**
- Connect to MinIO server
- Create buckets if they don't exist
- Upload files to buckets
- Download files from buckets
- Delete files
- Generate signed URLs

**Example:**
```python
class MinIOClient:
    def __init__(self, endpoint, access_key, secret_key):
        self.client = Minio(endpoint, access_key, secret_key)
    
    def upload_file(self, bucket, file_path, file_data):
        self.client.put_object(bucket, file_path, file_data)
    
    def download_file(self, bucket, file_path):
        return self.client.get_object(bucket, file_path)
```

---

### **image_store.py**
**Purpose:** High-level image operations

**Responsibilities:**
- Upload images with validation
- Resize/compress images
- Generate thumbnails
- Get image URL
- Delete images by ID

**Used by:** Data ingestion service

**Example:**
```python
class ImageStore:
    def upload_image(self, dataset_id: int, image_file, metadata):
        # Validate file is an image
        # Compress if needed
        # Generate thumbnail
        # Store in MinIO
        # Return image_id & URL
        pass
    
    def get_image_url(self, image_id: int) -> str:
        # Generate signed URL that expires in 1 hour
        pass
```

---

### **model_store.py**
**Purpose:** High-level ML model file operations

**Responsibilities:**
- Upload model files with validation
- Version model files
- Get model download URL
- Delete old model versions
- Store model metadata

**Used by:** Model submission service

**Example:**
```python
class ModelStore:
    def upload_model(self, submission_id: int, model_file, metadata):
        # Validate file is PyTorch/.pkl
        # Store model file
        # Store with version number
        # Return model_id & size
        pass
    
    def get_model_download_url(self, model_id: int) -> str:
        # Generate signed URL
        pass
```

---

## File Organization & Naming

### **Images**
```
competitions/
├── {competition_id}/
    ├── datasets/
        ├── {dataset_id}/
            ├── {image_id}.jpg
            ├── {image_id}.png
            └── {image_id}_thumbnail.jpg
```

### **Models**
```
competitions/
├── {competition_id}/
    ├── submissions/
        ├── {submission_id}/
            ├── model_v1.pkl
            ├── model_v2.pkl
            └── metadata.json
```

## How Storage Is Used

### **In Data Ingestion Service**
```python
# services/data_ingestion/service.py
from storage.image_store import ImageStore

class DataIngestionService:
    def __init__(self, image_store: ImageStore):
        self.image_store = image_store
    
    def ingest_dataset(self, dataset_id: int, images: List):
        for image_file in images:
            image_id = self.image_store.upload_image(dataset_id, image_file)
            # Save image_id to database
```

### **In Model Submission Service**
```python
# services/model_submission/service.py
from storage.model_store import ModelStore

class ModelSubmissionService:
    def __init__(self, model_store: ModelStore):
        self.model_store = model_store
    
    def submit_model(self, submission_id: int, model_file):
        model_id = self.model_store.upload_model(submission_id, model_file)
        # Save model_id to database
```

### **In Evaluation Service**
```python
# services/evaluation/service.py
from storage.model_store import ModelStore

class EvaluationService:
    def __init__(self, model_store: ModelStore):
        self.model_store = model_store
    
    def evaluate_model(self, submission_id: int):
        # Get model download URL
        model_url = self.model_store.get_model_download_url(submission_id)
        
        # Pass to worker for evaluation
        # Worker downloads and executes model
```

## MinIO Configuration

MinIO is configured with environment variables:

```env
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=false  # true in production
```

Buckets created automatically:
- `competitions` - Main storage bucket
- `cache` - Temporary files, thumbnails

## Key Features

### **File Upload with Validation**
```python
def upload_image(self, image_file):
    # Check file size < 50MB
    # Check file type (jpg, png, etc.)
    # Compress if needed
    # Upload to MinIO
```

### **Signed URLs**
```python
def get_download_url(self, image_id: str, expires_in=3600):
    # Generate URL that expires in 1 hour
    # Client can download without authentication
    # Great for serving images to frontend
```

### **Versioning**
```python
def upload_model(self, submission_id, model_file):
    # Get current version number
    # Upload as model_v{version}.pkl
    # Keep all versions for rollback
```

## Best Practices

- ✅ Always validate file type & size before upload
- ✅ Use signed URLs for time-limited access
- ✅ Keep versioning for model submissions
- ✅ Clean up old files periodically
- ✅ Organize by competition/dataset/submission for easy retrieval
- ✅ Store metadata (file size, upload date) in database

## Error Handling

```python
try:
    image_url = image_store.upload_image(image_file)
except FileTooLargeError:
    raise HTTPException(status_code=413, detail="File too large")
except InvalidFileTypeError:
    raise HTTPException(status_code=400, detail="Invalid file type")
except MinIOConnectionError:
    raise HTTPException(status_code=503, detail="Storage service unavailable")
```

## Database vs Storage

**Database stores:** Metadata (file name, size, upload date, user_id)
**MinIO stores:** Actual file data (images, models)

```python
# Database: image table
{
    id: 1,
    dataset_id: 42,
    filename: "photo.jpg",
    size: 2048576,
    minio_key: "competitions/1/datasets/42/1.jpg",
    upload_date: "2024-01-15"
}

# MinIO: actual image file at that key
competitions/1/datasets/42/1.jpg → [binary image data]
```

## Adding New Storage Types

Need to store PDFs or docs? Create new file:

```python
# storage/document_store.py
class DocumentStore:
    def upload_document(self, competition_id, doc_file):
        # Similar pattern
        pass
```

Then use in relevant service.

Storage Layer = Abstraction for Large Files 📁

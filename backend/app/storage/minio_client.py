import boto3
import os
from botocore.exceptions import ClientError
from botocore.config import Config
from io import BytesIO

class MinioStorageService:
    def __init__(self):
        # Development mode: If endpoint is empty, use local fallback
        self.endpoint = os.environ.get("MINIO_ENDPOINT", "")
        self.access_key = os.environ.get("MINIO_ACCESS_KEY", "")
        self.secret_key = os.environ.get("MINIO_SECRET_KEY", "")
        self.bucket_name = os.environ.get("MINIO_BUCKET_NAME", "axon-uploads")
        
        # Check if we're in development mode (empty endpoint = use local storage)
        self.development_mode = not self.endpoint
        self.minio_available = False
        self.s3_client = None
        
        if not self.development_mode:
            # Production mode: Try to connect to MinIO
            try:
                # Configure boto3 to fail fast instead of retrying multiple times
                boto_config = Config(connect_timeout=2, read_timeout=2, retries={'max_attempts': 0})
                self.s3_client = boto3.client(
                    's3',
                    endpoint_url=self.endpoint,
                    aws_access_key_id=self.access_key,
                    aws_secret_access_key=self.secret_key,
                    config=boto_config
                )
                self._ensure_bucket()
                self.minio_available = True
                print("✅ MinIO connected successfully")
            except Exception as e:
                print(f"⚠️  MinIO connection failed: {e}. Using local fallback.")
                self.minio_available = False
        else:
            print("📁 Development mode: Using local file storage fallback")

    def _ensure_bucket(self):
        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
        except ClientError:
            try:
                self.s3_client.create_bucket(Bucket=self.bucket_name)
            except Exception:
                pass  # Probably already created or permissions issue
        except Exception:
            self.minio_available = False  # Endpoint unreachable

    def upload_file(self, file_content: bytes, object_name: str) -> str:
        if self.minio_available and self.s3_client:
            try:
                self.s3_client.upload_fileobj(
                    BytesIO(file_content),
                    self.bucket_name,
                    object_name
                )
                return object_name
            except Exception as e:
                print(f"⚠️  MinIO upload failed: {e}. Falling back to local storage.")
                self.minio_available = False

        # Fallback to local storage if MinIO is unavailable
        upload_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads")
        os.makedirs(upload_dir, exist_ok=True)
        local_path = os.path.join(upload_dir, os.path.basename(object_name))
        with open(local_path, "wb") as f:
            f.write(file_content)
        return object_name

    def get_file(self, object_name: str) -> bytes:
        if self.minio_available and self.s3_client:
            try:
                response = self.s3_client.get_object(Bucket=self.bucket_name, Key=object_name)
                return response['Body'].read()
            except Exception:
                self.minio_available = False

        # Fallback local retrieval
        upload_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads")
        local_path = os.path.join(upload_dir, os.path.basename(object_name))
        try:
            with open(local_path, "rb") as f:
                return f.read()
        except FileNotFoundError:
            return b""

    def delete_file(self, object_name: str) -> bool:
        if self.minio_available and self.s3_client:
            try:
                self.s3_client.delete_object(Bucket=self.bucket_name, Key=object_name)
                return True
            except ClientError:
                return False
        
        # Fallback local deletion
        upload_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads")
        local_path = os.path.join(upload_dir, os.path.basename(object_name))
        try:
            if os.path.exists(local_path):
                os.remove(local_path)
            return True
        except Exception:
            return False

storage_service = MinioStorageService()

import boto3
import os
from botocore.exceptions import ClientError
from botocore.config import Config
from io import BytesIO

class MinioStorageService:
    def __init__(self):
        self.endpoint = os.environ.get("MINIO_ENDPOINT", "")
        self.access_key = os.environ.get("MINIO_ACCESS_KEY", "")
        self.secret_key = os.environ.get("MINIO_SECRET_KEY", "")
        self.bucket_name = os.environ.get("MINIO_BUCKET_NAME", "axon-uploads")
        
        self.minio_available = bool(self.endpoint)
        self.s3_client = None

        if self.minio_available:
            # Configure boto3 to fail fast instead of retrying multiple times
            boto_config = Config(connect_timeout=2, read_timeout=2, retries={'max_attempts': 0})

            try:
                self.s3_client = boto3.client(
                    's3',
                    endpoint_url=self.endpoint,
                    aws_access_key_id=self.access_key,
                    aws_secret_access_key=self.secret_key,
                    config=boto_config
                )
                self._ensure_bucket()
            except Exception:
                self.minio_available = False

    def _ensure_bucket(self):
        if not self.s3_client: return
        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
        except ClientError:
            try:
                self.s3_client.create_bucket(Bucket=self.bucket_name)
            except Exception:
                pass # Probably already created or permissions issue
        except Exception:
            self.minio_available = False # Endpoint unreachable

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
                self.minio_available = False # Mark unavailable for future requests

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
                pass
        
        # Fallback local delete
        upload_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads")
        local_path = os.path.join(upload_dir, os.path.basename(object_name))
        try:
            if os.path.exists(local_path):
                os.remove(local_path)
                return True
        except OSError:
            return False
        return False

storage_service = MinioStorageService()

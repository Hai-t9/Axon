import os
import shutil
from io import BytesIO
from pathlib import Path


def _resolve_upload_dir() -> str:
    return str(
        Path(__file__).resolve().parent.parent.parent / "uploads"
    )


class MinioStorageService:
    def __init__(self):
        raw_endpoint = os.environ.get("MINIO_ENDPOINT", "")

        self.bucket_name = os.getenv("MINIO_BUCKET_NAME", "axon-uploads")
        self.minio_available = False
        self.s3_client = None

        if raw_endpoint and raw_endpoint.strip():
            import boto3
            from botocore.config import Config
            from botocore.exceptions import ClientError

            self.endpoint = raw_endpoint.strip()
            self.access_key = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
            self.secret_key = os.getenv("MINIO_SECRET_KEY", "minioadmin")
            self.minio_available = True

            boto_config = Config(
                connect_timeout=2, read_timeout=2, retries={"max_attempts": 0}
            )
            self.s3_client = boto3.client(
                "s3",
                endpoint_url=self.endpoint,
                aws_access_key_id=self.access_key,
                aws_secret_access_key=self.secret_key,
                region_name=os.getenv("S3_REGION", "us-east-1"),
                config=boto_config,
            )
            self._ensure_bucket()

    def _ensure_bucket(self):
        from botocore.exceptions import ClientError

        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
        except ClientError:
            try:
                self.s3_client.create_bucket(Bucket=self.bucket_name)
            except Exception:
                pass
        except Exception:
            self.minio_available = False

    def _local_path(self, object_name: str) -> str:
        return os.path.join(_resolve_upload_dir(), object_name)

    def upload_file(self, file_content: bytes, object_name: str) -> str:
        if self.minio_available:
            try:
                self.s3_client.upload_fileobj(
                    BytesIO(file_content), self.bucket_name, object_name
                )
                return object_name
            except Exception:
                self.minio_available = False

        local_path = self._local_path(object_name)
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        with open(local_path, "wb") as f:
            f.write(file_content)
        return object_name

    def get_file(self, object_name: str) -> bytes:
        if self.minio_available:
            try:
                response = self.s3_client.get_object(
                    Bucket=self.bucket_name, Key=object_name
                )
                return response["Body"].read()
            except Exception:
                self.minio_available = False

        local_path = self._local_path(object_name)
        try:
            with open(local_path, "rb") as f:
                return f.read()
        except FileNotFoundError:
            return b""

    def delete_file(self, object_name: str) -> bool:
        if self.minio_available:
            try:
                self.s3_client.delete_object(Bucket=self.bucket_name, Key=object_name)
                return True
            except Exception:
                self.minio_available = False

        local_path = self._local_path(object_name)
        try:
            os.remove(local_path)
            return True
        except FileNotFoundError:
            return False

    def copy_file(self, source_key: str, dest_key: str) -> bool:
        if self.minio_available:
            try:
                self.s3_client.copy_object(
                    Bucket=self.bucket_name,
                    CopySource={"Bucket": self.bucket_name, "Key": source_key},
                    Key=dest_key,
                )
                return True
            except Exception:
                self.minio_available = False

        src = self._local_path(source_key)
        dst = self._local_path(dest_key)
        try:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            return True
        except FileNotFoundError:
            return False


storage_service = MinioStorageService()

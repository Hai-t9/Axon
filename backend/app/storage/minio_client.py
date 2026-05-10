import logging
import os
import shutil
from io import BytesIO
from pathlib import Path

logger = logging.getLogger("storage")


def _resolve_upload_dir() -> str:
    return str(
        Path(__file__).resolve().parent.parent.parent / "uploads"
    )


class MinioStorageService:
    def __init__(self):
        raw_endpoint = os.environ.get("MINIO_ENDPOINT", "")

        self.bucket_name = os.getenv("MINIO_BUCKET_NAME", "axon-uploads")
        self.s3_client = None

        if raw_endpoint and raw_endpoint.strip():
            self._init_s3(raw_endpoint.strip())

    def _init_s3(self, endpoint: str):
        import boto3
        from botocore.config import Config

        self.endpoint = endpoint
        self.access_key = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
        self.secret_key = os.getenv("MINIO_SECRET_KEY", "minioadmin")

        boto_config = Config(
            connect_timeout=10,
            read_timeout=30,
            retries={"max_attempts": 3},
            s3={"addressing_style": "path"},
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
            logger.info("S3 bucket '%s' found", self.bucket_name)
        except ClientError as exc:
            logger.warning("S3 bucket '%s' not found (will try create): %s", self.bucket_name, exc)
            try:
                self.s3_client.create_bucket(Bucket=self.bucket_name)
                logger.info("S3 bucket '%s' created", self.bucket_name)
            except Exception as create_err:
                logger.error("Failed to create S3 bucket '%s': %s", self.bucket_name, create_err)
        except Exception as exc:
            logger.error("Failed to access S3: %s", exc)

    def _local_path(self, object_name: str) -> str:
        return os.path.join(_resolve_upload_dir(), object_name)

    def _s3_available(self) -> bool:
        return self.s3_client is not None

    def upload_file(self, file_content: bytes, object_name: str) -> str:
        if self._s3_available():
            try:
                self.s3_client.upload_fileobj(
                    BytesIO(file_content), self.bucket_name, object_name
                )
                logger.info("S3 upload succeeded: %s", object_name)
                return object_name
            except Exception as exc:
                logger.error("S3 upload failed, falling back to local: %s", exc)

        local_path = self._local_path(object_name)
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        with open(local_path, "wb") as f:
            f.write(file_content)
        return object_name

    def get_file(self, object_name: str) -> bytes:
        if self._s3_available():
            try:
                response = self.s3_client.get_object(
                    Bucket=self.bucket_name, Key=object_name
                )
                body = response["Body"].read()
                if body:
                    return body
                logger.warning("S3 returned empty body for %s, retrying once", object_name)
                response = self.s3_client.get_object(
                    Bucket=self.bucket_name, Key=object_name
                )
                body = response["Body"].read()
                if body:
                    return body
            except Exception as exc:
                logger.error("S3 get failed, falling back to local: %s", exc)

        local_path = self._local_path(object_name)
        try:
            body = open(local_path, "rb").read()
            if body:
                return body
        except FileNotFoundError:
            pass
        raise FileNotFoundError(
            f"Model zip not found at S3 key {object_name} "
            f"(local fallback {local_path} also missing or empty)"
        )

    def delete_file(self, object_name: str) -> bool:
        if self._s3_available():
            try:
                self.s3_client.delete_object(Bucket=self.bucket_name, Key=object_name)
                return True
            except Exception as exc:
                logger.error("S3 delete failed, falling back to local: %s", exc)

        local_path = self._local_path(object_name)
        try:
            os.remove(local_path)
            return True
        except FileNotFoundError:
            return False

    def copy_file(self, source_key: str, dest_key: str) -> bool:
        if self._s3_available():
            try:
                self.s3_client.copy_object(
                    Bucket=self.bucket_name,
                    CopySource={"Bucket": self.bucket_name, "Key": source_key},
                    Key=dest_key,
                )
                return True
            except Exception as exc:
                logger.error("S3 copy failed, falling back to local: %s", exc)

        src = self._local_path(source_key)
        dst = self._local_path(dest_key)
        try:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            return True
        except FileNotFoundError:
            return False


storage_service = MinioStorageService()

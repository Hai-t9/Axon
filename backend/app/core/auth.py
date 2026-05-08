import base64
import hashlib
import hmac
import json
import os
import time
from typing import Any, Dict, Optional
from uuid import UUID

from .exceptions import AuthenticationError

_SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret")
_DEFAULT_EXPIRES = int(os.getenv("ACCESS_TOKEN_EXPIRE_SECONDS", "3600"))


def _base64url_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def _base64url_decode(raw: str) -> bytes:
    padding = "=" * (-len(raw) % 4)
    return base64.urlsafe_b64decode(f"{raw}{padding}")


def _sign(message: bytes) -> str:
    signature = hmac.new(_SECRET_KEY.encode("utf-8"), message, hashlib.sha256).digest()
    return _base64url_encode(signature)


def _encode_jwt(payload: Dict[str, Any]) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    header_b64 = _base64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = _base64url_encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    )
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
    signature = _sign(signing_input)
    return f"{header_b64}.{payload_b64}.{signature}"


def _decode_jwt(token: str) -> Dict[str, Any]:
    parts = token.split(".")
    if len(parts) != 3:
        raise ValueError("Invalid token format")

    signing_input = f"{parts[0]}.{parts[1]}".encode("utf-8")
    expected_signature = _sign(signing_input)
    if not hmac.compare_digest(parts[2], expected_signature):
        raise ValueError("Invalid token signature")

    payload_raw = _base64url_decode(parts[1])
    return json.loads(payload_raw)


def create_access_token(user_id: Any, expires_in: Optional[int] = None) -> str:
    issued_at = int(time.time())
    expires_at = issued_at + (expires_in or _DEFAULT_EXPIRES)
    payload = {
        "sub": str(user_id),
        "iat": issued_at,
        "exp": expires_at,
    }
    return _encode_jwt(payload)


def verify_access_token(token: str) -> Optional[Any]:
    try:
        payload = _decode_jwt(token)
    except ValueError:
        return None

    if int(payload.get("exp", 0)) < int(time.time()):
        return None

    subject = payload.get("sub")
    if not subject:
        return None

    if isinstance(subject, int):
        return subject
    if isinstance(subject, str) and subject.isdigit():
        return int(subject)
    try:
        return UUID(str(subject))
    except (TypeError, ValueError):
        return None


def extract_bearer_token(authorization: str) -> str:
    if not authorization:
        raise AuthenticationError("Missing Authorization header")

    # Expected format: "Bearer <token>".
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise AuthenticationError("Invalid Authorization header")

    return token


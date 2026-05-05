import base64
import binascii
import hashlib
import hmac
import os

_HASH_PREFIX = "pbkdf2_sha256"
_ITERATIONS = 120000
_SALT_SIZE = 16


def hash_password(password: str) -> str:
    if not password:
        raise ValueError("Password must not be empty")

    salt = os.urandom(_SALT_SIZE)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, _ITERATIONS)
    salt_b64 = base64.b64encode(salt).decode("ascii")
    digest_b64 = base64.b64encode(digest).decode("ascii")

    # Store algorithm + iterations so we can verify later without extra config.
    return f"{_HASH_PREFIX}${_ITERATIONS}${salt_b64}${digest_b64}"


def verify_password(password: str, stored_hash: str) -> bool:
    if not password or not stored_hash:
        return False

    try:
        prefix, iterations_raw, salt_b64, digest_b64 = stored_hash.split("$", 3)
        if prefix != _HASH_PREFIX:
            return False
        iterations = int(iterations_raw)
    except ValueError:
        return False

    try:
        salt = base64.b64decode(salt_b64.encode("ascii"))
        expected = base64.b64decode(digest_b64.encode("ascii"))
    except (ValueError, binascii.Error):
        return False

    actual = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return hmac.compare_digest(actual, expected)


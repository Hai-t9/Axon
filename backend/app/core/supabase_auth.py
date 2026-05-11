import logging
import os
from typing import Optional

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

logger = logging.getLogger(__name__)

_supabase = None


def _is_placeholder(val: Optional[str]) -> bool:
    """Check if a value is still a placeholder (not yet configured)."""
    if not val:
        return True
    placeholders = ["your-project.supabase.co", "your-service-role-key", "your-anon-key"]
    return any(p in val for p in placeholders)


def get_supabase_admin():
    global _supabase
    if _supabase is None:
        if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
            return None
        if _is_placeholder(SUPABASE_URL) or _is_placeholder(SUPABASE_SERVICE_ROLE_KEY):
            logger.warning("Supabase Auth is not configured — using placeholder values")
            return None
        try:
            from supabase import create_client
            _supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
        except Exception as e:
            logger.error("Failed to initialize Supabase client: %s", e)
            return None
    return _supabase


def signup_with_supabase(email: str, password: str) -> dict:
    """Create user in Supabase Auth and send verification email.

    Returns {'supabase_uid': <id>} on success.
    Returns {'supabase_uid': None} if Supabase is not configured (skip verification).
    Returns {'error': <msg>} on failure.
    """
    client = get_supabase_admin()
    if client is None:
        return {"supabase_uid": None}

    try:
        resp = client.auth.admin.create_user({
            "email": email,
            "password": password,
            "email_confirm": False,
        })
        return {"supabase_uid": resp.user.id}
    except Exception as e:
        logger.error("Supabase signup failed for %s: %s", email, e)
        return {"error": str(e)}


def check_email_verified(supabase_uid: str) -> bool:
    """Check if user's email is confirmed in Supabase Auth."""
    client = get_supabase_admin()
    if client is None:
        return True

    try:
        resp = client.auth.admin.get_user_by_id(supabase_uid)
        return resp.user.email_confirmed_at is not None
    except Exception as e:
        logger.error("Failed to check verification for %s: %s", supabase_uid, e)
        return False


def verify_access_token(access_token: str) -> Optional[str]:
    """Verify a Supabase access token and return the user's email if confirmed.

    This is used when the frontend receives the token from the email redirect.
    """
    from supabase import create_client

    anon_key = os.getenv("SUPABASE_ANON_KEY")
    if not SUPABASE_URL or _is_placeholder(SUPABASE_URL):
        return None
    if not anon_key or _is_placeholder(anon_key):
        return None

    try:
        client = create_client(SUPABASE_URL, anon_key)
        resp = client.auth.get_user(access_token)
        user = resp.user
        if user.email_confirmed_at is not None:
            return user.email
        return None
    except Exception as e:
        logger.error("Failed to verify access token: %s", e)
        return None


def resend_verification_email(email: str) -> dict:
    """Resend the verification email for the given address.

    Returns {'ok': True} on success, {'ok': False, 'error': <msg>} on failure.
    """
    client = get_supabase_admin()
    if client is None:
        return {"ok": False, "error": "Supabase not configured"}

    try:
        client.auth.admin.generate_link({
            "type": "signup",
            "email": email,
        })
        return {"ok": True}
    except Exception as e:
        logger.error("Failed to resend verification for %s: %s", email, e)
        return {"ok": False, "error": str(e)}

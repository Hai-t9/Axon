"""
FILE: backend/app/services/invitation/service.py

Handles competition invitation links.

A host generates an invitation link that encodes a signed token.
Participants call POST /invitations/join with the token to receive
a Role row (participant) in that competition.

Token format: base64url( JSON({comp_id, exp}) ) + "." + HMAC-SHA256-sig
"""

import base64
import hashlib
import hmac
import json
import os
import time
from typing import Optional

from sqlalchemy.orm import Session

from app.core.exceptions import AuthenticationError, NotFoundError, ValidationError
from app.models import Competition, Role, RoleType, User


_SECRET = os.getenv("SECRET_KEY", "dev-secret-change-in-production")
_TOKEN_TTL = int(os.getenv("INVITE_TOKEN_TTL_SECONDS", str(7 * 24 * 3600)))  # 7 days


def _b64_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _b64_decode(s: str) -> bytes:
    pad = "=" * (-len(s) % 4)
    return base64.urlsafe_b64decode(s + pad)


def _sign(payload: str) -> str:
    return _b64_encode(
        hmac.new(_SECRET.encode(), payload.encode(), hashlib.sha256).digest()
    )


def generate_invite_token(competition_id: int) -> str:
    payload = json.dumps(
        {"comp_id": competition_id, "exp": int(time.time()) + _TOKEN_TTL},
        separators=(",", ":"),
    )
    payload_b64 = _b64_encode(payload.encode())
    sig = _sign(payload_b64)
    return f"{payload_b64}.{sig}"


def verify_invite_token(token: str) -> int:
    """Return competition_id or raise AuthenticationError."""
    try:
        payload_b64, sig = token.rsplit(".", 1)
    except ValueError:
        raise AuthenticationError("Invalid invitation token format")

    expected_sig = _sign(payload_b64)
    if not hmac.compare_digest(sig, expected_sig):
        raise AuthenticationError("Invitation token signature is invalid")

    try:
        data = json.loads(_b64_decode(payload_b64))
    except Exception:
        raise AuthenticationError("Invitation token payload is corrupt")

    if int(data.get("exp", 0)) < int(time.time()):
        raise AuthenticationError("Invitation token has expired")

    return int(data["comp_id"])


class InvitationService:
    def __init__(self, db: Session):
        self.db = db

    def create_invitation_link(self, competition_id: int, base_url: str) -> str:
        """
        Generate a signed invitation link for a competition.
        Persists the token in competition.invitation_link for reference.
        """
        comp = self.db.query(Competition).filter(Competition.id == competition_id).first()
        if not comp:
            raise NotFoundError("Competition not found")

        token = generate_invite_token(competition_id)
        link = f"{base_url.rstrip('/')}/api/v1/invitations/join?token={token}"

        comp.invitation_link = link
        self.db.commit()
        return link

    def join_via_token(self, token: str, user: User) -> dict:
        """
        Validate the token and add the user as a participant in the competition.
        Idempotent — calling twice returns success without creating duplicates.
        """
        competition_id = verify_invite_token(token)

        comp = self.db.query(Competition).filter(Competition.id == competition_id).first()
        if not comp:
            raise NotFoundError("Competition not found")

        # Check if role already exists.
        existing = (
            self.db.query(Role)
            .filter(Role.user_id == user.id, Role.competition_id == competition_id)
            .first()
        )
        if existing:
            return {
                "competition_id": competition_id,
                "competition_name": comp.name,
                "role": existing.role.value,
                "already_member": True,
            }

        # Create participant role.
        role = Role(
            user_id=user.id,
            competition_id=competition_id,
            role=RoleType.participant,
        )
        self.db.add(role)
        self.db.commit()

        return {
            "competition_id": competition_id,
            "competition_name": comp.name,
            "role": RoleType.participant.value,
            "already_member": False,
        }
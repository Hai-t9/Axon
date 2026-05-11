from app.core.auth import create_access_token
from app.core.exceptions import AuthenticationError, ValidationError
from app.core.security import hash_password, verify_password
from app.core.supabase_auth import (
    resend_verification_email,
    signup_with_supabase,
    verify_access_token,
)
from app.schemas.user import LoginRequest, SignupRequest

from .repository import RegisterRepository


class RegisterService:
    def __init__(self, repository: RegisterRepository):
        self.repository = repository

    def signup(self, payload: SignupRequest) -> dict:
        if self.repository.get_by_email(payload.email):
            raise ValidationError("Email already registered")

        full_name = payload.full_name or payload.email.split("@", 1)[0]

        supabase_result = signup_with_supabase(payload.email, payload.password)
        if "error" in supabase_result:
            raise ValidationError(
                "Failed to create account. Please try again later."
            )

        verification_sent = supabase_result.get("supabase_uid") is not None

        self.repository.create(
            {
                "email": payload.email,
                "password": hash_password(payload.password),
                "fullname": full_name,
                "email_verified": not verification_sent,
            }
        )

        return {
            "message": (
                "Account created. Please check your email to verify your account."
                if verification_sent
                else "Account created."
            ),
            "email": payload.email,
            "verification_sent": verification_sent,
        }

    def login(self, payload: LoginRequest) -> dict:
        user = self.repository.get_by_email(payload.email)
        if not user or not verify_password(payload.password, user.password):
            raise AuthenticationError("Invalid email or password")

        if user.email_verified is False:
            raise AuthenticationError(
                "Please verify your email before logging in. "
                "Check your inbox for the verification link."
            )

        token = create_access_token(user.id)
        return {
            "access_token": token,
            "token_type": "bearer",
            "user": user,
        }

    def confirm_verification(self, access_token: str) -> dict:
        email = verify_access_token(access_token)
        if not email:
            return {"verified": False, "message": "Invalid or expired verification token."}

        user = self.repository.get_by_email(email)
        if not user:
            return {"verified": False, "message": "User not found."}

        self.repository.mark_verified(user.id)
        return {"verified": True, "message": "Email verified successfully. You can now log in."}

    def resend_verification(self, email: str) -> dict:
        user = self.repository.get_by_email(email)
        if not user:
            raise ValidationError("No account found with this email.")

        result = resend_verification_email(email)
        if not result.get("ok"):
            return {"sent": False, "message": result.get("error", "Failed to resend verification email.")}

        return {"sent": True, "message": "Verification email resent. Please check your inbox."}

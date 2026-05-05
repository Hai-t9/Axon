class AxonError(Exception):
    """Base exception for domain errors."""


class AuthenticationError(AxonError):
    """Raised when authentication fails."""


class AuthorizationError(AxonError):
    """Raised when a user lacks required permissions."""


class NotFoundError(AxonError):
    """Raised when a requested resource is not found."""


class ValidationError(AxonError):
    """Raised when input data fails validation."""


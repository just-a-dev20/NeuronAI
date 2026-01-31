"""JWT validation utilities."""

from typing import Any

from jose import JWTError, jwt

from neuronai.config.settings import get_settings


class JWTValidator:
    """Validates JWT tokens from Supabase."""

    def __init__(self) -> None:
        settings = get_settings()
        self.secret = settings.jwt_secret
        self.algorithm = settings.jwt_algorithm

    def validate(self, token: str) -> dict[str, Any] | None:
        """Validate a JWT token and return the payload."""
        try:
            payload = jwt.decode(
                token,
                self.secret,
                algorithms=[self.algorithm],
            )
            return payload
        except JWTError:
            return None

    def get_user_id(self, token: str) -> str | None:
        """Extract user ID from a valid token."""
        payload = self.validate(token)
        if payload:
            return payload.get("sub")
        return None

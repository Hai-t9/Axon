from enum import Enum as PyEnum

from sqlalchemy import Enum as SqlEnum


class RoleType(str, PyEnum):
    host = "host"
    staff = "staff"
    participant = "participant"


class ImageStatus(str, PyEnum):
    verified = "verified"
    onhold = "onhold"


role_type_enum = SqlEnum(RoleType, name="role_type")
image_status_enum = SqlEnum(ImageStatus, name="image_status")

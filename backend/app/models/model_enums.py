from enum import Enum as PyEnum

from sqlalchemy import Enum as SqlEnum


class RoleType(str, PyEnum):
    host = "host"
    staff = "staff"
    participant = "participant"


class ImageStatus(str, PyEnum):
    verified = "verified"
    onhold = "onhold"


class EvaluationProtocol(str, PyEnum):
    standard = "standard"
    loto = "loto"
    toto = "toto"


class EvaluationStatus(str, PyEnum):
    scheduled = "scheduled"
    queued = "queued"
    in_progress = "in_progress"
    completed = "completed"
    failed = "failed"


class TaskStatus(str, PyEnum):
    pending = "pending"
    queued = "queued"
    executing = "executing"
    completed = "completed"
    failed = "failed"


role_type_enum = SqlEnum(RoleType, name="role_type")
image_status_enum = SqlEnum(ImageStatus, name="image_status")
evaluation_protocol_enum = SqlEnum(EvaluationProtocol, name="evaluation_protocol")
evaluation_status_enum = SqlEnum(EvaluationStatus, name="evaluation_status")
task_status_enum = SqlEnum(TaskStatus, name="task_status")


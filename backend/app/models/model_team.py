from uuid import uuid4

from sqlalchemy import Column, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSON
from sqlalchemy.dialects.postgresql import UUID as PostgresUUID
from sqlalchemy.orm import relationship

from app.core.database import Base


class Team(Base):
    __tablename__ = "team"

    id = Column(PostgresUUID(as_uuid=True), primary_key=True, default=uuid4)
    name = Column(String, nullable=False)
    comp_id = Column(
        PostgresUUID(as_uuid=True), ForeignKey("competition.id"), nullable=False
    )
    user_emails = Column(JSON, nullable=True)  # {"email": bool} – false=invited, true=joined

    images = relationship("Image", back_populates="team", cascade="all, delete-orphan")
    dataset = relationship(
        "Dataset", back_populates="team", uselist=False, cascade="all, delete-orphan"
    )
    models = relationship("Model", back_populates="team", cascade="all, delete-orphan")

    __table_args__ = (UniqueConstraint("name", "comp_id", name="uq_team_name_comp_id"),)

    competition = relationship(
        "Competition", back_populates="teams", foreign_keys=[comp_id]
    )

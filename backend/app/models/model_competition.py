from sqlalchemy import Column, Date, Float, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import relationship

from app.core.database import Base


class Competition(Base):
    __tablename__ = "competition"

    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    launch_date = Column(Date, nullable=True)
    invitation_link = Column(String, unique=True, nullable=True)

    roles = relationship("Role", back_populates="competition", cascade="all, delete-orphan")
    config = relationship(
        "Config",
        back_populates="competition",
        uselist=False,
        cascade="all, delete-orphan",
    )
    teams = relationship("Team", back_populates="competition", cascade="all, delete-orphan")
    phase_logs = relationship(
        "PhaseLog", back_populates="competition", cascade="all, delete-orphan"
    )
    models = relationship("Model", back_populates="competition", cascade="all, delete-orphan")


class Config(Base):
    __tablename__ = "config"

    id = Column(Integer, primary_key=True)
    competition_id = Column(Integer, ForeignKey("competition.id"), unique=True, nullable=False)
    labels = Column(JSON, nullable=True)
    data_ex = Column(String, nullable=True)
    scoring_ex = Column(String, nullable=True)
    overview = Column(String, nullable=True)
    terms_conditions = Column(String, nullable=True)
    data_md = Column(String, nullable=True)
    data_format = Column(String, nullable=True)
    evaluation = Column(String, nullable=True)
    duplicate_threshhold = Column(Float, nullable=True)
    max_validations = Column("maxValidations", Integer, nullable=True)

    competition = relationship("Competition", back_populates="config")


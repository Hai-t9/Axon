from sqlalchemy import Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.core.database import Base


class Dataset(Base):
    __tablename__ = "dataset"

    id = Column(Integer, primary_key=True)
    team_id = Column(Integer, ForeignKey("team.id"), unique=True, nullable=False)
    team_folderpath = Column(String, nullable=True)

    team = relationship("Team", back_populates="dataset")


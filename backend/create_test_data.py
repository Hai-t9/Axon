import sys
import os
from sqlalchemy.orm import Session
from app.core.database import SessionLocal, Base, engine
from app.models.model_user import User, Role
from app.models.model_team import Team
from app.models.model_competition import Competition, Config
from app.models.model_phase import PhaseLog
from app.models.model_enums import RoleType
from app.core.security import hash_password

def main():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    email = "houriabdo10@gmail.com"
    password = "houri"
    
    # Check if user exists
    user = db.query(User).filter(User.email == email).first()
    if not user:
        user = User(
            email=email,
            password=hash_password(password),
            fullname="Test User"
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        print(f"Created user {email}")
    else:
        print(f"User {email} already exists")
        
    comp = db.query(Competition).first()
    if not comp:
        comp = Competition(name="Test Competition", description="Demo competition")
        db.add(comp)
        db.commit()
        db.refresh(comp)
        print("Created Competition")

    role = db.query(Role).filter_by(user_id=user.id, competition_id=comp.id).first()
    if not role:
        role = Role(user_id=user.id, competition_id=comp.id, role=RoleType.participant)
        db.add(role)
        db.commit()

    team = db.query(Team).first()
    if not team:
        team = Team(
            name="Alpha Team",
            comp_id=comp.id,
            user_ids=[user.id]
        )
        db.add(team)
        db.commit()
        db.refresh(team)
        print("Created Alpha Team")
    else:
        if not team.user_ids:
            team.user_ids = []
        if user.id not in team.user_ids:
            team.user_ids = team.user_ids + [user.id]
            db.commit()

    phase_log = db.query(PhaseLog).filter_by(competition_id=comp.id).first()
    if not phase_log:
        phase_log = PhaseLog(competition_id=comp.id, current_phase="active")
        db.add(phase_log)
        db.commit()
        print("Created active phase log for competition")
    else:
        phase_log.current_phase = "active"
        db.commit()
        print("Updated competition to active phase")

    config = db.query(Config).filter_by(competition_id=comp.id).first()
    if not config:
        config = Config(
            competition_id=comp.id,
            labels=["Healthy", "Blight", "Rust", "Weed"],
            max_validations=5
        )
        db.add(config)
        db.commit()
        print("Created competition config")
        
    db.close()

if __name__ == "__main__":
    main()

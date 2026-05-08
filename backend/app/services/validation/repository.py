from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import Config, Image, Label, LabelValidation, Team


from app.core.cache import get_validation_cache

class ValidationRepository:
    def __init__(self, db: Session):
        self.db = db
        self.cache = get_validation_cache()

    def is_dataset_locked(self, comp_id: int) -> bool:
        from app.models import PhaseLog
        log = self.db.query(PhaseLog).filter(PhaseLog.competition_id == comp_id).first()
        if log and log.dataset_locked:
            return True
        return False

    def find_participant_team(self, comp_id: int, participant_id: int) -> Team | None:
        cached_team_id = self.cache.get_participant_team(comp_id, participant_id)
        if cached_team_id:
            team = self.db.query(Team).filter(Team.id == cached_team_id).first()
            if team:
                return team

        teams = (
            self.db.query(Team)
            .filter(Team.comp_id == comp_id)
            .order_by(Team.id.asc())
            .all()
        )
        for team in teams:
            if participant_id in (team.user_ids or []):
                self.cache.set_participant_team(comp_id, participant_id, team.id)
                return team
        return None

    def find_validation_threshold(self, comp_id: int) -> int | None:
        cached_thresh = self.cache.get_threshold(comp_id)
        if cached_thresh is not None:
            return cached_thresh

        config = (
            self.db.query(Config)
            .filter(Config.competition_id == comp_id)
            .first()
        )
        if not config:
            return None
            
        if config.max_validations is not None:
            self.cache.set_threshold(comp_id, config.max_validations)
            
        return config.max_validations

    def count_participant_validations(
        self, comp_id: int, participant_id: int, team_id: int
    ) -> dict:
        rows = (
            self.db.query(Team.id.label("team_id"), func.count(LabelValidation.id))
            .join(Image, Image.team_id == Team.id)
            .join(Label, Label.image_id == Image.id)
            .join(LabelValidation, LabelValidation.label_id == Label.id)
            .filter(Team.comp_id == comp_id, LabelValidation.validator_id == participant_id)
            .group_by(Team.id)
            .all()
        )

        own_count = 0
        other_count = 0
        for team_id_row, count in rows:
            if team_id_row == team_id:
                own_count += int(count or 0)
            else:
                other_count += int(count or 0)

        return {"ownCount": own_count, "otherCount": other_count}

    def _build_voted_image_subquery(self, comp_id: int, participant_id: int):
        return (
            self.db.query(Image.id)
            .join(Label, Label.image_id == Image.id)
            .join(LabelValidation, LabelValidation.label_id == Label.id)
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id, LabelValidation.validator_id == participant_id)
            .subquery()
        )

    def _build_threshold_label_subquery(self, threshold: int):
        return (
            self.db.query(LabelValidation.label_id)
            .group_by(LabelValidation.label_id)
            .having(func.count(LabelValidation.id) >= threshold)
            .subquery()
        )

    def find_batch_from_own_team(
        self,
        comp_id: int,
        team_id: int,
        participant_id: int,
        threshold: int,
        count: int,
    ) -> list[dict]:
        voted_subquery = self._build_voted_image_subquery(comp_id, participant_id)
        threshold_subquery = self._build_threshold_label_subquery(threshold)

        rows = (
            self.db.query(Image.id, Image.filepath, Label.label)
            .join(Label, Label.image_id == Image.id)
            .filter(
                Image.team_id == team_id,
                Label.validated.is_(False),
                ~Image.id.in_(voted_subquery),
                ~Label.id.in_(threshold_subquery),
            )
            .order_by(Image.id.asc())
            .limit(count)
            .all()
        )

        return [{"id": row.id, "filepath": row.filepath, "current_label": row.label} for row in rows]

    def find_batch_from_other_teams(
        self,
        comp_id: int,
        team_id: int,
        participant_id: int,
        threshold: int,
        count: int,
    ) -> list[dict]:
        voted_subquery = self._build_voted_image_subquery(comp_id, participant_id)
        threshold_subquery = self._build_threshold_label_subquery(threshold)

        rows = (
            self.db.query(Image.id, Image.filepath, Label.label)
            .join(Label, Label.image_id == Image.id)
            .join(Team, Team.id == Image.team_id)
            .filter(
                Team.comp_id == comp_id,
                Image.team_id != team_id,
                Label.validated.is_(False),
                ~Image.id.in_(voted_subquery),
                ~Label.id.in_(threshold_subquery),
            )
            .order_by(Image.id.asc())
            .limit(count)
            .all()
        )

        return [{"id": row.id, "filepath": row.filepath, "current_label": row.label} for row in rows]

    def insert_vote(self, image_id: int, validator_id: int, label: str) -> LabelValidation | None:
        label_entry = self.db.query(Label).filter(Label.image_id == image_id).first()
        if not label_entry:
            return None

        existing_vote = (
            self.db.query(LabelValidation)
            .filter(
                LabelValidation.label_id == label_entry.id,
                LabelValidation.validator_id == validator_id,
            )
            .first()
        )
        if existing_vote:
            return None

        vote = LabelValidation(label_id=label_entry.id, validator_id=validator_id, label=label)
        self.db.add(vote)
        self.db.commit()
        self.db.refresh(vote)
        return vote

    def count_votes_for_image(self, image_id: int) -> int:
        return int(
            self.db.query(func.count(LabelValidation.id))
            .join(Label, Label.id == LabelValidation.label_id)
            .filter(Label.image_id == image_id)
            .scalar()
            or 0
        )

    def find_label_by_image_id(self, image_id: int) -> Label | None:
        return self.db.query(Label).filter(Label.image_id == image_id).first()

    def find_votes_by_label_id(self, label_id: int) -> list[LabelValidation]:
        return (
            self.db.query(LabelValidation)
            .filter(LabelValidation.label_id == label_id)
            .order_by(LabelValidation.id.asc())
            .all()
        )

    def find_pending_by_comp(self, comp_id: int) -> list[dict]:
        rows = (
            self.db.query(Image.id, Image.filepath, Label.label)
            .join(Label, Label.image_id == Image.id)
            .join(Team, Team.id == Image.team_id)
            .filter(Team.comp_id == comp_id, Label.validated.is_(False))
            .order_by(Image.id.asc())
            .all()
        )
        return [
            {"id": row.id, "filepath": row.filepath, "label": row.label}
            for row in rows
        ]

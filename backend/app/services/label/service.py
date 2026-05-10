import os
import shutil
from uuid import UUID

from app.core.exceptions import NotFoundError, ValidationError
from app.storage.minio_client import storage_service
from app.storage.paths import image_key, image_local_path

from .repository import LabelRepository


class LabelService:
    def __init__(self, repository: LabelRepository):
        self.repository = repository

    def get_competition_id(self, image_id: UUID) -> UUID:
        comp_id = self.repository.get_competition_id_for_image(image_id)
        if not comp_id:
            raise NotFoundError("Image not found")
        return comp_id

    def create_label(self, image_id: UUID, label: str):
        if not self.repository.get_image_by_id(image_id):
            raise NotFoundError("Image not found")
        if self.repository.find_by_image_id(image_id):
            raise ValidationError("Label already exists for image")
        return self.repository.insert_label(image_id, label)

    def get_label(self, image_id: UUID):
        label_entry = self.repository.find_by_image_id(image_id)
        if not label_entry:
            raise NotFoundError("Label not found")
        return label_entry

    def update_label(self, image_id: UUID, new_label: str):
        if not self.repository.get_image_by_id(image_id):
            raise NotFoundError("Image not found")
        label_entry = self.repository.find_by_image_id(image_id)
        if not label_entry:
            raise NotFoundError("Label not found")

        old_label = label_entry.label
        if old_label == new_label:
            return label_entry

        # Move file to new label folder (only if stored in structured layout)
        image = self.repository.get_image_with_team(image_id)
        if not image:
            raise NotFoundError("Image not found")

        comp_id = image.team.comp_id
        team_id = image.team_id
        comp_name = image.team.competition.name
        team_name = image.team.name
        filename = os.path.basename(image.filepath)

        old_local = image_local_path(comp_id, team_id, comp_name, team_name, old_label, filename)
        new_local = image_local_path(comp_id, team_id, comp_name, team_name, new_label, filename)
        old_s3 = image_key(comp_id, team_id, comp_name, team_name, old_label, filename)
        new_s3 = image_key(comp_id, team_id, comp_name, team_name, new_label, filename)

        # Always move in S3 — works regardless of local file presence
        storage_service.copy_file(old_s3, new_s3)
        storage_service.delete_file(old_s3)

        # Local move — only if the local file actually exists
        if os.path.exists(old_local):
            os.makedirs(os.path.dirname(new_local), exist_ok=True)
            shutil.move(old_local, new_local)

        self.repository.update_image_filepath(image_id, new_local)

        # Update label in DB
        label_entry = self.repository.modify_label(image_id, new_label)

        # Sync Image.label so the gallery shows the validated label
        self.repository.update_image_label(image_id, new_label)

        return label_entry

    def validate_label(self, image_id: UUID):
        label_entry = self.repository.set_label_validated(image_id)
        if not label_entry:
            raise NotFoundError("Label not found")
        self.repository.set_image_status(image_id, "verified")
        return label_entry

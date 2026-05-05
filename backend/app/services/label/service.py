from app.core.exceptions import NotFoundError, ValidationError

from .repository import LabelRepository


class LabelService:
    def __init__(self, repository: LabelRepository):
        self.repository = repository

    def get_competition_id(self, image_id: int) -> int:
        comp_id = self.repository.get_competition_id_for_image(image_id)
        if not comp_id:
            raise NotFoundError("Image not found")
        return comp_id

    def create_label(self, image_id: int, label: str):
        if not self.repository.get_image_by_id(image_id):
            raise NotFoundError("Image not found")
        if self.repository.find_by_image_id(image_id):
            raise ValidationError("Label already exists for image")
        return self.repository.insert_label(image_id, label)

    def get_label(self, image_id: int):
        label_entry = self.repository.find_by_image_id(image_id)
        if not label_entry:
            raise NotFoundError("Label not found")
        return label_entry

    def update_label(self, image_id: int, label: str):
        if not self.repository.get_image_by_id(image_id):
            raise NotFoundError("Image not found")
        label_entry = self.repository.modify_label(image_id, label)
        if not label_entry:
            raise NotFoundError("Label not found")
        return label_entry

    def validate_label(self, image_id: int):
        label_entry = self.repository.set_label_validated(image_id)
        if not label_entry:
            raise NotFoundError("Label not found")
        return label_entry

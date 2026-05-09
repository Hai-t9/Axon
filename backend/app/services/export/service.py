from datetime import datetime
from uuid import UUID

from app.core.exceptions import NotFoundError, ValidationError
from app.services.phase.repository import PhaseRepository
from app.services.phase.service import PHASE_LABELS, PhaseService

from .repository import ExportRepository


class ExportService:
    def __init__(self, repository: ExportRepository, db=None):
        self.repository = repository
        self._db = db

    def _get_phase(self, comp_id: UUID) -> tuple[str, str]:
        phase_service = PhaseService(PhaseRepository(self._db))
        phase_log = phase_service.get_current_phase(comp_id)
        phase = phase_log.current_phase
        label = PHASE_LABELS.get(phase, "Unknown")
        return phase, label

    def _check_phase_gate(self, comp_id: UUID):
        phase, label = self._get_phase(comp_id)
        phase_num = int(phase)
        if phase_num < 2:
            raise ValidationError(
                f"Data export is not available yet. Current phase: {label} "
                f"(requires Data Validation or later)"
            )
        return phase, label

    def _image_to_dict(self, image) -> dict:
        return {
            "id": image.id,
            "team_id": image.team_id,
            "team_name": image.team.name if image.team else "",
            "author_id": str(image.author_id),
            "author_name": image.author.fullname if image.author else None,
            "filepath": image.filepath,
            "original_filename": image.original_filename,
            "label": image.label,
            "status": image.status,
            "device": image.device,
            "time": image.time,
            "image_hash": image.image_hash,
            "old_size_mb": image.old_size_mb,
            "old_width": image.old_width,
            "old_height": image.old_height,
        }

    def _metadata_to_dict(self, meta) -> dict:
        return {
            "image_id": meta.image_id,
            "gps_info": meta.gps_info,
            "make": meta.make,
            "camera_model": meta.camera_model,
            "software": meta.software,
            "orientation": meta.orientation,
            "date_time": meta.date_time,
            "image_width": meta.image_width,
            "image_length": meta.image_length,
            "resolution_unit": meta.resolution_unit,
            "x_resolution": meta.x_resolution,
            "y_resolution": meta.y_resolution,
            "new_width": meta.new_width,
            "new_height": meta.new_height,
            "new_size_mb": meta.new_size_mb,
            "original_resolution": meta.original_resolution,
            "new_resolution": meta.new_resolution,
            "resizing_method": meta.resizing_method,
            "format_change": meta.format_change,
            "english_name": meta.english_name,
            "scientific_name": meta.scientific_name,
            "extra_subfolder": meta.extra_subfolder,
        }

    def _build_labels_by_image(self, image_ids: list[UUID]) -> list[dict]:
        labels = self.repository.get_labels_for_images(image_ids)
        label_ids = [lb.id for lb in labels]
        validations = self.repository.get_validations_for_labels(label_ids)

        validations_by_label: dict[int, list] = {}
        for v in validations:
            validations_by_label.setdefault(v.label_id, []).append({
                "validator_id": str(v.validator_id),
                "label": v.label,
                "validated_at": v.validated_at,
            })

        result = []
        for lb in labels:
            result.append({
                "image_id": lb.image_id,
                "label": lb.label,
                "validated": lb.validated,
                "validations": validations_by_label.get(lb.id, []),
            })
        return result

    def _build_export_data(
        self, images: list, comp_id: UUID, phase: str, phase_label: str,
        export_type: str, include_metadata: bool = False,
    ) -> dict:
        image_ids = [img.id for img in images]
        labels_data = self._build_labels_by_image(image_ids)

        metadata_data = None
        if include_metadata:
            metadata_records = self.repository.get_metadata_for_images(image_ids)
            metadata_data = [self._metadata_to_dict(m) for m in metadata_records]

        team_ids = {img.team_id for img in images}
        images_data = [self._image_to_dict(img) for img in images]

        return {
            "type": export_type,
            "phase": phase,
            "phase_label": phase_label,
            "images": images_data,
            "labels": labels_data,
            "metadata": metadata_data,
            "total_images": len(images),
            "total_teams": len(team_ids),
            "exported_at": datetime.utcnow(),
        }

    def export_team_data(self, comp_id: UUID, user_id: UUID) -> dict:
        phase, phase_label = self._check_phase_gate(comp_id)

        team = self.repository.get_team_for_user(comp_id, user_id)
        if not team:
            raise NotFoundError("You are not assigned to any team in this competition")

        images = self.repository.get_team_images_with_labels(team.id)
        return self._build_export_data(images, comp_id, phase, phase_label, "team")

    def export_full_data(self, comp_id: UUID) -> dict:
        phase, phase_label = self._check_phase_gate(comp_id)

        images = self.repository.get_all_competition_images(comp_id)
        return self._build_export_data(images, comp_id, phase, phase_label, "full",
                                       include_metadata=True)

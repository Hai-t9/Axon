from io import BytesIO
from PIL import Image as PILImage
import exifread
import hashlib
import json
import os
import uuid
from fastapi import UploadFile
from app.services.image.repository import ImageRepository


class ImageService:
    def __init__(self, repository: ImageRepository):
        self.repository = repository

    @staticmethod
    def _parse_label(raw_label: str | None) -> str | None:
        """Parse label from Flutter FormData.

        Accepts:
          - JSON: '{"tags": ["scratch"]}'  ->  "scratch"
          - Plain string: 'scratch'        ->  "scratch"
          - None / empty                   ->  None
        """
        if not raw_label or raw_label.strip() in ("", "null", "None"):
            return None

        try:
            parsed = json.loads(raw_label)
            if isinstance(parsed, dict):
                tags = parsed.get("tags", [])
                if tags and isinstance(tags, list):
                    return str(tags[0])
            # If it parsed as a plain string from JSON
            if isinstance(parsed, str):
                return parsed
        except (json.JSONDecodeError, TypeError):
            pass

        # Fallback: treat the raw value as a plain string label
        return str(raw_label).strip()

    async def upload_image(self, user_id: int, team_id: int, file: UploadFile, label: str = None):
        # Validate format
        allowed = ["image/jpeg", "image/png", "image/jpg"]
        if file.content_type not in allowed:
            raise ValueError(f"Invalid format. Allowed: {', '.join(allowed)}")

        parsed_label = self._parse_label(label)

        contents = await file.read()
        
        # Hash for deduplication
        image_hash = hashlib.sha256(contents).hexdigest()
        existing = self.repository.find_by_hash(image_hash)
        if existing:
            raise ValueError("Duplicate image detected.")

        # Store file
        upload_dir = "uploads"
        os.makedirs(upload_dir, exist_ok=True)
        ext = file.filename.split(".")[-1]
        filename = f"{uuid.uuid4()}.{ext}"
        filepath = os.path.join(upload_dir, filename)
        
        with open(filepath, "wb") as f:
            f.write(contents)

        # Extract metadata correctly using exifread and Pillow
        img_buffer = BytesIO(contents)
        tags = exifread.process_file(img_buffer, details=False)
        
        # Fallback to Pillow for dimensions if EXIF is missing
        try:
            with PILImage.open(BytesIO(contents)) as pil_img:
                width, height = pil_img.size
        except Exception:
            width, height = 0, 0

        metadata = {
            "make": str(tags.get('Image Make', 'Unknown')),
            "camera_model": str(tags.get('Image Model', 'Unknown')),
        }
        
        # Convert EXIF tags to plain values if they are ExifRead classes
        for k, v in metadata.items():
            if hasattr(v, 'values'):
                metadata[k] = v.values[0] if isinstance(v.values, list) and len(v.values) > 0 else str(v)

        image_data = {
            "team_id": team_id,
            "author_id": user_id,
            "filepath": filepath,
            "image_hash": image_hash,
            "label": parsed_label,
            "original_filename": file.filename,
            "old_extension": ext,
            "old_size_mb": len(contents) / (1024 * 1024),
            "old_width": float(width),
            "old_height": float(height),
            "device": metadata.get("make", "Unknown")
        }

        record = self.repository.create(image_data, metadata)

        # Auto-create a Label record in the label table so the
        # Validation / Data-Validation workflows have something to work with.
        if parsed_label:
            self.repository.create_label_record(record.id, parsed_label)

        return record

    def get_image_by_id(self, image_id: int):
        return self.repository.find_by_id(image_id)

    def get_images_by_team(self, team_id: int, status: str = None, page: int = 1):
        limit = 10
        skip = (page - 1) * limit
        return self.repository.find_by_team(team_id, status, skip, limit)

    def get_images_by_competition(self, comp_id: int, status: str = None):
        return self.repository.find_by_competition(comp_id, status)

    def get_image_stats(self, comp_id: int):
        return self.repository.get_stats(comp_id)

    def update_image_status(self, image_id: int, status: str):
        valid_statuses = ["onhold", "verified"]
        if status not in valid_statuses:
            raise ValueError(f"Invalid status. Must be one of {valid_statuses}")
        record = self.repository.update_status(image_id, status)
        if not record:
            raise ValueError("Image not found")
        return record

    def delete_image(self, image_id: int):
        image = self.repository.find_by_id(image_id)
        if image:
            try:
                os.remove(image.filepath)
            except OSError:
                pass

        success = self.repository.delete(image_id)
        if not success:
            raise ValueError("Image not found")
        return True

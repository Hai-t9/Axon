import hashlib
import json
import os
import uuid
from io import BytesIO
from uuid import UUID

import exifread
import imagehash
from app.services.image.repository import ImageRepository
from app.storage.minio_client import storage_service
from app.storage.paths import image_key, image_local_path
from fastapi import UploadFile
from PIL import Image as PILImage


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

    async def upload_image(
        self, user_id: UUID, team_id: UUID, file: UploadFile, label: str = None
    ):

        allowed = ["image/jpeg", "image/png", "image/jpg"]
        if file.content_type not in allowed:
            raise ValueError(f"Invalid format. Allowed: {', '.join(allowed)}")

        parsed_label = self._parse_label(label)

        contents = await file.read()

        try:
            with PILImage.open(BytesIO(contents)) as pil_img:
                image_hash = str(imagehash.phash(pil_img))
                width, height = pil_img.size
        except Exception:
            image_hash = hashlib.sha256(contents).hexdigest()
            width, height = 0, 0

        existing = self.repository.find_by_hash(image_hash)
        if existing:
            raise ValueError("Duplicate image detected.")

        # Store file
        ext = file.filename.split(".")[-1]
        filename = f"{uuid.uuid4()}.{ext}"

        team_info = self.repository.get_team_info(team_id)
        if not team_info:
            raise ValueError("Team not found")
        comp_id, comp_name, team_name = team_info

        safe_label = (
            parsed_label.replace(" ", "_").lower() if parsed_label else "unlabeled"
        )

        object_name = image_key(
            comp_id, team_id, comp_name, team_name, safe_label, filename
        )
        storage_service.upload_file(contents, object_name)

        filepath = image_local_path(
            comp_id, team_id, comp_name, team_name, safe_label, filename
        )
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        with open(filepath, "wb") as f:
            f.write(contents)

        # Extract metadata correctly using exifread
        img_buffer = BytesIO(contents)
        tags = exifread.process_file(img_buffer, details=False)

        metadata = {
            "make": str(tags.get("Image Make", "Unknown")),
            "camera_model": str(tags.get("Image Model", "Unknown")),
            "softwares": str(tags.get("Image Software", "")),
            "orientation": str(tags.get("Image Orientation", "")),
            "date_time": str(tags.get("Image DateTime", "")),
            "image_width": str(tags.get("Image ImageWidth", "")),
            "image_length": str(tags.get("Image ImageLength", "")),
            "gps_info": str(tags.get("GPS GPSLatitude", ""))
            + " "
            + str(tags.get("GPS GPSLongitude", "")),
            "x_resolution": str(tags.get("Image XResolution", "")),
            "y_resolution": str(tags.get("Image YResolution", "")),
            "resolution_unit": str(tags.get("Image ResolutionUnit", "")),
            "ycbcr_positioning": str(tags.get("Image YCbCrPositioning", "")),
        }

        # Convert EXIF tags to plain values if they are ExifRead classes
        for k, v in metadata.items():
            if hasattr(v, "values"):
                metadata[k] = (
                    v.values[0]
                    if isinstance(v.values, list) and len(v.values) > 0
                    else str(v)
                )
            if metadata[k] == "None" or metadata[k].strip() == "":
                metadata[k] = None

        # Try to parse floats and dates specifically safely for db
        def try_float(val):
            if val is None:
                return None
            try:
                # Some come as ratios like '72/1'
                if "/" in str(val):
                    n, d = str(val).split("/")
                    return float(n) / float(d)
                return float(val)
            except Exception:
                return None

        parsed_metadata = {
            "make": metadata.get("make"),
            "camera_model": metadata.get("camera_model"),
            "software": metadata.get("softwares"),
            "orientation": try_float(metadata.get("orientation")),
            "image_width": try_float(metadata.get("image_width")),
            "image_length": try_float(metadata.get("image_length")),
            "x_resolution": try_float(metadata.get("x_resolution")),
            "y_resolution": try_float(metadata.get("y_resolution")),
            "resolution_unit": metadata.get("resolution_unit"),
            "ycbcr_positioning": metadata.get("ycbcr_positioning"),
            "gps_info": metadata.get("gps_info")
            if metadata.get("gps_info") and metadata.get("gps_info") != "None None"
            else None,
        }

        # Date parsing
        date_str = metadata.get("date_time")
        parsed_date = None
        if date_str:
            try:
                from datetime import datetime

                # EXIF date format is usually YYYY:MM:DD HH:MM:SS
                parsed_date = datetime.strptime(str(date_str), "%Y:%m:%d %H:%M:%S")
            except Exception:
                pass
        parsed_metadata["date_time"] = parsed_date

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
            "device": parsed_metadata.get("make") or "Unknown",
        }

        record = self.repository.create(image_data, parsed_metadata)

        # Auto-create a Label record in the label table so the
        # Validation / Data-Validation workflows have something to work with.
        if parsed_label:
            self.repository.create_label_record(record.id, parsed_label)

        return record

    def get_image_by_id(self, image_id: UUID):
        return self.repository.find_by_id(image_id)

    def get_images_by_team(
        self,
        team_id: UUID,
        status: str = None,
        author_id: UUID = None,
        label: str = None,
        page: int = 1,
        limit: int = 50,
    ):
        skip = (page - 1) * limit
        return self.repository.find_by_team(
            team_id, status, author_id, label, skip, limit
        )

    def get_images_by_competition(self, comp_id: UUID, status: str = None):
        return self.repository.find_by_competition(comp_id, status)

    def get_image_stats(self, comp_id: UUID):
        return self.repository.get_stats(comp_id)

    def update_image_status(self, image_id: UUID, status: str):
        valid_statuses = ["onhold", "verified"]
        if status not in valid_statuses:
            raise ValueError(f"Invalid status. Must be one of {valid_statuses}")
        record = self.repository.update_status(image_id, status)
        if not record:
            raise ValueError("Image not found")
        return record

    def delete_image(self, image_id: UUID):
        image = self.repository.find_by_id(image_id)
        if image:
            try:
                os.remove(image.filepath)
            except OSError:
                pass
            s3_key = image.filepath[len("uploads/") :]
            storage_service.delete_file(s3_key)

        success = self.repository.delete(image_id)
        if not success:
            raise ValueError("Image not found")
        return True

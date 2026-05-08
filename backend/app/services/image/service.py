from io import BytesIO
from PIL import Image as PILImage
import exifread
import hashlib
import imagehash
import json
import os
import uuid
from uuid import UUID
from fastapi import UploadFile
from app.services.image.repository import ImageRepository
from app.storage.minio_client import storage_service

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

    async def upload_image(self, user_id: UUID, team_id: UUID, file: UploadFile, label: str = None):
        # Validate format
        allowed = ["image/jpeg", "image/png", "image/jpg"]
        if file.content_type not in allowed:
            raise ValueError(f"Invalid format. Allowed: {', '.join(allowed)}")

        parsed_label = self._parse_label(label)

        contents = await file.read()
        
        # We need a PILImage instance to reliably calculate the visual imagehash
        try:
            with PILImage.open(BytesIO(contents)) as pil_img:
                image_hash = str(imagehash.phash(pil_img))
                width, height = pil_img.size
        except Exception:
            # Fallback to standard hash if corrupted or unknown
            image_hash = hashlib.sha256(contents).hexdigest()
            width, height = 0, 0

        # Hash for deduplication
        existing = self.repository.find_by_hash(image_hash)
        if existing:
            raise ValueError("Duplicate image detected.")

        # Store file
        ext = file.filename.split(".")[-1]
        filename = f"{uuid.uuid4()}.{ext}"

        # Uploading to MinIO
        object_name = f"images/{filename}"
        storage_service.upload_file(contents, object_name)

        # We also keep a local copy for Pillow compatibility with current codebase or we just use filepath.
        # But wait, local codebase uses `filepath` heavily. Let's write locally too for now, or just return s3 link?
        # The Cleaner uses local files for Pillow ops. I will continue writing locally, but add MinIO upload.
        upload_dir = "uploads"
        os.makedirs(upload_dir, exist_ok=True)
        filepath = os.path.join(upload_dir, filename)
        
        with open(filepath, "wb") as f:
            f.write(contents)

        # Extract metadata correctly using exifread
        img_buffer = BytesIO(contents)
        tags = exifread.process_file(img_buffer, details=False)

        metadata = {
            "make": str(tags.get('Image Make', 'Unknown')),
            "camera_model": str(tags.get('Image Model', 'Unknown')),
            "softwares": str(tags.get('Image Software', '')),
            "orientation": str(tags.get('Image Orientation', '')),
            "date_time": str(tags.get('Image DateTime', '')),
            "image_width": str(tags.get('Image ImageWidth', '')),
            "image_length": str(tags.get('Image ImageLength', '')),
            "gps_info": str(tags.get('GPS GPSLatitude', '')) + " " + str(tags.get('GPS GPSLongitude', '')),
            "x_resolution": str(tags.get('Image XResolution', '')),
            "y_resolution": str(tags.get('Image YResolution', '')),
            "resolution_unit": str(tags.get('Image ResolutionUnit', '')),
            "ycbcr_positioning": str(tags.get('Image YCbCrPositioning', ''))
        }
        
        # Convert EXIF tags to plain values if they are ExifRead classes
        for k, v in metadata.items():
            if hasattr(v, 'values'):
                metadata[k] = v.values[0] if isinstance(v.values, list) and len(v.values) > 0 else str(v)
            if metadata[k] == "None" or metadata[k].strip() == "":
                metadata[k] = None

        # Try to parse floats and dates specifically safely for db
        def try_float(val):
            if val is None: return None
            try:
                # Some come as ratios like '72/1'
                if '/' in str(val):
                    n, d = str(val).split('/')
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
            "gps_info": metadata.get("gps_info") if metadata.get("gps_info") and metadata.get("gps_info") != "None None" else None
        }

        # Date parsing
        date_str = metadata.get("date_time")
        parsed_date = None
        if date_str:
            try:
                from datetime import datetime
                # EXIF date format is usually YYYY:MM:DD HH:MM:SS
                parsed_date = datetime.strptime(str(date_str), '%Y:%m:%d %H:%M:%S')
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
            "device": parsed_metadata.get("make") or "Unknown"
        }

        record = self.repository.create(image_data, parsed_metadata)

        # Auto-create a Label record in the label table so the
        # Validation / Data-Validation workflows have something to work with.
        if parsed_label:
            self.repository.create_label_record(record.id, parsed_label)

        return record

    def get_image_by_id(self, image_id: int):
        return self.repository.find_by_id(image_id)

    def get_images_by_team(self, team_id: UUID, status: str = None, page: int = 1):
        limit = 10
        skip = (page - 1) * limit
        return self.repository.find_by_team(team_id, status, skip, limit)

    def get_images_by_competition(self, comp_id: UUID, status: str = None):
        return self.repository.find_by_competition(comp_id, status)

    def get_image_stats(self, comp_id: UUID):
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
            # Extract object name if it exists in Minio
            filename = os.path.basename(image.filepath)
            storage_service.delete_file(f"images/{filename}")

        success = self.repository.delete(image_id)
        if not success:
            raise ValueError("Image not found")
        return True

import logging
import os
from collections import defaultdict
from datetime import datetime
from typing import List

from PIL import Image as PILImage
from PIL import ImageFile
from pillow_heif import register_heif_opener

from app.models.model_image import Image
from app.models.model_label import Label
from app.services.cleaner.repository import CleanerRepository
from app.services.cleaner.utils import TARGET_SIZE, group_by_hash, normalize_class, pick_best_from_group

# ── Module-level initialisation ──────────────────────────
register_heif_opener()
ImageFile.LOAD_TRUNCATED_IMAGES = True

logger = logging.getLogger(__name__)


class CleanerService:
    def __init__(self, repository: CleanerRepository):
        self.repository = repository
        self.resized_count = 0
        self.freed_space_mb = 0.0

    # ── Pipeline (kept as-is from original) ────────────────
    async def run_cleaning_pipeline(self, comp_id: int):
        duplicates = await self.scan_for_duplicates(comp_id)
        for dup in duplicates:
            try:
                if os.path.exists(dup.filepath):
                    os.remove(dup.filepath)
            except OSError:
                pass
        self.repository.bulk_delete(duplicates)

        corrupted = await self.detect_corrupted_images(comp_id)
        for corr in corrupted:
            try:
                if os.path.exists(corr.filepath):
                    os.remove(corr.filepath)
            except OSError:
                pass
        self.repository.bulk_delete(corrupted)

        await self.normalize_image_format(comp_id)
        await self.resize_images(comp_id)
        await self.clean_metadata(comp_id)
        await self.enforce_dataset_rules(comp_id)

        datasets_rebuilt = await self.rebuild_datasets(comp_id)
        storage_optimized = await self.optimize_storage(comp_id)

        return {
            "duplicates_removed": len(duplicates),
            "corrupted_removed": len(corrupted),
            "images_normalized": 0,
            "images_resized": self.resized_count,
            "datasets_rebuilt": datasets_rebuilt,
            "storage_freed_mb": storage_optimized.get("freed_mb", 0.0)
            + self.freed_space_mb,
            "completed_at": datetime.utcnow(),
        }

    # ── Duplicate scanning (kept as-is — already correct) ──
    async def scan_for_duplicates(self, comp_id: int) -> List[Image]:
        images = self.repository.find_images_by_competition(comp_id)
        return self.get_duplicate_candidates(images)

    def get_duplicate_candidates(self, images: List[Image]) -> List[Image]:
        hash_groups = defaultdict(list)
        for img in images:
            if img.image_hash:
                hash_groups[img.image_hash].append(img)

        duplicates_to_remove = []

        for image_hash, group in hash_groups.items():
            if len(group) == 1:
                continue

            def sort_key(img):
                size = img.old_size_mb or 0.0
                width = img.old_width or 0.0
                height = img.old_height or 0.0
                resolution = width * height
                known_device = 1 if img.device and img.device.lower() != "unknown" else 0
                is_not_ai4o = 1
                try:
                    if img.team and img.team.name == "AI-4o":
                        is_not_ai4o = 0
                except Exception:
                    pass
                return (size, resolution, known_device, is_not_ai4o)

            best_image = max(group, key=sort_key)
            for img in group:
                if img.id != best_image.id:
                    duplicates_to_remove.append(img)

        return duplicates_to_remove

    async def get_duplicate_groups(self, comp_id: int) -> List[dict]:
        images = self.repository.find_images_by_competition(comp_id)
        groups = group_by_hash(images)
        result = []
        for h, group in groups.items():
            if len(group) >= 2:
                result.append({
                    "hash": h,
                    "image_ids": [img.id for img in group],
                })
        return result

    # ── Corrupted detection ────────────────────────────────
    async def detect_corrupted_images(self, comp_id: int) -> List[Image]:
        return self.repository.find_corrupted_images()

    # ── Fix 6: Normalise format with safe handling ────────
    async def normalize_image_format(self, comp_id: int):
        images = self.repository.find_images_by_competition(comp_id)
        for img in images:
            if not os.path.exists(img.filepath):
                continue
            if img.filepath.lower().endswith(".png"):
                try:
                    with PILImage.open(img.filepath) as pil_img:
                        if pil_img.mode in ("RGBA", "P"):
                            pil_img = pil_img.convert("RGB")

                        new_filepath = img.filepath.rsplit(".", 1)[0] + ".jpg"
                        pil_img.save(new_filepath, "JPEG", optimize=True)

                    original_size = os.path.getsize(img.filepath)
                    os.remove(img.filepath)

                    img.filepath = new_filepath
                    new_size = os.path.getsize(new_filepath)
                    if new_size < original_size:
                        self.freed_space_mb += (original_size - new_size) / (1024 * 1024)
                except Exception as e:
                    logger.warning("Error normalising format for %s: %s", img.filepath, e)
                    self.repository.mark_corrupted(img.id, str(e))
                    continue
        self.repository.bulk_update(images)

    # ── Fix 3+6: Resize with upscaling, class norm, safe handling ──
    async def resize_images(self, comp_id: int):
        images = self.repository.find_images_by_competition(comp_id)
        self.resized_count = 0
        self.freed_space_mb = 0.0

        for img in images:
            if not os.path.exists(img.filepath):
                continue

            try:
                with PILImage.open(img.filepath) as pil_img:
                    w, h = pil_img.size

                    if w == TARGET_SIZE and h == TARGET_SIZE:
                        continue

                    original_size = os.path.getsize(img.filepath)
                    original_res = f"{w}x{h}"

                    # Determine resizing method
                    resizing_method = "unknown"
                    if w < TARGET_SIZE or h < TARGET_SIZE:
                        resizing_method = "upscale_and_crop"
                    elif w == h:
                        resizing_method = "square_resize"
                    else:
                        resizing_method = "rectangular_crop"

                    # Resize
                    if w == h:
                        resized_img = pil_img.resize(
                            (TARGET_SIZE, TARGET_SIZE), PILImage.Resampling.BICUBIC
                        )
                    else:
                        if w < h:  # Portrait
                            new_h = int(h * TARGET_SIZE / w)
                            temp_img = pil_img.resize(
                                (TARGET_SIZE, new_h), PILImage.Resampling.BICUBIC
                            )
                            left, top = 0, (temp_img.height - TARGET_SIZE) / 2
                        else:  # Landscape
                            new_w = int(w * TARGET_SIZE / h)
                            temp_img = pil_img.resize(
                                (new_w, TARGET_SIZE), PILImage.Resampling.BICUBIC
                            )
                            left, top = (temp_img.width - TARGET_SIZE) / 2, 0

                        resized_img = temp_img.crop(
                            (left, top, left + TARGET_SIZE, top + TARGET_SIZE)
                        )

                    resized_img.save(img.filepath, optimize=True)

                    new_size = os.path.getsize(img.filepath)
                    self.resized_count += 1
                    self.freed_space_mb += (original_size - new_size) / (1024 * 1024)

                    # Update metadata
                    self.repository.update_metadata_after_resize(
                        image_id=img.id,
                        new_width=float(TARGET_SIZE),
                        new_height=float(TARGET_SIZE),
                        new_size_mb=new_size / (1024 * 1024),
                        resizing_method=resizing_method,
                        format_change="->JPEG",
                        original_resolution=original_res,
                        new_resolution=f"{TARGET_SIZE}x{TARGET_SIZE}",
                    )

                    # Class normalisation (Fix 3B)
                    if img.label:
                        normalized = normalize_class(img.label)
                        if normalized != img.label.strip().lower():
                            self.repository.update_label(img.id, normalized)
                            # Also sync the label table record if it exists
                            label_rec = (
                                self.repository.db.query(Label)
                                .filter(Label.image_id == img.id)
                                .first()
                            )
                            if label_rec:
                                label_rec.label = normalized

            except Exception as e:
                logger.warning("Error resizing image %s: %s", img.filepath, e)
                self.repository.mark_corrupted(img.id, str(e))
                continue

        self.repository.commit()

    # ── Metadata cleaning ──────────────────────────────────
    async def clean_metadata(self, comp_id: int):
        images = self.repository.find_images_by_competition(comp_id)
        from app.models.model_image import ImageMetadata

        for img in images:
            metas = (
                self.repository.db.query(ImageMetadata)
                .filter(ImageMetadata.image_id == img.id)
                .all()
            )
            for meta in metas:
                if getattr(meta, "gps_info", None):
                    meta.gps_info = None
        self.repository.db.commit()

    # ── Enforce dataset rules ──────────────────────────────
    async def enforce_dataset_rules(self, comp_id: int):
        images = self.repository.find_images_by_competition(comp_id)
        violating = []
        for img in images:
            label_record = (
                self.repository.db.query(Label)
                .filter(Label.image_id == img.id)
                .first()
            )
            label_text = label_record.label if label_record else img.label

            if not label_text or label_text == "unlabeled":
                violating.append(img)

        for v in violating:
            try:
                if os.path.exists(v.filepath):
                    os.remove(v.filepath)
            except OSError:
                pass
        self.repository.bulk_delete(violating)

    # ── Fix 3: Real rebuild_datasets ───────────────────────
    async def rebuild_datasets(self, comp_id: int) -> bool:
        await self.resize_images(comp_id)
        return True

    # ── Fix 2: Real optimize_storage ───────────────────────
    async def optimize_storage(self, comp_id: int = None) -> dict:
        if comp_id is not None:
            images = self.repository.find_images_by_competition(comp_id)
        else:
            images = []

        all_groups = group_by_hash(images)
        duplicate_groups = {h: g for h, g in all_groups.items() if len(g) >= 2}

        total_freed_mb = 0.0
        total_removed = 0

        for h, group in duplicate_groups.items():
            best, reason = pick_best_from_group(group)
            for img in group:
                if img.id != best.id:
                    self.repository.mark_duplicate(
                        image_id=img.id,
                        duplicate_of_id=best.id,
                        reason=reason,
                    )
                    total_freed_mb += img.old_size_mb or 0.0
                    total_removed += 1

        self.repository.commit()

        return {
            "freed_mb": round(total_freed_mb, 2),
            "files_removed": total_removed,
        }

    # ── Fix 4: Clean dataset orchestration ─────────────────
    async def clean_dataset_by_team(self, team_id: int) -> dict:
        comp_id = self.repository.get_team_comp_id(team_id)
        if not comp_id:
            return {"images_processed": 0, "issues_found": ["Team not found"]}

        issues = []
        total_processed = 0

        # Step 1: detect unlabeled images
        unlabeled = self.repository.find_unlabeled_images(comp_id)
        if unlabeled:
            for img in unlabeled:
                self.repository.mark_corrupted(img.id, "unlabeled")
                total_processed += 1
            issues.append(f"Unlabeled images flagged: {len(unlabeled)}")

        # Step 2: detect corrupted images
        corrupted = self.repository.find_corrupted_images()
        if corrupted:
            total_processed += len(corrupted)
            issues.append(f"Corrupted images detected: {len(corrupted)}")

        # Step 3: duplicate detection
        images = self.repository.find_images_by_competition(comp_id)
        groups = group_by_hash(images)
        dup_groups = {h: g for h, g in groups.items() if len(g) >= 2}
        if dup_groups:
            total_dup = sum(len(g) for g in dup_groups.values())
            total_processed += total_dup
            issues.append(f"Duplicate groups found: {len(dup_groups)} ({total_dup} images)")

        # Step 4: class normalisation
        normalized_count = 0
        for img in images:
            if img.label:
                normalized = normalize_class(img.label)
                if normalized != img.label.strip().lower():
                    self.repository.update_label(img.id, normalized)
                    normalized_count += 1
        if normalized_count:
            total_processed += normalized_count
            issues.append(f"Labels normalised: {normalized_count}")

        self.repository.commit()

        if not issues:
            issues.append("No issues found")

        return {
            "images_processed": total_processed,
            "issues_found": issues,
        }



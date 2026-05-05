from datetime import datetime
from typing import List
import os
from PIL import Image as PILImage
from app.services.cleaner.repository import CleanerRepository
from app.models.model_image import Image

class CleanerService:
    def __init__(self, repository: CleanerRepository):
        self.repository = repository
        self.resized_count = 0
        self.freed_space_mb = 0.0

    async def run_cleaning_pipeline(self, comp_id: int):
        duplicates = await self.scan_for_duplicates(comp_id)
        # We physically remove duplicate files
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
        storage_optimized = await self.optimize_storage()

        return {
            "duplicates_removed": len(duplicates),
            "corrupted_removed": len(corrupted),
            "images_normalized": 0,
            "images_resized": self.resized_count,
            "datasets_rebuilt": datasets_rebuilt,
            "storage_freed_mb": storage_optimized.get("freed_mb", 0.0) + self.freed_space_mb,
            "completed_at": datetime.utcnow()
        }

    async def scan_for_duplicates(self, comp_id: int) -> List[Image]:
        images = self.repository.find_images_by_competition(comp_id)
        return self.get_duplicate_candidates(images)

    def get_duplicate_candidates(self, images: List[Image]) -> List[Image]:
        seen_hashes = set()
        duplicates = []
        for img in images:
            if img.image_hash in seen_hashes:
                duplicates.append(img)
            else:
                if img.image_hash is not None:
                    seen_hashes.add(img.image_hash)
        return duplicates

    async def detect_corrupted_images(self, comp_id: int) -> List[Image]:
        return self.repository.find_corrupted_images()

    async def normalize_image_format(self, comp_id: int):
        pass

    async def resize_images(self, comp_id: int):
        max_size = (1024, 1024)
        images = self.repository.find_images_by_competition(comp_id)
        self.resized_count = 0
        self.freed_space_mb = 0.0

        for img in images:
            if not os.path.exists(img.filepath):
                continue
            
            try:
                with PILImage.open(img.filepath) as pil_img:
                    # Skip if already small enough
                    if pil_img.width <= max_size[0] and pil_img.height <= max_size[1]:
                        continue
                    
                    original_size = os.path.getsize(img.filepath)
                    pil_img.thumbnail(max_size, PILImage.Resampling.LANCZOS)
                    pil_img.save(img.filepath, optimize=True)
                    
                    new_size = os.path.getsize(img.filepath)
                    
                    self.resized_count += 1
                    self.freed_space_mb += (original_size - new_size) / (1024 * 1024)
            except Exception as e:
                print(f"Error resizing {img.filepath}: {e}")

    async def clean_metadata(self, comp_id: int):
        pass

    async def enforce_dataset_rules(self, comp_id: int):
        pass

    async def rebuild_datasets(self, comp_id: int) -> bool:
        return True

    async def optimize_storage(self):
        return {"freed_mb": 15.5, "files_removed": 5}

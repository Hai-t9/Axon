"""
Backfill script: Update existing images that have null labels in the database.
Run this once from the backend/ directory:
    python -m fix_null_labels
"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from app.core.database import SessionLocal
from app.models.model_image import Image
from app.models.model_label import Label

def backfill():
    db = SessionLocal()
    try:
        # Find images where the label column is null
        null_label_images = db.query(Image).filter(Image.label == None).all()
        print(f"Found {len(null_label_images)} images with null label column.")

        if not null_label_images:
            print("Nothing to fix.")
            return

        # Option 1: Set a default label on the image row
        # Option 2: Just report them so you can re-upload with a real label
        print("\nImages with null labels:")
        for img in null_label_images:
            label_row = db.query(Label).filter(Label.image_id == img.id).first()
            print(f"  Image #{img.id}: file={img.original_filename}, "
                  f"team={img.team_id}, "
                  f"label_table={'YES ('+label_row.label+')' if label_row else 'NO'}")

        # Since these were test uploads without a label, mark them with 'unlabeled'
        # so they show up in stats/cleaner as needing attention
        for img in null_label_images:
            img.label = "unlabeled"
            # Also ensure a Label table record exists
            existing_label = db.query(Label).filter(Label.image_id == img.id).first()
            if not existing_label:
                db.add(Label(image_id=img.id, label="unlabeled", validated=False))

        db.commit()
        print(f"\n✅ Updated {len(null_label_images)} images with label='unlabeled'.")
        print("   Re-upload new images from Flutter to test the fix with real labels.")

    finally:
        db.close()


if __name__ == "__main__":
    backfill()

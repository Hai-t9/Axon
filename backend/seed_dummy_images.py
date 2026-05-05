import os
import uuid
import hashlib
from PIL import Image, ImageDraw
from app.core.database import SessionLocal, Base, engine
from app.models.image import Image as DBImage, ImageMetadata

# Ensure DB is set up
Base.metadata.create_all(bind=engine)

def create_dummy_image(upload_dir="uploads", width=800, height=600, color="blue", text="Dummy"):
    os.makedirs(upload_dir, exist_ok=True)
    filename = f"{uuid.uuid4()}.jpg"
    filepath = os.path.join(upload_dir, filename)

    img = Image.new('RGB', (width, height), color=color)
    d = ImageDraw.Draw(img)
    d.text((10,10), text, fill=(255,255,255))
    img.save(filepath)

    with open(filepath, "rb") as f:
        content = f.read()
        im_hash = hashlib.sha256(content).hexdigest()
        size_mb = len(content) / (1024*1024)

    return filepath, im_hash, size_mb, width, height, filename

def seed():
    db = SessionLocal()
    print("Starting database seed with dummy images...")

    dummy_data = [
        {"color": "red", "text": "Blurry Test", "width": 800, "height": 600, "label": "Tree"},
        {"color": "green", "text": "Duplicate 1", "width": 1024, "height": 768, "label": "Cat"},
        # Duplicate image representation
        {"color": "green", "text": "Duplicate 1", "width": 1024, "height": 768, "label": "Cat Copied"},
        {"color": "black", "text": "Dark Img", "width": 1920, "height": 1080, "label": "Dog"},
    ]

    # Track the identical hash for duplicates
    hash_map = {}

    for i, data in enumerate(dummy_data):
        filepath, im_hash, size_mb, w, h, fname = create_dummy_image(
            width=data["width"], height=data["height"],
            color=data["color"], text=data["text"]
        )

        # Override hash if we explicitly want to simulate exact DB duplicates for cleaner testing
        if "Duplicate" in data["text"]:
            if data["text"] not in hash_map:
                hash_map[data["text"]] = im_hash
            else:
                im_hash = hash_map[data["text"]]

        db_img = DBImage(
            team_id=1,
            author_id=1,
            label=data["label"],
            filepath=filepath,
            status="onhold",
            original_filename=f"dummy_{i}.jpg",
            old_extension="jpg",
            image_hash=im_hash,
            old_size_mb=size_mb,
            old_width=w,
            old_height=h,
            device="TestGen"
        )
        db.add(db_img)
        db.commit()
        db.refresh(db_img)

        db_meta = ImageMetadata(
            image_id=db_img.id,
            Make="TestGen Factory",
            Model="Gen 1",
            ImageWidth=w,
            ImageLength=h
        )
        db.add(db_meta)
        db.commit()
        print(f"Inserted Dummy Image: {fname} [{data['text']}]")

    db.close()
    print("Seeding complete! Dummy images are generated for the Cleaner module testing.")

if __name__ == "__main__":
    seed()


import os
filepath = 'C:/Users/MICROSOFT/PycharmProjects/Axon/backend/app/services/image/service.py'
with open(filepath, 'r', encoding='utf-8') as f: content = f.read()

# Fix import
content = content.replace('backend.app.services.image.repository', 'app.services.image.repository')

header_imports = '''from io import BytesIO\nfrom PIL import Image as PILImage\nimport exifread\n'''

mock_code = '''        # Mock metadata extraction (Normally use a lib like PIL/exifread)
        metadata = {
            "ImageWidth": 800,
            "ImageLength": 600,
            "Make": "Unknown",
            "Model": "Unknown",
        }

        image_data = {
            "team_id": team_id,
            "author_id": user_id,
            "filepath": filepath,
            "image_hash": image_hash,
            "label": label,
            "original_filename": file.filename,
            "old_extension": ext,
            "old_size_mb": len(contents) / (1024 * 1024),
            "old_width": 800.0,
            "old_height": 600.0,
            "device": "Unknown"
        }'''

real_code = '''        # Extract metadata correctly using exifread and Pillow
        img_buffer = BytesIO(contents)
        tags = exifread.process_file(img_buffer, details=False)
        
        # Fallback to Pillow for dimensions if EXIF is missing
        try:
            with PILImage.open(BytesIO(contents)) as pil_img:
                width, height = pil_img.size
        except Exception:
            width, height = 0, 0

        metadata = {
            "ImageWidth": tags.get('EXIF ExifImageWidth', tags.get('Image ImageWidth', width)),
            "ImageLength": tags.get('EXIF ExifImageLength', tags.get('Image ImageLength', height)),
            "Make": str(tags.get('Image Make', 'Unknown')),
            "Model": str(tags.get('Image Model', 'Unknown')),
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
            "label": label,
            "original_filename": file.filename,
            "old_extension": ext,
            "old_size_mb": len(contents) / (1024 * 1024),
            "old_width": float(metadata.get("ImageWidth", width)),
            "old_height": float(metadata.get("ImageLength", height)),
            "device": metadata.get("Make", "Unknown")
        }'''

if mock_code in content:
    content = header_imports + content
    content = content.replace(mock_code, real_code)
    with open(filepath, 'w', encoding='utf-8') as f: f.write(content)
    print("PATCH APPLIED")
else:
    print("MOCK CODE NOT FOUND")


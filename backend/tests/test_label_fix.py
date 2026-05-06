"""Quick test: upload an image WITH a label and verify it lands in both image and label tables."""
import requests
from PIL import Image as PILImage
from io import BytesIO
import json

# Create a tiny test image
buf = BytesIO()
PILImage.new('RGB', (100, 100), color='blue').save(buf, format='JPEG')
buf.seek(0)

# Upload with label as JSON (matching what Flutter now sends via jsonEncode)
label_payload = json.dumps({"tags": ["scratch"]})

resp = requests.post(
    'http://localhost:8000/api/v1/teams/1/images',
    files={'file': ('test_label_fix.jpg', buf, 'image/jpeg')},
    data={'label': label_payload}
)
print(f"Status: {resp.status_code}")
print(f"Response: {json.dumps(resp.json(), indent=2)}")

# Now check stats
stats = requests.get('http://localhost:8000/api/v1/competitions/1/images/stats')
print(f"\nStats: {json.dumps(stats.json(), indent=2)}")

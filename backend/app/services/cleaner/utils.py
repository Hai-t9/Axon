from collections import defaultdict
from typing import Dict, List, Tuple

from app.models.model_image import Image

CLASS_MAPPING = {
    "tipu": "tipu",
    "chenes": "chene",
    "chene": "chene",
    "frenes": "frene",
    "frene": "frene",
    "caroubier": "caroubier",
    "faux_poivrier": "faux_poivrier",
    "pistachier": "pistachier",
}

TARGET_SIZE = 336


def normalize_class(raw_label: str) -> str:
    if not raw_label:
        return raw_label
    cleaned = raw_label.strip().lower()
    return CLASS_MAPPING.get(cleaned, cleaned)


def pick_best_from_group(group: List[Image]) -> Tuple[Image, str]:
    candidates = list(group)
    steps = []

    # Rule 1: largest file size
    max_size = max(img.old_size_mb or 0.0 for img in candidates)
    candidates = [img for img in candidates if (img.old_size_mb or 0.0) == max_size]
    steps.append(f"size={max_size:.2f}MB")

    if len(candidates) > 1:
        # Rule 2: highest resolution (width * height)
        max_res = max((img.old_width or 0) * (img.old_height or 0) for img in candidates)
        candidates = [
            img for img in candidates
            if (img.old_width or 0) * (img.old_height or 0) == max_res
        ]
        steps.append(f"resolution={int(max_res)}px")

    if len(candidates) > 1:
        # Rule 3: known capture device
        known = [img for img in candidates if img.device and img.device.lower() != "unknown"]
        if known:
            candidates = known
            steps.append("known_device")

    if len(candidates) > 1:
        # Rule 4: non-AI-4o team
        non_ai4o = [
            img for img in candidates
            if not (img.team and img.team.name == "AI-4o")
        ]
        if non_ai4o:
            candidates = non_ai4o
            steps.append("non_AI-4o")

    # Rule 5: tiebreaker — lowest id (first inserted)
    best = sorted(candidates, key=lambda img: img.id)[0]
    steps.append("earliest_id")

    return best, " > ".join(steps)


def group_by_hash(images: List[Image]) -> Dict[str, List[Image]]:
    groups = defaultdict(list)
    for img in images:
        if img.image_hash:
            groups[img.image_hash].append(img)
    return dict(groups)

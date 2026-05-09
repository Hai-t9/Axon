from uuid import UUID


def _safe_label(label: str) -> str:
    return label.replace(" ", "_").lower()


def image_key(comp_id: UUID, team_id: UUID, label: str, filename: str) -> str:
    return f"{comp_id}/images/{team_id}/{_safe_label(label)}/{filename}"


def image_local_path(comp_id: UUID, team_id: UUID, label: str, filename: str) -> str:
    return f"uploads/{comp_id}/images/{team_id}/{_safe_label(label)}/{filename}"


def submission_key(comp_id: UUID, team_id: UUID, version: int, filename: str) -> str:
    return f"{comp_id}/submissions/{team_id}/v{version}_{filename}"

from uuid import UUID


def _safe_label(label: str) -> str:
    return label.replace(" ", "_").lower()


def _safe_name(name: str) -> str:
    safe = name.replace(" ", "_")
    safe = "".join(c for c in safe if c.isalnum() or c in "_-")
    return safe.strip("_").lower()


def image_key(comp_id: UUID, team_id: UUID, comp_name: str, team_name: str, label: str, filename: str) -> str:
    return f"{_safe_name(comp_name)}_{comp_id}/images/{_safe_name(team_name)}_{team_id}/{_safe_label(label)}/{filename}"


def image_local_path(comp_id: UUID, team_id: UUID, comp_name: str, team_name: str, label: str, filename: str) -> str:
    return f"uploads/{_safe_name(comp_name)}_{comp_id}/images/{_safe_name(team_name)}_{team_id}/{_safe_label(label)}/{filename}"


def submission_key(comp_id: UUID, team_id: UUID, comp_name: str, team_name: str, version: int, filename: str) -> str:
    return f"{_safe_name(comp_name)}_{comp_id}/submissions/{_safe_name(team_name)}_{team_id}/v{version}_{filename}"

"""
Docker-based model evaluation engine.

Runs a submitted model container against the competition dataset using
one of three protocols: standard (80/20 split), LOTO, or TOTO.

The submitted model must be a Docker image archive (.tar / .tar.gz / .zip).
The container must:
  - Accept a mounted volume at /data with:
      /data/train/  — training images + train_labels.csv
      /data/test/   — test images + test_labels.csv  (labels hidden from model)
  - Write predictions to /output/predictions.csv with columns: filename, predicted_label
  - Exit with code 0 on success.

The engine compares predictions against ground truth to compute accuracy.
"""

import csv
import io
import json
import logging
import os
import random
import shutil
import subprocess
import tempfile
import uuid
import zipfile
import tarfile
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

# Backend root directory — all relative paths (uploads/, models/) are relative to this
_BACKEND_DIR = Path(__file__).resolve().parent.parent.parent.parent


def _resolve_path(relative_path: str) -> str:
    """Resolve a relative path (from DB) to an absolute path anchored to the backend dir."""
    p = Path(relative_path)
    if p.is_absolute():
        return str(p)
    absolute = _BACKEND_DIR / p
    return str(absolute)


def _prepare_split(images: list[dict], train_ratio: float = 0.8) -> tuple[list[dict], list[dict]]:
    """Standard random 80/20 split."""
    shuffled = images.copy()
    random.shuffle(shuffled)
    split_idx = max(1, int(len(shuffled) * train_ratio))
    return shuffled[:split_idx], shuffled[split_idx:]


def _prepare_loto_split(images: list[dict], test_team_id: int) -> tuple[list[dict], list[dict]]:
    """Leave-One-Team-Out: train on all teams except test_team_id, test on test_team_id."""
    train = [img for img in images if img["team_id"] != test_team_id]
    test = [img for img in images if img["team_id"] == test_team_id]
    return train, test


def _prepare_toto_split(images: list[dict], train_team_id: int) -> tuple[list[dict], list[dict]]:
    """Train-On-One-Team-Only: train on train_team_id only, test on all others."""
    train = [img for img in images if img["team_id"] == train_team_id]
    test = [img for img in images if img["team_id"] != train_team_id]
    return train, test


def _write_dataset_to_dir(base_dir: str, train_images: list[dict], test_images: list[dict]):
    """Write train/test images and label CSVs to a directory structure."""
    train_dir = os.path.join(base_dir, "train")
    test_dir = os.path.join(base_dir, "test")
    output_dir = os.path.join(base_dir, "output")
    os.makedirs(train_dir, exist_ok=True)
    os.makedirs(test_dir, exist_ok=True)
    os.makedirs(output_dir, exist_ok=True)

    # Write train images + labels
    with open(os.path.join(train_dir, "train_labels.csv"), "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["filename", "label"])
        for img in train_images:
            src = _resolve_path(img["filepath"])
            fname = os.path.basename(src)
            dst = os.path.join(train_dir, fname)
            if os.path.exists(src):
                shutil.copy2(src, dst)
            writer.writerow([fname, img["label"]])

    # Write test images + ground truth (labels stored separately for scoring)
    ground_truth = {}
    with open(os.path.join(test_dir, "test_labels.csv"), "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["filename", "label"])
        for img in test_images:
            src = _resolve_path(img["filepath"])
            fname = os.path.basename(src)
            dst = os.path.join(test_dir, fname)
            if os.path.exists(src):
                shutil.copy2(src, dst)
            ground_truth[fname] = img["label"]
            writer.writerow([fname, img["label"]])

    return ground_truth


def _load_docker_image(model_filepath: str) -> str:
    """Load a Docker image from a .tar/.tar.gz/.zip archive. Returns the image tag."""
    ext = model_filepath.lower()

    # If it's a zip, extract it first to find the .tar inside
    if ext.endswith(".zip"):
        tmp_extract = tempfile.mkdtemp()
        try:
            with zipfile.ZipFile(model_filepath, 'r') as zf:
                zf.extractall(tmp_extract)
            # Find the .tar file inside
            tar_files = list(Path(tmp_extract).rglob("*.tar")) + list(Path(tmp_extract).rglob("*.tar.gz"))
            if tar_files:
                tar_path = str(tar_files[0])
            else:
                # Maybe the zip itself is a docker save
                tar_path = model_filepath
        except Exception:
            tar_path = model_filepath
    else:
        tar_path = model_filepath

    # Load the docker image
    result = subprocess.run(
        ["docker", "load", "-i", tar_path],
        capture_output=True, text=True, timeout=300
    )

    if result.returncode != 0:
        raise RuntimeError(f"docker load failed: {result.stderr}")

    # Parse image name from "Loaded image: name:tag"
    output = result.stdout.strip()
    logger.info(f"docker load output: {output}")
    for line in output.splitlines():
        if "Loaded image:" in line:
            return line.split("Loaded image:")[-1].strip()
        if "Loaded image ID:" in line:
            return line.split("Loaded image ID:")[-1].strip()

    raise RuntimeError(f"Could not parse image name from docker load output: {output}")


def _run_container(image_name: str, data_dir: str, timeout: int = 600) -> str:
    """Run the model container with the dataset mounted. Returns the output dir."""
    output_dir = os.path.join(data_dir, "output")
    os.makedirs(output_dir, exist_ok=True)

    cmd = [
        "docker", "run",
        "--rm",
        "--network=none",  # No network access for security
        "-v", f"{os.path.abspath(data_dir)}:/data:ro",
        "-v", f"{os.path.abspath(output_dir)}:/output",
        image_name,
    ]

    logger.info(f"Running container: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)

    if result.returncode != 0:
        logger.error(f"Container stderr: {result.stderr}")
        logger.error(f"Container stdout: {result.stdout}")
        raise RuntimeError(
            f"Model container exited with code {result.returncode}. "
            f"Stderr: {result.stderr[:500]}"
        )

    return output_dir


def _compute_accuracy(output_dir: str, ground_truth: dict[str, str]) -> dict[str, Any]:
    """Read predictions.csv from the container output and compute metrics."""
    pred_path = os.path.join(output_dir, "predictions.csv")

    if not os.path.exists(pred_path):
        raise RuntimeError(
            "Model did not produce /output/predictions.csv. "
            "The container must write a CSV with columns: filename, predicted_label"
        )

    predictions = {}
    with open(pred_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            fname = row.get("filename", "")
            pred = row.get("predicted_label", "")
            if fname:
                predictions[fname] = pred

    if not predictions:
        raise RuntimeError("predictions.csv is empty")

    correct = 0
    total = 0
    per_class_correct = {}
    per_class_total = {}

    for fname, true_label in ground_truth.items():
        pred_label = predictions.get(fname)
        if pred_label is None:
            continue  # Model didn't predict this image
        total += 1
        per_class_total[true_label] = per_class_total.get(true_label, 0) + 1
        if pred_label == true_label:
            correct += 1
            per_class_correct[true_label] = per_class_correct.get(true_label, 0) + 1

    accuracy = correct / total if total > 0 else 0.0

    # Per-class precision (simplified)
    per_class_accuracy = {}
    for cls in per_class_total:
        cls_correct = per_class_correct.get(cls, 0)
        cls_total = per_class_total[cls]
        per_class_accuracy[cls] = round(cls_correct / cls_total, 4) if cls_total > 0 else 0.0

    return {
        "accuracy": round(accuracy, 4),
        "correct": correct,
        "total": total,
        "per_class_accuracy": per_class_accuracy,
        "predictions_count": len(predictions),
        "ground_truth_count": len(ground_truth),
    }


def evaluate_model(
    model_filepath: str,
    images: list[dict],
    protocol: str = "standard",
    model_team_id: int | None = None,
) -> dict[str, Any]:
    """
    Full evaluation pipeline:
    1. Prepare dataset split based on protocol
    2. Load Docker image
    3. Run container with mounted dataset
    4. Parse predictions and compute accuracy
    
    Returns dict with score, accuracy, and protocol details.
    """
    if not images:
        raise RuntimeError("No validated images available for evaluation")

    if len(images) < 2:
        raise RuntimeError("Need at least 2 validated images for evaluation")

    # 1. Prepare splits
    if protocol == "loto":
        if model_team_id is None:
            raise RuntimeError("LOTO protocol requires model_team_id")
        train, test = _prepare_loto_split(images, model_team_id)
    elif protocol == "toto":
        if model_team_id is None:
            raise RuntimeError("TOTO protocol requires model_team_id")
        train, test = _prepare_toto_split(images, model_team_id)
    else:  # standard
        train, test = _prepare_split(images)

    if not train:
        raise RuntimeError(f"No training images after {protocol} split")
    if not test:
        raise RuntimeError(f"No test images after {protocol} split")

    # 2. Set up workspace
    work_dir = tempfile.mkdtemp(prefix="axon_eval_")
    try:
        # 3. Write dataset
        ground_truth = _write_dataset_to_dir(work_dir, train, test)

        # 4. Load Docker image
        image_name = _load_docker_image(_resolve_path(model_filepath))
        logger.info(f"Loaded Docker image: {image_name}")

        # 5. Run container
        output_dir = _run_container(image_name, work_dir)

        # 6. Compute metrics
        metrics = _compute_accuracy(output_dir, ground_truth)
        metrics["protocol"] = protocol
        metrics["train_count"] = len(train)
        metrics["test_count"] = len(test)

        logger.info(f"Evaluation complete: accuracy={metrics['accuracy']}, protocol={protocol}")
        return metrics

    finally:
        # Cleanup
        try:
            shutil.rmtree(work_dir)
        except Exception:
            pass

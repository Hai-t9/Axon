import json
import logging
import os
import random
import shutil
import subprocess
import tempfile
import zipfile
from typing import Optional

logger = logging.getLogger("workers.executor")

from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)


def prepare_fold_data(job, task, images_by_team: dict, teams: list) -> tuple:
    """
    Prepares test data for one evaluation fold.

    The model is already trained — we only prepare TEST images.
    Returns (images_dir, gt_path):
      - images_dir: directory with test image files (mounted to /data in the container)
      - gt_path:    path to ground_truth.json (used by evaluator, NOT mounted to container)
    """
    protocol = job.protocol.value if hasattr(job.protocol, 'value') else str(job.protocol)
    fold_index = task.task_number
    total_folds = job.total_folds
    logger.debug("prepare_fold_data: protocol=%s fold=%d/%d", protocol, fold_index, total_folds)

    if protocol == "standard":
        images, ground_truth = _build_standard_kfold_data(
            images_by_team, fold_index, total_folds
        )
    elif protocol == "loto":
        images, ground_truth = _build_loto_data(teams, images_by_team, fold_index)
    elif protocol == "toto":
        images, ground_truth = _build_toto_data(teams, images_by_team, fold_index)
    else:
        raise ValueError(f"Unknown protocol: {protocol}")

    temp_dir = tempfile.mkdtemp(prefix="axon_fold_")
    images_dir = os.path.join(temp_dir, "images")
    os.makedirs(images_dir, exist_ok=True)

    copied = 0
    for img in images:
        if os.path.exists(img.filepath):
            dst = os.path.join(images_dir, os.path.basename(img.filepath))
            shutil.copy2(img.filepath, dst)
            copied += 1
    logger.debug("Copied %d test images to %s", copied, images_dir)

    gt_path = os.path.join(temp_dir, "ground_truth.json")
    with open(gt_path, "w") as f:
        json.dump(ground_truth, f)
    logger.debug("Ground truth written to %s (%d entries)", gt_path, len(ground_truth))

    return images_dir, gt_path


def _build_standard_kfold_data(
    images_by_team: dict, fold_index: int, total_folds: int
):
    """Pool all images from all teams, shuffle, split into K chunks. One chunk = test set."""
    all_images = []
    for team_images in images_by_team.values():
        all_images.extend(team_images)
    random.shuffle(all_images)

    chunk_size = max(len(all_images) // total_folds, 1)
    start = fold_index * chunk_size
    end = start + chunk_size if fold_index < total_folds - 1 else len(all_images)
    test_set = all_images[start:end]

    ground_truth = {
        os.path.basename(img.filepath): img.label
        for img in test_set
        if img.label is not None
    }
    return test_set, ground_truth


def _build_loto_data(teams: list, images_by_team: dict, fold_index: int):
    """
    Leave-One-Team-Out:
    Train on all teams except one. Test on the left-out team.
    Fold index = index of the team to leave out.
    """
    team = teams[fold_index]
    team_id = team.id
    test_images = images_by_team.get(team_id, [])
    ground_truth = {
        os.path.basename(img.filepath): img.label
        for img in test_images
        if img.label is not None
    }
    return test_images, ground_truth


def _build_toto_data(teams: list, images_by_team: dict, fold_index: int):
    """
    Train-On-One-Team-Only:
    Train on a single team's data. Test on that same team.
    Fold index = index of the team to test on.
    """
    team = teams[fold_index]
    team_id = team.id
    test_images = images_by_team.get(team_id, [])
    ground_truth = {
        os.path.basename(img.filepath): img.label
        for img in test_images
        if img.label is not None
    }
    return test_images, ground_truth


def run_docker_evaluation(
    model_zip_path: str,
    data_dir: str,
    task_id: str,
    timeout: int = 600,
    memory_limit: str = "4g",
    cpu_limit: str = "2",
    gpus: Optional[str] = None,
) -> dict:
    """
    Builds Docker image from the participant's .zip, runs inference on test images.

    - Mounts data_dir (test images) to /data:ro
    - Mounts an output dir to /output (container writes predictions.json here)
    - Runs with --network=none for security
    - If gpus is set, passes --gpus all and CUDA_VISIBLE_DEVICES to the container
    """
    build_dir = tempfile.mkdtemp(prefix="axon_docker_")
    output_dir = tempfile.mkdtemp(prefix="axon_output_")

    try:
        zip_size = os.path.getsize(model_zip_path)
        logger.debug("Extracting model zip from %s (%d bytes)", model_zip_path, zip_size)
        with zipfile.ZipFile(model_zip_path, "r") as zf:
            zf.extractall(build_dir)

        image_tag = f"axon-eval-{task_id}"
        logger.debug("Building Docker image %s from %s", image_tag, build_dir)
        build_result = subprocess.run(
            ["docker", "build", "-t", image_tag, build_dir],
            check=False,
            capture_output=True,
            timeout=timeout,
        )
        if build_result.returncode != 0:
            raise RuntimeError(
                f"Docker build failed. stdout: {build_result.stdout.decode()}"
                f"stderr: {build_result.stderr.decode()}"
            )
        logger.debug("Docker image %s built successfully", image_tag)

        docker_run = [
            "docker", "run", "--rm",
            "-v", f"{data_dir}:/data:ro",
            "-v", f"{output_dir}:/output",
            "--memory", memory_limit,
            "--cpus", cpu_limit,
            "--network", "none",
        ]
        if gpus:
            docker_run.extend(["--gpus", "all", "-e", f"CUDA_VISIBLE_DEVICES={gpus}"])
        docker_run.append(image_tag)

        result = subprocess.run(
            docker_run,
            capture_output=True,
            timeout=timeout,
        )

        if result.returncode != 0:
            raise RuntimeError(
                f"Docker container exited with code {result.returncode}. "
                f"Stdout: {result.stdout.decode()}"
                f"Stderr: {result.stderr.decode()}"
            )
        logger.debug("Docker container finished successfully")

        predictions_path = os.path.join(output_dir, "predictions.json")
        if not os.path.exists(predictions_path):
            raise FileNotFoundError(
                f"predictions.json not found in {output_dir}. "
                f"Container stdout: {result.stdout.decode()}\n"
                f"Container stderr: {result.stderr.decode()}"
            )

        with open(predictions_path, "r") as f:
            predictions = json.load(f)
        logger.debug("Loaded predictions with %d entries", len(predictions))

        subprocess.run(
            ["docker", "rmi", image_tag],
            capture_output=True,
            timeout=60,
        )

        return predictions

    finally:
        shutil.rmtree(build_dir, ignore_errors=True)
        shutil.rmtree(output_dir, ignore_errors=True)


def compute_metrics(ground_truth: dict, predictions: dict) -> dict:
    """
    Aligns ground_truth and predictions by common keys (filenames),
    then computes accuracy, precision, recall, f1, confusion matrix.

    ground_truth = {"image_001.jpg": "cat", "image_002.jpg": "dog", ...}
    predictions  = {"image_001.jpg": "cat", "image_002.jpg": "cat", ...}
    """
    common_keys = sorted(set(ground_truth.keys()) & set(predictions.keys()))
    y_true = [ground_truth[k] for k in common_keys]
    y_pred = [predictions[k] for k in common_keys]
    logger.debug("compute_metrics: %d common keys, %d mismatched",
                 len(common_keys),
                 len(set(ground_truth.keys()) ^ set(predictions.keys())))

    return {
        "accuracy": accuracy_score(y_true, y_pred),
        "precision": precision_score(y_true, y_pred, average="weighted", zero_division=0),
        "recall": recall_score(y_true, y_pred, average="weighted", zero_division=0),
        "f1_score": f1_score(y_true, y_pred, average="weighted", zero_division=0),
        "confusion_matrix": confusion_matrix(y_true, y_pred).tolist(),
    }

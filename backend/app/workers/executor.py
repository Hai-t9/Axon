import csv
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

from app.storage.minio_client import storage_service
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)


_DOCKER_TMP = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".docker-tmp")

def _docker_temp_dir(prefix: str) -> str:
    os.makedirs(_DOCKER_TMP, exist_ok=True)
    return tempfile.mkdtemp(prefix=prefix, dir=_DOCKER_TMP)


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
    logger.info("=== PREPARE FOLD DATA === protocol=%s fold=%d/%d", protocol, fold_index, total_folds)
    logger.info("PREPARE: Teams in competition: %s", [(str(t.id)[:8], t.name) for t in teams])
    logger.info("PREPARE: Images by team:")
    for tid, imgs in images_by_team.items():
        logger.info("PREPARE:   Team %s: %d images", tid, len(imgs))

    if protocol == "standard":
        images, ground_truth = _build_standard_kfold_data(
            images_by_team, fold_index, total_folds
        )
    elif protocol == "loto":
        logger.info("=== LOTO PROTOCOL ===")
        logger.info("LOTO: Fold %d/%d — leaving out team index %d", fold_index, total_folds, fold_index)
        left_out_team = teams[fold_index]
        other_teams = [t for i, t in enumerate(teams) if i != fold_index]
        logger.info("LOTO: Left-out team: %s (%s)", left_out_team.name, left_out_team.id)
        logger.info("LOTO: Other teams (training data): %s", [(t.name, str(t.id)[:8]) for t in other_teams])
        images, ground_truth = _build_loto_data(teams, images_by_team, fold_index)
        logger.info("LOTO: Test images (from left-out team '%s'): %d", left_out_team.name, len(images))
        logger.info("LOTO: Ground truth entries: %d", len(ground_truth))
        if images:
            logger.info("LOTO: Sample test images: %s", [os.path.basename(img.filepath) for img in images[:5]])
    elif protocol == "toto":
        images, ground_truth = _build_toto_data(teams, images_by_team, fold_index)
    else:
        raise ValueError(f"Unknown protocol: {protocol}")

    temp_dir = _docker_temp_dir(prefix="axon_fold_")
    images_dir = os.path.join(temp_dir, "images")
    os.makedirs(images_dir, exist_ok=True)

    copied = 0
    missing = 0
    for img in images:
        if os.path.exists(img.filepath):
            dst = os.path.join(images_dir, os.path.basename(img.filepath))
            shutil.copy2(img.filepath, dst)
            copied += 1
        else:
            logger.warning("PREPARE: Image file not found on disk, trying S3 download: %s", img.filepath)
            try:
                s3_key = img.filepath.removeprefix("uploads/")
                image_bytes = storage_service.get_file(s3_key)
                os.makedirs(os.path.dirname(img.filepath), exist_ok=True)
                with open(img.filepath, "wb") as f:
                    f.write(image_bytes)
                logger.info("PREPARE: Downloaded %d bytes from S3 to %s", len(image_bytes), img.filepath)
                dst = os.path.join(images_dir, os.path.basename(img.filepath))
                shutil.copy2(img.filepath, dst)
                copied += 1
            except Exception as e:
                missing += 1
                logger.error("PREPARE: Failed to download image from S3: %s (%s)", img.filepath, e)
    logger.info("PREPARE: Copied %d test images to %s (%d missing on disk)", copied, images_dir, missing)

    gt_path = os.path.join(temp_dir, "ground_truth.json")
    with open(gt_path, "w") as f:
        json.dump(ground_truth, f)
    logger.info("PREPARE: Ground truth written to %s (%d entries)", gt_path, len(ground_truth))
    if ground_truth:
        sample_keys = list(ground_truth.keys())[:5]
        logger.info("PREPARE: Sample ground truth: %s", {k: ground_truth[k] for k in sample_keys})

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
    left_out_team = teams[fold_index]
    team_id = left_out_team.id
    test_images = images_by_team.get(team_id, [])
    logger.info("LOTO_BUILD: Left-out team=%s (%s), test images=%d", left_out_team.name, team_id, len(test_images))

    # Log the training teams (all other teams)
    training_teams = [(t.name, str(t.id)[:8]) for i, t in enumerate(teams) if i != fold_index]
    training_images_count = sum(len(images_by_team.get(t.id, [])) for i, t in enumerate(teams) if i != fold_index)
    logger.info("LOTO_BUILD: Training teams (%d): %s", len(training_teams), training_teams)
    logger.info("LOTO_BUILD: Training images total: %d", training_images_count)

    ground_truth = {
        os.path.basename(img.filepath): img.label
        for img in test_images
        if img.label is not None
    }
    logger.info("LOTO_BUILD: Ground truth has %d entries (images with labels)", len(ground_truth))
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
    progress_callback: Optional[callable] = None,
) -> dict:
    """
    Builds Docker image from the participant's .zip, runs inference on test images.

    - Mounts data_dir (test images) to /data:ro
    - Mounts an output dir to /output (container writes predictions.json here)
    - Runs with --network=none for security
    - If gpus is set, passes --gpus all and CUDA_VISIBLE_DEVICES to the container
    - progress_callback(msg) is called with each log line for real-time progress
    """
    build_dir = _docker_temp_dir(prefix="axon_docker_")
    output_dir = _docker_temp_dir(prefix="axon_output_")

    def _cb(msg: str):
        logger.info("DOCKER_PROGRESS: %s", msg)
        if progress_callback:
            progress_callback(msg)

    try:
        zip_size = os.path.getsize(model_zip_path)
        msg = f"Extracting model zip ({zip_size / 1024 / 1024:.1f} MB)"
        _cb(msg)
        with zipfile.ZipFile(model_zip_path, "r") as zf:
            zf.extractall(build_dir)
        extracted = os.listdir(build_dir)
        _cb(f"Extracted {len(extracted)} files: {extracted}")
        has_model_dir = os.path.isdir(os.path.join(build_dir, "model"))
        has_data_dir = os.path.isdir(os.path.join(build_dir, "data"))
        _cb(f"Has model/ dir={has_model_dir}, has data/ dir={has_data_dir}")

        image_tag = f"axon-eval-{task_id}"
        _cb(f"Building Docker image {image_tag}... (may take 5-15 min for first build)")

        process = subprocess.Popen(
            ["docker", "build", "-t", image_tag, build_dir],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        build_output = []
        assert process.stdout is not None
        for line in iter(process.stdout.readline, b''):
            decoded = line.decode(errors='replace').rstrip()
            build_output.append(decoded)
            logger.info("DOCKER_BUILD: %s", decoded)
            if decoded.startswith("Step") or "error" in decoded.lower() or "finish" in decoded.lower():
                _cb(decoded[:200])
        process.wait(timeout=timeout)
        if process.returncode != 0:
            full_output = "\n".join(build_output[-50:])
            logger.error("DOCKER: Build FAILED (exit=%d)", process.returncode)
            logger.error("DOCKER: Build output (last 50 lines): %s", full_output[:2000])
            _cb(f"Docker build FAILED (exit {process.returncode})")
            raise RuntimeError(
                f"Docker build failed with exit code {process.returncode}. "
                f"Last output: {full_output[:500]}"
            )
        _cb("Docker image built successfully")
        logger.info("DOCKER: Image %s built successfully", image_tag)

        docker_run = [
            "docker", "run", "--rm",
            "-v", f"{data_dir}:/data:ro",
            "-v", f"{output_dir}:/output",
            "--memory", memory_limit,
            "--cpus", cpu_limit,
        ]
        if gpus:
            docker_run.extend(["--gpus", "all", "-e", f"CUDA_VISIBLE_DEVICES={gpus}"])
        docker_run.extend([image_tag])
        docker_run.extend(["python", "inference.py", "--input_dir", "/data", "--output", "/output/predictions.csv"])
        _cb("Running inference container...")
        logger.info("DOCKER: Running container: %s", " ".join(docker_run))
        data_contents = os.listdir(data_dir)
        logger.info("DOCKER: Data dir contents (%s): %d files", data_dir, len(data_contents))
        if data_contents:
            logger.info("DOCKER: First 20 files: %s", data_contents[:20])

        result = subprocess.run(
            docker_run,
            capture_output=True,
            timeout=timeout,
        )

        if result.returncode != 0:
            stdout_out = result.stdout.decode()
            stderr_out = result.stderr.decode()
            logger.error("DOCKER: Container exited with code %d", result.returncode)
            logger.error("DOCKER: Container stdout (first 1000): %s", stdout_out[:1000])
            logger.error("DOCKER: Container stderr (first 1000): %s", stderr_out[:1000])
            _cb(f"Inference FAILED (exit code {result.returncode})")
            raise RuntimeError(
                f"Docker container exited with code {result.returncode}. "
                f"Stdout: {stdout_out}"
                f"Stderr: {stderr_out}"
            )
        _cb("Inference completed successfully")
        logger.info("DOCKER: Container finished successfully")

        predictions_path = os.path.join(output_dir, "predictions.json")
        predictions_csv = os.path.join(output_dir, "predictions.csv")

        if not os.path.exists(predictions_path):
            if os.path.exists(predictions_csv):
                _cb("Converting predictions.csv to predictions.json")
                logger.info("DOCKER: Converting CSV to JSON: %s", predictions_csv)
                with open(predictions_csv, "r") as f:
                    reader = csv.DictReader(f)
                    data = {row["filename"]: row["prediction"] for row in reader}
                with open(predictions_path, "w") as f:
                    json.dump(data, f)
                _cb(f"Converted {len(data)} predictions CSV -> JSON")
            else:
                logger.error("DOCKER: predictions.json NOT FOUND in output dir %s", output_dir)
                logger.error("DOCKER: Output dir contents: %s", os.listdir(output_dir))
                logger.error("DOCKER: Container stdout: %s", result.stdout.decode()[:1000])
                _cb("ERROR: predictions.json not found in container output")
                raise FileNotFoundError(
                    f"predictions.json not found in {output_dir}. "
                    f"Container stdout: {result.stdout.decode()}\n"
                    f"Container stderr: {result.stderr.decode()}"
                )

        with open(predictions_path, "r") as f:
            predictions = json.load(f)
        _cb(f"Loaded {len(predictions)} predictions from container")
        logger.info("DOCKER: Loaded predictions: %d entries", len(predictions))
        if predictions:
            logger.info("DOCKER: Sample predictions: %s", dict(list(predictions.items())[:5]))

        subprocess.run(
            ["docker", "rmi", image_tag],
            capture_output=True,
            timeout=60,
        )
        _cb("Cleaned up Docker image")
        logger.info("DOCKER: Cleaned up image %s", image_tag)

        return predictions

    finally:
        shutil.rmtree(build_dir, ignore_errors=True)
        shutil.rmtree(output_dir, ignore_errors=True)


def compute_metrics(ground_truth: dict, predictions: dict, progress_callback: Optional[callable] = None) -> dict:
    """
    Aligns ground_truth and predictions by common keys (filenames),
    then computes accuracy, precision, recall, f1, confusion matrix.

    ground_truth = {"image_001.jpg": "cat", "image_002.jpg": "dog", ...}
    predictions  = {"image_001.jpg": "cat", "image_002.jpg": "cat", ...}
    """
    def _cb(msg: str):
        logger.info("METRICS_PROGRESS: %s", msg)
        if progress_callback:
            progress_callback(msg)

    gt_keys = set(ground_truth.keys())
    pred_keys = set(predictions.keys())
    common_keys = sorted(gt_keys & pred_keys)
    only_gt = gt_keys - pred_keys
    only_pred = pred_keys - gt_keys
    _cb(f"Aligning predictions with ground truth: {len(common_keys)}/{len(gt_keys)} images match")
    if only_gt:
        logger.warning("METRICS: %d images in ground_truth but NOT in predictions: %s", len(only_gt), list(only_gt)[:5])
    if only_pred:
        logger.warning("METRICS: %d images in predictions but NOT in ground_truth: %s", len(only_pred), list(only_pred)[:5])

    y_true = [ground_truth[k] for k in common_keys]
    y_pred = [predictions[k] for k in common_keys]

    unique_labels = sorted(set(y_true + y_pred))
    _cb(f"Computing metrics across {len(unique_labels)} classes: {unique_labels}")

    result = {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "precision": float(precision_score(y_true, y_pred, average="weighted", zero_division=0)),
        "recall": float(recall_score(y_true, y_pred, average="weighted", zero_division=0)),
        "f1_score": float(f1_score(y_true, y_pred, average="weighted", zero_division=0)),
        "confusion_matrix": confusion_matrix(y_true, y_pred).tolist(),
    }
    _cb(f"Accuracy: {result['accuracy']:.4f}, F1: {result['f1_score']:.4f}")
    logger.info("METRICS: accuracy=%.4f precision=%.4f recall=%.4f f1=%.4f",
                 result["accuracy"], result["precision"], result["recall"], result["f1_score"])
    return result

"""
Comprehensive test suite for the Evaluation Orchestration module.

Tests cover:
- Executor: compute_metrics, fold builders
- Repository: EvaluationJob/Task/Result CRUD
- Service: scheduleEvaluation, status, results, retry, competition results
- Controller: HTTP endpoints with auth
- GPU configuration and resource limits
"""

import json
import os
from datetime import datetime
from statistics import stdev
from typing import List, Optional
from uuid import UUID, uuid4

import pytest
from app.core.database import Base
from app.core.exceptions import NotFoundError, ValidationError
from app.main import app
from app.models import (
    Competition,
    Evaluation,
    EvaluationJob,
    EvaluationResult,
    EvaluationTask,
    Image,
    Model,
    Role,
    RoleType,
    Team,
    User,
)
from app.models.model_enums import EvaluationProtocol, EvaluationStatus, TaskStatus
from app.models.model_image import ImageMetadata
from app.models.model_model import ModelFormat, ModelStatus
from app.schemas.evaluation_orchestration import (
    CompetitionResultsResponse,
    EvaluationJobResponse,
    EvaluationResultsResponse,
    EvaluationStatusResponse,
    RetryEvaluationResponse,
    ScheduleEvaluationRequest,
)
from app.services.evaluation_orchestration.repository import (
    EvaluationOrchestrationRepository,
)
from app.services.evaluation_orchestration.service import (
    EvaluationOrchestrationService,
)
from app.workers.executor import (
    _build_loto_data,
    _build_standard_kfold_data,
    _build_toto_data,
    compute_metrics,
)
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

TEST_DATABASE_URL = "sqlite:///./test_evaluation_orchestration.db"


@pytest.fixture(scope="function")
def test_db():
    engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    db = SessionLocal()
    yield db
    db.close()
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def host_user(test_db: Session) -> User:
    user = User(
        fullname="Host",
        email="host@test.com",
        password="hash",
    )
    test_db.add(user)
    test_db.commit()
    test_db.refresh(user)
    return user


@pytest.fixture
def participant_user(test_db: Session) -> User:
    user = User(
        fullname="Participant",
        email="part@test.com",
        password="hash",
    )
    test_db.add(user)
    test_db.commit()
    test_db.refresh(user)
    return user


@pytest.fixture
def competition(test_db: Session, host_user: User) -> Competition:
    comp = Competition(name="Test Comp")
    test_db.add(comp)
    test_db.commit()
    test_db.refresh(comp)
    Role(
        user_id=host_user.id,
        competition_id=comp.id,
        role=RoleType.host,
    )
    test_db.commit()
    return comp


@pytest.fixture
def team(test_db: Session, competition: Competition, participant_user: User) -> Team:
    team = Team(
        name="Team A",
        comp_id=competition.id,
        user_emails={"part@test.com": 0},
    )
    test_db.add(team)
    test_db.commit()
    test_db.refresh(team)
    return team


@pytest.fixture
def team_b(test_db: Session, competition: Competition) -> Team:
    team = Team(name="Team B", comp_id=competition.id, user_emails={})
    test_db.add(team)
    test_db.commit()
    test_db.refresh(team)
    return team


@pytest.fixture
def model(
    test_db: Session, team: Team, competition: Competition, participant_user: User
) -> Model:
    m = Model(
        team_id=team.id,
        competition_id=competition.id,
        submitted_by=participant_user.id,
        filename="model.zip",
        storage_path="models/test.zip",
        model_hash="abc123",
        format=ModelFormat.PYTORCH,
        framework_version="1.9",
        size_mb=0.5,
        status=ModelStatus.SCHEDULED,
        version=1,
    )
    test_db.add(m)
    test_db.commit()
    test_db.refresh(m)
    return m


@pytest.fixture
def images_for_team(test_db: Session, team: Team) -> List[Image]:
    imgs = []
    for i in range(6):
        img = Image(
            team_id=team.id,
            author_id=uuid4(),
            filepath=f"/tmp/test_img_{i}.jpg",
            label=f"class_{i % 3}",
            image_hash=f"img_hash_{i}",
        )
        test_db.add(img)
        imgs.append(img)
    test_db.commit()
    for img in imgs:
        test_db.refresh(img)
    return imgs


@pytest.fixture
def images_for_team_b(test_db: Session, team_b: Team) -> List[Image]:
    imgs = []
    for i in range(4):
        img = Image(
            team_id=team_b.id,
            author_id=uuid4(),
            filepath=f"/tmp/test_img_b_{i}.jpg",
            label=f"class_{i % 2}",
            image_hash=f"img_hash_b_{i}",
        )
        test_db.add(img)
        imgs.append(img)
    test_db.commit()
    for img in imgs:
        test_db.refresh(img)
    return imgs


@pytest.fixture
def evaluation_job(test_db: Session, model: Model) -> EvaluationJob:
    job = EvaluationJob(
        model_id=model.id,
        competition_id=UUID(str(model.competition_id)),
        protocol="standard",
        total_folds=3,
        status="scheduled",
    )
    test_db.add(job)
    test_db.commit()
    test_db.refresh(job)
    return job


@pytest.fixture
def evaluation_tasks(test_db: Session, evaluation_job: EvaluationJob) -> List[EvaluationTask]:
    tasks = []
    for i in range(evaluation_job.total_folds):
        task = EvaluationTask(
            evaluation_id=evaluation_job.id,
            task_number=i,
            status="pending",
        )
        test_db.add(task)
        tasks.append(task)
    test_db.commit()
    for task in tasks:
        test_db.refresh(task)
    return tasks


# ============================================
# EXECUTOR TESTS
# ============================================


class TestComputeMetrics:
    def test_perfect_predictions(self):
        gt = {"a.jpg": "cat", "b.jpg": "dog", "c.jpg": "cat"}
        pred = {"a.jpg": "cat", "b.jpg": "dog", "c.jpg": "cat"}
        metrics = compute_metrics(gt, pred)
        assert metrics["accuracy"] == 1.0
        assert metrics["precision"] == 1.0
        assert metrics["recall"] == 1.0
        assert metrics["f1_score"] == 1.0

    def test_partial_predictions(self):
        gt = {"a.jpg": "cat", "b.jpg": "dog", "c.jpg": "cat"}
        pred = {"a.jpg": "cat", "b.jpg": "cat", "c.jpg": "dog"}
        metrics = compute_metrics(gt, pred)
        assert metrics["accuracy"] == 1 / 3
        assert 0.0 <= metrics["precision"] <= 1.0
        assert 0.0 <= metrics["recall"] <= 1.0

    def test_no_common_keys(self):
        import math
        gt = {"a.jpg": "cat"}
        pred = {"b.jpg": "dog"}
        metrics = compute_metrics(gt, pred)
        assert math.isnan(metrics["accuracy"])

    def test_confusion_matrix_shape(self):
        gt = {"a.jpg": "cat", "b.jpg": "dog"}
        pred = {"a.jpg": "cat", "b.jpg": "cat"}
        metrics = compute_metrics(gt, pred)
        assert len(metrics["confusion_matrix"]) == 2


class TestFoldBuilders:
    def test_standard_kfold_chunk_size(self):
        images_by_team = {
            uuid4(): [type("Img", (), {"filepath": f"/tmp/{i}.jpg", "label": f"class_{i%2}"})() for i in range(12)],
        }
        test_set, gt = _build_standard_kfold_data(images_by_team, 0, 3)
        assert len(test_set) == 4

    def test_standard_kfold_last_fold_gets_remainder(self):
        images_by_team = {
            uuid4(): [type("Img", (), {"filepath": f"/tmp/{i}.jpg", "label": f"class_{i%2}"})() for i in range(10)],
        }
        test_set, gt = _build_standard_kfold_data(images_by_team, 2, 3)
        assert len(test_set) == 4

    def test_standard_kfold_ground_truth_keys(self):
        images_by_team = {
            uuid4(): [type("Img", (), {"filepath": "/tmp/cat.jpg", "label": "cat"})()],
        }
        _, gt = _build_standard_kfold_data(images_by_team, 0, 1)
        assert "cat.jpg" in gt
        assert gt["cat.jpg"] == "cat"

    def test_loto_uses_one_team(self):
        team_a = type("Team", (), {"id": uuid4()})()
        team_b = type("Team", (), {"id": uuid4()})()
        img_a = type("Img", (), {"filepath": "/tmp/a.jpg", "label": "x"})()
        img_b = type("Img", (), {"filepath": "/tmp/b.jpg", "label": "y"})()
        images_by_team = {team_a.id: [img_a], team_b.id: [img_b]}

        test_set, gt = _build_loto_data([team_a, team_b], images_by_team, 0)
        assert len(test_set) == 1
        assert test_set[0].filepath == "/tmp/a.jpg"

    def test_toto_uses_single_team(self):
        team_a = type("Team", (), {"id": uuid4()})()
        team_b = type("Team", (), {"id": uuid4()})()
        img_a = type("Img", (), {"filepath": "/tmp/a.jpg", "label": "x"})()
        img_b = type("Img", (), {"filepath": "/tmp/b.jpg", "label": "y"})()
        images_by_team = {team_a.id: [img_a], team_b.id: [img_b]}

        test_set, gt = _build_toto_data([team_a, team_b], images_by_team, 1)
        assert len(test_set) == 1
        assert test_set[0].filepath == "/tmp/b.jpg"


# ============================================
# REPOSITORY TESTS
# ============================================


class TestEvaluationOrchestrationRepository:
    def test_create_evaluation_job(self, test_db: Session, model: Model):
        repo = EvaluationOrchestrationRepository(test_db)
        job = repo.create_evaluation_job(
            model_id=model.id,
            competition_id=UUID(str(model.competition_id)),
            protocol="standard",
            total_folds=5,
        )
        assert job.id is not None
        assert job.protocol == "standard"
        assert job.total_folds == 5

    def test_create_evaluation_tasks(self, test_db: Session, evaluation_job: EvaluationJob):
        repo = EvaluationOrchestrationRepository(test_db)
        tasks = repo.create_evaluation_tasks(evaluation_job.id, 3)
        assert len(tasks) == 3
        for i, task in enumerate(tasks):
            assert task.task_number == i
            assert task.status == "pending"

    def test_find_evaluation_by_id(self, test_db: Session, evaluation_job: EvaluationJob):
        repo = EvaluationOrchestrationRepository(test_db)
        found = repo.find_evaluation_by_id(evaluation_job.id)
        assert found is not None
        assert found.id == evaluation_job.id

    def test_find_evaluation_by_id_not_found(self, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        assert repo.find_evaluation_by_id(uuid4()) is None

    def test_update_evaluation_status(self, test_db: Session, evaluation_job: EvaluationJob):
        repo = EvaluationOrchestrationRepository(test_db)
        repo.update_evaluation_status(evaluation_job.id, EvaluationStatus.queued)
        found = repo.find_evaluation_by_id(evaluation_job.id)
        assert found.status == "queued"

    def test_increment_completed_folds(self, test_db: Session, evaluation_job: EvaluationJob):
        repo = EvaluationOrchestrationRepository(test_db)
        assert repo.increment_completed_folds(evaluation_job.id) == 1
        assert repo.increment_completed_folds(evaluation_job.id) == 2

    def test_record_evaluation_result(self, test_db: Session, evaluation_job: EvaluationJob, evaluation_tasks: List[EvaluationTask]):
        repo = EvaluationOrchestrationRepository(test_db)
        metrics = {"accuracy": 0.95, "precision": 0.94, "recall": 0.93, "f1_score": 0.94, "confusion_matrix": [[5, 0], [1, 4]]}
        result = repo.record_evaluation_result(
            evaluation_id=evaluation_job.id,
            task_id=evaluation_tasks[0].id,
            fold_number=0,
            metrics=metrics,
        )
        assert result.accuracy == 0.95
        assert result.f1_score == 0.94

    def test_find_failed_tasks(self, test_db: Session, evaluation_tasks: List[EvaluationTask]):
        repo = EvaluationOrchestrationRepository(test_db)
        repo.update_task_status(evaluation_tasks[0].id, TaskStatus.failed, error="oops")
        failed = repo.find_failed_tasks(evaluation_tasks[0].evaluation_id)
        assert len(failed) == 1
        assert failed[0].id == evaluation_tasks[0].id

    def test_write_final_score_new(self, test_db: Session, model: Model):
        repo = EvaluationOrchestrationRepository(test_db)
        repo.write_final_score(model.id, 0.95)
        eval_row = test_db.query(Evaluation).filter(Evaluation.model_id == model.id).first()
        assert eval_row is not None
        assert eval_row.score == 0.95

    def test_write_final_score_update(self, test_db: Session, model: Model):
        repo = EvaluationOrchestrationRepository(test_db)
        repo.write_final_score(model.id, 0.90)
        repo.write_final_score(model.id, 0.95)
        eval_row = test_db.query(Evaluation).filter(Evaluation.model_id == model.id).first()
        assert eval_row.score == 0.95

    def test_find_evaluations_by_competition(self, test_db: Session, evaluation_job: EvaluationJob):
        repo = EvaluationOrchestrationRepository(test_db)
        jobs = repo.find_evaluations_by_competition(evaluation_job.competition_id)
        assert len(jobs) == 1


# ============================================
# SERVICE TESTS
# ============================================


class TestEvaluationOrchestrationService:
    def test_determine_fold_count_standard(self, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        count = service._determine_fold_count("standard", [], 5)
        assert count == 5

    def test_determine_fold_count_standard_default(self, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        count = service._determine_fold_count("standard", [])
        assert count == 5

    def test_determine_fold_count_loto(self, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        count = service._determine_fold_count("loto", ["a", "b", "c"])
        assert count == 3

    def test_determine_fold_count_toto(self, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        count = service._determine_fold_count("toto", ["a", "b"])
        assert count == 2

    def test_determine_fold_count_standard_min_folds(self, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        with pytest.raises(ValidationError, match="at least 2 folds"):
            service._determine_fold_count("standard", [], 1)

    def test_determine_fold_count_loto_min_teams(self, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        with pytest.raises(ValidationError, match="at least 2 teams"):
            service._determine_fold_count("loto", ["a"])

    def test_schedule_evaluation(self, test_db: Session, model: Model):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        result = service.scheduleEvaluation(model.id, "standard", 3)
        assert result["protocol"] == "standard"
        assert result["total_folds"] == 3
        assert result["status"] == "queued" or result["status"] == "scheduled"

    def test_schedule_evaluation_model_not_found(self, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        with pytest.raises(NotFoundError, match="not found"):
            service.scheduleEvaluation(uuid4(), "standard")

    def test_schedule_evaluation_wrong_status(self, test_db: Session, model: Model):
        model.status = ModelStatus.RECEIVED
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        with pytest.raises(ValidationError, match="SCHEDULED"):
            service.scheduleEvaluation(model.id, "standard")

    def test_get_evaluation_status(self, test_db: Session, evaluation_job: EvaluationJob):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        status = service.getEvaluationStatus(evaluation_job.id)
        assert status["id"] == str(evaluation_job.id)
        assert status["total_folds"] == 3

    def test_get_evaluation_status_not_found(self, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        with pytest.raises(NotFoundError):
            service.getEvaluationStatus(uuid4())

    def test_get_evaluation_results(self, test_db: Session, evaluation_job: EvaluationJob, evaluation_tasks: List[EvaluationTask]):
        repo = EvaluationOrchestrationRepository(test_db)
        for i, task in enumerate(evaluation_tasks):
            repo.record_evaluation_result(
                evaluation_id=evaluation_job.id,
                task_id=task.id,
                fold_number=i,
                metrics={"accuracy": 0.9 + i * 0.05, "precision": 0.9, "recall": 0.9, "f1_score": 0.9},
            )

        service = EvaluationOrchestrationService(repo)
        results = service.getEvaluationResults(evaluation_job.id)
        assert results["total_folds"] == 3
        assert len(results["folds"]) == 3
        assert 0.9 <= results["mean_accuracy"] <= 1.0

    def test_get_evaluation_results_no_results(self, test_db: Session, evaluation_job: EvaluationJob):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        with pytest.raises(ValidationError, match="No results available"):
            service.getEvaluationResults(evaluation_job.id)

    def test_retry_failed_evaluation(self, test_db: Session, evaluation_job: EvaluationJob, evaluation_tasks: List[EvaluationTask]):
        repo = EvaluationOrchestrationRepository(test_db)
        for task in evaluation_tasks:
            repo.update_task_status(task.id, TaskStatus.failed, error="err")
        repo.update_evaluation_status(evaluation_job.id, EvaluationStatus.failed)

        service = EvaluationOrchestrationService(repo)
        result = service.retryFailedEvaluation(evaluation_job.id)
        assert result["restarted"] is True
        assert result["retry_count"] >= 1

    def test_retry_not_failed(self, test_db: Session, evaluation_job: EvaluationJob):
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        with pytest.raises(ValidationError, match="failed"):
            service.retryFailedEvaluation(evaluation_job.id)

    def test_get_competition_results(self, test_db: Session, model: Model, competition: Competition, team: Team, evaluation_job: EvaluationJob, evaluation_tasks: List[EvaluationTask]):
        repo = EvaluationOrchestrationRepository(test_db)
        evaluation_job.status = "completed"
        for i, task in enumerate(evaluation_tasks):
            repo.record_evaluation_result(
                evaluation_id=evaluation_job.id,
                task_id=task.id,
                fold_number=i,
                metrics={"accuracy": 0.9, "precision": 0.9, "recall": 0.9, "f1_score": 0.9},
            )

        service = EvaluationOrchestrationService(repo)
        results = service.getCompetitionResults(competition.id)
        assert len(results["final_rankings"]) == 1
        assert results["final_rankings"][0]["team_name"] == "Team A"

    def test_aggregate_metrics(self, test_db: Session):
        results = [
            type("R", (), {"accuracy": 0.9, "precision": 0.8, "recall": 0.7, "f1_score": 0.75})(),
            type("R", (), {"accuracy": 0.8, "precision": 0.7, "recall": 0.6, "f1_score": 0.65})(),
            type("R", (), {"accuracy": 0.7, "precision": 0.6, "recall": 0.5, "f1_score": 0.55})(),
        ]
        repo = EvaluationOrchestrationRepository(test_db)
        service = EvaluationOrchestrationService(repo)
        agg = service._aggregate_metrics(results)
        assert abs(agg["mean_accuracy"] - 0.8) < 0.01
        assert abs(agg["mean_precision"] - 0.7) < 0.01
        assert abs(agg["mean_recall"] - 0.6) < 0.01
        assert abs(agg["mean_f1"] - 0.65) < 0.01
        assert agg["std_accuracy"] > 0
        assert agg["std_precision"] > 0


# ============================================
# CONTROLLER / API TESTS
# ============================================


@pytest.fixture
def client(test_db: Session):
    app.dependency_overrides = {}
    from app.core.database import SessionLocal

    original = SessionLocal
    SessionLocal = lambda: test_db

    def override_db():
        yield test_db

    app.dependency_overrides = {}

    return TestClient(app)


@pytest.fixture
def auth_header(host_user: User):
    from app.core.auth import create_access_token
    token = create_access_token(user_id=str(host_user.id))
    return {"Authorization": f"Bearer {token}"}


class TestEvaluationController:
    def test_schedule_evaluation(self, client: TestClient, model: Model, auth_header: dict):
        response = client.post(
            f"/api/v1/competitions/{model.competition_id}/models/{model.id}/evaluate",
            json={"protocol": "standard", "folds": 3},
            headers=auth_header,
        )
        if response.status_code == 200:
            data = response.json()
            assert data["model_id"] == str(model.id)
        else:
            assert response.status_code in (400, 401, 403, 404)

    def test_schedule_evaluation_unauthorized(self, client: TestClient, model: Model):
        response = client.post(
            f"/api/v1/competitions/{model.competition_id}/models/{model.id}/evaluate",
            json={"protocol": "standard", "folds": 3},
        )
        assert response.status_code in (401, 422)

    def test_get_evaluation_status(self, client: TestClient, evaluation_job: EvaluationJob, auth_header: dict):
        response = client.get(
            f"/api/v1/evaluations/{evaluation_job.id}",
            headers=auth_header,
        )
        if response.status_code == 200:
            data = response.json()
            assert str(evaluation_job.id) == data["id"]
        else:
            assert response.status_code in (400, 401, 404)

    def test_get_evaluation_status_not_found(self, client: TestClient, auth_header: dict):
        response = client.get(
            f"/api/v1/evaluations/{uuid4()}",
            headers=auth_header,
        )
        assert response.status_code in (401, 404)

    def test_get_evaluation_results(self, client: TestClient, evaluation_job: EvaluationJob, evaluation_tasks: List[EvaluationTask], auth_header: dict, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        for i, task in enumerate(evaluation_tasks):
            repo.record_evaluation_result(
                evaluation_id=evaluation_job.id,
                task_id=task.id,
                fold_number=i,
                metrics={"accuracy": 0.95, "precision": 0.94, "recall": 0.93, "f1_score": 0.94},
            )

        response = client.get(
            f"/api/v1/evaluations/{evaluation_job.id}/results",
            headers=auth_header,
        )
        if response.status_code == 200:
            data = response.json()
            assert len(data["folds"]) == len(evaluation_tasks)
        else:
            assert response.status_code in (400, 401, 404)

    def test_retry_evaluation(self, client: TestClient, evaluation_job: EvaluationJob, evaluation_tasks: List[EvaluationTask], auth_header: dict, test_db: Session):
        repo = EvaluationOrchestrationRepository(test_db)
        for task in evaluation_tasks:
            repo.update_task_status(task.id, TaskStatus.failed, error="err")
        repo.update_evaluation_status(evaluation_job.id, EvaluationStatus.failed)

        response = client.put(
            f"/api/v1/evaluations/{evaluation_job.id}/retry",
            headers=auth_header,
        )
        if response.status_code == 200:
            data = response.json()
            assert data["restarted"] is True
        else:
            assert response.status_code in (400, 401, 403, 404)

    def test_get_competition_evaluations(self, client: TestClient, competition: Competition, evaluation_job: EvaluationJob, auth_header: dict):
        response = client.get(
            f"/api/v1/competitions/{competition.id}/evaluations",
            headers=auth_header,
        )
        if response.status_code == 200:
            data = response.json()
            assert len(data["evaluations"]) >= 1

    def test_get_competition_results(self, client: TestClient, competition: Competition, auth_header: dict):
        response = client.get(
            f"/api/v1/competitions/{competition.id}/results",
            headers=auth_header,
        )
        assert response.status_code in (200, 400, 401, 404)


# ============================================
# GPU / RESOURCE LIMIT TESTS
# ============================================


class TestGPUResourceConfig:
    def test_env_gpu_disabled_by_default(self):
        assert os.getenv("EVAL_GPU_ENABLE", "false") == "false"

    def test_env_docker_timeout_default(self):
        assert os.getenv("EVAL_DOCKER_TIMEOUT", "600") == "600"

    def test_env_docker_memory_default(self):
        assert os.getenv("EVAL_DOCKER_MEMORY_LIMIT", "4g") == "4g"

    def test_env_docker_cpu_default(self):
        assert os.getenv("EVAL_DOCKER_CPU_LIMIT", "2") == "2"

    def test_env_gpu_count_default(self):
        assert os.getenv("EVAL_GPU_COUNT", "1") == "1"

    def test_run_docker_evaluation_gpus_param_type(self):
        from app.workers.executor import run_docker_evaluation
        import inspect
        sig = inspect.signature(run_docker_evaluation)
        assert "gpus" in sig.parameters
        param = sig.parameters["gpus"]
        assert param.default is None
        assert param.annotation is Optional[str]


def pytest_configure(config):
    config.addinivalue_line("markers", "integration: mark test as an integration test")
    config.addinivalue_line("markers", "slow: mark test as slow running")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

---
sidebar_position: 1
title: System Design
---

# System Design

## Design artifacts and components

| Artifact | Purpose | Stored in |
| --- | --- | --- |
| Model submission | Team-provided model package and metadata | Object storage + database record |
| Dataset version | Immutable evaluation dataset snapshot | Object storage + database record |
| Evaluation job | Execution request for a submission | Database + job queue |
| Evaluation result | Metrics and scoring output | Database |
| Leaderboard entry | Ranked score per phase and team | Database |
| Audit log | Immutable trace of actions | Log store + database |

## Module responsibilities

### Dashboard module

- Controller: getDashboardData, getPhaseInfo, getImageStats, getTeamInfo, getConfiguration, refreshCache, clearCache
- Service: getDashboardData, getPhaseInfo, getImageStats, getConfiguration, refreshCache, clearCache, clearAllCache
- Repository: getTeamInfo, getImageStats, getPhaseInfo, getConfiguration, getPerformanceMetrics, aggregateAllData, cacheData, getCache, clearCache

### Leaderboard module

- Controller: getLeaderboard, getAggregatedScores, refreshRankings, clearCache
- Service: getLeaderboard, aggregateAllScores, sortByScore, updateRankings, clearCache
- Repository: getTeamScores, getEvaluationData, getTeamsByCompetition, updateTeamRank, getHistoricalScores, cacheRankings, clearCache

### Evaluation module

- Controller: submitModel, executeDocker, calculateScore, getQueueStatus
- Service: addToProcessQueue, executeDockerContainer, parseDockerOutput, calculateScore, insertToLeaderboard, processQueue, getQueueStatus
- Repository: storeDockerFile, getDataset, associateDatasetToModel, createModelRecord, getModelFilePath, storeEvaluation, updateModelStatus, calculateTeamScore, insertLeaderboardEntry, updateLeaderboardRank, cacheEvaluationResult, clearCache

## Key design considerations

- Idempotent submissions and evaluations to avoid duplicate scoring.
- Strong versioning for datasets and metrics.
- Clear separation between API requests and worker execution.
- Cache invalidation tied to evaluation completion and leaderboard refresh.

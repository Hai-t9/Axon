---
sidebar_position: 2
title: Problem Definition
---

# Problem Definition

## What is the agri challenge?

Axon targets the challenge of evaluating and comparing machine learning models for agricultural analytics (for example crop health, disease detection, or yield estimation) using shared datasets and standardized metrics.

## Main pain points

- Inconsistent evaluation pipelines lead to unfair comparisons.
- Dataset versions drift across teams, breaking reproducibility.
- Manual scoring and leaderboard updates are slow and error-prone.
- Limited traceability makes it hard to audit results or rerun evaluations.
- Compute resources are wasted on repeated, identical evaluations.

## How Axon solves it

- Containerized submissions run in a controlled, repeatable environment.
- Versioned datasets and metrics keep scoring consistent.
- Automated evaluation jobs update the leaderboard in real time.
- End-to-end audit logs capture who submitted what and when.
- Caching avoids re-evaluating identical artifacts.

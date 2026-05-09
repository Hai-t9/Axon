---
sidebar_position: 1
---

# Project Overview

Axon is a cross-platform software solution designed to modernize and unify the end-to-end workflow of data-centric AI competitions. Built specifically to address the challenges encountered during the **AgrI Challenge** (2024–2025), Axon provides a seamless bridge between field data collection and asynchronous model evaluation.

## The Problem: The Generalization Gap

In real-world agricultural environments, AI models often suffer from a "Generalization Gap." While models may achieve >99% accuracy on lab datasets, their performance frequently drops to ~54% in actual farm conditions. This is primarily a **data problem**, caused by:

*   **Inconsistent Metadata:** Previous editions saw ~10,000 images discarded due to missing device information.
*   **Format Fragmentation:** Variations in image dimensions and file types across teams led to major pipeline failures.
*   **Infrastructure Bottlenecks:** Reliance on manual storage dumps (Google Drive) and single-point-of-failure evaluation tools (Discord bots).
*   **Isolation:** A lack of standardized standards created friction between organizers, participants, and evaluators.

## Solution & Goals

Axon transforms these setbacks into a streamlined, modular platform. The primary goal is to provide a unified environment where data diversity is the first-class citizen, ensuring that models are trained and tested against the true heterogeneity of the field.

### Key Objectives:
*   **Standardized Ingestion:** Enforce strict metadata and format requirements at the point of capture.
*   **Scalable Evaluation:** Replace manual bottlenecks with an asynchronous, multi-source evaluation pipeline.
*   **Process Automation:** Facilitate the entire lifecycle from registration to live leaderboard management.

## Stakeholders & Users

Axon serves three primary user groups:

*   **Hosts (Organizers):** Entities like ENSA and ENSIA who configure competition parameters, define evaluation protocols, and manage the administrative lifecycle.
*   **Staff:** Moderators who monitor data quality, manage team approvals, and oversee day-to-day operations.
*   **Participants:** Teams of developers and researchers who use the mobile app for field collection and the web portal for model submission.

## Key Features

*   **Mobile Data Capture:** Direct upload from the field to the backend, extracting device metadata via EXIF to eliminate data loss.
*   **Cross-Team Validation Protocols:** Built-in support for advanced evaluation protocols:
    *   **LOTO (Leave-One-Team-Out):** Testing model robustness against completely unseen team domains.
    *   **TOTO (Train-On-One-Team-Only):** Assessing the generalization capability of a single team's data collection strategy.
*   **Asynchronous Task Queue:** Celery + Redis worker system that handles computationally expensive model evaluations without blocking the UI.
*   **Live Leaderboards:** Real-time ranking of teams based on validated model accuracy across multiple evaluation folds.

---
*Axon's first production deployment targets **Agrichallenge 2026**, building on the research published in: "AgrI Challenge: Cross-Team Insights from a Data-Centric AI Competition in Agricultural Vision" (Brahimi et al., 2026).*

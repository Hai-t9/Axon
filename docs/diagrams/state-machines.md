---
sidebar_position: 4
title: State Machines
---

# State Machine Diagram

This model tracks the lifecycle of a documentation version.

```mermaid
stateDiagram-v2
  [*] --> Draft
  Draft --> InReview: Submit for review
  InReview --> Draft: Changes requested
  InReview --> Approved: Approved
  Approved --> Published: Merge and deploy
  Published --> Archived: Superseded
  Published --> Draft: Start revision
  Archived --> [*]
```

## Usage

- Keep state names short and unambiguous.
- Define transition triggers as concrete actions.
- Mirror these states in workflows and automation where possible.

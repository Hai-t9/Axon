---
sidebar_position: 8
---

# Data Validation

## Overview

There is no separate "Data Validation Service" with its own set of endpoints. Label validation is handled by the **Validation module** (see [Validation Module Documentation](./module-validation.md)), which manages the participant voting workflow for finalizing image labels.

The Validation module handles:
- Generating validation assignments via round-robin distribution across teams
- Serving validation queues to participants
- Recording votes and tracking skip counts
- Auto-finalizing labels when vote/skip threshold is reached (majority vote)

### How Data Validation Works

```
1. Host generates assignments
   └─ POST /api/v1/competitions/{comp_id}/validations/generate
   └─ Round-robin: each image assigned to N teams (threshold times)
   └─ Stored in Redis per team

2. Participant fetches validation list
   └─ GET /api/v1/competitions/{comp_id}/validations/list
   └─ Returns unvalidated image IDs for participant's team
   └─ Deterministically shuffled per participant

3. Participant submits vote
   └─ POST /api/v1/images/{image_id}/validations  { label }
   └─ Vote recorded in label_validations table
   └─ If vote_count + skip_count >= threshold:
       └─ Majority vote computed
       └─ Label updated via Label Service
       └─ Label marked as validated

4. Participant can skip images
   └─ POST /api/v1/images/{image_id}/validations/skip
   └─ Removes from team's queue
   └─ If skip + votes >= threshold: auto-validate

5. Host checks pending validations
   └─ GET /api/v1/competitions/{comp_id}/validations/pending
```

### Dependencies

- `label`, `label_validations`, `image`, `team`, `config` tables
- **Label Service** — called to update and validate finalized labels
- **Redis** — stores team validation assignments (optional, falls back gracefully)
- **Image module** — retrieves images for validation
- **Teams Service** — validates team membership

---
sidebar_position: 2
---

# Phase

## Overview

Manages competition phase lifecycle, state transitions, deadlines, and phase history. Phases are stored as a single `PhaseLog` row per competition with a JSON `phase_dates` column that tracks the timeline, deadlines, transition mode, and audit history.

Phase values are string digits `"0"` through `"5"`:

| Phase | Label |
|---|---|
| `"0"` | Awaiting Initialisation |
| `"1"` | Data Collection |
| `"2"` | Data Validation |
| `"3"` | Model Submission |
| `"4"` | Model Evaluation |
| `"5"` | Finale & Leaderboard |

---

### Responsibility

Handles all phase-related operations: current phase retrieval, phase transitions (automatic and manual), deadline management, transition mode configuration, phase decrement (rollback), and complete phase history tracking.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `getCurrentPhase` | `compId` | `{ competition_id, current_phase, phase_dates }` |
| `advancePhase` | `compId` | `{ current_phase, previous_phase, transitioned_at }` |
| `decrementPhase` | `compId` | `{ current_phase, previous_phase, transitioned_at }` |
| `overridePhase` | `compId`, `targetPhase`, `reason` | `{ current_phase, override_reason, transitioned_at }` |
| `adjustPhaseDeadline` | `compId`, `newDeadline` | `{ phase, old_deadline, new_deadline, adjusted_at }` |
| `setPhaseTransitionMode` | `compId`, `mode` | `{ competition_id, transition_mode }` |
| `getPhaseTimeline` | `compId` | `{ phases[ { phase, start, deadline, status } ], total }` |
| `getPhaseHistory` | `compId` | `{ audit_logs[ { action, from_phase, to_phase, performed_by, timestamp } ], total }` |
| `validatePhaseTransition` | `currentPhase`, `targetPhase` | `{ valid: boolean, message: string }` |

### APIs

**Endpoints**

- `GET    /api/v1/competitions/{competition_id}/phase` — Get current phase information
- `POST   /api/v1/competitions/{competition_id}/phase/advance` — Advance to next phase — host only
- `POST   /api/v1/competitions/{competition_id}/phase/decrement` — Go back one phase — host only
- `PUT    /api/v1/competitions/{competition_id}/phase/override` — Manually jump to any phase — host only
- `PUT    /api/v1/competitions/{competition_id}/phase/deadline` — Adjust phase deadline — host only
- `PUT    /api/v1/competitions/{competition_id}/phase/transition-mode` — Set auto or manual transition — host only
- `GET    /api/v1/competitions/{competition_id}/phase/timeline` — Get all phases with deadlines and status
- `GET    /api/v1/competitions/{competition_id}/phase/history` — Get complete phase transition audit log
- `POST   /api/v1/competitions/{competition_id}/phase/validate` — Validate if phase transition is allowed

**Controller**

- `handleGetCurrentPhase(compId)`
- `handleAdvancePhase(compId)`
- `handleDecrementPhase(compId)`
- `handleOverridePhase(compId, targetPhase, reason)`
- `handleAdjustPhaseDeadline(compId, newDeadline)`
- `handleSetPhaseTransitionMode(compId, mode)`
- `handleGetPhaseTimeline(compId)`
- `handleGetPhaseHistory(compId)`
- `handleValidatePhaseTransition(currentPhase, targetPhase)`

**Service**

- `getCurrentPhase(compId)`
  - → `_ensurePhaseLog(compId)` — creates default if missing
  - → `_autoAdvanceIfDeadlinePassed(entry)` — checks and auto-advances
  - → return phase entry
- `advancePhase(compId, userId)`
  - → `getCurrentPhase(compId)`
  - → `getNextPhase(currentPhase)` — next in `["0","1","2","3","4","5"]`
  - → `validatePhaseTransition(currentPhase, nextPhase)`
  - → update timeline + log history → save
  - → return transition result
- `decrementPhase(compId, userId)`
  - → go back one phase in the order
  - → mark current phase timeline entry as "rolled_back"
  - → restore previous phase to "in_progress"
  - → log in history → save
- `overridePhase(compId, targetPhase, reason, userId)`
  - → directly set phase, log with reason
- `adjustPhaseDeadline(compId, newDeadline, userId)`
  - → validate deadline is in future, after launch date
  - → store in `phase_dates.deadlines[current_phase]`
  - → log in history
- `setPhaseTransitionMode(compId, mode, userId)`
  - → store `phase_dates.transition_mode = 'auto' | 'manual'`
- `getTimeline(compId)` → `phase_dates.timeline[]`
- `getHistory(compId)` → `phase_dates.history[]`
- `validatePhaseTransition(currentPhase, targetPhase)` → pure logic

**Repository**

- `getByCompetitionId(compId)` — single PhaseLog row
- `create(competitionId, currentPhase, phaseDates)`
- `update(entry, updates)` — uses `flag_modified` for JSON column

### Dependencies

- `phase_log` table only (single table with JSON column — no separate `phase`, `phase_transition_config`, or `phase_audit_log` tables)
- **Competition module** — phase operations belong to a competition
- **Authentication module** — tracks who performed phase transitions for audit

### Data Model

**PhaseLog Entity**
```
{
  id: integer (PK),
  competition_id: UUID (FK → competition.id),
  current_phase: string ("0" | "1" | "2" | "3" | "4" | "5"),
  phase_dates: JSON {
    transition_mode: "auto" | "manual",
    deadlines: { "0": "2026-...", "1": "2026-...", ... },
    timeline: [
      { phase: "0", start: "2026-...", deadline: null, status: "completed" },
      { phase: "1", start: "2026-...", deadline: "2026-...", status: "in_progress" }
    ],
    history: [
      { action: "advance", from_phase: "0", to_phase: "1",
        performed_by: "user-uuid", details: {}, performed_at: "..." }
    ]
  }
}
```

### Phase Transition Rules

**Valid Transitions**

```
0 → 1 (Awaiting Initialisation → Data Collection)
1 → 2 (Data Collection → Data Validation)
2 → 3 (Data Validation → Model Submission)
3 → 4 (Model Submission → Model Evaluation)
4 → 5 (Model Evaluation → Finale & Leaderboard)
```

**Manual Override Rules**

- Host can override to any phase (even backward) with documented reason
- Backward transitions trigger cascade operations (e.g., reopening validation)
- Override action logged with reason and user ID for audit trail

**Auto-Advance**

- If `transition_mode == "auto"` and the current phase's deadline has passed, the system auto-advances to the next phase on `getCurrentPhase()` calls.

**Decrement**

- Host can go back exactly one phase (no skip-back). Timeline entries are marked as "rolled_back".
- Cannot decrement below phase `"0"`.

**Deadline Rules**

- All phases except final (`"5"`) have adjustable deadlines
- New deadline must be in the future and on or after competition launch date
- Adjusting deadline does not trigger state change
- Adjustment logged in audit trail

### Phase Workflow Example

```
1. Competition created → phase_log created with current_phase = "0"
2. Host configures competition → transition_mode = "manual"
3. Host advances phase → phase = "1" (Data Collection)
4. Data collection happens during phase "1"
5. Host sets deadline for phase "2" → auto-advance possible
6. Host advances → phase = "2" (Data Validation)
7. Models validated during phase "2"
8. Host advances → phase = "3" (Model Submission)
9. Teams submit models
10. Host advances → phase = "4" (Model Evaluation)
11. Models evaluated
12. Host advances → phase = "5" (Finale & Leaderboard)
13. Results published, no further transitions (unless overridden)
```

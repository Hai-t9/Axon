---
sidebar_position: 2
---

# Phase

## Overview

Manages competition phase lifecycle, state transitions, deadlines, and phase history. Provides granular control over phase progression including automatic transitions, manual overrides, deadline adjustments, and phase rollbacks. Maintains immutable phase audit logs for tracking all phase changes throughout the competition lifecycle.

---

### Responsibility

Handles all phase-related operations: current phase retrieval, phase transitions (automatic and manual), deadline management, transition mode configuration, and complete phase history tracking. Enforces valid phase transitions and prevents invalid state changes.

### Inputs / Outputs

| Function | Input | Output |
|---|---|---|
| `getCurrentPhase` | `compId` | `{ phase, started_at, deadline, status }` |
| `advancePhase` | `compId` | `{ current_phase, previous_phase, transitioned_at }` |
| `overridePhase` | `compId`, `targetPhase` | `{ current_phase, override_reason, transitioned_at }` |
| `adjustPhaseDeadline` | `compId`, `newDeadline` | `{ phase, old_deadline, new_deadline, adjusted_at }` |
| `setPhaseTransitionMode` | `compId`, `mode` | `{ competition_id, transition_mode }` |
| `getPhaseTimeline` | `compId` | `{ phases[ { phase, start, deadline, status } ], total }` |
| `getPhaseHistory` | `compId` | `{ audit_logs[ { phase, action, performed_by, timestamp } ], total }` |
| `validatePhaseTransition` | `currentPhase`, `targetPhase` | `{ valid: boolean, message: string }` |

### APIs

**Endpoints**

- `GET    /competitions/:compId/phase` — Get current phase information
- `POST   /competitions/:compId/phase/advance` — Advance to next phase — host only
- `PUT    /competitions/:compId/phase/override` — Manually override to specific phase — host only
- `PUT    /competitions/:compId/phase/deadline` — Adjust phase deadline — host only
- `PUT    /competitions/:compId/phase/transition-mode` — Set automatic or manual transition — host only
- `GET    /competitions/:compId/phase/timeline` — Get all phases with deadlines and status
- `GET    /competitions/:compId/phase/history` — Get complete phase transition audit log
- `POST   /competitions/:compId/phase/validate` — Validate if phase transition is allowed

**Controller**

- `handleGetCurrentPhase(compId)`
- `handleAdvancePhase(compId)`
- `handleOverridePhase(compId, targetPhase, reason)`
- `handleAdjustPhaseDeadline(compId, newDeadline)`
- `handleSetPhaseTransitionMode(compId, mode)`
- `handleGetPhaseTimeline(compId)`
- `handleGetPhaseHistory(compId)`
- `handleValidatePhaseTransition(currentPhase, targetPhase)`

**Service**

- `getCurrentPhase(compId)`
  - → `findPhaseByCompetitionId(compId)`
  - → return current phase with metadata
- `advancePhase(compId, userId)`
  - → `getCurrentPhase(compId)`
  - → `getNextPhase(currentPhase)`
  - → `validatePhaseTransition(currentPhase, nextPhase)`
  - → `updatePhase(compId, nextPhase)`
  - → `logPhaseChange(compId, currentPhase, nextPhase, userId, 'advance')`
  - → return transition result
- `overridePhase(compId, targetPhase, reason, userId)`
  - → `validatePhaseTransition(currentPhase, targetPhase)` — enforce override rules
  - → `updatePhase(compId, targetPhase)`
  - → `logPhaseChange(compId, currentPhase, targetPhase, userId, 'override', reason)`
  - → return override confirmation
- `adjustPhaseDeadline(compId, newDeadline, userId)`
  - → `validateDeadline(newDeadline)` — ensure deadline is in future
  - → `updatePhaseDeadline(compId, newDeadline)`
  - → `logPhaseChange(compId, currentPhase, null, userId, 'deadline_adjustment', newDeadline)`
  - → return deadline update confirmation
- `setPhaseTransitionMode(compId, mode, userId)`
  - → `validateMode(mode)` — 'auto' or 'manual'
  - → `updateTransitionMode(compId, mode)`
  - → `logPhaseChange(compId, currentPhase, null, userId, 'transition_mode_changed', mode)`
  - → return mode update confirmation
- `getPhaseTimeline(compId)`
  - → `findAllPhasesByCompetition(compId)`
  - → return array of all phases with dates and status
- `getPhaseHistory(compId)`
  - → `findPhaseAuditLog(compId)`
  - → return complete audit trail with actor information
- `validatePhaseTransition(currentPhase, targetPhase)`
  - → pure logic function checking valid state transitions
  - → return validation result with message

**Repository**

- `findPhaseByCompetitionId(compId)`
- `findAllPhasesByCompetition(compId)`
- `updatePhase(compId, phase)`
- `updatePhaseDeadline(compId, newDeadline)`
- `updateTransitionMode(compId, mode)`
- `logPhaseChange(compId, fromPhase, toPhase, userId, action, details)`
- `findPhaseAuditLog(compId)`

### Dependencies

- `phase`, `phase_log`, `phase_transition_config` tables
- **Competition module** — phase operations belong to a competition
- **Authentication module** — tracks who performed phase transitions for audit

### Data Model

**Phase Entity**
```
{
  id: UUID,
  competition_id: UUID,
  phase: enum('creation' | 'active' | 'evaluation' | 'complete'),
  started_at: timestamp,
  deadline: timestamp (nullable for final phase),
  status: enum('pending' | 'in_progress' | 'completed'),
  created_at: timestamp,
  updated_at: timestamp
}
```

**Phase Transition Config**
```
{
  id: UUID,
  competition_id: UUID,
  transition_mode: enum('auto' | 'manual'),
  auto_advance_on_deadline: boolean (if mode = 'auto'),
  created_at: timestamp,
  updated_at: timestamp
}
```

**Phase Audit Log**
```
{
  id: UUID,
  competition_id: UUID,
  from_phase: enum (nullable if deadline adjustment),
  to_phase: enum (nullable if deadline adjustment),
  action: enum('advance' | 'override' | 'deadline_adjustment' | 'transition_mode_changed' | 'rollback'),
  action_details: JSON (reason for override, new deadline value, etc.),
  performed_by: UUID (userId of host who triggered change),
  performed_at: timestamp
}
```

### Phase Transition Rules

**Valid Transitions**

```
creation → active (automatic on start date OR manual advance)
active → evaluation (automatic on deadline OR manual advance)
evaluation → complete (automatic on all evaluations done OR manual advance)
```

**Manual Override Rules**

- Host can override to any phase (even backward) with documented reason
- Backward transitions trigger cascade operations (e.g., reopening validation)
- Override action logged with reason and user ID for audit trail

**Deadline Rules**

- All phases except final have adjustable deadlines
- New deadline must be in future
- Adjusting deadline does not trigger state change
- Adjustment logged in audit trail

### Phase Workflow Example

```
1. Competition created → phase = 'creation', no deadline
2. Host configures competition → transition_mode = 'manual'
3. Host advances phase → phase = 'active', deadline = set_by_host
4. Data collection happens during 'active' phase
5. Host manually overrides (OR auto-advance if deadline passed) → phase = 'evaluation'
6. Models evaluated during 'evaluation' phase
7. Host or system advances → phase = 'complete'
8. Results published, no further transitions allowed
```

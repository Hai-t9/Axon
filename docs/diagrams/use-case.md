---
sidebar_position: 1
title: Use Case Diagram
---

# Use Case Diagram

Mermaid does not have a native use case diagram type, so this model uses a flowchart to represent actors and system capabilities.

```mermaid
flowchart LR
  PO[Product Owner]
  TW[Technical Writer]
  RV[Reviewer]
  ENG[Engineer]

  subgraph ADP[Axon Documentation Platform]
    UC1([Propose schema change])
    UC2([Author documentation page])
    UC3([Request review])
    UC4([Approve and merge update])
    UC5([Publish to GitHub Pages])
  end

  PO --> UC1
  TW --> UC2
  TW --> UC3
  RV --> UC4
  ENG --> UC1
  ENG --> UC2
  UC4 --> UC5
```

## Modeling guidance

- Actors stay outside the system boundary.
- Use naming patterns like verb plus noun for each use case.
- Keep this diagram high-level and move details to activity or sequence diagrams.

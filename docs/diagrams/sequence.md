---
sidebar_position: 3
title: Sequence Diagram
---

# Sequence Diagram

This sequence shows how a documentation publish request propagates through source control and deployment.

```mermaid
sequenceDiagram
  autonumber
  participant A as Author
  participant G as GitHub Repo
  participant C as CI Workflow
  participant P as GitHub Pages
  participant U as End User

  A->>G: Push docs update to main
  G->>C: Trigger deploy workflow
  C->>C: Install dependencies
  C->>C: Build Docusaurus site
  alt Build passed
    C->>P: Upload and deploy static build
    P-->>U: Serve updated documentation
  else Build failed
    C-->>A: Report failure logs
  end
```

## Why this matters

- The sequence makes dependencies between authoring and deployment explicit.
- Failure branches identify where to add alerting and remediation steps.

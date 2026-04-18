---
sidebar_position: 2
title: Activity Diagram
---

# Activity Diagram

This diagram captures the flow for publishing a documentation update.

```mermaid
flowchart TD
  A([Start]) --> B[Create or update markdown page]
  B --> C[Validate Mermaid blocks locally]
  C --> D[Open pull request]
  D --> E{Review outcome}
  E -->|Changes requested| F[Revise content]
  F --> C
  E -->|Approved| G[Merge to main]
  G --> H[GitHub Actions build]
  H --> I{Build successful?}
  I -->|No| J[Fix build issues]
  J --> D
  I -->|Yes| K[Deploy to GitHub Pages]
  K --> L([End])
```

## Operational notes

- Keep each step deterministic and repeatable.
- Fail fast at build time for broken links and invalid markdown.

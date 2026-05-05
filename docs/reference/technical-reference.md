---
sidebar_position: 1
title: Technical Reference
---

# Technical Reference

## Stack

- Documentation portal framework: Docusaurus classic preset with TypeScript
- Diagram engine: Mermaid via theme integration
- Hosting: GitHub Pages
- Deployment: GitHub Actions workflow

For Axon platform implementation details, see the Tech Stack page.

## Repository conventions

- Keep primary documentation under docs.
- Group domain docs by concern: architecture, schema, diagrams, and reference.
- Prefer stable document slugs to avoid broken links.

## Authoring conventions

- Write diagrams in Mermaid blocks inside markdown files.
- Keep one primary diagram per page when possible.
- Add a short explanation below each diagram for context.

## Build and run commands

```bash
npm install
npm run start
npm run build
npm run serve
```

## Deployment behavior

- Pushes to main trigger the deploy workflow.
- The workflow builds the site and publishes static output to GitHub Pages.
- If deployment fails, inspect workflow logs and rerun after fixes.

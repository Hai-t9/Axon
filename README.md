# Axon Technical Documentation

This repository hosts Axon schema documentation, UML-style Mermaid diagrams, and technical references using Docusaurus.

## Stack

- Docusaurus (TypeScript)
- Mermaid for diagrams
- GitHub Actions for deployment
- GitHub Pages for hosting

## Local setup

```bash
npm install
npm run start
```

## Build and preview

```bash
npm run build
npm run serve
```

## Documentation structure

- docs/schema: database schema and data model references
- docs/diagrams: use case, activity, sequence, and state diagrams
- docs/reference: technical implementation references

## Deployment

Push to main to trigger automatic deployment via .github/workflows/deploy.yml.

Site configuration for GitHub Pages is defined in docusaurus.config.ts.

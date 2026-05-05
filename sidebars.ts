import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */
const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    'intro',
    {
      type: 'category',
      label: 'High-Level Overview',
      items: ['high-level-overview/project-overview'],
    },
    {
      type: 'category',
      label: 'Requirements',
      items: [
        'requirements/functional-requirements',
        'requirements/non-functional-requirements'
      ],
    },
    {
      type: 'category',
      label: 'System Architecture',
      items: ['system-architecture/architecture-overview'],
    },
    {
      type: 'category',
      label: 'Modules & Components',
      items: [
        'modules-components/module-breakdown',
        'modules-components/module-dashboard',
        'modules-components/module-leaderboard',
        'modules-components/module-label',
        'modules-components/module-validation',
        'modules-components/module-image',
        'modules-components/module-cleaner',
        'modules-components/module-competition',
        'modules-components/module-data-ingestion',
        'modules-components/module-data-validation',
        'modules-components/module-evaluation-orchestration',
        'modules-components/module-model-submission',
        'modules-components/module-phase',
        'modules-components/module-teams'
      ],
    },
    {
      type: 'category',
      label: 'Data Layer',
      items: ['data-layer/data-layer'],
    },
    {
      type: 'category',
      label: 'Development & Setup',
      items: ['development-setup/setup-docs'],
    },
    {
      type: 'category',
      label: 'API Documentation',
      items: ['api-documentation/api-docs'],
    },
    {
      type: 'category',
      label: 'Testing Strategy',
      items: ['testing-strategy/testing-strategy'],
    },
    {
      type: 'category',
      label: 'Deployment & Operations',
      items: ['deployment-operations/deployment-ops'],
    },
    {
      type: 'category',
      label: 'Decision Log',
      items: ['decision-log/decision-log'],
    },
  ],
};

export default sidebars;

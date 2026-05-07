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
    'problem-definition',
    'what-is-axon',
    {
      type: 'category',
      label: 'System Architecture',
      items: ['architecture/system-architecture'],
    },
    {
      type: 'category',
      label: 'System Design',
      items: ['architecture/system-design'],
    },
    {
      type: 'category',
      label: 'About Axon',
      items: [
        'modules-components/module-breakdown',
        'modules-components/module-competition',
        'modules-components/module-phase',
        'modules-components/module-teams',
        'modules-components/module-dashboard',
        'modules-components/module-data-ingestion',
        'modules-components/module-label',
        'modules-components/module-data-validation',
        'modules-components/module-cleaner',
        'modules-components/module-image',
        'modules-components/module-model-submission',
        'modules-components/module-evaluation-orchestration',
        'modules-components/module-leaderboard',
        'modules-components/module-validation'
      ],
    },
    {
      type: 'category',
      label: 'Schema',
      items: ['schema/database-schema'],
    },
    {
      type: 'category',
      label: 'Diagrams',
      items: ['diagrams/use-case', 'diagrams/activity'],
    },
    {
      type: 'category',
      label: 'API Contract',
      items: ['reference/api-contract'],
    },
    {
      type: 'category',
      label: 'Tech Stack',
      items: ['reference/tech-stack'],
    },
    {
      type: 'category',
      label: 'Technical Reference',
      items: ['reference/technical-reference'],
    },
  ],
};

export default sidebars;

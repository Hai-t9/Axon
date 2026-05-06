import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'Axon Technical Docs',
  tagline: 'Schema docs, UML diagrams, and technical references',
  favicon: 'img/favicon.ico',

  // Set the production url of your site here
  url: 'https://hai-t9.github.io',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/Axon/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'Hai-t9', // Usually your GitHub org/user name.
  projectName: 'Axon', // Usually your repo name.

  onBrokenLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  markdown: {
    mermaid: true,
  },

  themes: ['@docusaurus/theme-mermaid'],

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          routeBasePath: 'docs',
          editUrl:
            'https://github.com/Hai-t9/Axon/tree/docs/',  // Changed: Hai-t9 instead of mustapha, docs branch
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/docusaurus-social-card.jpg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Axon Docs',
      logo: {
        alt: 'Axon Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          href: 'https://github.com/Hai-t9/Axon',  // Changed: Hai-t9 instead of mustapha
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Overview',
              to: '/docs/intro',
            },
          ],
        },
        {
          title: 'Diagrams',
          items: [
            {
              label: 'Database Schema',
              to: '/docs/schema/database-schema',
            },
            {
              label: 'Sequence Diagram',
              to: '/docs/diagrams/sequence',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/Hai-t9/Axon',  // Changed: Hai-t9 instead of mustapha
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Axon. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,

  customFields: {
    future: {
      v4: true, // Improve compatibility with the upcoming Docusaurus v4
    },
  },
};

export default config;
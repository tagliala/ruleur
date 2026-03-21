import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: 'Ruleur',
  description: 'A composable Business Rules Engine for Ruby',
  base: '/ruleur/',
  ignoreDeadLinks: true,
  
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/ruleur/logo.svg' }],
    ['meta', { name: 'theme-color', content: '#CC342D' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:locale', content: 'en' }],
    ['meta', { property: 'og:title', content: 'Ruleur | Business Rules Engine for Ruby' }],
    ['meta', { property: 'og:site_name', content: 'Ruleur' }],
    ['meta', { property: 'og:url', content: 'https://tagliala.github.io/ruleur/' }],
  ],

  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    logo: '/logo.svg',
    
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/getting-started/' },
      { text: 'Guide', link: '/guide/' },
      { text: 'API', link: '/api/' },
      { text: 'Examples', link: '/examples/' },
      {
        text: 'v1.0',
        items: [
          { text: 'v1.0 (Latest)', link: '/' },
          { text: 'Changelog', link: 'https://github.com/tagliala/ruleur/blob/main/CHANGELOG.md' }
        ]
      }
    ],

    sidebar: {
      '/getting-started/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Introduction', link: '/getting-started/' },
            { text: 'Installation', link: '/getting-started/installation' },
            { text: 'Your First Rule', link: '/getting-started/first-rule' }
          ]
        }
      ],
      
      '/guide/': [
        {
          text: 'Guide',
          items: [
            { text: 'Overview', link: '/guide/' },
            { text: 'DSL Basics', link: '/guide/dsl-basics' },
            { text: 'Conditions', link: '/guide/conditions' },
            { text: 'Operators', link: '/guide/operators' },
            { text: 'YAML Rules', link: '/guide/yaml-rules' },
            { text: 'Validation', link: '/guide/validation' },
            { text: 'Persistence', link: '/guide/persistence' },
            { text: 'Versioning & Audit', link: '/guide/versioning' },
            { text: 'Advanced Topics', link: '/guide/advanced' }
          ]
        }
      ],

      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview', link: '/api/' },
            { text: 'Engine', link: '/api/engine' },
            { text: 'Rule', link: '/api/rule' },
            { text: 'Context', link: '/api/context' },
            { text: 'Condition', link: '/api/condition' },
            { text: 'Operators', link: '/api/operators' },
            { text: 'DSL', link: '/api/dsl' },
            { text: 'YAML Loader', link: '/api/yaml-loader' },
            { text: 'Validation', link: '/api/validation' },
            { text: 'Repositories', link: '/api/repositories' }
          ]
        }
      ],

      '/examples/': [
        {
          text: 'Examples',
          items: [
            { text: 'Overview', link: '/examples/' },
            { text: 'Permission Rules', link: '/examples/permissions' },
            { text: 'Workflow Automation', link: '/examples/workflow' },
            { text: 'Dynamic Pricing', link: '/examples/pricing' },
            { text: 'Real-World Cases', link: '/examples/real-world' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/tagliala/ruleur' }
    ],

    editLink: {
      pattern: 'https://github.com/tagliala/ruleur/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2024-present Geremia Taglialatela'
    },

    search: {
      provider: 'local'
    }
  },

  markdown: {
    theme: {
      light: 'github-light',
      dark: 'github-dark'
    },
    lineNumbers: true
  }
})

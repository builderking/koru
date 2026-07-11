import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://koru-dc8.pages.dev',
  output: 'static',
  trailingSlash: 'always',
  integrations: [sitemap()],
  // Keep component scripts as external /_astro/ files (never inlined) so the
  // dist check can enforce that only self-hosted bundled modules ship.
  vite: { build: { assetsInlineLimit: 0 } },
});

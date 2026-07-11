import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://koru-dc8.pages.dev',
  output: 'static',
  trailingSlash: 'always',
  integrations: [sitemap()],
});

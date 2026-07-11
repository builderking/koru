import { access, readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';

const root = new URL('../dist/', import.meta.url).pathname;
const requiredFiles = [
  'index.html', 'privacy/index.html', 'security/index.html', 'download/index.html',
  'docs/index.html', 'docs/getting-started/index.html', 'faq/index.html',
  'open-source/index.html', '404.html', 'robots.txt', 'sitemap-index.xml',
  '_headers', '_redirects', 'og.png', 'icons/favicon-32.png',
  'icons/apple-touch-icon.png', 'icons/icon-192.png', 'icons/icon-512.png',
];
for (const file of requiredFiles) await access(join(root, file));

const htmlFiles = [];
async function walk(path) {
  for (const entry of await readdir(path, { withFileTypes: true })) {
    const full = join(path, entry.name);
    if (entry.isDirectory()) await walk(full);
    else if (entry.name.endsWith('.html')) htmlFiles.push(full);
  }
}
await walk(root);

const knownRoutes = new Set(htmlFiles.map((file) => {
  const relative = file.slice(root.length);
  if (relative === 'index.html') return '/';
  if (relative === '404.html') return '/404/';
  return `/${relative.replace(/index\.html$/, '').replace(/\.html$/, '/')}`;
}));

for (const file of htmlFiles) {
  const html = await readFile(file, 'utf8');
  const relative = file.slice(root.length);
  const h1s = html.match(/<h1(?:\s|>)/g) ?? [];
  if (h1s.length !== 1) throw new Error(`${relative}: expected one h1, found ${h1s.length}`);
  for (const landmark of ['<header', '<main', '<footer']) {
    if (!html.includes(landmark)) throw new Error(`${relative}: missing ${landmark}`);
  }
  if (!html.includes('Skip to content')) throw new Error(`${relative}: missing skip link`);
  if (!html.includes('rel="canonical"')) throw new Error(`${relative}: missing canonical`);
  if (!html.includes('property="og:image"')) throw new Error(`${relative}: missing social image metadata`);
  if (/<img(?![^>]*\salt=)[^>]*>/i.test(html)) throw new Error(`${relative}: image without alt text`);
  const hrefs = [...html.matchAll(/href="([^"]+)"/g)].map((match) => match[1]);
  for (const href of hrefs) {
    if (!href.startsWith('/') || href.startsWith('//') || href.startsWith('/_astro/') || href.includes('#')) continue;
    const path = new URL(href, 'https://koru.pages.dev').pathname;
    if (/\.(png|ico|xml|txt)$/.test(path)) continue;
    if (!knownRoutes.has(path)) throw new Error(`${relative}: broken internal link ${href}`);
  }
}

const home = await readFile(join(root, 'index.html'), 'utf8');
if (!home.includes('application/ld+json')) throw new Error('Homepage is missing JSON-LD.');
if (/<script(?!(?:[^>]*type="application\/ld\+json"))[^>]*>/i.test(home)) throw new Error('Unexpected client-side JavaScript found.');
const headers = await readFile(join(root, '_headers'), 'utf8');
for (const header of ['Content-Security-Policy', 'Permissions-Policy', 'Referrer-Policy', 'X-Content-Type-Options']) {
  if (!headers.includes(header)) throw new Error(`Missing security header: ${header}`);
}
console.log(`Production output checks passed across ${htmlFiles.length} HTML files and ${requiredFiles.length} required artifacts.`);

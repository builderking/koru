import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';

const root = new URL('..', import.meta.url);
const files = [];
async function walk(path) {
  for (const entry of await readdir(path, { withFileTypes: true })) {
    const full = join(path, entry.name);
    if (entry.isDirectory()) await walk(full);
    else if (/\.(astro|ts|css|mjs)$/.test(entry.name)) files.push(full);
  }
}
await walk(join(root.pathname, 'src'));
const source = (await Promise.all(files.map((file) => readFile(file, 'utf8')))).join('\n');

// Koru is distributed as a free app; it is not open source and has no public repository.
// Also forbid absolute privacy overclaims the product cannot guarantee.
const forbidden = [/open[ -]?source/i, /github\.com/i, /apache/i, /100% private/i, /never lose anything/i, /unhackable/i];
for (const pattern of forbidden) {
  if (pattern.test(source)) throw new Error(`Copy-truth check failed: ${pattern}`);
}
for (const required of ['free', 'download for macos', 'local', 'privacy', 'explicit']) {
  if (!source.toLowerCase().includes(required)) throw new Error(`Missing required truth marker: ${required}`);
}
console.log(`Source checks passed across ${files.length} files.`);

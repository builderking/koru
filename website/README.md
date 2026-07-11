# Koru website

Static Astro website for Koru. It is designed for Cloudflare Pages with no server runtime, functions, environment variables, analytics, or client-side JavaScript.

## Local verification

Use Node 22 or later.

```sh
npm ci
npm test
```

The production output is written to `dist/`. `npm test` checks Astro diagnostics, copy-truth rules, internal links, accessibility basics, metadata, JSON-LD, required assets, security headers, redirects, and generated routes.

## Release-dependent updates

Before a public release:

1. Replace the pre-release action and status copy only after a signed, notarized, checksum-verified GitHub Release exists.
2. Add the verified version, macOS range, compatibility matrix, installation details, and release URL from the release record.
3. Replace the concept product loop with reviewed product captures and accessible transcript content.
4. Confirm or change `https://koru.pages.dev` in `astro.config.mjs`, `src/content/site.ts`, and `public/robots.txt` after the Cloudflare project or a custom domain is explicitly approved.
5. Replace the neutral wordmark/glyph only after trademark and Māori cultural review is complete.
6. Update privacy, security, NOTICE, and third-party attribution content from the shipped implementation and dependency audit.

Do not add a download claim, compatibility claim, analytics, remote asset, or third-party script without updating the public privacy and release contracts.

## Hosting files

- `public/_headers` contains the Cloudflare Pages security and cache policy.
- `public/_redirects` contains stable short links and legacy route redirects.
- Preview deployment indexing remains a Cloudflare setting/header to verify during the separately authorized Pages setup; this repository does not create or configure remote resources.

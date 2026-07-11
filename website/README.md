# Koru website

Static Astro marketing website for Koru, the free writing-memory app for macOS. It is designed for Cloudflare Pages with no server runtime, functions, environment variables, analytics, or client-side JavaScript.

## Local verification

Use Node 22 or later.

```sh
npm ci
npm test
```

The production output is written to `dist/`. `npm test` checks Astro diagnostics, copy-truth rules, internal links, accessibility basics, metadata, JSON-LD, required assets, security headers, redirects, and generated routes.

## Positioning rules

The site presents Koru as a free, downloadable, local-first macOS app. Two rules are enforced by `scripts/check-source.mjs`:

1. No open-source, repository, or license positioning — Koru is not open source.
2. No absolute privacy overclaims ("100% private", "never lose anything").

## Wiring the real download

Download buttons currently point at `/download/`, and the button on that page uses a placeholder link. When a signed, notarized artifact exists:

1. Set `download.artifactUrl` in `src/content/site.ts` to the real artifact URL.
2. Add the verified version, macOS range, and release notes to `/download/`.
3. Confirm or change `https://koru.pages.dev` in `astro.config.mjs`, `src/content/site.ts`, and `public/robots.txt` once the production domain is final.

## Assets

Icons and the social image are generated placeholders. Regenerate them after editing `scripts/generate-icons.swift`:

```sh
swift scripts/generate-icons.swift public
```

Replace these with final brand assets when brand review is complete. The support and security email addresses in `src/content/site.ts` are placeholders to confirm before launch.

## Hosting files

- `public/_headers` contains the Cloudflare Pages security and cache policy.
- `public/_redirects` contains stable short links and legacy route redirects.

# Koru website

Static Astro marketing website for Koru, the free writing-memory app for macOS. It is designed for Cloudflare Pages with no server runtime, functions, environment variables, analytics, or third-party scripts. The only client-side JavaScript is a small self-hosted animation for the homepage product demo; the dist check rejects any other script.

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

## Download artifact

Download buttons point at `/download/`, and the button on that page links directly to `/downloads/Koru.zip` — an ad-hoc-signed universal Release build of the current alpha. `../scripts/package-website-download.sh` produces the zip, its `.sha256` checksum, and `src/content/download-artifact.ts` (version, build date, commit, and checksum rendered on `/download/`). Both app build scripts (`build-unsigned.sh`, `build-signed-local.sh`) run it automatically, so every app build refreshes the website copy; set `KORU_SKIP_WEBSITE_PACKAGE=1` to opt out. Commit the refreshed `public/downloads/` files and `download-artifact.ts` to publish the new build.

When a Developer ID-signed, notarized artifact exists:

1. Point `scripts/package-website-download.sh` at the notarized bundle (or replace the ad-hoc seal step).
2. Remove the alpha Gatekeeper notice on `/download/`.
3. Confirm or change `https://koru-dc8.pages.dev` in `astro.config.mjs`, `src/content/site.ts`, and `public/robots.txt` once a custom production domain is attached.

## Assets

Icons and the social image are generated placeholders. Regenerate them after editing `scripts/generate-icons.swift`:

```sh
swift scripts/generate-icons.swift public
```

Replace these with final brand assets when brand review is complete. The support and security email addresses in `src/content/site.ts` are placeholders to confirm before launch.

## Hosting files

- `public/_headers` contains the Cloudflare Pages security and cache policy.
- `public/_redirects` contains stable short links and legacy route redirects.

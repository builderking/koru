# Cloudflare Pages runbook

Status: local configuration only. No Cloudflare project, Git integration, deployment, URL, custom domain, DNS, TLS, analytics, or rollback has been created or verified.

## Intended configuration

| Setting | Value |
|---|---|
| Project | `koru` (confirm availability) |
| Repository | `builderking/koru` |
| Production branch | `main` |
| Root/build | repository root / website build command (define when `website/` exists) |
| Output | `website/dist` |
| Preview | eligible same-repository pull requests only; fork previews are not promised |
| Production trigger | merged `main` through Git integration |

`wrangler.toml` records the future output directory for local validation. It does not create a remote resource or deployment.

## Manual creation gate

After the website exists and its own tests pass, an authorized owner must create/connect the Pages project through the approved Cloudflare MCP/API/dashboard workflow, record account/project identifiers outside public logs where appropriate, restrict production to `main`, and verify that untrusted fork code receives no secrets and cannot create privileged previews.

Do not configure application signing or notarization material in Cloudflare. The site is static and should not require secrets to build. A future analytics choice requires an explicit consent/privacy decision; default is none.

## Pre-deploy verification

- `website/` builds from a clean checkout with pinned dependencies and no network-dependent content generation.
- Copy is limited to behavior proven in the target tagged release.
- Download URL, asset name, size, SHA-256, source tag, compatibility matrix, privacy/security/install/uninstall links all agree.
- CSP/security headers, canonical/OG/structured data, sitemap, robots, accessible headings, keyboard/contrast/reduced motion, responsive layouts, no-JavaScript baseline, custom 404, redirects, cache rules, and broken links pass.
- Same-repository preview and fork boundary are tested without secrets (`MAN-FORK-001`).

## Production verification record

Record deployment ID, source commit, UTC time, `*.pages.dev` URL, custom domain/canonical state, headers/redirect/cache evidence, download checksum match, approver, and previous known-good deployment ID. A green build alone is not approval.

## Rollback

Use the procedure in [Rollback and withdrawal](../release/rollback.md). Rollback is a manual authorized Cloudflare action. After rollback, recheck download integrity and every public claim; record both deployment IDs.

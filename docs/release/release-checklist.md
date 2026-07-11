# Release-candidate checklist

Release: `v________`  Commit: `________`  Owner: `________`  Date: `________`

Unchecked items are gates, not optional documentation.

## Source and quality

- [ ] Protected signed tag resolves to reviewed commit; checkout is clean.
- [ ] CI, locked behavior, redaction/plaintext, parser/fuzz, migration, accessibility, performance, and reliability suites pass.
- [ ] Dependency resolution is committed/unchanged; allowlist, licenses, vulnerability review, SBOM, manifest, and provenance pass.
- [ ] No open Critical/High issue; accepted lower-severity issues are listed.

## App acceptance

- [ ] Fresh install and onboarding on a clean account pass.
- [ ] Upgrade from previous test/stable release with a populated encrypted vault passes.
- [ ] Rollback behavior and compatible encrypted backup restoration pass.
- [ ] Permission, OS/hardware, compatibility, accessibility, offline/network, deletion, export, backup, and recovery matrices pass.

## Artifact

- [ ] Universal arm64/x86_64 archive built from tagged source.
- [ ] Minimal entitlements reviewed; no debug/get-task-allow or unapproved network capability.
- [ ] Nested code/app/DMG signature, Hardened Runtime, secure timestamp, notarization Accepted, staple, Gatekeeper, quarantine download, checksum, and launch pass.
- [ ] Release notes identify behavior, permissions, migrations, compatibility limits, recovery, and irreversible changes.

## Publication (separate manual action)

- [ ] Draft release contains source, DMG, checksums, SBOM, manifest, provenance, notes, compatibility matrix, and rollback artifact.
- [ ] Public download path independently matches recorded digest.
- [ ] Website claims/links and Cloudflare production revision are approved.
- [ ] Support, vulnerability response, incident, and app/website rollback owners are active.

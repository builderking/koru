# Repository-local release qualification

Date: 2026-07-11  Baseline: `01cb610`  Scope: post-Wave 2 local checkout

This record distinguishes deterministic repository evidence from gates that require real permissions, other machines, people, credentials, or remote systems.

## Locally verified

- All build-plan files, REQ-001 through REQ-015, TASK-001 through TASK-103, roadmap gates, and the 19-definition-of-done categories were audited against source rather than prior completion claims.
- Strict Swift 6 build and tests pass with warnings treated as errors: 7 XCTest cases and 39 Swift Testing cases.
- The encrypted vault persists Library mutations; active, archived, and recently-deleted lifecycle metadata round-trips; Save Selection opens an explicit editor; vault reset removes database, backups, encrypted assets, and Keychain key.
- Repository validation, shell syntax, JSON/schema checks, unsigned Xcode app and harness builds, static website source/output checks, clean website install, dependency audit, and Astro build pass.
- The protected release path is implemented and fail-closed. It requires a manual signed tag and protected Developer ID/notary credentials, creates a universal archive and notarized DMG, and emits SBOM/checksums before verification.
- The website remains static and makes no verified-release download claim.

## External release blockers

- Execute the real TCC and host compatibility matrix on every supported macOS major version, including secure/protected fields, permission denial/revocation, Accessibility, Input Monitoring, Services, global hotkeys, insertion/undo, and clipboard behavior.
- Complete human VoiceOver, Full Keyboard Access, contrast/transparency/motion, localization scaling, cultural/brand, product, and independent security review.
- Meet private/public beta thresholds with representative users and record owner sign-off.
- Configure and verify GitHub repository visibility, branch protection, CODEOWNERS enforcement, labels/issue forms/Discussions, private vulnerability reporting, protected environments, and signing/deployment secrets.
- Create and rehearse the Cloudflare Pages preview/production/rollback path; verify the public URL, headers, DNS/TLS, canonical behavior, and deployment commit.
- Create a protected annotated release tag, run Developer ID signing/notarization/stapling/Gatekeeper/quarantine checks, test install/upgrade/rollback/delete-all on a clean Mac, and publish only after artifact/source/checksum provenance matches.
- Perform an external clean-room contributor build and activate support, incident, vulnerability, and launch-review owners.

No remote resource, deployment, signature, notarization request, or public release was created during this qualification.

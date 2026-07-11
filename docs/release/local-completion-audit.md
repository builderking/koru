# Local build-plan completion audit

Audit baseline: `f498bb1` and later local commits. Audit date: 2026-07-11.

This record distinguishes repository proof from release claims. A green command is evidence only for the behavior that command actually exercises. `Proven` means the named local implementation or artifact exists and has direct automated or inspectable evidence. `Weak/missing` means evidence requires a human, another machine, or a release artifact and is not represented as complete. `External` means completing it would require permissions, credentials, users, signing identity, or a remote mutation forbidden during this audit. No item is classified as proven merely because `scripts/check` exits successfully.

## Numbered product requirements

| Requirement | Classification | Direct evidence |
| --- | --- | --- |
| REQ-001 local-first | Proven locally | Encrypted repository and in-memory search have no network dependency; vault, search, clipboard, product, and support-bundle tests exercise offline paths. Network observation of the final signed binary remains a release gate. |
| REQ-002 modes and permissions | Proven locally | `PermissionCoordinator`, `TypedEventTapService`, lifecycle degradation tests, real permission callbacks from `ProductStore`, onboarding/settings UI, and hotkey tests. System prompts still require manual verification. |
| REQ-003 eligible fresh input | Proven locally | `FreshInputSession`, `RecallRuntime`, generated state sequences, secure/unknown-context tests, focus-only and mid-writing regression tests. |
| REQ-004 typed matching | Proven locally | Runtime orchestration, deterministic search, prefix preservation/revalidation, dismissal, and explicit-insertion tests. Host compatibility remains manual. |
| REQ-005 manual recall | Proven locally | Carbon registered hotkeys, conflict states, manual runtime scope, caret fallback, and permission-independent hotkey tests. Actual shortcut conflicts remain host-dependent. |
| REQ-006 result presentation | Proven locally | Native nonactivating panel, stable identity navigator, keyboard commands, accessible row labels, placement tests. Full VoiceOver review remains manual. |
| REQ-007 safe insertion | Proven locally | Three-tier insertion coordinator, destination digest revalidation, exactly-once tests, pasteboard fallback contract, and mutation/failure tests. Destination undo is host behavior and remains compatibility evidence. |
| REQ-008 Clipboard and `clp` | Proven locally | Opt-in monitor, mixed logical events, encrypted retention, `clp` fresh-start runtime, independent manual Clipboard command, and clipboard tests. |
| REQ-009 selection capture | Proven locally | AX full-selection guard, non-destructive Service and shortcut paths, menu command now invokes capture, and selection tests. Floating icon is optional (`may`) and remains disabled by default. |
| REQ-010 save choices | Proven locally | Canonical behavior model, editor validation, reserved-term and lifecycle tests, locally derived capture draft. Near-duplicate UX remains conservative rather than semantic. |
| REQ-011 templates | Proven locally | Deterministic token parser, ordered fields, required validation, in-memory values, completion view, and render tests. Runtime panel integration needs host UI evidence before release. |
| REQ-012 library | Proven locally | Native Library CRUD, pin, tags, archive, recently deleted, duplicate, import/export, encrypted persistence, and lifecycle tests. |
| REQ-013 Clipboard controls | Proven locally | Off-by-default retention, pause/clear/exclusions, bounded assets/events, encrypted storage, denial and oversize tests. macOS pasteboard access reporting is SDK-dependent and is honestly shown as unavailable when no API exists. |
| REQ-014 portability | Proven locally | Versioned human-readable JSON, plaintext warning, validation-before-mutation, duplicate policies, round-trip tests, and documented format behavior. |
| REQ-015 accessibility | Weak/missing release evidence | Native semantic controls, labels, keyboard routes, reduced-motion CSS, and deterministic view/service tests exist. VoiceOver, Full Keyboard Access, contrast, scaling, and appearance matrices require human execution on supported macOS versions. |

## Named local artifacts and invariants

| Area | Classification | Evidence |
| --- | --- | --- |
| Native app, harness, packages, tests, Xcode project | Proven locally | `App/`, `Harness/`, `Packages/`, `Tests/`, `Package.swift`, and `Koru.xcodeproj`; SwiftPM and Xcode builds. |
| Canonical saved-item and temporary Clipboard models | Proven locally | `KoruDomain/Models.swift`; domain and persistence tests. |
| Keychain key, encrypted SQLite records/backups/assets | Proven locally | vault key, repository, asset store, maintenance implementations; tamper, corruption, key-loss, disk-full, plaintext-scan, and retention tests. |
| Search, ranking, learning, reset, 10,000-item bound | Proven locally | `InMemorySearch`; deterministic ranking, encrypted learning, bounded-index and performance tests. |
| Accessibility inspection, event tap, registered hotkeys, insertion, Services | Proven locally | `KoruPlatform` integrations and production-integration tests. Host matrix remains manual. |
| Menu lifecycle, pause, quit, settings, diagnostics | Proven locally | `App/main.swift`, lifecycle tests, real permission delegation, persisted settings, and platform Launch-at-Login integration. |
| Website routes and public assets | Proven locally | Landing, privacy, security, download, FAQ, open-source and docs pages; headers, redirects, 404, robots, sitemap integration, icons, OG image; source/dist tests. |
| Open-source policy files | Proven locally | Apache-2.0 `LICENSE`, `NOTICE`, README, contribution, conduct, governance, security, support, CODEOWNERS, issue forms, PR template, Dependabot. |
| Architecture, privacy, security, install, uninstall, support, release and rollback docs | Proven locally | Files under `docs/`, including ADR, threat model, compatibility, operations and release records. |
| CI workflows | Proven as repository artifacts | Build/test, website preview, CodeQL, dependency review, secret scan, release and Pages workflows are statically validated; remote execution status is external. |
| Release scripts | Proven locally for unsigned paths | bootstrap, repository validation, unsigned build, preflight, checksums, SBOM and verification scripts. Signing/notarization branches require credentials. |
| No raw keystroke/content diagnostics | Proven locally | bounded in-memory trigger state, allowlisted diagnostic fields, support-bundle schema/tests, encrypted-store plaintext scans. Final binary network inspection remains manual. |
| Universal macOS 13+ unsigned app | Proven locally when qualification commands below pass | Release build plus `lipo -archs`, deployment target inspection, launch/process smoke. Signing and notarization are external. |

## Required local commands

These commands are rerun at audit completion and their exact result is recorded in the committing audit report:

```sh
./scripts/check
(cd website && npm audit --audit-level=high && npm test)
./scripts/build-unsigned.sh
lipo -archs build/UnsignedProducts/Koru.app/Contents/MacOS/Koru
open build/UnsignedProducts/Koru.app
```

The process smoke must confirm the executable remains alive long enough to initialize, then terminate only that locally launched process. It does not grant TCC permissions or modify a remote system.

## Genuinely external or manual remaining gates

- Developer ID signing, hardened-runtime validation with the production identity, notarization, stapling, signed update rehearsal, published checksums/SBOM/release notes, tag provenance, and public-download smoke.
- Cloudflare Pages creation, GitHub App connection, production/preview deployments, pages.dev/DNS/TLS verification, and rollback rehearsal.
- GitHub repository settings: public visibility, branch protection, labels, Discussions, private vulnerability reporting, owners, and remote CI results.
- Compatibility and accessibility matrices on every supported macOS version and named host application, including VoiceOver, Full Keyboard Access, appearance/display settings, permission denial/revocation, undo, and clean-Mac install/uninstall.
- Independent security review, external clean-room build, second-maintainer release rehearsal, representative-user beta thresholds, approvals, launch metrics, announcements, and final sign-off record.

These gates must remain unchecked in the definition of done until their evidence exists. They are not actionable local code gaps and were not simulated during this audit.

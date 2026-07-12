# 19. Definition of done

Local implementation evidence is tracked in [`../docs/release/local-completion-audit.md`](../docs/release/local-completion-audit.md). That audit does not mark this release checklist complete: human compatibility/accessibility work, signing, notarization, remote configuration, beta evidence, publication, and final approval remain required.

Koru reaches 100% only when the product, native implementation, privacy model, open-source repository, website, distribution, and operating model are all release-ready. A working demo alone is not completion.

## 19.1 Product definition

- [ ] Target user, core jobs, positioning, principles, and non-goals are approved.
- [ ] V1 behavior is represented by numbered requirements and acceptance tests.
- [ ] Automatic activation is implemented exactly: a complete assigned tag of at least three user-perceived characters at a left boundary opens at the beginning, middle, or end of writing; partial, fuzzy, derived-label, content, and stale-generation matches stay hidden.
- [ ] `clp` is the locked V1 Clipboard command: it works at a left boundary anywhere, leaves the typed characters untouched until explicit result selection, and has a manual Clipboard fallback.
- [ ] Recall never removes or replaces typed characters until the user explicitly inserts a result.
- [ ] The global-hotkey fallback works when typed matching is unavailable or disabled wherever macOS permits the registered shortcut.
- [ ] Product vocabulary does not require the word “prompt.”
- [ ] Every visible limitation has an honest user-facing fallback or explanation.

## 19.2 Core app

- [ ] Signed universal arm64/x86_64 macOS 13+ application launches without administrator access.
- [ ] Menu-bar lifecycle, launch-at-login, pause, quit, and permission-health states work.
- [ ] The canonical saved-item model requires only reusable content plus one or more exact tags; no user-authored title, behavior subtype, or template schema is required, while the separate temporary Clipboard scope behaves as specified.
- [ ] Exact automatic tag retrieval, fuzzy manual tag/content retrieval, explicit insertion, and query learning pass deterministic tests.
- [ ] Text, rich text, images, links, file references, and supported video references have defined insertion or copy-only behavior.
- [ ] Selection capture works through supported Accessibility behavior and through reliable Service/hotkey fallbacks.
- [ ] The library supports create, read, update, archive, delete, pin, flat tags, import, export, and duplicate handling.
- [ ] Undo immediately reverses Koru's most recent text insertion where the target app supports undo.

## 19.3 User experience and accessibility

- [ ] The quick surface is native, minimal, compact, low-copy, and keyboard-first.
- [ ] The quick surface never obscures the caret, selected text, or the next line when a safe alternative position exists.
- [ ] Continued typing, Escape, outside click, focus change, and app change dismiss or update the surface predictably.
- [ ] VoiceOver can identify the surface, result count, focused result, type, and available action without implying that focus has already selected or inserted it.
- [ ] Full Keyboard Access, Increase Contrast, Reduce Transparency, Reduce Motion, light appearance, and dark appearance are verified.
- [ ] Text remains legible at supported display scaling and localization sizes.
- [ ] No action depends on color alone.

## 19.4 Privacy and security

- [ ] Raw keystrokes are held only in a bounded per-process in-memory suffix and are never persisted, logged, or transmitted.
- [ ] Automatic recall applies no Koru secure-field or app exclusion; macOS Secure Input and protected authorization limitations are documented and cause no unintended modification. Clipboard exclusions remain independently enforced.
- [ ] Clipboard history is explicit opt-in and communicates retention before enabling.
- [ ] Saved-item content, clipboard payloads, sensitive metadata, and encrypted assets are encrypted at rest with a Keychain-protected key; only the approved low-sensitivity operational metadata remains plaintext.
- [ ] Clear history, delete all data, pause, Clipboard exclusions, retention, and export controls work offline.
- [ ] Logs, analytics, notifications, and crash reports never include saved text, clipboard payloads, file paths, typed queries, or encryption keys.
- [ ] Threat model and independent security review findings are resolved or documented.
- [ ] Dependency and release provenance checks pass.
- [ ] Private vulnerability reporting is enabled and tested.

## 19.5 Compatibility and quality

- [ ] The required application/field compatibility matrix is executed on every supported macOS major version.
- [ ] Unsupported and partially supported fields use the correct fallback rather than failing silently.
- [ ] Direct AX replacement, AX selection/paste, validated synthetic Backspace-and-paste, and Copy-only tiers replace only the exact tag range and never insert without explicit selection.
- [ ] Unit, integration, UI, accessibility, migration, performance, fault-injection, and security suites pass.
- [ ] Cold launch, recall latency, memory, CPU, database growth, and clipboard-disk limits meet the budgets in the quality plan.
- [ ] Update, downgrade/rollback, database backup, restore, import, and export paths are tested.
- [ ] A clean Mac can install, grant permissions, complete the guided test, run Koru's explicit Delete All Data flow, and then remove the app without Koru-managed sensitive data remaining in its live Application Support or Keychain locations; the uninstall guide explains that dragging the app to Trash alone does not perform this cleanup.

## 19.6 Distribution and release

- [ ] CI builds and tests from a clean checkout using pinned dependencies.
- [ ] Release automation produces signed and notarized artifacts, release notes, SBOM, and SHA-256 checksums.
- [ ] The published artifact matches the tagged source and recorded provenance.
- [ ] Manual release upgrades are signed, verified, staged, and recoverable; V1 does not imply an automatic updater.
- [ ] A rollback procedure exists for both the app and website.
- [ ] The first public release is installed and smoke-tested from the public download path.

## 19.7 Open-source readiness

- [ ] Repository is public under `builderking/koru`.
- [ ] Apache-2.0 license, README, contribution guide, code of conduct, security policy, architecture overview, privacy statement, and support policy are present.
- [ ] Issue forms, pull-request template, labels, Discussions, private vulnerability reporting, and branch protection are configured.
- [ ] Contribution builds and tests can run without private credentials.
- [ ] Required signing and deployment secrets are isolated from forks and never committed.
- [ ] At least one external clean-room build is completed from the public instructions.

## 19.8 Marketing website and Cloudflare Pages

- [ ] `website/` contains the approved minimal landing page, privacy page, security page, download page, documentation links, FAQ, and open-source attribution.
- [ ] All copy reflects shipped behavior and names limitations honestly.
- [ ] Metadata, canonical URLs, Open Graph image, structured data, sitemap, robots rules, favicon/app icons, and accessible headings are verified.
- [ ] Page-speed, responsive layout, keyboard access, contrast, reduced motion, broken links, and no-JavaScript baseline pass.
- [ ] Cloudflare Pages project is created through the documented MCP/API workflow and connected to `builderking/koru`.
- [ ] `main` creates production deployments and eligible same-repository pull requests create isolated previews; fork pull requests are not promised the same automatic preview behavior.
- [ ] Security headers, redirects, cache behavior, custom 404, and analytics consent decisions are verified.
- [ ] The `*.pages.dev` URL is live; any custom domain has valid DNS, TLS, redirects, and canonical behavior.
- [ ] Production deploy and rollback are executed once as a release rehearsal.

## 19.9 Launch and operations

- [ ] Beta thresholds in the launch plan are met with representative users.
- [ ] Documentation covers installation, permissions, first save, recall, clipboard, Clipboard exclusions, backup, update, uninstall, and troubleshooting.
- [ ] GitHub issues/discussions, support triage, security response, release cadence, and dependency maintenance have owners.
- [ ] Release verification, website monitoring, and explicit content-free local diagnostics support investigation of failed manual upgrades, broken downloads, website errors, and crash regressions without automatic app telemetry or content collection.
- [ ] Launch announcements point to the same verified release and website.
- [ ] The 24-hour, 7-day, and 30-day launch review checklists are ready.

## 19.10 Final sign-off record

The release issue must record:

- release tag and commit;
- signed artifact name, size, checksum, and notarization result;
- compatibility and accessibility evidence;
- security review and known limitations;
- Cloudflare Pages production deployment ID and public URL;
- rollback points for app and website;
- approving maintainers;
- unresolved issues explicitly accepted for the release.

Koru is done only when this record is complete and a new user can discover, install, trust, use, update, and remove the product using public documentation alone.

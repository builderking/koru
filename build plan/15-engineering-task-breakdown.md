# 15. Engineering Task Breakdown

## 1. Task rules

This breakdown is dependency-driven and contains no time estimates.

Every task is complete only when:

- Production code and tests are merged.
- Error, denied-permission, and unsupported-target paths are covered.
- No user content is added to logs or diagnostics.
- Koru-owned UI is keyboard accessible and VoiceOver-labeled.
- Relevant build-plan and user documentation is updated.
- The task preserves the locked behavior: exact complete tags of at least three characters anywhere in writing, a tiny panel, explicit insertion, `clp` mixed recall, and selection-capture fallbacks.

Task IDs are stable. Pull requests and issues should reference them.

## 2. Decision gates

### TASK-001 — Lock platform and distribution contract

**Depends on:** None

**Scope:**

- Minimum macOS 13.
- Universal arm64 and x86_64 release artifact.
- AppKit system integration plus SwiftUI product UI.
- Direct Developer ID distribution, Hardened Runtime, and notarization.
- Nonsandboxed core app.
- No InputMethodKit, helper daemon, browser extension, system extension, or kernel extension.
- Standard-component Liquid Glass on supported current macOS, standard translucent fallback on earlier supported versions.
- No automatic updater or background network request in the initial release.

**Complete when:**

- Decisions appear in the main index, technical plan, README, and contributor guide.
- Xcode deployment targets and architecture settings enforce the decision.

### TASK-002 — Lock privacy and retention policy

**Depends on:** TASK-001

**Scope:**

- Clipboard history off by default.
- D-001-approved V1 retention: 7 days, 500 events, 256 MiB encrypted asset cap, 25 MiB per retained image.
- File/video references only in temporary history; saving creates a separate permanent saved-item reference and does not duplicate the full binary in V1.
- Saved items do not expire automatically.
- No cloud sync, content telemetry, remote exclusion rules, or AI processing.
- Default Clipboard-sensitive-app exclusions and user override model; no automatic-recall app or secure-field exclusion.

**Complete when:**

- Values are approved in the main index and represented by one policy type used by UI, repository, diagnostics, tests, and docs.
- ADR-001, policy code, tests, settings, privacy docs, and public copy use the same exact limits.

### TASK-003 — Lock compatibility and fallback contract

**Depends on:** TASK-001

**Scope:**

- Capability labels: Full, Paste, Copy-only, Palette-only, Blocked.
- Exact-tag suffix and left-boundary verification with no partial automatic matches.
- Insertion tiers A, B, and C.
- Selection icon is optional and opportunistic.
- Services and global hotkey remain supported capture paths.

**Complete when:**

- The capability enum, fallback rules, and user wording are approved and cannot be bypassed by feature code.

## 3. Foundation workstream

### TASK-010 — Create Xcode project and application shell

**Depends on:** TASK-001

**Scope:**

- Native Swift macOS app.
- Agent-style menu-bar lifecycle.
- NSStatusItem menu.
- Library, Settings, Onboarding, and Diagnostics window routes.
- Universal Release configuration.
- Debug-only Integration Harness target.

**Complete when:**

- The unsigned app launches on macOS 13 and current macOS.
- Menu-bar lifecycle works with no Dock icon in normal operation.
- All product windows can be opened and closed without terminating the agent.

### TASK-011 — Define module boundaries and dependency direction

**Depends on:** TASK-001, TASK-010

**Scope:**

- AppShell.
- Domain.
- Repository.
- Security.
- Search.
- MacIntegrations.
- PanelUI.
- ProductUI.
- Diagnostics.
- TestSupport.

**Complete when:**

- Domain and repository protocols do not import AppKit.
- Mac integration types are injectable.
- No cyclic module dependency exists.

### TASK-012 — Define domain models and stable IDs

**Depends on:** TASK-002, TASK-003, TASK-011

**Scope:**

- SavedItem with canonical reusable content and one-or-more exact tags.
- Legacy encoded SavedItemBehavior, TemplateField, and MatchTerm fields retained only for backward-compatible decoding and migration.
- RecallSignal.
- ClipboardEvent and ClipboardRepresentation.
- ContentType.
- ClipboardCaptureExclusion; automatic typed recall has no app-exclusion model.
- RetentionPolicy.
- CompatibilityCapability.
- InsertionTransaction.
- PermissionSnapshot.
- DiagnosticEvent.

**Complete when:**

- Codable/versioning behavior is tested.
- UI never uses database row IDs as identity.
- Models distinguish encrypted content from display-safe metadata.

### TASK-013 — Establish code-quality and dependency policy

**Depends on:** TASK-010

**Scope:**

- Formatting and lint configuration.
- Strict concurrency warnings.
- Dependency allowlist and committed resolution.
- Secret scanning.
- Pull-request template tied to security and permission changes.

**Complete when:**

- CI blocks formatting, build, dependency-resolution, secret, and test failures.
- Forked pull requests have no release secrets.

### TASK-014 — Implement adaptive visual foundation

**Depends on:** TASK-010

**Scope:**

- Shared spacing, typography, corner, color, shadow, and motion tokens.
- macOS 26+ standard glass behavior.
- macOS 13 through pre-glass material fallback.
- Reduce Transparency, Increase Contrast, and Reduce Motion behavior.

**Complete when:**

- Panel and product windows preserve layout across visual generations.
- Opaque fallback passes contrast checks.

## 4. Security and repository workstream

### TASK-020 — Produce executable threat model

**Depends on:** TASK-001, TASK-002

**Scope:**

- Map data flows from events, AX, pasteboard, selection, storage, export, logs, and release pipeline.
- Define trust boundaries and prohibited data.
- Convert mitigations into test IDs.

**Complete when:**

- Each in-scope threat has an owner, mitigation, and automated or manual test.
- Out-of-scope threats are documented without misleading security claims.

### TASK-021 — Implement Keychain vault-key manager

**Depends on:** TASK-020

**Scope:**

- Generate 256-bit key.
- Store through the data-protection Keychain, nonsynchronizable.
- Load only when the session is usable.
- Purge on pause, lock, and termination.
- Detect missing key without creating a replacement against existing data.

**Complete when:**

- Key creation, read, lock, removal, and missing-key tests pass.
- Key material never appears in database, preferences, logs, or diagnostics.

### TASK-022 — Implement encrypted SQLite repository

**Depends on:** TASK-012, TASK-020, TASK-021

**Scope:**

- Schema for minimum plaintext operational metadata and AES-GCM ciphertext.
- Saved-item lifecycle state for Active, Archived, and Recently Deleted, including stable-ID restore and permanent-purge transactions.
- Repository actor.
- Prepared statements, transactions, foreign keys, integrity checks.
- Encrypted pre-migration backup.
- Versioned schema and ciphertext migrations.

**Complete when:**

- CRUD, interruption, disk-full, corruption, migration, and rollback tests pass.
- Known plaintext does not appear in database, WAL, temporary files, or backup.

### TASK-023 — Implement encrypted asset store

**Depends on:** TASK-021, TASK-022

**Scope:**

- Opaque filenames.
- Bounded image encryption and decryption.
- Thumbnail generation with dimension and byte limits.
- Orphan cleanup.
- File/video reference metadata without automatic full-asset duplication.

**Complete when:**

- Malformed and oversized assets fail safely.
- Permanently purging a record removes its owned asset and search entry; moving it to Recently Deleted does not destroy its recoverable asset.
- Full video content is never retained through ordinary clipboard capture.

### TASK-024 — Implement in-memory search and deterministic ranking

**Depends on:** TASK-012, TASK-022

**Scope:**

- Memory-only FTS or equivalent index.
- Exact, prefix, and fuzzy tag matches plus content tokens, explicit-selection recall signals, pinned/app context, recency, and frequency ordering for manual recall.
- A separate automatic lookup that accepts only a complete assigned tag of at least three characters at a left boundary and never consults content or fuzzy signals.
- Separate saved-item and clp modes.
- Independent reset of learned recall signals without deleting Saved or Clipboard content.
- Index destruction on pause, lock, and termination.

**Complete when:**

- Search fixtures are deterministic.
- No plaintext search index persists.
- Performance budget passes at the default retention limit.

### TASK-025 — Implement retention, deduplication, and exclusions

**Depends on:** TASK-002, TASK-022, TASK-023

**Scope:**

- Keyed content digest.
- Count, age, total-byte, and per-image limits.
- Permanent saved-item separation from temporary clipboard retention.
- Never Save Clipboard From policy; automatic typed recall has no per-app Never Observe policy.
- Versioned default Clipboard-sensitive-app exclusions.

**Complete when:**

- Policies apply in one transaction.
- Temporary retention never evicts permanent saved items or silently promotes clipboard entries.
- Tests cover boundary order and concurrent capture.

### TASK-026 — Implement vault maintenance and reset

**Depends on:** TASK-021, TASK-022, TASK-023, TASK-025

**Scope:**

- Integrity check.
- Expiry cleanup.
- Recently Deleted recovery-window cleanup and explicit permanent purge.
- Orphan cleanup.
- Encrypted backup pruning.
- Missing-key state.
- Explicit whole-vault reset.

**Complete when:**

- Reset stops integrations, deletes the active key and data, and creates no new vault until deletion completes.
- Recovery paths never upload data automatically.

## 5. Permissions and lifecycle workstream

### TASK-030 — Implement Permission Coordinator

**Depends on:** TASK-011, TASK-012

**Scope:**

- Accessibility trust.
- Input-listening and post-event access.
- General pasteboard access behavior with availability guards.
- Login-item status.
- Runtime state refresh and revocation notifications.

**Complete when:**

- Each permission has unknown, unavailable, denied, granted, and revoked behavior.
- Feature services start and stop from one permission snapshot.

### TASK-031 — Build progressive onboarding

**Depends on:** TASK-014, TASK-030, TASK-034

**Scope:**

- No-permission value demonstration.
- Separate Typed Matching and Clipboard History opt-ins.
- Plain-language Accessibility, Input Monitoring, and pasteboard explanations.
- Sensitive-context and local-only disclosure.
- Retry after returning from System Settings.

**Complete when:**

- No system prompt appears before an explanatory action.
- Declining any prompt preserves Library access and shows the correct fallback.

### TASK-032 — Implement pause, lock, wake, and shutdown lifecycle

**Depends on:** TASK-021, TASK-030

**Scope:**

- Visible Pause state.
- Session lock/unlock.
- Sleep/wake.
- Fast user switch.
- Integration teardown and decrypted-memory purge.

**Complete when:**

- No panel, event buffer, AX observer, decrypted index, or clipboard monitor remains active while paused or locked.

### TASK-033 — Implement Launch at Login

**Depends on:** TASK-010, TASK-030

**Scope:**

- SMAppService main-app registration.
- Status and approval UI.
- Register/unregister flow.

**Complete when:**

- Enabled, denied, requires-approval, updated-app, and disabled scenarios match system state on macOS 13 and current macOS.

### TASK-034 — Implement GlobalHotKeyRegistrar

**Depends on:** TASK-010, TASK-030, TASK-032

**Scope:**

- Public `RegisterEventHotKey` path, behind an auditable registrar protocol and independent of CG event taps and Input Monitoring.
- Commands for manual Saved recall, Clipboard recall, and Save Selection.
- Configurable bindings, duplicate/reserved-binding checks, conflict detection, and per-command registration status.
- Registration, rebinding, wake recovery, pause/lock dispatch behavior, and unregistration on quit.
- Command dispatch without observing or retaining the ordinary key stream.

**Complete when:**

- Manual recall opens during established writing with Typed Matching disabled and Input Monitoring denied.
- A conflicting binding remains with its existing owner, Koru reports the conflict, and another binding can be registered.
- Registration, conflict, rebinding, wake, pause/lock, and unregister behavior pass on macOS 13 and current stable macOS.

## 6. Typed matching and panel workstream

### TASK-040 — Implement typed-matching event-tap service

**Depends on:** TASK-013, TASK-030, TASK-032

**Scope:**

- Narrow key, modifier, reset, and panel-navigation event mask used only for typed matching and its target-field interaction.
- No global shortcut registration; TASK-034 owns every registered hotkey.
- Compact internal messages.
- Timeout/user-input disable recovery.
- Event-tap performance signposts.

**Complete when:**

- Callback p99 stays below the defined budget.
- A 100,000-event soak has no timeout, leaked raw event, or unbounded memory.
- Disabling Typed Matching stops the event tap while TASK-034 registered hotkeys remain available.

### TASK-041 — Implement Accessibility client and observers

**Depends on:** TASK-030, TASK-032

**Scope:**

- Focused element and process.
- Roles, subroles, protected content, value, selection, and settable attributes.
- Bounds-for-range.
- Focus/value/selection notifications.
- Bounded AX timeouts and typed failures.

**Complete when:**

- Full fake-AX error matrix passes.
- Unsupported targets produce capability outcomes, not crashes or retries.

### TASK-042 — Implement integration-capability classifier

**Depends on:** TASK-003, TASK-025, TASK-041

**Scope:**

- Editable and writable Accessibility capabilities.
- Secure Input, protected/system controls, and unavailable host semantics as platform limitations.
- Clipboard-excluded application bundle IDs only for Clipboard capture.
- Unknown insertion context fails without modification while automatic panel eligibility remains governed only by the exact-tag rule.

**Complete when:**

- Secure Input and protected harness controls produce no unintended modification and never claim that Koru bypassed macOS.
- No secure-field or application rule suppresses an otherwise valid automatic exact-tag match on Koru's behalf.
- Clipboard default-sensitive-app tests remain isolated to Clipboard capture.

### TASK-043 — Implement exact typed-trigger state machine

**Depends on:** TASK-040, TASK-041, TASK-042, TASK-045, TASK-046

**Scope:**

- Unknown, Tracking bounded suffix, Panel visible, Completed/dismissed.
- Complete tag matching at the current caret during established writing.
- Minimum three-character tags, left-boundary checks, and longest exact suffix selection.
- Reset and ineligibility conditions.
- Reserved clp transition.
- Phase 50 typed-session adapter into the shared TASK-045 panel and TASK-046 insertion transaction.
- Continued target-field typing and deliberate Tab transfer into panel search without changing the tracked exact tag.

**Complete when:**

- A typed panel can become visible only when the text ending at the caret equals a complete assigned tag or the reserved `clp` command.
- Empty focus alone, a partial or fuzzy tag, and content-only matches never open the typed panel.
- Generated tests cover established writing, multi-word tags, left boundaries, Unicode/UTF-16 ranges, and the three-character minimum.
- Dismissal or insertion clears the active match and Koru's bounded suffix.

### TASK-044 — Implement caret placement and nonactivating panel shell

**Depends on:** TASK-014, TASK-041

**Scope:**

- Nonactivating NSPanel.
- AX/AppKit coordinate conversion.
- Multi-display clamping and above/below flip.
- Target process/focus preservation.
- Labeled fallback placement.

**Complete when:**

- Harness placement is within eight points of a valid caret rectangle.
- Missing bounds uses a documented fallback without claiming caret anchoring.

### TASK-045 — Implement tiny result panel and keyboard navigation

**Depends on:** TASK-024, TASK-034, TASK-044

**Scope:**

- Shared Saved-item and Clipboard result rows for manual and typed invocation adapters.
- Manual-recall search input captured inside the panel.
- Stable selection.
- Up/down, Return, Escape, and click.
- VoiceOver semantics and reduced-motion behavior.

**Complete when:**

- Panel never inserts on appearance.
- TASK-034 manual recall works during established writing without TASK-040 or Input Monitoring.
- Escape preserves target text and restores focus after manual recall.
- Result identity remains stable through live updates.

### TASK-046 — Implement insertion coordinator and tiers

**Depends on:** TASK-003, TASK-041, TASK-045

**Scope:**

- Target transaction snapshot and immediate revalidation.
- Manual-recall insertion at the caret or over an explicitly active selection.
- Typed exact-tag ranges supplied only by the TASK-043 Phase 50 adapter.
- Tier A direct AX replacement.
- Tier B current-host-only pasteboard plus Paste event.
- Tier C copy-only fallback.
- Koru-originated pasteboard marker.

**Complete when:**

- Focus/range mismatch produces no target modification.
- Manual hotkey recall can complete safe insertion before the typed-session adapter is enabled.
- Explicit insertion occurs once.
- Every failure reaches a safe fallback without deleting the matched tag.

### TASK-047 — Preserve legacy template compatibility (superseded product surface)

**Depends on:** TASK-012, TASK-045, TASK-046

**Scope:**

- Keep supported older template fields and placeholder payloads decodable during vault and export migration.
- Keep compatibility parsing deterministic and non-executable.
- Do not expose template creation, completion, or behavior selection in the canonical editor.
- Canonical saves write reusable content plus exact tags and clear obsolete template fields.

**Complete when:**

- Supported legacy fixtures remain readable and migrate without content loss.
- New saved items require only content plus one or more exact tags.
- No user-facing Template label, field-completion flow, or template behavior is reachable.

## 7. Clipboard workstream

### TASK-050 — Implement pasteboard monitor and safe decoder

**Depends on:** TASK-023, TASK-025, TASK-030, TASK-032

**Scope:**

- changeCount monitor.
- AccessBehavior availability handling.
- Multi-item grouping.
- Text/RTF/HTML/image/file URL/media reference decoding.
- Type, byte, pixel, and allocation limits.
- Koru-originated change suppression.

**Complete when:**

- Mixed fixtures persist correctly.
- Unknown, denied, malformed, and oversized inputs fail safely.
- NSPasteboardItem data is materialized only under policy.

### TASK-051 — Implement clp recall experience

**Depends on:** TASK-024, TASK-034, TASK-043, TASK-045, TASK-046, TASK-050

**Scope:**

- Reserved clp mode.
- Dedicated registered Clipboard-recall hotkey supplied by TASK-034, independent of typed activation.
- Mixed type badges and safe previews.
- Search/ranking within retained clipboard events.
- Focused panel search after Tab without extending or changing the original clp span.
- Missing-file and unsupported-target states.

**Complete when:**

- `clp` is eligible at a left boundary anywhere in ordinary writing.
- The Clipboard hotkey opens Clipboard recall with TASK-040 stopped and Input Monitoring denied.
- Mixed results insert through the documented target tier.
- Full file/video bytes are not loaded for result rendering.

### TASK-052 — Build clipboard history controls

**Depends on:** TASK-025, TASK-031, TASK-050

**Scope:**

- Enable/disable.
- Current access state.
- Clear history.
- Save to Library through the normal saved-item flow.
- Retention controls.
- Never Save Clipboard From list.

**Complete when:**

- Disabling stops capture immediately.
- Clear removes only clipboard history.
- Settings reflect actual retained count and encrypted bytes without content telemetry.

## 8. Selection-capture workstream

### TASK-060 — Implement optional selection icon

**Depends on:** TASK-014, TASK-041, TASK-042, TASK-044

**Scope:**

- Stable Select All detection in a nonsecure editable control.
- Full-range proof: selected range begins at zero and equals full character count.
- Tiny nonactivating icon.
- Immediate dismissal conditions.
- Explicit open of save confirmation.

**Complete when:**

- Unsupported notification/bounds means no icon.
- Partial selections mean no icon and retain hotkey/Services fallbacks.
- Secure/excluded contexts never show it.
- No content persists before Save.

### TASK-061 — Implement Save Selection Service

**Depends on:** TASK-010, TASK-012

**Scope:**

- NSServices declaration.
- Service provider registration.
- Supported string and rich-text send types.
- Shared save-confirmation input.

**Complete when:**

- Harness host sends a selection without Accessibility.
- Service never replaces the selection or general clipboard.

### TASK-062 — Implement global Save Selection shortcut

**Depends on:** TASK-034, TASK-041, TASK-042

**Scope:**

- Configurable registered Save Selection command supplied by TASK-034.
- Explicit AX selected-text read.
- Services guidance when AX is unsupported.
- Shared save-confirmation input.

**Complete when:**

- Supported selection opens confirmation.
- Unsupported selection does not synthesize Copy or disturb the clipboard.

### TASK-063 — Implement save confirmation/editor

**Depends on:** TASK-012, TASK-022, TASK-024, TASK-060, TASK-061, TASK-062

**Scope:**

- Review captured content.
- Reusable content.
- One or more exact word-or-phrase tags, each meeting the three-character minimum.
- Reserved `clp`, duplicate, and empty-tag validation.
- Save/cancel.
- Duplicate warning.

**Complete when:**

- Cancel leaves no persistent draft.
- Save creates one encrypted saved item and updates the in-memory index.

## 9. Product UI workstream

### TASK-070 — Build Library and saved-item editor

**Depends on:** TASK-014, TASK-022, TASK-024

**Scope:**

- Search, browse, create, edit, duplicate, pin, archive, move to Recently Deleted, restore, and permanently delete with confirmation.
- Content-type previews.
- Exact-tag validation including minimum length, duplicates, and reserved `clp` conflict.
- Content and one-or-more exact-tag editing with no title, behavior picker, match-term mode, or template editor.

**Complete when:**

- CRUD remains usable without system integration permissions.
- Archive and Recently Deleted are distinct destinations; restoring preserves the stable ID, while final deletion removes the record and owned assets transactionally.
- No decrypted content remains in persistent UI restoration state.

### TASK-071 — Build Settings and exclusion management

**Depends on:** TASK-025, TASK-030, TASK-033, TASK-034, TASK-052

**Scope:**

- Permissions status.
- Typed matching and selection icon toggles.
- Global shortcuts.
- Retention and asset limits.
- Never Save Clipboard From; automatic typed recall has no per-app Never Observe list.
- Launch at Login.
- Pause and clear/reset entry points.

**Complete when:**

- Settings reflect actual service state, not stale preferences.
- Security-affecting changes apply immediately.

### TASK-072 — Implement import and export

**Depends on:** TASK-022, TASK-070

**Scope:**

- Explicit Open/Save panels.
- Versioned saved-item format.
- Plaintext export warning.
- Clipboard history excluded by default.
- Validation and conflict handling.

**Complete when:**

- Round-trip fixtures pass.
- Cancel creates no output.
- Malformed import cannot corrupt the active vault.

## 10. Diagnostics and operations workstream

### TASK-080 — Implement privacy-safe structured logging

**Depends on:** TASK-020, TASK-011

**Scope:**

- OSLog categories and privacy annotations.
- Error codes, capability outcomes, insertion tiers, latency, and aggregate counters.
- Prohibited-field guard tests.
- Bounded retention.

**Complete when:**

- Known private fixtures never appear in logs.
- Every fallback has a diagnostic reason code.

### TASK-081 — Implement Diagnostics screen and support bundle

**Depends on:** TASK-030, TASK-034, TASK-080

**Scope:**

- Version, OS, architecture, permission state, registered-hotkey status, event-tap health, pasteboard state, repository state, and compatibility outcomes.
- Explicit previewable/redactable local export.
- No automatic upload.

**Complete when:**

- Export passes the redaction suite.
- A support person can distinguish permission, AX, pasteboard, insertion, migration, and key-loss failures without content.

### TASK-082 — Implement local watchdogs and recovery actions

**Depends on:** TASK-026, TASK-030, TASK-040, TASK-041, TASK-050, TASK-081

**Scope:**

- Event-tap recovery.
- AX observer rebuild.
- Pasteboard monitor suspension.
- Repository degraded mode.
- Retry, clear history, integrity check, restore encrypted backup, and reset vault actions.

**Complete when:**

- Repeated failure cannot create a busy loop.
- Every destructive action requires confirmation and produces a local audit outcome without user content.

## 11. Testing and compatibility workstream

### TASK-090 — Build Koru Integration Harness

**Depends on:** TASK-010, TASK-011

**Scope:**

- AppKit, SwiftUI, WebKit, secure, rich, custom, stale, delayed, and multi-window controls defined in section 10.
- Expected target-value and focus recorder.

**Complete when:**

- Harness supports deterministic AX, placement, insertion, clipboard, and Services assertions.

### TASK-091 — Implement locked-behavior and generated tests

**Depends on:** TASK-043, TASK-046, TASK-090

**Scope:**

- Exact complete-tag invariant.
- No typed panel on empty focus alone, a partial tag, a fuzzy match, or a content-only match.
- Typed panel allowed when a qualifying complete tag or reserved `clp` ends at the caret with a valid left boundary.
- Explicit insertion.
- Dismissal.
- Target mismatch.
- Secure/excluded states.
- 100,000-sequence seeded run.

**Complete when:**

- Zero typed-panel openings for partial/nonqualifying text and zero automatic insertions; exact tags must open reliably during established writing.
- Failing seeds become permanent regression tests.

### TASK-092 — Implement security, parser, and migration test suites

**Depends on:** TASK-022, TASK-023, TASK-025, TASK-050, TASK-080

**Scope:**

- Plaintext-at-rest scan.
- Ciphertext tamper.
- Key loss.
- Pasteboard fuzz corpus.
- Retention boundaries.
- Diagnostics redaction.
- Migration interruption and restore.

**Complete when:**

- Section 09 security acceptance criteria pass in Release configuration.

### TASK-093 — Run accessibility, performance, and reliability qualification

**Depends on:** TASK-045, TASK-050, TASK-070, TASK-081, TASK-090

**Scope:**

- VoiceOver and keyboard-only use.
- Transparency, motion, contrast, appearance.
- Event callback, search, panel, insertion, clipboard, CPU, memory, and soak budgets.

**Complete when:**

- Section 10 budgets pass on recorded reference hardware.
- Deviations have an explicit release-blocking decision.

### TASK-094 — Execute external compatibility matrix

**Depends on:** TASK-051, TASK-060, TASK-061, TASK-062, TASK-093

**Scope:**

- Native, WebKit, Chromium, Electron, Office, browser document editor, developer tool, terminal, Finder/system, remote/canvas, and sensitive categories.
- macOS 13, macOS 15, current stable.
- Apple Silicon and supported Intel.

**Complete when:**

- Every tested target has a versioned capability label and known limitations.
- The public matrix is updated.

## 12. Release and open-source workstream

### TASK-100 — Implement signing and notarization configuration

**Depends on:** TASK-001, TASK-010, TASK-013

**Scope:**

- Developer ID signing.
- Hardened Runtime.
- Minimal entitlements.
- Secure timestamp.
- notarytool submission and stapling.
- Gatekeeper validation.

**Complete when:**

- A quarantined clean download passes codesign, notarization, stapling, Gatekeeper, and universal-architecture checks.

### TASK-101 — Implement protected release pipeline

**Depends on:** TASK-092, TASK-093, TASK-100

**Scope:**

- Protected tags and release environment.
- Manual signing approval.
- Universal archive and DMG.
- Checksums, dependency manifest, SBOM, provenance, and draft release.
- No secrets for forks.

**Complete when:**

- One reproducible release candidate completes from a clean checkout and remains draft until manual approval.

### TASK-102 — Prepare contributor, privacy, security, and support documentation

**Depends on:** TASK-001, TASK-002, TASK-003, TASK-081

**Scope:**

- README and build instructions.
- Permission and privacy explanation.
- Compatibility policy.
- SECURITY.md and private disclosure route.
- Issue templates that forbid user content by default.
- Diagnostics and recovery guide.
- License and dependency acknowledgments.

**Complete when:**

- A new contributor can build without release credentials.
- A person can understand every permission, retained-data type, fallback, and hard limit before enabling it.

### TASK-103 — Release-candidate acceptance

**Depends on:** TASK-031, TASK-047, TASK-071, TASK-072, TASK-082, TASK-091, TASK-092, TASK-094, TASK-101, TASK-102

**Scope:**

- Fresh install.
- Upgrade from previous test release with populated encrypted vault.
- Permission matrix.
- Compatibility matrix.
- Security and performance gates.
- Signed/notarized artifact.
- Release notes and rollback artifact.

**Complete when:**

- All section 10 release gates pass.
- No open Critical or High defect remains.
- Publication is a separate explicit manual action.

## 13. Dependency summary

The principal dependency chains are:

- Platform decisions → project shell → modules/models → macOS integrations.
- Threat model → Keychain → encrypted repository/assets → search and retention.
- Permission Coordinator → GlobalHotKeyRegistrar → manual Saved recall, Clipboard recall, and Save Selection commands without Input Monitoring.
- Search + caret placement + registered manual recall → shared panel → insertion in Phase 40.
- Event tap + optional AX context + shared panel/insertion → exact-tag suffix state machine and typed-session adapter in Phase 50.
- Repository/assets/retention + pasteboard permission → clipboard monitor → clp.
- AX/context + panel placement → optional selection icon.
- Services and registered Save Selection command + AX selected-text read → shared save confirmation.
- Logging + integration health → diagnostics → recovery.
- Harness + feature completion → generated/security/performance tests → compatibility matrix.
- Quality gates + signing → protected release candidate.

Work on UI, repository, permission onboarding, harness, Services, and release infrastructure can proceed in parallel once their listed contracts exist.

## 14. Decisions the main index must surface

- macOS 13 minimum and universal Intel/Apple Silicon artifact.
- Direct Developer ID download; no Mac App Store build.
- Nonsandboxed core because of Accessibility requirements.
- No InputMethodKit or privileged/background helper.
- Global shortcuts use a public registered-hotkey path independent of the CG event tap and Input Monitoring.
- The event tap is limited to typed matching and its target-field panel navigation.
- Typed matching uses exact complete tags of at least three characters at a left boundary anywhere in ordinary writing.
- No automatic insertion.
- clp is the reserved clipboard-recall command.
- Selection icon is optional; Services and global hotkey are supported fallbacks.
- Clipboard history defaults off. ADR-001 locks V1 limits to 7 days, 500 events, 256 MiB total encrypted assets, and 25 MiB per retained image.
- Files and videos remain references in V1; Save creates a permanent saved-item reference without silently extending the temporary entry's retention.
- Encrypted local repository and Keychain-held, nonsynchronizable key.
- No cloud sync, content telemetry, background network request, or automatic updater in the initial release.
- macOS 26+ current visual appearance with a standard material fallback on macOS 13 through pre-glass releases.

## 15. Official Apple references

- [AXUIElement API](https://developer.apple.com/documentation/applicationservices/axuielement_h)
- [Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services)
- [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)
- [NSServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsservices)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
- [CryptoKit](https://developer.apple.com/documentation/cryptokit/)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

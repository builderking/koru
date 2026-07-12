# 10. Testing, Quality, and Release

## 1. Quality bar

Koru modifies text in other applications and retains private clipboard content. A false positive is more damaging than a missed suggestion.

Release priorities, in order:

1. Never show a typed panel unless the complete suffix before the caret exactly matches an assigned tag of at least three characters at a left boundary or is the reserved `clp` command; partial, fuzzy, derived-label, content, focus-only, and stale-generation matches never open it.
2. Never insert without explicit confirmation, including in secure or password fields where Koru applies no product exclusion and macOS may suppress access.
3. Never delete or replace text when the target process, exact range, or input generation changed.
4. Never leak content into logs, diagnostics, release artifacts, or network traffic.
5. Preserve data through upgrades and failure.
6. Degrade visibly to synthetic paste, copy-only, palette-only, Services, or manual paste when a target is unsupported.
7. Keep the event path fast enough that Koru never affects normal typing.

Any violation of priorities 1 through 4 is release-blocking.

## 2. Test layers

### 2.1 Unit tests

Cover pure and deterministic logic:

- Exact-tag suffix state machine and generation invalidation.
- Exact automatic matching and separate fuzzy manual ranking.
- Reserved clp mode.
- Result selection and dismissal.
- Insertion transaction validation.
- Synthetic Backspace-and-paste validation and generated-event filtering.
- Clipboard exclusion evaluation.
- Clipboard type classification.
- Keyed deduplication.
- Retention and asset-budget eviction.
- Saved-item lifecycle transitions: Active, Archived, Recently Deleted, Restore, recovery-window expiry, and final purge.
- Encryption, authentication failure, and key loss.
- Schema and ciphertext-format migrations.
- Diagnostics redaction.
- Permission-state reducer.
- Multi-display placement calculations.

Use property-based or generated-event tests for the state machine. Generate sequences containing:

- Focus changes.
- Empty and established destination values.
- Caret movement.
- Selection.
- Typing.
- Paste.
- Delete and undo.
- Composition and unknown mutations.
- Panel navigation.
- Dismissal.
- Target replacement.
- Permission revocation.

Invariant: no generated sequence can enter Panel visible unless the current committed suffix is a complete assigned tag of at least three characters at a left boundary or reserved `clp`, and the process/generation still match. No generated sequence modifies text without explicit selection and immediate target validation.

### 2.2 Component tests

Every macOS integration sits behind a protocol and fake:

- AXClient and AXObserver.
- EventTap.
- PasteboardClient.
- PermissionClient.
- LoginItemClient.
- KeychainClient.
- Clock.
- Repository and encrypted asset store.
- FrontmostApplicationProvider.

Component tests simulate:

- AXError values.
- Missing attributes.
- Delayed or stale elements.
- Pasteboard ownership changes.
- Permission denial and revocation.
- Event-tap timeout.
- Keychain lock and missing key.
- Disk-full and interrupted transaction.

### 2.3 Koru Integration Harness

Build a small test-only macOS host application with controlled fields:

- AppKit NSTextField, NSTextView, search field, token field, and NSSecureTextField.
- SwiftUI TextField, TextEditor, SearchField-equivalent, and SecureField.
- WebKit input, textarea, contenteditable, and password controls.
- Empty and prefilled states.
- Caret at zero, middle, and end.
- Read-only and disabled controls.
- Rich-text destinations.
- Image/file paste destinations.
- A custom canvas control with deliberately incomplete Accessibility.
- A control that replaces its AX element while typing.
- A delayed/unresponsive AX responder.
- Multiple windows, sheets, full-screen spaces, and multiple displays.

The harness records expected target value, selection, focus, and paste representations without using personal data.

### 2.4 UI and accessibility tests

Automate Koru-owned surfaces with XCTest/XCUITest:

- Onboarding.
- Permission cards and degraded states.
- Menu-bar menu.
- Library and editor.
- Archive, Recently Deleted, Restore, and permanently delete confirmation.
- Tiny panel keyboard navigation.
- Clipboard mixed-item rows.
- Selection-save confirmation.
- Settings, Clipboard exclusions, retention, clear/reset flows.
- Diagnostics preview and export.

Use Accessibility Inspector and VoiceOver for manual verification of:

- Labels, roles, and values.
- Logical navigation.
- Keyboard-only operation.
- Focus restoration.
- Increase Contrast.
- Reduce Transparency.
- Reduce Motion.
- Light and dark appearance.
- Large system text and different accent colors.

Apple provides XCTest and Accessibility Inspector as the supported testing and inspection tools: [XCTest](https://developer.apple.com/documentation/xctest), [Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibility-inspector).

### 2.5 Security tests

- Search all application data, WAL, temp files, backups, and logs for known plaintext fixtures.
- Modify ciphertext, nonce, authenticated metadata, and schema version; every modification must fail authentication.
- Remove or replace the Keychain key and verify the existing vault never opens with a new key.
- Fuzz pasteboard item types, sizes, malformed URLs, invalid image data, RTF, and HTML.
- Confirm HTML is never script-executed.
- Confirm file references are not opened or executed automatically.
- Confirm Recently Deleted records and assets remain encrypted and recoverable until final purge, then disappear from active indexes and the live encrypted store.
- Confirm current-host-only pasteboard writes where supported.
- Confirm no network request occurs in the initial production build.
- Confirm source builds and release builds contain no debug entitlement or secrets.
- Confirm exported diagnostics exclude all prohibited data.

Run Address Sanitizer, Undefined Behavior Sanitizer, and Thread Sanitizer in separate CI or scheduled jobs where compatible with the target.

## 3. Locked-behavior test suite

### 3.1 Exact-tag matching anywhere

Release-blocking scenarios:

| Scenario | Expected result |
|---|---|
| Focus any field; type nothing | Never appear |
| Assigned tag is `dav`; type `da` | Never appear |
| Assigned tag is `dav`; type complete `dav` at field start | Tiny panel may appear |
| Type complete `dav` after existing paragraph text and a space | Tiny panel may appear |
| Put caret in the middle of existing text; type complete `dav` at a left boundary | Tiny panel may appear and range covers only `dav` |
| Type `adav` where the `dav` suffix has no left boundary | Never appear |
| Assign phrase tag `project reply`; type the complete phrase | Tiny panel may appear with the full phrase range |
| Type a derived-label/content word that is not an assigned tag | Never appear automatically; manual fuzzy recall may find it |
| Two items share `dav` | One panel shows both stable result IDs |
| Tags `dav` and `hello dav` both match the suffix | Only the longest complete tag participates |
| Type reserved `clp` after existing writing at a left boundary | Clipboard panel may appear |
| Dismiss panel, then complete the tag again later | A new valid generation may reopen it |
| Continue typing past an exact tag before selection | Old panel/context becomes stale and cannot insert |
| Begin unverified IME composition | Blind rolling-suffix fallback cannot insert; verified committed AX text may match after commit |
| AX value/range unavailable but typed suffix is exact | Panel may appear with synthetic/copy capability |
| Explicitly insert result | Exactly one result replaces exactly the matched tag range |
| Target field changes before insertion | Cancel without modifying text |
| Secure field or sensitive app | Apply the same exact-tag rule; if macOS suppresses input/AX/posting, leave text untouched and expose the supported fallback |

Run the generated state-machine suite with at least 100,000 deterministic seeded event sequences per release configuration. Preserve failing seeds as regression fixtures.

### 3.2 Explicit insertion

- No timer, top-result selection, blur event, or query completion can trigger insertion.
- Return inserts only while a result is actively selected.
- Escape closes without modifying target text.
- Click inserts only the clicked stable result ID.
- Double-delivered input events cannot cause duplicate insertion.
- Tier failure advances once to the next safe tier and never loops.
- Direct AX replacement uses the matched UTF-16 range, not character zero.
- Synthetic fallback requires unchanged process and input generation, posts exactly one marked Backspace per matched grapheme, then Command-V, and its generated events are ignored by Koru's tap.
- Copy-only fallback does not remove the matched tag.

### 3.3 clp mixed recall

Fixtures:

- Plain and multiline text.
- RTF and HTML with a plain-text alternative.
- Web URL.
- PNG/TIFF image.
- Multiple images.
- Single and multiple file URLs.
- Video file reference.
- Mixed multi-item clipboard event.
- Unsupported custom type.
- Oversized image.
- Missing or moved file.

Verify:

- Correct type badge and safe preview.
- One clipboard copy creates one logical history event.
- Koru-originated paste is not recaptured as a duplicate.
- Expired items disappear from both persistent storage and in-memory search.
- File/video recall does not read an entire asset to render the row.
- A text-only target reaches an appropriate text or copy-only fallback for nontext content.
- `clp` works at a left boundary anywhere, not only at field start.
- Pressing Tab after clp moves focus into panel search without changing the matched clp span; Escape restores target focus and leaves clp untouched.

### 3.4 AX and synthetic insertion fallbacks

- Honest AX replacement is verified against the resulting caret/value before success is reported.
- A host that acknowledges AX replacement without applying it advances to paste or synthetic fallback without duplicating content.
- Synthetic events carry a Koru marker and never re-enter matching or panel command handling.
- Event-post preflight failure performs zero Backspaces and reaches Copy.
- A process, focus, pointer, caret, or input-generation change performs zero Backspaces and reaches Copy.
- Unicode tags use grapheme count for synthetic deletion and UTF-16 ranges for AX replacement.

### 3.5 Selection capture

- A stable Select All selection in a supported editable control shows the optional icon when enabled.
- A partial selection never shows the optional icon, but the hotkey and Services paths remain available.
- Collapsed selection, scroll, typing, focus change, exclusion, permission loss, or secure state hides it.
- Unsupported AX notification or bounds produces no icon and no repeated polling loop.
- Save Selection hotkey works through AX in the harness.
- Save Selection Service works through the service pasteboard without Accessibility.
- Service and hotkey open the same confirmation/editor pipeline.
- No path persists the selection until Save is confirmed.

## 4. Compatibility matrix

### 4.1 Capability labels

Record one of:

- **Full** — exact-tag matching, caret panel, direct or paste insertion, and selection capture.
- **Paste** — exact-tag matching and caret context work; insertion uses pasteboard.
- **Synthetic** — exact-tag panel works but insertion requires validated Backspace plus Command-V because AX replacement/selection is unavailable.
- **Copy-only** — result is copied for manual paste.
- **Palette-only** — automatic typed matching is unavailable; global/menu-bar palette remains.

Do not report unsupported behavior as Full merely because it worked once.

### 4.2 Host categories

Release testing covers:

| Category | Representative targets |
|---|---|
| Native AppKit | TextEdit, Mail, standard Koru harness controls |
| Native SwiftUI | Koru harness, current Apple SwiftUI fields |
| Apple productivity | Notes, Pages |
| WebKit | Safari simple inputs, textareas, contenteditable |
| Chromium | Chrome simple inputs, textareas, contenteditable |
| Electron | Slack or Discord, Visual Studio Code |
| Office | Microsoft Word |
| Browser document editors | Google Docs |
| Developer tools | Xcode editor, Visual Studio Code, one JetBrains editor |
| Terminals | Terminal and iTerm2 |
| Finder/system fields | Finder rename and other ordinary nonsecure fields |
| Remote/canvas controls | A remote-desktop client and harness canvas control |
| Sensitive controls | NSSecureTextField, browser password field, password manager |

Use dedicated test documents and accounts. Do not use personal clipboard or production data.

Expected limitations:

- Browser document editors, terminals, remote desktops, canvas editors, and custom source editors may be Full, Paste, Synthetic, Copy-only, or Palette-only.
- The selection icon is not a compatibility requirement where the target lacks selected-text notifications or bounds.
- Secure and password targets are tested without a Koru exclusion. The matrix records whether macOS exposes Full, Paste, Synthetic, Copy-only, or Palette-only behavior and never implies Secure Input can be bypassed.

Publish the compatibility matrix with each stable release and include the tested app and macOS versions.

## 5. Operating-system and hardware matrix

### Release-blocking operating systems

- macOS 13 latest available patch.
- macOS 15 latest available patch, representing the last pre-Liquid-Glass visual generation.
- Current stable macOS latest patch.

### Hardware

- Apple Silicon on every release-blocking OS that supports the test machine.
- Intel on macOS 13 and the newest supported Intel release.
- At least one Retina single-display setup.
- Mixed-scale two-display setup.
- Built-in display plus external display.

### Scenarios

- Normal desktop, Stage Manager, full-screen Space, and multiple Spaces.
- Light/dark appearance.
- Reduce Motion, Reduce Transparency, and Increase Contrast.
- Sleep/wake.
- Session lock/unlock.
- Fast user switch.
- App moved before first launch and app updated in place.
- US, non-US Latin, right-to-left, dead-key, and at least one CJK input method.

Beta macOS testing begins after Apple publishes the beta, but a beta-only failure is not release-blocking until the release candidate unless it reveals data loss or a security issue likely to affect stable systems.

## 6. Permission matrix

Test each permission as:

- Never requested.
- Request shown.
- Denied.
- Granted.
- Revoked while Koru runs.
- Granted after initial denial.
- Changed while panel is visible.
- Changed after app update.
- Affected by moving or rebuilding the app.

Specific combinations:

- Accessibility granted, Input Monitoring denied.
- Input Monitoring granted, Accessibility denied.
- Both granted.
- General pasteboard default/ask.
- General pasteboard always allow.
- General pasteboard always deny.
- Launch at Login registered, requires approval, denied, and unregistered.

Because system privacy dialogs and settings are user-controlled, hosted CI cannot fully replace clean-machine manual permission testing. Use resettable test users or restored test-machine snapshots for release validation.

## 7. Performance and reliability budgets

Measure with OS signposts and Instruments, using release builds.

| Area | Acceptance budget |
|---|---|
| Event-tap callback | p99 under 1 ms; no synchronous AX, pasteboard, database, or UI work |
| Exact-tag suffix lookup at default saved-item limit | p95 under 50 ms |
| Qualifying key to visible panel in harness | p95 under 150 ms |
| Explicit selection to completed supported insertion | p95 under 250 ms |
| Allowed clipboard change to searchable retained entry | under 1 second |
| Idle CPU with event tap and clipboard history enabled | median under 0.5%, p95 under 1% on reference hardware |
| Resident memory with 500 text clips and bounded thumbnails | under 150 MB after steady state |
| Event soak | 100,000-event run with no tap timeout, lost target character, duplicate insertion, or unbounded growth |
| AX failure recovery | no tight retries and no main-thread stall over 100 ms |

Record reference hardware, OS, build, and fixture size with every benchmark. A regression over 20 percent requires review even when still inside the absolute budget.

Apple's signpost and Instruments facilities are designed for measuring intervals and performance behavior: [Signposts](https://developer.apple.com/documentation/os/signpost), [Instruments](https://developer.apple.com/documentation/xcode/instruments).

## 8. CI pipeline

### 8.1 Pull-request checks

- Validate Markdown links and formatting for build-plan and user docs.
- Resolve dependencies from the committed lock file.
- Build Debug and unsigned Release configurations.
- Run unit and component tests.
- Run the integration harness tests that do not require TCC interaction.
- Run formatting and lint checks.
- Run diagnostics-redaction tests.
- Run known-plaintext-at-rest tests against a temporary vault.
- Run dependency and secret scanning.
- Verify no new network, hardened-runtime exception, or privacy entitlement appears without review.

Forked pull requests never receive signing or notarization secrets.

### 8.2 Scheduled checks

- Generated state-machine suite.
- Pasteboard parser fuzz corpus.
- Sanitizer configurations.
- Performance and memory benchmark.
- Dependency vulnerability audit.
- Current stable Xcode build.
- Current macOS beta build when runners are available.

### 8.3 Tagged release workflow

1. Start from a protected, signed version tag.
2. Use a clean checkout and committed dependency resolution.
3. Run all release-blocking automated tests.
4. Archive a universal Release build.
5. Sign nested code and the outer app with Developer ID Application.
6. Verify Hardened Runtime, entitlements, secure timestamp, and absence of get-task-allow.
7. Submit with notarytool and require Accepted status.
8. Staple and validate the ticket.
9. Package the signed app in the release DMG.
10. Sign/notarize the final deliverable as required by the packaging choice.
11. Verify codesign, Gatekeeper assessment, architecture slices, and launch from a quarantined clean download.
12. Generate SHA-256 checksums, dependency manifest, software bill of materials, and provenance metadata.
13. Create a draft release with notes and compatibility matrix.
14. Require manual release-owner approval before publication.

Apple requires Developer ID, Hardened Runtime, secure timestamps, and notarization for directly distributed modern macOS software: [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## 9. Release gates

A stable release requires:

- All locked-behavior scenarios passing.
- No open Critical or High security defect.
- No data-loss or database-migration defect.
- No unintended modification when Secure Input suppresses capabilities, and no clipboard-sensitive-app exclusion defect.
- No plaintext-at-rest or diagnostics-redaction failure.
- Permission-state matrix completed on a clean machine.
- Operating-system and hardware matrix completed.
- Compatibility matrix updated.
- Performance budgets met or an explicitly documented release decision.
- Upgrade from the previous stable release verified with a populated encrypted vault.
- Fresh install and uninstall/reset verified.
- Signed/notarized artifact verified from a quarantined download.
- User-facing permission, privacy, compatibility, and recovery documentation updated.
- CHANGELOG, checksums, SBOM, and source tag published together.

## 10. Severity definitions

- **Critical:** content exposure, arbitrary code execution, signature/update compromise, key disclosure, persisted or transmitted secure-field input, or unrecoverable widespread data loss.
- **High:** typed popup without a complete exact tag, unintended insertion/deletion, repeatable private-data logging, vault corruption, permission bypass, or clipboard-sensitive-app capture.
- **Medium:** fallback failure, incorrect caret placement, compatibility regression, retention defect without exposure, elevated resource use, or broken diagnostics.
- **Low:** visual defect, copy issue, minor accessibility-label defect, or isolated nonblocking compatibility problem.

Critical and High defects block release.

## 11. Upgrade, rollback, and recovery

- Every migration is transactional and starts with an encrypted backup.
- A binary must refuse to open a schema newer than it understands.
- Failed migration restores the prior database and leaves integrations stopped.
- Keep the previous notarized stable artifact and its checksums available.
- Rolling back the app does not automatically roll back data. Restore requires the compatible encrypted pre-migration backup.
- Release notes identify irreversible schema or ciphertext changes.
- For a bad release, mark it withdrawn, restore the previous release as recommended, publish a security notice when relevant, and keep evidence needed for incident review.
- If signing credentials are compromised, follow Apple's certificate and notarization incident process and rotate update/release credentials.

Apple notes that notarization maintains an audit trail and supports ticket revocation coordination when a Developer ID key is exposed: [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## 12. Initial update policy

The initial release does not contain an automatic updater.

- Check for Updates opens the official Koru release page after an explicit action.
- The page publishes source, notarized DMG, checksum, compatibility matrix, and release notes.
- Automatic updates require a later design decision covering a second update-signing key, feed integrity, rollback, proxy/privacy behavior, and failure recovery.

This decision must be surfaced in the main build-plan index.

## 13. Quality acceptance criteria

1. Zero typed-panel openings from focus alone, incomplete tags, tags under three characters, fuzzy/derived-label/content matches, missing left boundaries, or stale generations; complete exact tags and `clp` work at the beginning, middle, and end of writing.
2. Zero automatic insertions.
3. Zero target modifications after focus/range mismatch.
4. Zero unintended modification when macOS Secure Input or a protected host suppresses observation, AX state, or event posting; Koru applies no automatic secure/app exclusion.
5. Zero known plaintext fixture occurrences in persistent files and logs.
6. All supported controls reach their documented insertion tier or copy-only fallback.
7. Unsupported selection-icon contexts retain Services and global-hotkey capture.
8. All permission denial/revocation states are recoverable without restart unless macOS itself requires it.
9. All release-blocking OS and hardware targets launch the same universal artifact.
10. The quarantined release artifact passes Gatekeeper, signature, notarization, and stapling validation.
11. Upgrade preserves saved items, saved items created from Clipboard, archive and Recently Deleted states, Clipboard exclusions, retention settings, and Keychain access.
12. The current release's diagnostics can distinguish permission denial, event-tap failure, AX unsupported, pasteboard denial, insertion-tier failure, migration failure, and key loss without containing user content.

## 14. Official Apple references

- [XCTest](https://developer.apple.com/documentation/xctest)
- [Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibility-inspector)
- [Signposts](https://developer.apple.com/documentation/os/signpost)
- [Instruments](https://developer.apple.com/documentation/xcode/instruments)
- [Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services)
- [AXUIElement API](https://developer.apple.com/documentation/applicationservices/axuielement_h)
- [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

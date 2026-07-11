# 16. Observability, Support, and Operations

## 1. Operating model

Koru has no backend service in the initial release.

There is:

- No account system.
- No cloud database.
- No remote feature flag.
- No content telemetry.
- No analytics endpoint.
- No crash-upload SDK.
- No automatic update feed.
- No remote compatibility-rule service.

Observability is local, bounded, privacy-safe, and controlled by the person using the Mac. Support is based on a previewable diagnostic bundle that the person explicitly exports and chooses to attach to an issue.

This keeps operations consistent with Koru's local-first promise, but it means the project cannot remotely measure adoption, failures, performance, or permission state. Product and support copy must not imply that maintainers can see a person's Koru data.

## 2. Observability principles

1. **Content is never an observable.**
   - No keystrokes, prefixes, saved-item bodies, clipboard bodies, selected text, filled template values, titles, tags, previews, paths, filenames, window titles, document titles, or URLs.

2. **Record outcomes, not inputs.**
   - Permission state, capability tier, error code, latency, content-type category, and bounded byte bucket are sufficient.

3. **Normal incompatibility is not an error storm.**
   - An unsupported AX attribute or absent selection notification is expected. Aggregate it and show a capability result rather than logging on every key.

4. **Everything is local by default.**
   - Logs and diagnostic counters remain on the Mac.
   - Export and sharing are separate explicit actions.

5. **Diagnostics must be understandable.**
   - A person can see what Koru plans to export and remove optional fields.

6. **Watchdogs fail safe.**
   - Repeated event-tap, AX, pasteboard, or repository failure stops the affected feature instead of retrying indefinitely.

## 3. Structured logging

Use Apple's unified logging through Logger and OSLog.

Categories:

- app.lifecycle
- permissions
- hotkeys
- eventTap
- accessibility
- context
- panel
- insertion
- clipboard
- selectionCapture
- services
- repository
- encryption
- migration
- retention
- performance
- release

Every event has:

- Stable event code.
- Severity.
- Monotonic timestamp.
- App build and schema version.
- Operation category.
- Result enum.
- Optional numeric duration, count, or byte bucket.
- Correlation ID generated for the Koru operation, not derived from content.

Mark all strings private unless they are fixed enums controlled by Koru. Do not interpolate arbitrary NSError descriptions into production logs because they may contain paths or target-app details. Map them to reviewed codes.

Apple's Logger API supports privacy-aware structured logging: [Logging](https://developer.apple.com/documentation/os/logging).

## 4. Event and error taxonomy

### 4.1 Permission

- PERM-AX-UNKNOWN
- PERM-AX-DENIED
- PERM-AX-GRANTED
- PERM-EVENT-DENIED
- PERM-EVENT-POST-DENIED
- PERM-PASTEBOARD-ASK
- PERM-PASTEBOARD-DENIED
- PERM-PASTEBOARD-ALLOWED
- PERM-LOGIN-REQUIRES-APPROVAL

Log state transitions, not repeated state polling.

### 4.2 Registered global hotkeys

- HOTKEY-REGISTERED
- HOTKEY-UNREGISTERED
- HOTKEY-CONFLICT
- HOTKEY-RESERVED-OR-UNSUPPORTED
- HOTKEY-REGISTRATION-FAILED
- HOTKEY-DELIVERED

Record only the Koru command enum and registration result. Do not log the configured key code, modifier sequence, surrounding keyboard events, or target application. A hotkey conflict is integration state, not a denied TCC permission.

### 4.3 Event tap

- EVT-TAP-STARTED
- EVT-TAP-STOPPED
- EVT-TAP-DISABLED-TIMEOUT
- EVT-TAP-DISABLED-USER
- EVT-TAP-RECOVERED
- EVT-TAP-RECOVERY-ABORTED

Never log event key codes, characters, or modifier sequences.

### 4.4 Accessibility and context

- AX-FOCUS-UNAVAILABLE
- AX-ATTRIBUTE-UNSUPPORTED
- AX-NOTIFICATION-UNSUPPORTED
- AX-STALE-ELEMENT
- AX-CANNOT-COMPLETE
- AX-MESSAGING-TIMEOUT
- AX-SECURE-BLOCKED
- AX-EXCLUDED-APP
- CONTEXT-INITIAL-EMPTY-VERIFIED
- CONTEXT-INELIGIBLE

CONTEXT-INELIGIBLE is an aggregate counter by reason enum; it is not emitted for every key.

Target app bundle identifiers are excluded by default. Diagnostics may include an app identifier only after the person turns on Include App Identifiers in the export preview.

### 4.5 Panel and insertion

- PANEL-CARET-ANCHORED
- PANEL-FALLBACK-POSITION
- PANEL-DISMISSED
- INSERT-TARGET-CHANGED
- INSERT-TIER-A-SUCCEEDED
- INSERT-TIER-A-FAILED
- INSERT-TIER-B-SUCCEEDED
- INSERT-TIER-B-FAILED
- INSERT-COPY-ONLY
- INSERT-CANCELLED

Do not log result ID, query, content type beyond a broad category, or content size beyond a bucket.

### 4.6 Clipboard

- CLIP-MONITOR-STARTED
- CLIP-MONITOR-STOPPED
- CLIP-READ-DENIED
- CLIP-TYPE-ACCEPTED
- CLIP-TYPE-UNSUPPORTED
- CLIP-OVERSIZED
- CLIP-MALFORMED
- CLIP-DEDUPE
- CLIP-FILE-MISSING
- CLIP-RETENTION-EVICTED

Allowed categories are text, richText, image, fileReference, mediaReference, multiple, and unknown. Do not log custom pasteboard type strings.

### 4.7 Vault

- VAULT-OPENED
- VAULT-LOCKED
- VAULT-KEY-MISSING
- VAULT-AUTHENTICATION-FAILED
- DB-INTEGRITY-FAILED
- DB-MIGRATION-STARTED
- DB-MIGRATION-SUCCEEDED
- DB-MIGRATION-FAILED
- DB-BACKUP-RESTORED
- VAULT-RESET

Never include record IDs, ciphertext, nonces, SQL text containing values, or Keychain query output.

## 5. Performance observability

Use OS signposts for:

- Event normalization.
- AX context verification.
- Saved-item search.
- Clipboard search.
- Caret calculation.
- Panel presentation.
- Explicit insertion transaction.
- Pasteboard decode.
- Encryption/decryption.
- Retention maintenance.
- Database migration.

Signpost names and correlation IDs are fixed and content-free.

Collect local rolling aggregates:

- Count.
- Minimum.
- Maximum.
- p50, p95, and p99 where sample size is sufficient.
- Failure count by reviewed reason.

Reset fine-grained samples after seven days or 1,000 diagnostic events, whichever comes first. Preserve only current aggregate health after compaction.

Apple's signpost APIs are intended for measuring intervals and work with Instruments: [Signposts](https://developer.apple.com/documentation/os/signpost), [Instruments](https://developer.apple.com/documentation/xcode/instruments).

## 6. Local health model

The menu-bar status and Diagnostics screen expose:

### Healthy

- Vault open.
- Required enabled-feature permissions present.
- Configured global commands successfully registered, or intentionally disabled.
- Event tap active when typed matching is enabled.
- Pasteboard monitor active when history is enabled and permitted.
- Repository integrity last passed.
- No recovery loop.

### Limited

- One optional permission denied.
- One or more global commands have a registration conflict or unsupported chord; equivalent menu commands remain available.
- Clipboard access set to Ask.
- Target app is Palette-only or Copy-only.
- Selection icon unsupported.
- Panel used fallback position.
- Login item requires approval.

### Paused

- Person paused Koru.
- User session locked.
- Privacy shutdown after repeated integration failure.

### Action required

- Vault key missing.
- Database integrity or migration failure.
- Event tap cannot recover.
- Accessibility was revoked while typed matching is enabled.
- Clipboard access is denied while history is enabled.

Status text describes the affected feature and safe next action. It does not use alarm language for ordinary target incompatibility.

## 7. Diagnostics screen

Display:

- Koru version, build, source revision, and release channel.
- macOS version and CPU architecture.
- Code-signing/notarization status summary where public validation is available.
- Vault state and schema/ciphertext format version.
- Encrypted database and asset byte counts.
- Saved-item count and retained clipboard count.
- Retention policy.
- Accessibility, event-listening, post-event, pasteboard, and login-item states.
- GlobalHotKeyRegistrar state per command: registered, disabled, conflict, reserved/unsupported, or failed. Do not include the chord in the default support export.
- Event-tap enabled/disabled state and last reviewed failure code.
- AX observer state and aggregate compatibility outcomes.
- Last insertion tier and result, without content.
- Clipboard monitor state and broad accepted/rejected type counts.
- Last integrity check and migration outcome.
- Local performance aggregates.
- Whether Koru is paused or the session is locked.
- A list of active default/user exclusions by count; names appear only in the interactive local screen, not the default export.

Actions:

- Recheck permissions.
- Retry stopped integration.
- Open relevant Koru settings guidance.
- Run repository integrity check.
- Clear Clipboard History.
- Export diagnostics.
- Open recovery guide.
- Reset Vault through a separate destructive confirmation.

## 8. Diagnostic support bundle

### 8.1 Explicit export only

Koru never uploads a support bundle.

Flow:

1. Person clicks Export Diagnostics.
2. Koru shows every category that will be included.
3. Optional Include App Identifiers is off by default.
4. Person can inspect a human-readable preview.
5. Koru writes the bundle through an explicit Save panel.
6. Person independently chooses whether to attach it to a GitHub issue or private security report.

### 8.2 Bundle contents

- manifest.json
  - Format version.
  - Koru build.
  - Creation time.
  - Included categories.
  - Redaction policy version.
- environment.json
  - macOS version.
  - Architecture.
  - Display count and scale-factor categories, not serial numbers or names.
  - Appearance/accessibility setting booleans relevant to rendering.
- permissions.json
  - State enums only.
- health.json
  - Current local health model.
- events.jsonl
  - Bounded reviewed diagnostic events.
- performance.json
  - Content-free aggregate signpost metrics.
- compatibility.json
  - Capability counts and optional app identifiers.
- repository.json
  - Schema versions, integrity outcome, record counts, encrypted byte counts, and migration result.
- README.txt
  - Plain-language description of what is and is not included.

### 8.3 Never included

- Vault database or encrypted assets.
- Keychain items or keys.
- Ciphertext, nonces, or authentication tags.
- Saved-item or clipboard content.
- Queries or eligible prefixes.
- Selected text.
- Filled template values.
- Titles, tags, previews, file paths, or file names.
- Window/document titles or browser URLs.
- Raw pasteboard types.
- Raw key events.
- Full system log archive.
- Other applications' logs.

### 8.4 Redaction verification

- Export from typed fixtures containing unique canary strings.
- Scan every bundle file for the canaries and their common encodings.
- Reject export if a prohibited pattern is detected.
- Unit-test every field against an allowlist schema.
- Include the redaction-policy version in the manifest.

## 9. Crash and unclean-shutdown handling

- Use the system crash report; do not install a remote crash reporter.
- Maintain a content-free launch marker and clean-shutdown marker.
- On the next launch after an unclean shutdown:
  - Keep typed matching and clipboard monitoring stopped until vault integrity opens successfully.
  - Run lightweight repository and encrypted-asset consistency checks.
  - Show a nonmodal Koru Closed Unexpectedly message with Open Diagnostics.
  - Do not automatically collect or upload the system crash report.
- The support guide explains how to attach a macOS crash report after reviewing it for private data.

Do not catch fatal signals merely to continue running or attempt database writes from an unsafe crash context.

## 10. Watchdogs and self-recovery

### 10.1 Global hotkey registrar

- Register configured commands at launch and after an explicit shortcut change.
- Unregister replaced commands before committing a new valid registration; preserve or restore the previous valid binding when replacement fails.
- Revalidate registrations after wake and app update through bounded, idempotent registration work.
- Mark conflicts and unsupported chords Limited and keep equivalent menu commands available.
- Do not request Input Monitoring or start the event tap as a recovery path.

### 10.2 Event tap

- Re-enable once after a timeout/user disable event when permission is still present.
- Use bounded backoff for recurrence.
- Stop typed matching after the retry budget and set Action required.
- Registered global commands, Menu, Library, and manual copy remain available.

### 10.3 Accessibility

- Invalidate stale elements.
- Rebuild observers on frontmost-app change.
- Do not retry cannot-complete or timeout in a tight loop.
- Downgrade that target session to Palette-only or Copy-only.

### 10.4 Pasteboard

- Stop monitor on denied access.
- Back off after malformed provider data or repeated read failures.
- Never repeatedly trigger permission prompts.
- Preserve already retained encrypted history.

### 10.5 Repository

- Stop mutation after integrity, authentication, key, or migration failure.
- Preserve encrypted files for explicit recovery.
- Do not create a new key automatically.
- Offer integrity check, encrypted backup restore, or destructive reset according to the failure.

### 10.6 UI

- Close panel on permission revocation, target mismatch, Space/display change that invalidates placement, lock, pause, or frontmost-process change.
- Never keep a stale overlay over a secure or unrelated app.

## 11. Support playbooks

### 11.1 Global hotkey does not respond

Check:

1. The command is enabled and Koru is running.
2. `GlobalHotKeyRegistrar` reports registered rather than conflict, reserved/unsupported, or failed.
3. The configured physical key and modifiers match the current keyboard-layout presentation.
4. The equivalent menu command works.

Do not ask the person to grant Input Monitoring; registered commands are independent of the event tap. If the command opens Koru but caret placement or insertion is unavailable, check Accessibility separately and preserve screen-safe/Copy-only behavior.

### 11.2 Typed suggestions never appear

Check:

1. Typed Matching is enabled.
2. Koru is not paused.
3. Accessibility and event-listening states are granted.
4. Event tap is healthy.
5. The target is not excluded or secure.
6. The input was truly empty and caret began at zero.
7. The target capability is Full/Paste rather than Palette-only.

Do not ask for what the person typed. Ask for the diagnostic reason code and, optionally, target app/version.

### 11.3 Panel appears away from caret

Check:

- AX bounds availability.
- Fallback-position reason.
- Display scale and visible-frame category.
- Full-screen/Space state.
- Target compatibility label.

This may be a platform limitation. Request a screenshot only after warning the person to remove private content.

### 11.4 Result copies but does not paste

Check:

- Post-event permission.
- Target revalidation outcome.
- Insertion-tier failure.
- Target paste support for that broad content type.

Copy-only is the required safe fallback. Never recommend granting unrelated permissions.

### 11.5 Clipboard history is empty or stopped

Check:

- Clipboard History enabled.
- General pasteboard access behavior.
- Sensitive-app exclusion.
- Retention policy.
- Oversized/unsupported counts.
- Monitor health.

Do not ask the person to attach clipboard data.

### 11.6 Selection icon is absent

Check:

- Selection Capture Icon enabled.
- Accessibility.
- Entire editable-control content is selected, with a selected range beginning at zero and equal to the full character count.
- Target notification and bounds capability.
- Secure/excluded state.

Explain that the icon is opportunistic. Direct the person to Save Selection hotkey or Services.

### 11.7 High CPU or typing delay

Check:

- Event-tap timeout/recovery count.
- AX cannot-complete rate.
- Clipboard malformed-provider rate.
- Signpost aggregates.
- Current app capability.

Immediate safe action is Pause. A performance report requires diagnostics, not typed content.

### 11.8 Vault key missing or database authentication fails

- Stop all integration services.
- Preserve encrypted data.
- Confirm whether Keychain was reset or the app identity changed.
- Offer encrypted backup restore if compatible.
- Explain that missing key means content cannot be decrypted.
- Offer destructive Reset Vault only after confirmation.

Never request the person's vault database or Keychain export in a public issue.

### 11.9 Permissions changed after update

Check:

- App path.
- Bundle identifier.
- Signing team and designated requirement.
- Whether the build is an unsigned contributor build.
- Current TCC state.

Do not advise disabling System Integrity Protection or Gatekeeper.

## 12. Compatibility operations

- Keep a versioned compatibility registry in source.
- Each entry contains bundle identifier, tested app version, macOS version, supported capability, insertion tier, selection-icon support, and a content-free note.
- A compatibility change requires an Integration Harness regression where possible.
- Do not hot-patch the registry remotely.
- Publish the human-readable matrix with every stable release.
- Issue templates collect:
  - Koru version.
  - macOS version.
  - App/version, optional.
  - Capability shown in Diagnostics.
  - Error code.
  - Safe reproduction using test text.

No issue template should ask for a person's real saved items or clipboard.

## 13. Release operations

### 13.1 Initial update model

- Check for Updates opens the official release page only after a click.
- The project publishes source tag, notarized DMG, checksum, SBOM, release notes, and compatibility matrix.
- Koru makes no automatic update request.
- Maintainers do not infer installed-version counts.

### 13.2 Release record

For each stable release retain:

- Protected source tag and revision.
- Xcode and SDK version.
- Build provenance.
- Signed/notarized artifact.
- SHA-256 checksum.
- Dependency manifest and SBOM.
- Notarization submission result.
- Compatibility matrix.
- Migration and rollback notes.
- Completed release checklist.

### 13.3 Rollback

- Keep the previous stable notarized artifact available.
- Mark a defective release withdrawn and restore the previous release as recommended.
- An older app refuses a newer unknown schema.
- Data rollback uses the compatible encrypted pre-migration backup; replacing the app alone is not presented as data rollback.
- Publish a security advisory when confidentiality, integrity, signing, or update trust is affected.

### 13.4 Signing incident

- Stop releases.
- Revoke/rotate affected credentials through Apple Developer processes.
- Inspect notarization and release history.
- Publish verified clean checksums and incident guidance.
- Rotate any future update-signing key separately from Developer ID credentials.

Apple explains that notarization creates an audit trail and can support revocation when a Developer ID key is exposed: [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## 14. Open-source support and security response

- Publish CONTRIBUTING.md with safe test-data guidance.
- Publish SECURITY.md with a private reporting route.
- Enable GitHub private vulnerability reporting if the repository host supports it.
- Triage public issues without requesting private data.
- Move suspected content exposure, key handling, arbitrary code execution, signing compromise, secure-field capture, or data-loss reports to the private security process.
- Credit reporters according to their preference.
- Publish fixes and advisories without exposing exploit details before users can update.
- Keep dependency alerts and secret scanning enabled.

The privacy policy should say plainly that the project has no server-side copy of a person's Koru library and cannot recover a lost local vault key.

## 15. Uninstall and data removal

Provide an in-app Prepare to Uninstall action:

1. Disable Launch at Login.
2. Unregister global commands and stop the event tap, AX observers, and clipboard monitor.
3. Offer export of saved items.
4. Offer Clear Clipboard History.
5. Offer Reset Vault and local settings.
6. Explain that removing the app bundle alone may leave Application Support and Keychain data.
7. Explain how to revoke Accessibility and Input Monitoring in System Settings.

Koru does not delete itself or request administrator privileges.

## 16. Operations acceptance criteria

1. Production logs contain only allowlisted enums, counts, durations, and reviewed low-sensitivity metadata.
2. Canary strings from keyboard, saved-item, clipboard, selection, title, tag, path, and URL fixtures never appear in logs or support bundles.
3. Diagnostic export is explicit, previewable, redactable, and never uploaded by Koru.
4. Include App Identifiers is off by default.
5. Hotkey-registrar, event-tap, AX, pasteboard, and repository watchdogs stop after bounded recovery and cannot create a busy loop.
6. Action-required health states preserve Library access and do not attempt unsafe insertion or capture.
7. An unclean shutdown runs integrity checks before integrations resume.
8. Support playbooks never request a vault database, Keychain export, real clipboard content, or real saved item in a public issue.
9. The compatibility registry and public matrix match the shipped binary.
10. Every published release retains source, artifact, checksum, SBOM, notarization result, compatibility matrix, and migration/rollback notes.
11. Check for Updates performs no network request until the person explicitly invokes it.
12. A network inspection of an idle initial-release build shows no Koru-originated connection.
13. Prepare to Uninstall disables login launch and offers complete local-data removal without root.
14. A security incident has a private intake, release-stop, credential-rotation, advisory, and clean-artifact verification path.
15. With Input Monitoring denied or the event tap failed, registered global commands remain operational; Accessibility absence degrades their downstream placement, selection read, and insertion to the documented screen-safe, Services, or Copy-only paths.
16. Hotkey conflict diagnostics never recommend Input Monitoring and always preserve an equivalent menu command.

## 17. Decisions the main index must surface

- Observability is local only; maintainers receive nothing unless a person exports and shares diagnostics.
- No content logging, analytics SDK, crash uploader, remote configuration, or automatic updater.
- App identifiers are excluded from support bundles by default.
- Compatibility rules ship in signed releases rather than remote hot patches.
- Initial updates are explicit visits to the official release page.
- Missing Keychain key is unrecoverable; the project cannot restore a person's local vault.
- Clipboard history and diagnostics have bounded local retention.
- Manual global commands use a separate public hotkey registrar and do not depend on Input Monitoring; Accessibility remains capability-specific for caret context, selection read, and direct insertion.

## 18. Official Apple references

- [Unified logging](https://developer.apple.com/documentation/os/logging)
- [Signposts](https://developer.apple.com/documentation/os/signpost)
- [Instruments](https://developer.apple.com/documentation/xcode/instruments)
- [AXUIElement API](https://developer.apple.com/documentation/applicationservices/axuielement_h)
- [Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services)
- [Carbon Event Manager Reference: registered hot keys](https://developer.apple.com/library/archive/documentation/Carbon/Reference/Carbon_Event_Manager_Ref/Reference/reference.html)
- [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

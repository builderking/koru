# macOS integrations

Koru's production integration layer is capability-based and fail-closed. The Library remains usable without system permissions. Typed matching, Accessibility, event posting, login-item control, and registered hotkeys report separate runtime states; a registered shortcut never implies Accessibility or Input Monitoring access.

## Runtime safety

- `PermissionCoordinator` refreshes actual system state and reports a previously granted capability as revoked when it disappears.
- Pause, session lock, sleep, fast-user-switch, and shutdown call `stopAndPurge()` on every active integration. Panels, event buffers, observers, clipboard monitors, and decrypted indexes must conform to that lifecycle contract.
- `TypedEventTapService` observes only key-down and click reset events needed by fresh-input matching. Its callback emits compact in-memory messages and never persists or logs characters.
- `SecurityContextClassifier` blocks secure/protected, excluded, unsupported, and unknown contexts.
- `FreshInputSession` requires a verified empty value and a zero caret, validates monotonic prefix/value agreement, and cannot reopen after dismissal or insertion until focus changes.
- `KoruPanel` is nonactivating. Placement clamps to the visible display and explicitly labels the no-caret-bounds path as fallback.
- `InsertionCoordinator` requires explicit confirmation and an immediate target snapshot match. AX replacement, pasteboard plus Command-V, and copy-only are the only tiers. Failure never deletes the typed prefix.
- Selection capture requires proof that the selected range is the full value plus stable bounds and notification support. Services use their supplied pasteboard and never replace the selection or write the general pasteboard.

## Local verification

Run `./scripts/check`. Deterministic tests use fake permissions, lifecycle integrations, AX-compatible target snapshots, named pasteboards, generated established-writing sessions, and fault outcomes. No test records raw key content.

## Manual compatibility gaps

The following cannot be certified by unit tests or unsigned CI and remain release gates:

- TCC prompt, denial, revocation, and signing-identity behavior on macOS 13 and current stable macOS.
- Carbon hotkey registration, conflict ownership, active keyboard layouts, wake recovery, and dispatch in supported Intel and Apple Silicon environments.
- Event-tap callback p99 and the 100,000-event soak under real Input Monitoring permission.
- AX notifications, caret coordinates, secure-field classification, direct replacement, paste fallback, and full-selection detection across the application matrix in `docs/compatibility.md`.
- VoiceOver announcements, Full Keyboard Access, focus restoration, reduced motion/transparency, multi-display scale/origin combinations, and the optional selection icon's interaction with host UI.
- SMAppService requires-approval, denied, app-update, and unregister behavior from an installed signed app.

Until those checks are recorded, no host application is labeled Full and the implementation must retain screen-safe, copy-only, menu-bar, and Services fallbacks.

# macOS integrations

Koru's production integration layer is capability-based and fail-closed. The Library remains usable without system permissions. Typed matching, Accessibility, event posting, login-item control, and registered hotkeys report separate runtime states; a registered shortcut never implies Accessibility or Input Monitoring access.

## Runtime safety

- `PermissionCoordinator` refreshes actual system state and reports a previously granted capability as revoked when it disappears.
- Pause, session lock, sleep, fast-user-switch, and shutdown call `stopAndPurge()` on every active integration. Panels, event buffers, observers, clipboard monitors, and decrypted indexes must conform to that lifecycle contract.
- `TypedEventTapService` observes only the key-down and pointer events needed for typed matching. A bounded rolling suffix exists in memory only; characters and dismissed queries are never persisted or logged.
- Automatic recall compares the suffix ending at the caret with complete assigned tags. Tags are 3–64 characters and must begin at the start of text or after a non-letter/non-number. This works during established writing and supports multi-word tags.
- The reserved `clp` command follows the same suffix rule anywhere in text and opens Clipboard results.
- Automatic typed recall has no per-application Never Observe list. Clipboard capture keeps its separate Never Save Clipboard From policy.
- `KoruPanel` is nonactivating. Placement uses AX caret bounds when available and otherwise clamps a screen-safe fallback to the visible display.
- A match only opens the panel. The insertion flow requires explicit selection and revalidation. It tries direct AX replacement first, then verified keyboard deletion plus local paste when AX text replacement is unavailable, and finally copy-only. Failure must not delete the trigger.
- macOS Secure Input can prevent the event tap from receiving keystrokes. Koru does not bypass that OS protection; use the manual shortcut when typed matching is unavailable.
- Selection capture requires proof that the selected range is the full value plus stable bounds and notification support. Services use their supplied pasteboard and never replace the selection or write the general pasteboard.

## Local verification

Run `./scripts/check`. Deterministic tests use fake permissions, lifecycle integrations, AX-compatible target snapshots, named pasteboards, exact tag suffixes in established writing, synthetic replacement events, and fault outcomes. No test records raw key content.

## Manual compatibility gaps

The following cannot be certified by unit tests or unsigned CI and remain release gates:

- TCC prompt, denial, revocation, and signing-identity behavior on macOS 13 and current stable macOS.
- Carbon hotkey registration, conflict ownership, active keyboard layouts, wake recovery, and dispatch in supported Intel and Apple Silicon environments.
- Event-tap callback p99 and the 100,000-event soak under real Input Monitoring permission.
- AX notifications, caret coordinates, direct replacement, keyboard fallback, Secure Input behavior, and full-selection detection across the application matrix in `docs/compatibility.md`.
- VoiceOver announcements, Full Keyboard Access, focus restoration, reduced motion/transparency, multi-display scale/origin combinations, and the optional selection icon's interaction with host UI.
- SMAppService requires-approval, denied, app-update, and unregister behavior from an installed signed app.

Until those checks are recorded, no host application is labeled Full and the implementation must retain screen-safe, copy-only, menu-bar, and Services fallbacks.

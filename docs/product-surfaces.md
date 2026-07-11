# Product surfaces and integration contract

Koru's onboarding, Library, Settings, template completion, import/export, and Diagnostics surfaces live in `KoruUI`. They share a `ProductStore`, which is deliberately an integration adapter rather than a persistence implementation.

## Shipped surface behavior

- Onboarding demonstrates value without requesting permissions, offers Hotkey-only or Full mode, explains Accessibility/Input Monitoring before an action, keeps Clipboard separate, and refreshes permission state after System Settings.
- Template completion parses `{{token}}` placeholders deterministically, orders single- and multiline fields, validates required values, retains values only in memory, and requires explicit Insert.
- The save/editor flow supports Saved text, Quick replacement, and Template behavior, flat tags, match terms, template fields, duplicate guidance, Save, and Cancel.
- Library supports search, create, edit, duplicate, pin, archive, Recently Deleted, stable-ID restore, and confirmed permanent deletion. The `clp` match term is rejected.
- Settings expose pause, typed matching, selection capture, Clipboard, retention, asset limits, shortcuts, exclusions, permissions, Launch at Login, clear history, and vault reset.
- Import/export uses the versioned `dev.koru.saved-items` JSON envelope. Import is decoded and validated before mutation, with skip/replace/keep-both duplicate strategies. Exports exclude Clipboard and are disclosed as plaintext.
- Diagnostics previews and explicitly exports a local, editable support bundle. It contains product version/state, permission and service health, compatibility outcomes, counters, and reason-coded events—never Saved content, Clipboard payloads, queries, file paths, or keys.
- Recovery actions include service retry, AX observer rebuild, pasteboard resume, integrity check, Clipboard clear, encrypted-backup restore, and vault reset. Destructive actions require confirmation.

## Platform integration handoff

`ProductStoreProtocol`, `SavedItemRepository`, `PermissionCoordinating`, `KoruSettingsServicing`, and `DiagnosticsServicing` are the seams for encrypted repository and macOS integration work. The current `ProductStore` is an in-memory development implementation so product UI remains buildable without pretending data is already encrypted or permissions are already controlled.

Platform implementations must hydrate state from the encrypted repository, replace simulated permission transitions with live coordinator snapshots, apply security-affecting settings immediately, revalidate the destination before Template insertion, execute imports transactionally, and provide real watchdog recovery with bounded backoff.

No support bundle is uploaded automatically. A person must preview, optionally redact, save, and share it.

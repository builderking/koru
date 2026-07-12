# Product surfaces and integration contract

Koru's onboarding, Library, saved-text editor, Settings, import/export, and Diagnostics surfaces live in `KoruUI`. They share a `ProductStore`, which is deliberately an integration adapter rather than a persistence implementation.

## Shipped surface behavior

- Onboarding demonstrates value without requesting permissions, offers Hotkey-only or Full mode, explains Accessibility/Input Monitoring before an action, keeps Clipboard separate, and refreshes permission state after System Settings.
- The editor exposes only Content and one comma-separated Tags field. It requires nonempty content and at least one unique tag of three or more characters; tags may contain spaces. `clp` is reserved for Clipboard.
- Existing encoded title, behavior, match-term, and template fields remain readable for vault/export compatibility. An editor save derives the internal display title from content, mirrors canonical tags into the legacy trigger fields, stores Saved text behavior, and clears template fields.
- Library supports content/tag search, create, edit, duplicate, pin, archive, Recently Deleted, stable-ID restore, and confirmed permanent deletion. Rows and details show content-derived labels and the unified tag list.
- Settings expose pause, typed matching, selection capture, Clipboard, retention, asset limits, shortcuts, Clipboard exclusions, permissions, Launch at Login, clear history, and vault reset. Automatic typed recall has no Never Observe list.
- Import/export uses the versioned `dev.koru.saved-items` JSON envelope. Import is decoded and validated before mutation, with skip/replace/keep-both duplicate strategies. Exports exclude Clipboard and are disclosed as plaintext.
- Diagnostics previews and explicitly exports a local, editable support bundle. It contains product version/state, permission and service health, compatibility outcomes, counters, and reason-coded events—never Saved content, Clipboard payloads, queries, file paths, or keys.
- Recovery actions include service retry, AX observer rebuild, pasteboard resume, integrity check, Clipboard clear, encrypted-backup restore, and vault reset. Destructive actions require confirmation.

## Platform integration handoff

`ProductStoreProtocol`, `SavedItemRepository`, `PermissionCoordinating`, `KoruSettingsServicing`, and `DiagnosticsServicing` are the seams for encrypted repository and macOS integration work. The current `ProductStore` is an in-memory development implementation so product UI remains buildable without pretending data is already encrypted or permissions are already controlled.

Platform implementations must hydrate state from the encrypted repository, replace simulated permission transitions with live coordinator snapshots, apply security-affecting settings immediately, revalidate the destination before insertion, execute imports transactionally, and provide real watchdog recovery with bounded backoff.

No support bundle is uploaded automatically. A person must preview, optionally redact, save, and share it.

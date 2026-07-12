# Privacy

Status: implementation requirements for an unreleased product. This document does not claim these controls have shipped or passed review.

Koru is designed to keep reusable writing on the Mac. The initial release requires no account, cloud service, analytics, crash uploader, remote configuration, AI service, or automatic update network request.

## Data and retention

| Data | Default | Intended protection |
|---|---|---|
| Saved content and trigger tags | Kept until user deletion | AES-GCM encrypted; Keychain-protected key |
| Clipboard history | Off | If enabled: 7 days, 500 events, 256 MiB total encrypted assets, 25 MiB per retained image |
| Selection being saved | Memory only until Save | Purged on cancel/failure |
| Bounded rolling typed suffix | Short-lived memory only while Typed Matching is enabled | Never persisted or used for dismissed-query analytics |
| Explicit recall learning signal | After explicit selection only | Encrypted and independently resettable |
| Operational diagnostics | Bounded local retention | Content-free enums, counters, buckets, timings |

These locked V1 limits are defined by [ADR-001](architecture/adr-001-v1-clipboard-retention.md). The first reached boundary removes the oldest temporary events and never removes Saved items.

## Koru must never persist, transmit, or include in diagnostics

- Raw key events, rolling suffixes, saved/clipboard/selected text, tags, or previews.
- File paths/names, window or document titles, browser URLs, or identifying custom pasteboard types.
- Encryption keys, Keychain query output, or a nonce paired with ciphertext.
- User content in analytics, crash reports, notifications, support bundles, tests, screenshots, or issue forms.

## Permissions

- Accessibility supports caret-relative UI, selection capture, target revalidation, and preferred direct replacement. Without writable AX text, automatic recall may still use the explicitly confirmed keyboard replacement fallback where macOS permits event posting.
- Input Monitoring supports optional typed matching. Denying it must leave registered manual shortcuts usable where macOS permits.
- Clipboard history is a separate opt-in. Koru cannot reliably identify secrets, so exclusions, pause, short retention, and Clear Clipboard History are the controls.
- Launch at Login is optional and revocable in System Settings.

Automatic typed recall has no Never Observe application list. macOS Secure Input is an OS-level boundary: while a host enables it, Koru may receive no key events and therefore cannot match a tag. Koru does not attempt to disable or bypass Secure Input; manual recall remains available. Never Save Clipboard From continues to apply only to Clipboard capture.

## Deletion and export

Delete All Data must stop integrations, delete the Keychain key, live database, encrypted assets, backups, search index, and requested preferences. Koru does not claim forensic erasure from APFS, SSDs, snapshots, or external backups. Plaintext export requires an explicit warning and clipboard history is excluded by default.

Dragging the app to Trash alone does not remove its data. See [Uninstall](uninstall.md).

## Diagnostics and support

Support bundles are created only after an explicit action, locally previewed, editable/redactable, and never uploaded automatically. See [Diagnostics](diagnostics.md). Public reports must use synthetic content.

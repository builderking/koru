# Privacy

Status: implementation requirements for an unreleased product. This document does not claim these controls have shipped or passed review.

Koru is designed to keep reusable writing on the Mac. The initial release requires no account, cloud service, analytics, crash uploader, remote configuration, AI service, or automatic update network request.

## Data and retention

| Data | Default | Intended protection |
|---|---|---|
| Saved items, titles, tags, triggers, templates | Kept until user deletion | AES-GCM encrypted; Keychain-protected key |
| Clipboard history | Off | If enabled, encrypted and bounded by approved count/age/bytes policy |
| Selection being saved | Memory only until Save | Purged on cancel/failure |
| Active typed prefix | Short-lived memory only | Never persisted or used for dismissed-query analytics |
| Explicit recall learning signal | After explicit selection only | Encrypted and independently resettable |
| Operational diagnostics | Bounded local retention | Content-free enums, counters, buckets, timings |

The candidate clipboard limits (500 events, 7 days, 256 MB total, 25 MB per image) are not a public promise until decision D-001 is closed.

## Koru must never collect or log

- Raw keystrokes, typed prefixes, saved/clipboard/selected text, template values, titles, tags, or previews.
- File paths/names, window or document titles, browser URLs, or identifying custom pasteboard types.
- Encryption keys, Keychain query output, or a nonce paired with ciphertext.
- User content in analytics, crash reports, notifications, support bundles, tests, screenshots, or issue forms.

## Permissions

- Accessibility supports target verification, caret-relative UI, selection capture, and insertion. Without it, Koru must explain the reduced palette/copy behavior.
- Input Monitoring supports optional typed matching. Denying it must leave registered manual shortcuts usable where macOS permits.
- Clipboard history is a separate opt-in. Koru cannot reliably identify secrets, so exclusions, pause, short retention, and Clear Clipboard History are the controls.
- Launch at Login is optional and revocable in System Settings.

Secure controls and configured excluded apps fail closed. Whole-browser exclusion is possible; per-site protection cannot be guaranteed.

## Deletion and export

Delete All Data must stop integrations, delete the Keychain key, live database, encrypted assets, backups, search index, and requested preferences. Koru does not claim forensic erasure from APFS, SSDs, snapshots, or external backups. Plaintext export requires an explicit warning and clipboard history is excluded by default.

Dragging the app to Trash alone does not remove its data. See [Uninstall](uninstall.md).

## Diagnostics and support

Support bundles are created only after an explicit action, locally previewed, editable/redactable, and never uploaded automatically. See [Diagnostics](diagnostics.md). Public reports must use synthetic content.

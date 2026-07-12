# Troubleshooting

There is no supported release yet. These are the required recovery paths, not a claim that current UI exists.

## Koru does not appear while typing

- Nonmatching text and partial tags intentionally show nothing. Type the complete assigned tag; it must be at least three characters, end at the caret, and begin at the start of text or after punctuation/whitespace.
- Exact tags and `clp` can match anywhere during established writing. Multi-word tags must be typed in full.
- Check Pause, Typed Matching, and Input Monitoring. Accessibility improves caret placement and direct insertion but is not the gate for event-only matching.
- There is no Never Observe list for automatic recall. Never Save Clipboard From affects Clipboard capture only.
- macOS Secure Input can prevent Koru from receiving key events. Koru does not bypass it; use the manual recall shortcut. Canvas, terminal, remote, and custom editors may also expose reduced capabilities.

## A result cannot insert

Koru cancels if focus, the tracked range, the frontmost process, or the rolling-input generation changed. After explicit selection it tries direct AX replacement, then the verified keyboard deletion/local-paste fallback, then copy-only. Retry with manual recall when a host rejects insertion; do not repeatedly grant broader permissions merely to force an unsupported target.

## Clipboard items are absent

Clipboard history is off by default. Check opt-in, retention, Never Save Clipboard From, pasteboard permission, supported type/size, and whether the monitor suspended after repeated failures. Koru-originated paste is intentionally not recaptured.

## Permission state looks stale

Quit/reopen only if macOS requires it after a grant/revocation. Moving or rebuilding the app can invalidate privacy grants. Use the permission-health screen when implemented; do not reset unrelated privacy permissions as a first step.

## Vault unavailable or key missing

Do not create a replacement key against the existing database. Export a previewed noncontent support bundle. An encrypted compatible backup may be restorable; otherwise Reset Vault is destructive and cannot recover the old content.

## Safe support report

Use a synthetic test such as `KORU_TEST_ALPHA`. Preview and redact the local support bundle. Do not attach saved/clipboard/selected text, typed queries, paths, URLs, screenshots of private documents, raw unified logs, the database, ciphertext, or Keychain output. Security/privacy exposure belongs in [private vulnerability reporting](https://github.com/builderking/koru/security/advisories/new), not a public issue.

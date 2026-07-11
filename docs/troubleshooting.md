# Troubleshooting

There is no supported release yet. These are the required recovery paths, not a claim that current UI exists.

## Koru does not appear while typing

- Empty focus alone and nonmatching text intentionally show nothing.
- Typed Matching applies only from a verified fresh-empty field at caret zero.
- Use manual recall in established writing.
- Check Pause, Never Observe exclusions, Input Monitoring, and Accessibility state.
- Secure, protected, canvas, terminal, remote, or custom fields may be Palette-only or Blocked.

## A result cannot insert

Koru cancels if focus or the tracked range changed. Retry with manual recall. If direct insertion is unsupported, use Paste or Copy-only fallback. Never repeatedly grant broader permissions merely to force an unsupported target.

## Clipboard items are absent

Clipboard history is off by default. Check opt-in, retention, Never Save Clipboard From, pasteboard permission, supported type/size, and whether the monitor suspended after repeated failures. Koru-originated paste is intentionally not recaptured.

## Permission state looks stale

Quit/reopen only if macOS requires it after a grant/revocation. Moving or rebuilding the app can invalidate privacy grants. Use the permission-health screen when implemented; do not reset unrelated privacy permissions as a first step.

## Vault unavailable or key missing

Do not create a replacement key against the existing database. Export a previewed noncontent support bundle. An encrypted compatible backup may be restorable; otherwise Reset Vault is destructive and cannot recover the old content.

## Safe support report

Use a synthetic test such as `KORU_TEST_ALPHA`. Preview and redact the local support bundle. Do not attach saved/clipboard/selected text, typed queries, paths, URLs, screenshots of private documents, raw unified logs, the database, ciphertext, or Keychain output. Security/privacy exposure belongs in [private vulnerability reporting](https://github.com/builderking/koru/security/advisories/new), not a public issue.

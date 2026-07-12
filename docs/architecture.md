# Architecture

The encrypted repository, bounded search index, vault maintenance, and Clipboard service details are documented in [Data, search, and Clipboard implementation](data-security-search-clipboard.md).

Status: implemented local alpha architecture. The encrypted repository, Clipboard monitor, Library, settings, diagnostics, Services provider, global hotkeys, and selection-capture path are wired in the native app. Typed event-tap and caret-panel components remain qualification-gated until the real TCC/host matrix is complete.

Koru is a local-first macOS menu-bar application. Core capture, recall, clipboard history, search, and insertion must work without an account or network connection. The intended deployment is a universal macOS 13+ app distributed directly as a Developer ID-signed and notarized DMG.

## Boundaries

| Area | Responsibility | Forbidden shortcut |
|---|---|---|
| KoruCore | Versioned domain models, ranking, retention, insertion transactions | AppKit, Accessibility, or persistence details |
| KoruPlatform | Keychain, encrypted repository, Accessibility, event tap, pasteboard, Services, hotkeys | UI policy or plaintext content logging |
| KoruUI | Onboarding, library, compact panel, settings, diagnostics | Direct Keychain/database access |
| Website | Static public documentation and verified release links | Product content, accounts, or runtime app API |
| Release pipeline | Clean build, tests, signing, notarization, SBOM, checksums, draft release | Fork secrets or automatic publication |

The proposed package names may change only through a documented architecture decision; the trust boundaries must remain.

## Data flow

1. With Typed Matching enabled, the input integration keeps a bounded in-memory rolling suffix for the frontmost process. When Accessibility exposes the value and collapsed caret, that authoritative text replaces the event-only view for matching.
2. Automatic recall accepts only a complete assigned tag of at least three characters ending at the caret and beginning at a left boundary. Multi-word tags are valid. Reserved `clp` follows the same suffix rule anywhere in writing and opens Clipboard results.
3. The in-memory search index returns stable saved-item identifiers. UI previews come from bounded decrypted values and never from plaintext disk indexes. A match only presents choices.
4. Explicit selection creates an insertion transaction that revalidates process, focused element/range, or the event-only process/generation identity.
5. Direct Accessibility replacement is preferred. If writable AX text is unavailable, an explicitly confirmed synthetic fallback deletes the matched trigger and pastes from a `currentHostOnly` pasteboard after revalidation; copy-only is the final safe result.
6. Saved and opted-in clipboard payloads are AES-GCM ciphertext. A random 256-bit nonsynchronizable Keychain key is unavailable while paused/locked.
7. Structured diagnostics accept enums, counts, bounded timings, and public system state—not arbitrary strings from a user-controlled source.

## Runtime safety

- One repository actor owns SQLite, transactions, migrations, and integrity checks.
- One permission coordinator owns macOS capability state.
- The event-tap callback classifies input and forwards compact messages; AX inspection, search, persistence, and replacement happen outside the callback.
- Automatic recall has no per-app Never Observe exclusion. macOS Secure Input may prevent event delivery; Koru does not bypass it and manual recall remains the fallback.
- Integrations stop before vault reset, pause, lock, or unrecoverable repository state.
- Watchdogs use bounded exponential backoff with jitter and a terminal degraded state; they never busy-loop.
- A newer schema is never opened by an older binary. Migration begins with an encrypted backup.

## Network boundary

The initial app has no background networking, analytics, crash upload, cloud sync, remote configuration, automatic update feed, or AI service. “Check for Updates” may open the official releases page only after an explicit user action. Adding networking requires a threat-model and privacy decision.

## Related contracts

- [Privacy](privacy.md)
- [Threat model](security/threat-model.md)
- [Diagnostics](diagnostics.md)
- [Compatibility](compatibility.md)
- [Release process](release/release-process.md)

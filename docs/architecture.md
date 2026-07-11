# Architecture

The encrypted repository, bounded search index, vault maintenance, and Clipboard service details are documented in [Data, search, and Clipboard implementation](data-security-search-clipboard.md).

Status: design contract; the production app is not implemented.

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

1. An Accessibility/input integration verifies an editable, initially empty, nonsecure, nonexcluded target before retaining only the current in-memory prefix.
2. The in-memory search index returns stable saved-item identifiers. UI previews come from bounded decrypted values and never from plaintext disk indexes.
3. Explicit selection creates an insertion transaction that revalidates application, focused element, range, and invocation identity.
4. Direct Accessibility insertion is preferred where verified. The pasteboard fallback writes only required representations with `currentHostOnly`; copy-only is the final safe fallback.
5. Saved and opted-in clipboard payloads are AES-GCM ciphertext. A random 256-bit nonsynchronizable Keychain key is unavailable while paused/locked.
6. Structured diagnostics accept enums, counts, bounded timings, and public system state—not arbitrary strings from a user-controlled source.

## Runtime safety

- One repository actor owns SQLite, transactions, migrations, and integrity checks.
- One permission coordinator owns macOS capability state.
- Event callbacks do no synchronous Accessibility, database, pasteboard, or UI work.
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

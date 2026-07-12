# Data, search, and Clipboard implementation

Koru's vault implementation lives in `KoruPlatform` and keeps user content local. It does not contain a network client.

## Vault key and encrypted records

- `VaultKeyManager` creates one random 256-bit key in the data-protection Keychain. The item is explicitly non-synchronizable and device-only.
- A key is loaded only for a usable vault session. Pause, lock, and shutdown callers must call `purgeSession()` (or close the repository), which releases the session key and decrypted indexes.
- If vault files exist but the Keychain item is missing, opening fails with `keyMissingForExistingVault`; no replacement key is created.
- SQLite stores stable IDs, record kind/lifecycle, timestamps, expiry, and ciphertext byte counts as operational metadata. Saved content, trigger tags, legacy compatibility fields, queries, previews, source application IDs, references, and payloads are JSON-encoded and AES-GCM encrypted before binding.
- Record identity, kind, lifecycle, creation timestamp, and format version are authenticated as AES-GCM additional data. Authentication failure returns no partial plaintext.
- SQLite uses prepared statements, foreign keys, in-memory temporary storage, WAL checkpointing, secure deletion, transactional schema versions, integrity checks, and SQLite's online backup API. Backups contain the same encrypted records.
- The live directory is mode `0700`; database and encrypted asset files are mode `0600` where the filesystem supports POSIX modes.

## Assets and references

Encrypted assets use opaque UUID filenames and independently authenticated AES-GCM payloads. Image ingestion checks source bytes and decoded pixel dimensions before producing a bounded thumbnail. Generic allocations are bounded. Files and videos are stored only as encrypted references during ordinary Clipboard capture; their full bytes are never read automatically.

Moving a Saved item to Recently Deleted preserves its encrypted record. Permanent purge removes the record, and maintenance removes assets without a live owner. Because APFS, snapshots, and external backups may retain old blocks, Koru makes no forensic secure-erasure claim.

## Search and learning

The deterministic index is an actor-owned, bounded in-memory structure. Saved and Clipboard scopes are separate. Manual recall ranks exact/prefix/contained tags, content tokens, bounded fuzzy tag distance, explicit selections, pinning, app context, frequency, and recency, with stable-ID tie breaking. Results are capped at 50 even if a larger caller limit is supplied.

Automatic recall uses a stricter index path: the complete assigned tag must be at least three characters, end exactly at the caret, and begin at the start of text or after a non-letter/non-number. Partial tags, content matches, and learned fuzzy matches never open the automatic panel. Multi-word tags retain their spaces.

Explicit query-to-item selections are encrypted as vault records. Reset Learned Recall deletes only those records and clears their in-memory weights. Pause, lock, and termination must call `purge()`; there is no plaintext FTS table or persisted preview cache.

## Clipboard capture and controls

Clipboard history starts disabled. `PasteboardMonitor` polls `changeCount`, checks macOS 15.4 pasteboard access behavior when available, checks the versioned Never Save Clipboard From policy, and materializes only supported representations within byte/item/allocation limits. Multiple pasteboard items become one logical event. Unknown, denied, malformed, and oversized input fails closed.

Deduplication uses HMAC-SHA256 under the vault key. Koru-originated change counts can be suppressed. RTF/HTML is retained as encrypted data and is never rendered in a WebView. File/video URLs are encrypted reference data, not commands.

The locked `RetentionPolicy.v1Defaults` values are 7 days, 500 events, 256 MiB total encrypted Clipboard storage, and 25 MiB per image. Count, age, byte, and enabled-state limits remove only temporary Clipboard rows. Saving a Clipboard entry creates a separate Saved item. Clear History does not remove Saved items, and disabling capture takes effect immediately. See [ADR-001](architecture/adr-001-v1-clipboard-retention.md).

Typed `clp` follows the exact suffix/left-boundary rule anywhere in current writing and preserves only its matched replacement span. The dedicated manual Clipboard recall API has no dependency on Input Monitoring. Automatic typed recall has no Never Observe application exclusion; Never Save Clipboard From remains a separate Clipboard-capture control.

Selecting a result is always explicit. Koru first attempts revalidated direct AX replacement. If the host cannot expose or modify the text through AX, the automatic path revalidates the frontmost process and input generation before posting one marked Backspace per trigger character followed by local Command-V. If event posting is unavailable, Koru copies without deleting the trigger. macOS Secure Input may suppress the original key events, and Koru does not bypass it.

## Reset and recovery

Maintenance verifies SQLite integrity, expires Clipboard rows, purges Recently Deleted rows after the configured recovery window, removes orphan assets, and prunes encrypted backups. Whole-vault reset requires confirmation, stops integrations, destroys the memory index and session key, deletes the Keychain item, then removes database/WAL/SHM, backups, and assets. It does not create a new vault and never uploads recovery data.

Security, migration, tamper, key-loss, plaintext-scan, asset-limit, ranking, retention, exclusion, decoder, deduplication, controls, and reset coverage is in `Tests/KoruPlatformTests`.

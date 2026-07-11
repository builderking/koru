# 09. Data Security and Privacy

## 1. Security position

Koru is local-first, free, and open source, but those labels are not a substitute for a threat model.

Koru can observe keyboard events, inspect accessible text controls, retain clipboard content, and place saved content into other applications. Those capabilities can expose passwords, API keys, private communications, customer data, images, and files if they are handled carelessly.

The default security posture is:

- No account.
- No cloud sync.
- No remote content processing.
- No content analytics.
- No automatic support uploads.
- No plug-in or remote-code system.
- Clipboard history off until explicitly enabled.
- Typed matching off until explicit permission onboarding is complete.
- Secure fields and sensitive applications blocked.
- Encrypted content at rest.
- Decrypted search data held only in memory while Koru is active and unlocked.
- Explicit insertion and explicit selection saving.

## 2. Threat model

### 2.1 In scope

Koru should reduce risk from:

- Theft or offline inspection of the Mac's storage.
- Another ordinary user browsing Koru's Application Support directory.
- Accidental inclusion of private content in logs, crash reports, screenshots, issue templates, or support bundles.
- Clipboard history retaining secrets indefinitely.
- A malformed or malicious pasteboard item causing a crash, excessive allocation, file access, HTML execution, or unsafe preview.
- A target application changing focus between selection and insertion.
- Database or ciphertext tampering.
- Dependency or release-pipeline compromise.
- A Koru bug displaying or inserting content in a secure or excluded application.
- Universal Clipboard transmitting a private Koru saved item merely because insertion uses the general pasteboard.

### 2.2 Out of scope, but documented

Koru cannot protect data from:

- Root, a compromised kernel, or a compromised logged-in user account.
- Malware already running with equivalent Accessibility, Input Monitoring, Full Disk Access, or process-injection capability.
- A target application receiving content after the person explicitly inserts it.
- The person copying Koru content into another application or cloud service.
- Screen capture by the person or an authorized screen-recording app.
- Filesystem snapshots or backups controlled outside Koru.
- A malicious source application putting deceptive content on the general pasteboard.
- Physical attacks while the user session and Koru vault are unlocked.

Encryption at rest protects stored data; it does not make Koru safe inside a fully compromised session.

## 3. Data inventory and classification

| Data | Classification | Persistent by default | Protection |
|---|---|---:|---|
| Saved-item bodies | Highly sensitive | Yes | AES-GCM encrypted |
| Clipboard text, rich text, and images | Highly sensitive | Only when history is enabled | AES-GCM encrypted and retention-limited |
| File and video references | Sensitive | Reference only | Encrypted bookmark/path metadata |
| Selection-capture content | Highly sensitive | No, until Save is confirmed | Memory only, then encrypted |
| Template definitions and defaults | Highly sensitive | Yes | AES-GCM encrypted |
| Filled template values | Highly sensitive | No, unless the person explicitly updates the saved item | Memory only and purged after insert/cancel |
| Recall signals and normalized local queries | Sensitive | Yes | AES-GCM encrypted |
| Trigger names and aliases | Sensitive | Yes | Encrypted; in-memory index after unlock |
| Titles, tags, and previews | Sensitive | Yes | Encrypted |
| Source app bundle ID and capture context | Private metadata | Only if needed | Encrypted |
| Excluded application list | Private metadata | Yes | Encrypted |
| Record ID, kind, schema version, ciphertext size, retention deadline | Low sensitivity | Yes | Minimum plaintext operational metadata |
| Permission state | Low sensitivity | Cached only for UI | Rechecked from public APIs |
| Raw keyboard events | Prohibited | Never | In-memory event normalization only |
| Active eligible prefix | Highly sensitive | Never | Short-lived memory only |
| Window titles, browser URLs, document names | Prohibited | Never | Do not collect |
| Diagnostics counters and error codes | Low sensitivity | Bounded local retention | Structured private-safe logs |

No persistent table may contain plaintext saved-item bodies, clipboard bodies, selected text, triggers, titles, tags, source app names, file paths, or a plaintext full-text index.

## 4. Vault and key architecture

### 4.1 Master key

- Generate a cryptographically random 256-bit key on first successful vault initialization.
- Store it as a non-synchronizable Keychain item.
- Use the data-protection keychain on macOS by passing kSecUseDataProtectionKeychain.
- Use an accessibility class that requires the user session to be unlocked.
- Do not store the key in UserDefaults, the SQLite database, environment variables, logs, or source control.
- Do not implement a hidden recovery key or developer backdoor.
- Purge the in-memory key when the session locks, Koru pauses for privacy, or the app terminates.

Apple recommends the data-protection keychain for modern macOS keychain behavior and describes Keychain as encrypted storage for small secrets: [kSecUseDataProtectionKeychain](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain), [Keychain Services](https://developer.apple.com/documentation/security/keychain-services).

### 4.2 Record encryption

Use CryptoKit AES-GCM.

For each encrypted record:

- Generate a fresh random nonce.
- Encrypt the canonical payload before giving bytes to SQLite.
- Authenticate the record ID, record kind, schema version, and content representation as additional data.
- Store the sealed payload and encryption-format version.
- Reject a record if authentication fails; never display unauthenticated plaintext.
- Quarantine the record metadata and offer a diagnostic/export path that does not include ciphertext unless explicitly requested.

Apple documents that AES-GCM encrypts and authenticates data and additional metadata: [CryptoKit AES.GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm).

### 4.3 SQLite rules

- Use SQLite through one repository actor.
- Encrypt payloads before binding them to prepared statements.
- Keep SQLite temporary storage in memory.
- Use Write-Ahead Logging only after tests confirm WAL contains ciphertext and permitted operational metadata, never plaintext content.
- Set restrictive filesystem permissions on the Application Support directory, database, encrypted asset store, and backups.
- Use foreign-key enforcement and integrity checks.
- Use versioned transactional migrations.
- Create an encrypted pre-migration backup before changing schema or ciphertext format.
- Bound backups and remove them according to the backup-retention policy.

SQLite is a container for ciphertext and low-sensitivity operational metadata; SQLite itself is not treated as the encryption boundary.

### 4.4 Search without a plaintext disk index

- Decrypt eligible records after the vault is unlocked.
- Populate an in-memory SQLite FTS index or equivalent deterministic in-memory index.
- Index only the fields needed for the current product search.
- Remove records immediately when retention deletes them.
- Destroy the in-memory index on pause, lock, or termination.
- Do not persist search terms.
- Do not persist result previews outside encrypted records.

If the retained collection grows beyond the memory budget, change the product limit or implement a reviewed encrypted-search design. Do not silently add a plaintext FTS table.

### 4.5 Assets

- Store bounded image payloads as encrypted files with opaque random names.
- Keep image dimensions and byte count in authenticated metadata.
- Decode previews with ImageIO thumbnail APIs and hard pixel/byte limits.
- Never render clipboard HTML in a WebView or execute embedded scripts.
- Treat file URLs as data, not commands.
- Do not open or execute a recalled file automatically.
- Store videos and large files as references by default. Saving one may create a permanent saved-item reference, but V1 does not duplicate the full binary into the vault automatically.

## 5. Clipboard privacy

### 5.1 Proposed default retention policy

Clipboard history is off until explicitly enabled.

When enabled, the D-001 candidate defaults are:

- Retain the newest **500 logical clipboard events**.
- Expire temporary clipboard events after **7 days**.
- Cap encrypted clipboard assets at **256 MB total**.
- Cap one retained image payload at **25 MB**.
- Store files and videos as references, not duplicated payloads.
- Saving a clipboard entry creates a separate permanent saved item through the normal save flow. The temporary clipboard entry keeps its original expiry and is not silently made permanent.

Apply all limits together; whichever limit is reached first triggers removal of the oldest temporary clipboard entries.

These values remain proposed until D-001 is closed. Product and security owners must either adopt them or record replacement values before retention implementation begins. Only the approved values should appear as public product claims or as locked policy in the main build-plan index.

### 5.2 Capture rules

Before persistence:

- Verify clipboard history is enabled.
- Verify the current pasteboard-access behavior allows the read.
- Check the frontmost application against Never Save Clipboard From.
- Reject unsupported or oversized representations before decoding.
- Group multiple pasteboard items into one logical event.
- Normalize only documented data types.
- Compute deduplication with a keyed digest, not a raw unsalted content hash.
- Encrypt before writing.
- Apply retention in the same transaction.

Do not retain an item's raw provider-specific pasteboard representation merely because it exists.

### 5.3 Insertion through the pasteboard

When Koru needs the general pasteboard for insertion:

- Prepare the new contents as current-host-only by default.
- Write only the representations required by the selected result.
- Mark the change as Koru-originated so the clipboard monitor does not duplicate it.
- Revalidate the target before posting Paste.
- Leave the selected item as the current clipboard item; restoration is not guaranteed safe.

NSPasteboard.ContentsOptions.currentHostOnly keeps prepared content on the current device rather than advertising it to other devices: [NSPasteboard contents options](https://developer.apple.com/documentation/appkit/nspasteboard/contentsoptions).

This reduces accidental Universal Clipboard exposure when inserting a private Koru item.

### 5.4 Secret-detection limit

Koru cannot reliably determine whether arbitrary clipboard text is a password, private key, session token, recovery code, or ordinary prose.

Required mitigations:

- Default exclusions for common password-manager, authenticator, and credential-management bundle IDs.
- User-defined app exclusions.
- Visible Pause.
- Short retention.
- One-click Clear Clipboard History.
- No cloud secret scanning.
- Clear product wording that browser-extension copies may look like ordinary browser clipboard content.

Heuristic secret detection may be added only as an additional local warning. It cannot be the primary security control and must not upload content.

## 6. Typed-input privacy

- Store at most the current prefix of a verified fresh-empty session.
- Never retain keystrokes before eligibility is established.
- Never continue after the field becomes ineligible.
- Ignore secure and protected controls.
- Stop observation when Koru is paused or the user session locks.
- Do not use unselected or dismissed prefixes for analytics or ranking history. Only after explicit item selection may Koru store the encrypted, normalized query-to-item recall signal defined by the product data model; it never stores the underlying raw key events and the signal can be reset independently.
- Do not capture composition text that cannot be validated against the focused control.
- Do not record application window titles, document titles, browser URLs, or surrounding text.

Accessibility exposes a distinct secure-text-field subrole. Koru must block it and also fail closed when custom controls do not provide enough security metadata: [kAXSecureTextFieldSubrole](https://developer.apple.com/documentation/applicationservices/kaxsecuretextfieldsubrole).

## 7. Sensitive-application policy

Maintain two user-visible lists:

1. **Never Observe**
   - No typed session.
   - No selection icon.
   - Global palette opens away from the caret and inserts only through copy-only fallback unless explicitly overridden.

2. **Never Save Clipboard From**
   - Clipboard changes observed while that app is frontmost are not retained.

The bundled defaults are versioned with source code and releases. They are not silently changed from a server.

The settings UI must:

- Explain that exclusions are based on application bundle ID.
- Let a person add the frontmost app.
- Let a person remove or restore defaults.
- Explain that entire-browser exclusion is available but per-site guarantees are not.
- Show when an exclusion blocked an action without exposing content.

## 8. Data lifecycle

### 8.1 Creation

- Create saved content only after explicit Save.
- Create clipboard records only after clipboard-history opt-in and permitted capture.
- Treat selection content as a memory-only draft until Save.
- Validate type and size before encryption.

### 8.2 Use

- Decrypt the minimum record set required for search or display.
- Keep decrypted previews bounded.
- Keep filled template values in memory only and purge them on insert, cancel, lock, pause, target invalidation, or termination.
- Re-encrypt edits before committing.
- Never pass content to network code.

### 8.3 Expiry and deletion

- Remove expired clipboard rows and assets transactionally.
- Moving a saved item to Recently Deleted is a logical lifecycle transition, not an immediate destructive purge. Preserve the encrypted record and owned encrypted assets during the configured recovery window.
- Remove Archived and Recently Deleted items from ordinary recall indexes immediately; maintain only the minimum separate index needed for their explicit Library destinations.
- Restore a Recently Deleted item transactionally, preserving its stable ID and content history needed by the supported model.
- Permanently purge a saved item only after an explicit final-delete confirmation or recovery-window expiry, then remove its record, search entries, and owned encrypted assets in the same maintenance transaction.
- Checkpoint and compact the database according to a bounded maintenance policy.
- Remove orphaned encrypted assets.
- Record only an aggregate deletion count in diagnostics.

Do not claim forensic secure erase on APFS, SSDs, snapshots, or backups. Logical deletion removes active references and ciphertext from Koru's live data set, but filesystem remnants may persist outside Koru's control.

### 8.4 Whole-vault reset

Reset:

- Requires explicit confirmation.
- Stops integrations first.
- Deletes the Keychain master key.
- Removes the active database, encrypted assets, search index, backups, and nonsecret preferences requested by the person.
- Creates a new vault only after reset completes.

Deleting the key makes remaining vault ciphertext unusable to Koru, but Koru still must not claim control over external backups that may contain an older key or exported plaintext.

### 8.5 Key loss

If the Keychain key is missing:

- Do not generate a replacement against the existing database.
- Mark the vault unavailable.
- Explain that encrypted content cannot be recovered.
- Offer export of noncontent diagnostics and a destructive Reset Vault action.
- Never upload the database or keychain material automatically.

## 9. Import, export, and backup

- File import uses an explicit Open panel.
- File export uses an explicit Save panel.
- Exported saved-text content is excluded from clipboard history unless the person explicitly includes it.
- Plaintext export carries an unavoidable privacy warning before writing.
- An encrypted portable export requires a separate reviewed format, explicit passphrase flow, authenticated encryption, and documented recovery behavior.
- Do not put exported content on the general pasteboard automatically.
- Do not include clipboard history in general-purpose library export by default.
- Pre-migration backups remain encrypted under the current vault key.

Sandboxed security-scoped bookmarks are not the primary architecture because Koru is directly distributed and nonsandboxed, but bookmarks remain useful for durable file references. Apple documents bookmark persistence and security scope: [NSURL bookmarks](https://developer.apple.com/documentation/foundation/nsurl).

## 10. Network and telemetry policy

### Initial release decision

The initial Koru binary makes no background network request.

- No analytics SDK.
- No crash-upload SDK.
- No remote configuration.
- No remote exclusion list.
- No cloud sync.
- No AI service.
- No automatic update feed.

Check for Updates opens the official release page after an explicit click. Adding an automatic updater later requires a separate threat review, update-signing design, privacy disclosure, and rollback plan.

This decision should be surfaced in the main build-plan index because it affects update UX and release operations.

## 11. Logging and diagnostics privacy

Allowed:

- App version and build.
- macOS version and architecture.
- Permission-state enum.
- Event-tap enabled/disabled state.
- AXError code and operation category.
- Insertion tier.
- Clipboard content type category and byte bucket.
- Latency and aggregate count.
- Database schema and migration status.

Prohibited:

- Keystrokes or prefixes.
- Saved text or clipboard content.
- Selected text.
- Titles, tags, or previews.
- File paths or names.
- Window and document titles.
- Browser URLs.
- Pasteboard raw types if they may contain identifying custom identifiers.
- Encryption keys, nonces paired with ciphertext, or Keychain query results.

Use Apple's unified logging privacy controls and mark potentially identifying values private even when they are expected to be safe: [Logging](https://developer.apple.com/documentation/os/logging).

Support-bundle export is explicit, locally generated, previewable, and redactable. Section 16 defines the format.

## 12. Release and supply-chain security

- Keep third-party dependencies minimal and pinned.
- Commit the Swift package resolution file.
- Generate a dependency manifest and software bill of materials for tagged releases.
- Run static analysis, tests, dependency review, and secret scanning in CI.
- Store Developer ID and notarization credentials only in protected release environments.
- Require manual approval for the signing job.
- Sign all nested executable code before the outer app.
- Enable Hardened Runtime and secure timestamps.
- Notarize and staple every published artifact.
- Publish SHA-256 checksums and retain immutable release artifacts.
- Do not load unsigned plug-ins, downloaded code, or arbitrary scripts.
- Provide SECURITY.md and a private vulnerability-reporting route before public release.

Apple's notary service scans Developer ID software for malicious content and signing issues, and Hardened Runtime is required for notarization: [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime).

## 13. Security acceptance criteria

1. Searching the application data directory for known saved-item and clipboard test strings finds no plaintext in the database, WAL, temporary files, encrypted assets, backups, or logs.
2. The Keychain item is nonsynchronizable and the vault cannot open when it is removed.
3. Modifying any authenticated ciphertext or bound metadata causes decryption failure and never displays partial plaintext.
4. Session lock, Pause, and termination destroy the in-memory search index and decrypted caches.
5. Raw key events and eligible prefixes never enter unified logs, crash metadata, diagnostics, or persistent storage.
6. Secure fields and protected-content controls produce no typed session, selection icon, selection read, or insertion attempt.
7. Default sensitive apps produce no typed observation and no retained clipboard event.
8. Clipboard history remains off until explicit opt-in.
9. The D-001-approved age, count, total-byte, and per-image limits apply transactionally to temporary clipboard history and never remove permanent saved items; until approval, the 7-day, 500-entry, 256-MB, and 25-MB candidate policy is the boundary-test fixture, not a public claim.
10. Full file and video bytes are not retained automatically.
11. Koru-originated pasteboard insertion uses current-host-only content where supported and is not recaptured as a duplicate.
12. Malformed, oversized, and unknown pasteboard data is rejected without crash or uncontrolled allocation.
13. Clear Clipboard History removes active rows, assets, and in-memory search entries without touching saved items.
14. Reset Vault renders the previous active vault unreadable and creates no replacement key until deletion completes.
15. A support bundle contains no test content, paths, titles, URLs, raw key data, ciphertext, or key material.
16. The release artifact passes signature, Hardened Runtime, notarization, stapling, and Gatekeeper verification.
17. The initial production binary performs no background network request.

## 14. Official Apple references

- [Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
- [Data-protection keychain](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain)
- [CryptoKit](https://developer.apple.com/documentation/cryptokit/)
- [AES-GCM](https://developer.apple.com/documentation/cryptokit/aes/gcm)
- [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)
- [Current-host-only pasteboard contents](https://developer.apple.com/documentation/appkit/nspasteboard/contentsoptions)
- [Secure text field subrole](https://developer.apple.com/documentation/applicationservices/kaxsecuretextfieldsubrole)
- [URL bookmarks](https://developer.apple.com/documentation/foundation/nsurl)
- [Unified logging](https://developer.apple.com/documentation/os/logging)
- [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

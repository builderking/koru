# Privacy-safe diagnostics and recovery

Status: specification for TASK-080 through TASK-082; no Diagnostics screen or app watchdog exists yet.

## Structured logging contract

Allowed fields are compile-time enums or bounded numbers: app/build, macOS/architecture, permission enum, subsystem health enum, public `AXError`, operation category, insertion tier, safe clipboard category and byte bucket, schema/migration state, latency bucket, aggregate count, recovery action/outcome, and nonidentifying compatibility capability.

No logging API should accept arbitrary user-controlled strings. Potentially identifying values remain OSLog-private even when expected to be safe. A prohibited-field canary suite must search unified log exports, support bundles, database/WAL/temp/backup files, and crash attachments for synthetic secrets.

Required reason-code families:

- `permission.*`: never-requested, denied, revoked, unavailable.
- `target.*`: insecure-metadata, secure, excluded, stale-focus, stale-range, unsupported.
- `eventTap.*`: disabled, timeout, invalidated, backoff-exhausted.
- `ax.*`: api-disabled, cannot-complete, notification-unsupported, observer-invalid.
- `pasteboard.*`: denied, unsupported-type, oversized, malformed, suspended.
- `insertion.*`: direct-failed, paste-failed, copy-only, target-mismatch.
- `repository.*`: locked, integrity-failed, migration-failed, key-missing, degraded.

Retention is local and bounded by an implementation decision before alpha. “Bounded” must become an exact count/age/byte limit and receive a test; this repository does not invent a shipped limit.

## Support bundle

The canonical machine-readable contract is [support-bundle.schema.json](support-bundle.schema.json) with a synthetic [example](support-bundle.example.json). Export is explicit, created locally, previewed before save, redactable, and never uploaded. The bundle should contain `manifest.json` plus optional content-free JSON Lines events and a user-approved note. It must never contain app database/ciphertext, unified raw logs, screenshots, crash dumps, paths, URLs, app/window/document names, or user content.

The exporter must reject unknown fields, recursively scan string values for canary fixtures and prohibited key names, and make no network request. Support staff can distinguish permission, Accessibility, event-tap, pasteboard, insertion tier, migration, repository integrity, and missing-key failures from enum state alone.

## Watchdog policy

Each integration owns a state machine: `healthy → degraded → retry_wait → recovering → healthy|suspended`. Retries use bounded exponential backoff with jitter, reset after a stable interval, stop after a fixed attempt budget, and never run synchronously on the event callback or main UI thread.

| Failure | Automatic action | Terminal/user action |
|---|---|---|
| Event tap timeout/disable | Re-enable after bounded delay | Suspend Typed Matching; manual recall remains |
| AX observer invalid | Rebuild for current verified target | Disable caret integration; palette/copy fallback |
| Pasteboard repeated error | Suspend monitor | Retry or keep Clipboard off |
| Repository integrity/migration | Stop integrations; read-only/degraded state | Integrity check or restore encrypted backup |
| Key missing | Never create replacement | Noncontent diagnostics or confirmed Reset Vault |

Destructive actions (Clear Clipboard History, restore backup when it replaces live state, Reset Vault) require a consequence summary and separate confirmation. Record only action enum, timestamp bucket, and outcome enum—never affected content, IDs, paths, or filenames.

Recovery tests must prove no busy loop, no event-callback blocking, idempotent retry, confirmation for destruction, safe failure interruption, and content-free audit outcomes.

# ADR-001: V1 Clipboard retention defaults

Status: Accepted — 2026-07-11

## Decision

Clipboard history remains off until the user explicitly enables it. When enabled, V1 defaults retain temporary Clipboard history for at most:

- 7 days;
- 500 logical events;
- 256 MiB of total encrypted assets;
- 25 MiB for one retained image.

The first reached age, count, or byte boundary evicts the oldest temporary events. Files and videos remain encrypted references in V1. Saving a Clipboard result creates a separate permanent Saved item and never extends the temporary event.

## Rationale

These limits bound sensitive-data lifetime, memory and disk use, and image-decoding risk while leaving useful recent history. Binary units match the implementation. A future change requires a replacement ADR, migration review, performance evidence, and synchronized product/privacy copy.

## Consequences

`RetentionPolicy.v1Defaults` is the single code policy. Repository retention, settings ceilings, deterministic tests, privacy documentation, onboarding, and public copy use these values. D-001 is closed.

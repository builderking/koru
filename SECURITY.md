# Security policy

Koru will operate near keyboard input, accessibility APIs, selections, and clipboard history. Security and privacy reports must be handled carefully.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability or a report containing private content.

Use GitHub's private vulnerability reporting for this repository. Include:

- the affected version or commit;
- macOS version and target application;
- reproducible steps;
- expected and actual behavior;
- impact and any known workaround;
- only synthetic test content, never real passwords, tokens, prompts, or clipboard data.

## Supported versions

There are no supported releases yet. A supported-version table and response policy will be added before the first public beta.

Receipt of a report is not a promise of a specific resolution time while the project is unreleased. Before public beta, maintainers must document response targets, assign a security owner, enable and test private vulnerability reporting, and define supported versions.

## Security baseline

The implementation must follow the security requirements in [`build plan/09-data-security-and-privacy.md`](build%20plan/09-data-security-and-privacy.md), including local encryption, Keychain-managed keys, secure-field suppression, per-app exclusions, redacted diagnostics, and no raw-keystroke persistence.

The repository-level threat register and test IDs are in [`docs/security/threat-model.md`](docs/security/threat-model.md). Signing/notarization credentials exist only in a manually approved protected release environment; pull requests and forks must never receive them.

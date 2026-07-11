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

## Security baseline

The implementation must follow the security requirements in [`build plan/09-data-security-and-privacy.md`](build%20plan/09-data-security-and-privacy.md), including local encryption, Keychain-managed keys, secure-field suppression, per-app exclusions, redacted diagnostics, and no raw-keystroke persistence.

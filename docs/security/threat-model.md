# Executable threat model

Status: repository specification for TASK-020. Tests marked `planned` cannot run until the relevant app component exists.

## Trust boundaries and prohibited data

Boundaries are: macOS input/Accessibility to Koru process; general pasteboard to parser; decrypted process memory to encrypted storage; app to target application; contributor CI to protected release environment; signed artifact to public download; and static website source to Cloudflare Pages.

Prohibited diagnostic/persistent fields are raw keys/prefixes, content, selection, template values, titles/tags/previews, paths/names, document/window titles, URLs, identifying custom pasteboard identifiers, keys, Keychain results, and nonce/ciphertext pairs.

## Threat register

| ID | Threat/boundary | Owner | Mitigation | Evidence/test | Status |
|---|---|---|---|---|---|
| TM-INPUT-001 | Observe secure/excluded or established writing | Platform | Fresh-empty state machine; secure subrole/exclusion fail-closed; memory-only prefix | `SEC-FRESH-001`, generated 100k sequence suite, host matrix | planned |
| TM-INPUT-002 | Persist/log raw input or dismissed query | Platform/Security | Typed API accepts normalized state only; prohibited-field guards; selection-only learning | `SEC-LOG-001`, plaintext scan | specified |
| TM-INSERT-001 | Focus/range changes before insert | Platform | Revalidate bundle, element, selection, and invocation; cancel on mismatch | `SEC-INSERT-001` | planned |
| TM-PASTE-001 | Pasteboard parser crash, allocation, execution, or file access | Clipboard | Type/size allowlist; bounded decode; never WebView-render HTML; references are data | fuzz corpus `SEC-PASTE-001` | planned |
| TM-PASTE-002 | Universal Clipboard exposes inserted content | Clipboard | Minimum representations; `currentHostOnly`; mark Koru-origin; no unsafe restore | `SEC-PASTE-002` | planned |
| TM-STORE-001 | Offline plaintext disclosure | Storage/Security | AES-GCM per record; authenticated metadata; Keychain random key; in-memory search | known-fixture scan `SEC-STORE-001` | planned |
| TM-STORE-002 | Ciphertext/schema tamper or key loss | Storage | Authentication failure/quarantine; never replace missing key; encrypted pre-migration backup | `SEC-STORE-002/003` | planned |
| TM-DELETE-001 | Misleading erase guarantee | Product/Storage | Explicit logical deletion language; transactional purge; no forensic-erasure claim | doc review `MAN-PRIV-001` | specified |
| TM-DIAG-001 | Logs/support bundle expose content | Diagnostics/Security | Typed allowlisted schema; no arbitrary user strings; preview/redact; no upload | schema + canary suite `SEC-DIAG-001` | specified |
| TM-NET-001 | Unexpected content egress | Security | No initial background network stack/SDK; binary/network inspection | `SEC-NET-001` | planned |
| TM-DEP-001 | Dependency compromise | Maintainers | Minimal allowlist, pinned resolution, dependency review, SBOM | `CI-DEP-001`, release SBOM | scaffolded |
| TM-CI-001 | Fork runs code with signing/deploy secrets | Release | PR workflow read-only; manual protected environments; clean tag checkout | workflow review `CI-SECRET-001` | scaffolded |
| TM-REL-001 | Substituted/unsigned artifact | Release/Security | Protected signed tag, manual approval, notarization, stapling, SHA-256, provenance | `REL-VERIFY-001` | blocked: app/credentials |
| TM-WEB-001 | Website deploy/copy overclaims release | Website/Release | Main-only production; preview boundaries; verified release manifest and manual sign-off | `WEB-REL-001` | blocked: website/project |

## Manual tests

- `MAN-PRIV-001`: security reviewer checks permissions, exclusions, retention, deletion, export, backup, and out-of-scope language against shipped UI.
- `MAN-CLEAN-001`: clean test account installs, exercises all permission states, deletes all data, uninstalls, and checks Koru-managed live storage and Keychain entries.
- `MAN-REL-001`: quarantine the public download, verify checksum, signature, Hardened Runtime, notarization ticket, Gatekeeper, architectures, and launch.
- `MAN-FORK-001`: open a fork PR containing a harmless secret-presence assertion; confirm no environment secret or write token is exposed and no preview/release deploy runs.

## Out of scope

Koru cannot defend against root/kernel compromise, malware with equivalent permissions, a compromised logged-in session, the receiving app after explicit insertion, user-directed copying/screen capture, deceptive source pasteboard data, or snapshots/backups outside Koru's control. Encryption at rest is not protection inside a fully compromised unlocked session.

## Change rule

Any new permission, entitlement, network path, dependency, persistent plaintext field, pasteboard representation, release credential, or diagnostic field must update this register and attach a test ID before merge.

# Native foundation

Koru currently contains an unsigned macOS 13+ menu-bar shell, dependency-directed Swift modules, canonical domain contracts, adaptive SwiftUI foundations, a disposable integration harness, and production-safe macOS integration services. It remains alpha code, not a supported release.

## Contributor commands

```sh
./scripts/bootstrap
./scripts/check
swift run Koru
swift run KoruIntegrationHarness
```

The harness uses synthetic fixture content and exposes explicit probes for Accessibility focus/caret state, a listen-only event tap, registered-hotkey feasibility, pasteboard representations, and copy-only insertion. macOS permission decisions and external-app behavior require manual testing. No signing secret is needed.

## Locked boundaries

- Clipboard history and typed matching are off by default.
- Nonmatching and partial text never opens a panel. Automatic recall requires a complete assigned tag of at least three characters ending at the caret and beginning at a left boundary; the match may occur anywhere during writing. `clp` uses the same rule for Clipboard.
- A match is not insertion. The person must explicitly select a result, and Koru revalidates the focused process/range or rolling-input generation before replacement.
- Direct AX insertion is preferred. If the host does not expose writable AX text, Koru uses a verified keyboard deletion plus local-paste fallback; copy-only remains the safe final outcome.
- Automatic recall has no Never Observe app list. macOS Secure Input may suppress keyboard events, in which case typed matching is unavailable and Koru does not bypass the OS.
- The initial app has no account, cloud sync, automatic updater, content telemetry, or background network request.

Implementation boundaries, local verification, and required signed/manual checks are documented in [macOS integrations](macos-integrations.md).

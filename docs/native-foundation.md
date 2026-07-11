# Native foundation

Koru currently contains an unsigned macOS 13+ menu-bar shell, dependency-directed Swift modules, canonical domain contracts, adaptive SwiftUI foundations, and a disposable integration harness. It is alpha feasibility code, not a supported release.

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
- Empty focus alone never opens a panel. A verified fresh empty field, caret at zero, and a qualifying fragment or `clp` are required.
- Focus is not selection. Insertion requires explicit confirmation and immediate target revalidation.
- Secure, excluded, unsupported, and unknown contexts fail closed.
- Direct AX insertion, pasteboard-plus-paste, and copy-only are the only planned insertion tiers; the harness implements only safe decision probes and copy-only output.
- The initial app has no account, cloud sync, automatic updater, content telemetry, or background network request.

# Compatibility policy and matrix

Status: deterministic integration tests pass locally; external host and signed-permission testing is not yet certified.

Koru targets a universal arm64/x86_64 app for macOS 13 and later. Release-blocking validation covers macOS 13 latest patch, macOS 15 latest patch, and current stable macOS, including Apple Silicon and supported Intel combinations defined in the quality plan.

## Capability labels

- **Full:** strict fresh-empty verification, caret panel, direct or paste insertion, and selection capture passed the matrix.
- **Paste:** strict verification and caret panel passed; insertion uses pasteboard.
- **Copy-only:** Koru copies for a manual paste without modifying the target.
- **Palette-only:** typed matching is unavailable; manual global/menu-bar palette remains.
- **Blocked:** secure, protected, sensitive, system, or excluded context.

One successful attempt is not enough to label a target Full. Secure fields remain Blocked even if an input event could technically be posted.

## Release matrix template

| Koru | macOS | Hardware | Target/version | Field type | Permission state | Typed match | Insertion | Selection capture | Label | Known limit | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Unreleased | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not certified | App absent | — |

Each release must cover native AppKit/SwiftUI, Safari/WebKit, Chrome/Chromium, Electron, Office, browser document editors, developer tools, terminals, Finder/system, remote/canvas, and secure controls using dedicated synthetic data. Browser editors, terminals, remote/canvas, and custom source editors are expected to use reduced capabilities honestly.

Fork/community reports are evidence inputs, not automatically certified results. Maintainers reproduce them on the release matrix before changing a public label.

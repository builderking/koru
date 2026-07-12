# Compatibility policy and matrix

Status: deterministic integration tests pass locally; external host and signed-permission testing is not yet certified.

Koru targets a universal arm64/x86_64 app for macOS 13 and later. Release-blocking validation covers macOS 13 latest patch, macOS 15 latest patch, and current stable macOS, including Apple Silicon and supported Intel combinations defined in the quality plan.

## Capability labels

- **Full:** exact tag-suffix detection during established writing, caret panel, direct AX insertion, manual recall, and selection capture passed the matrix.
- **Paste:** matching and the panel passed; insertion uses the verified keyboard deletion/local-paste fallback because writable AX text is unavailable.
- **Copy-only:** Koru copies for a manual paste without modifying the target.
- **Palette-only:** typed matching is unavailable; manual global/menu-bar palette remains.
- **Blocked:** the target changed, the host rejected every insertion path, or macOS denied the required capability.

One successful attempt is not enough to label a target Full. Automatic recall has no Never Observe application exclusion. When macOS Secure Input is active, the OS may withhold keystrokes from Koru, so typed matching is unavailable and the manual shortcut is the supported path; Koru does not bypass Secure Input.

## Release matrix template

| Koru | macOS | Hardware | Target/version | Field type | Permission state | Typed match | Insertion | Selection capture | Label | Known limit | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Unreleased | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not certified | App absent | — |

Each release must cover native AppKit/SwiftUI, Safari/WebKit, Chrome/Chromium, Electron, Office, browser document editors, developer tools, terminals, Finder/system, remote/canvas, and controls with Secure Input using dedicated synthetic data. The matrix must separately record exact-tag detection, `clp`, AX replacement, keyboard fallback, copy-only behavior, and OS-suppressed input. Browser editors, terminals, remote/canvas, and custom source editors are expected to use reduced capabilities honestly.

Fork/community reports are evidence inputs, not automatically certified results. Maintainers reproduce them on the release matrix before changing a public label.

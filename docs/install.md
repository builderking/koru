# Install Koru

There is no installable Koru release yet. Do not download binaries claiming to be official until this repository links a versioned GitHub Release with a notarized DMG and SHA-256 checksum.

For a future release:

1. Download the DMG and `SHA256SUMS` from the same official release.
2. Run `shasum -a 256 -c SHA256SUMS` from the download directory.
3. Open the DMG, drag Koru to Applications, and eject it.
4. Open Koru from Applications. Do not bypass Gatekeeper for an unverified build.
5. Choose Full or Hotkey-only mode and read each permission explanation before opening System Settings.
6. Enable Clipboard separately only after choosing retention; use a synthetic onboarding example.

Contributors build unsigned Debug/Release configurations without release secrets. Once the Xcode project exists, follow [Contributing](../CONTRIBUTING.md) and `./scripts/build-unsigned.sh`. A locally built app is not an official, notarized release.

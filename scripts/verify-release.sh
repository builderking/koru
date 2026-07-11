#!/usr/bin/env bash
set -euo pipefail

artifact="${1:-}"
checksums="${2:-$(dirname "$artifact")/SHA256SUMS}"
[[ -f "$artifact" ]] || { echo "artifact not found: $artifact" >&2; exit 2; }
[[ -f "$checksums" ]] || { echo "checksum file not found: $checksums" >&2; exit 3; }

(cd "$(dirname "$checksums")" && shasum -a 256 -c "$(basename "$checksums")")

case "$artifact" in
  *.app)
    codesign --verify --deep --strict --verbose=2 "$artifact"
    codesign -dv --verbose=4 "$artifact" 2>&1 | grep -q 'runtime' || { echo "Hardened Runtime missing" >&2; exit 4; }
    spctl --assess --type execute --verbose=4 "$artifact"
    lipo -archs "$artifact/Contents/MacOS/Koru" | grep -q 'arm64' && lipo -archs "$artifact/Contents/MacOS/Koru" | grep -q 'x86_64'
    ;;
  *.dmg)
    codesign --verify --strict --verbose=2 "$artifact"
    xcrun stapler validate "$artifact"
    spctl --assess --type open --context context:primary-signature --verbose=4 "$artifact"
    ;;
  *) echo "checksum verified; codesign validation supports .app or .dmg" ;;
esac

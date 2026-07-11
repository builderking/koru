#!/usr/bin/env bash
set -euo pipefail

required=(APPLE_SIGNING_IDENTITY APPLE_NOTARY_KEY_ID APPLE_NOTARY_ISSUER_ID APPLE_NOTARY_PRIVATE_KEY)
for name in "${required[@]}"; do
  [[ -n "${!name:-}" && "${!name}" != REPLACE_ME ]] || { echo "missing protected secret: $name" >&2; exit 20; }
done
[[ "${GITHUB_EVENT_NAME:-workflow_dispatch}" == workflow_dispatch ]] || { echo "release signing is manual only" >&2; exit 21; }

if [[ "${1:-}" == --check-config ]]; then
  echo "protected release configuration is present (values not printed)"
  exit
fi

cd "$(git rev-parse --show-toplevel)"
[[ -d Koru.xcodeproj ]] || { echo "Koru.xcodeproj is missing" >&2; exit 22; }
[[ -n "${RELEASE_TAG:-}" ]] || { echo "RELEASE_TAG is required" >&2; exit 23; }

rm -rf build/ReleaseArchive.xcarchive build/dmg-root dist
mkdir -p build/dmg-root dist
key_file="$(mktemp)"
trap 'rm -f "$key_file"' EXIT
printf '%s' "$APPLE_NOTARY_PRIVATE_KEY" > "$key_file"
chmod 600 "$key_file"

xcodebuild archive \
  -project Koru.xcodeproj \
  -scheme Koru \
  -configuration Release \
  -archivePath build/ReleaseArchive.xcarchive \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$APPLE_SIGNING_IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"

app="build/ReleaseArchive.xcarchive/Products/Applications/Koru.app"
[[ -d "$app" ]] || { echo "archive did not contain Koru.app" >&2; exit 24; }
codesign --verify --deep --strict --verbose=2 "$app"
lipo -archs "$app/Contents/MacOS/Koru" | grep -q arm64
lipo -archs "$app/Contents/MacOS/Koru" | grep -q x86_64

ditto "$app" build/dmg-root/Koru.app
ln -s /Applications build/dmg-root/Applications
dmg="dist/Koru-${RELEASE_TAG}.dmg"
hdiutil create -quiet -volname Koru -srcfolder build/dmg-root -format UDZO "$dmg"
codesign --force --timestamp --sign "$APPLE_SIGNING_IDENTITY" "$dmg"
xcrun notarytool submit "$dmg" --key "$key_file" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID" --wait
xcrun stapler staple "$dmg"

./scripts/generate-sbom.sh "dist/Koru-${RELEASE_TAG}.cdx.json"
./scripts/generate-checksums.sh dist
./scripts/verify-release.sh "$dmg"
echo "signed and notarized release candidate created at $dmg"

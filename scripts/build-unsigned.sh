#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
[[ -d Koru.xcodeproj ]] || { echo "Koru.xcodeproj is not implemented yet" >&2; exit 2; }

target="${KORU_TARGET:-Koru}"
products="${CONFIGURATION_BUILD_DIR:-build/UnsignedProducts}"
common=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SWIFT_STRICT_CONCURRENCY=complete ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CONFIGURATION_BUILD_DIR="$products")

xcodebuild -project Koru.xcodeproj -target "$target" -configuration Debug "${common[@]}" build
xcodebuild -project Koru.xcodeproj -target "$target" -configuration Release "${common[@]}" build

app="$products/Koru.app"
binary="$app/Contents/MacOS/Koru"
[[ -d "$app" && -x "$binary" ]] || { echo "Unsigned app bundle was not produced at $app" >&2; exit 3; }
architectures="$(lipo -archs "$binary")"
[[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]] || {
  echo "Expected arm64 and x86_64, found: $architectures" >&2
  exit 4
}
echo "Unsigned universal Release app: $app ($architectures)"

# Keep the website's downloadable copy in sync with every build.
[[ "${KORU_SKIP_WEBSITE_PACKAGE:-0}" == "1" ]] || ./scripts/package-website-download.sh "$app"

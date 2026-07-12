#!/usr/bin/env bash
# Builds a locally signed Debug Koru.app for development testing.
# Signing with a stable identity keeps TCC grants (Accessibility, Input
# Monitoring) valid across rebuilds, unlike ad-hoc/unsigned builds whose
# cdhash changes every build. Requires an "Apple Development" certificate
# in the login keychain (Xcode > Settings > Accounts > Manage Certificates).
# Team IDs are not secrets; override with KORU_DEVELOPMENT_TEAM if needed.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
[[ -d Koru.xcodeproj ]] || { echo "Koru.xcodeproj is missing" >&2; exit 2; }

identity="${KORU_SIGNING_IDENTITY:-Apple Development}"
team="${KORU_DEVELOPMENT_TEAM:-A2WF62PKP6}"
products="build/SignedLocal"

xcodebuild -project Koru.xcodeproj -target Koru -configuration Debug \
  CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=$identity" DEVELOPMENT_TEAM="$team" \
  CONFIGURATION_BUILD_DIR="$products" build

app="$products/Koru.app"
codesign --verify --strict --verbose=2 "$app"
codesign -dv "$app" 2>&1 | grep -E "Authority=Apple Development|TeamIdentifier"
echo "signed local build at $app"

# Keep the website's downloadable copy in sync with every build. The website
# artifact is always a fresh universal Release build, not this Debug bundle.
[[ "${KORU_SKIP_WEBSITE_PACKAGE:-0}" == "1" ]] || ./scripts/package-website-download.sh

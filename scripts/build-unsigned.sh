#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
[[ -d Koru.xcodeproj ]] || { echo "Koru.xcodeproj is not implemented yet" >&2; exit 2; }

scheme="${KORU_SCHEME:-Koru}"
derived="${DERIVED_DATA_PATH:-build/DerivedData}"
common=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO SWIFT_STRICT_CONCURRENCY=complete)

xcodebuild -project Koru.xcodeproj -scheme "$scheme" -configuration Debug -derivedDataPath "$derived" "${common[@]}" build
xcodebuild -project Koru.xcodeproj -scheme "$scheme" -configuration Release -derivedDataPath "$derived" "${common[@]}" build

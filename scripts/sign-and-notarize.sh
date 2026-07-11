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
[[ -d Koru.xcodeproj ]] || { echo "MANUAL GATE: Koru.xcodeproj is not implemented" >&2; exit 22; }

# This script deliberately stops until the app target, minimal reviewed
# entitlements, archive/export options, and DMG layout exist. Implement those in
# the finished app change; do not weaken this gate or ad-hoc sign a release.
[[ -f config/release-ready.marker ]] || {
  echo "MANUAL GATE: app/release configuration has not passed security review" >&2
  exit 23
}

echo "Release signing implementation must be completed with the finished app target."
exit 24

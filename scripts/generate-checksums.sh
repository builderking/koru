#!/usr/bin/env bash
set -euo pipefail

directory="${1:-dist}"
output="${2:-$directory/SHA256SUMS}"
[[ -d "$directory" ]] || { echo "directory not found: $directory" >&2; exit 2; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
find "$directory" -type f ! -name "$(basename "$output")" ! -name '*.sig' -print0 \
  | LC_ALL=C sort -z \
  | while IFS= read -r -d '' file; do
      digest="$(shasum -a 256 "$file" | awk '{print $1}')"
      printf '%s  %s\n' "$digest" "${file#"$directory"/}"
    done > "$tmp"
[[ -s "$tmp" ]] || { echo "no release files found in $directory" >&2; exit 3; }
mv "$tmp" "$output"
echo "wrote $output"

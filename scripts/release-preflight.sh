#!/usr/bin/env bash
set -euo pipefail

tag="${1:-}"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || { echo "tag must be semantic v*: $tag" >&2; exit 2; }

git rev-parse --verify "refs/tags/$tag^{commit}" >/dev/null
tag_commit="$(git rev-list -n 1 "$tag")"
[[ "$tag_commit" == "$(git rev-parse HEAD)" ]] || { echo "tag does not point to checked-out commit" >&2; exit 3; }
[[ -z "$(git status --porcelain)" ]] || { echo "working tree is not clean" >&2; exit 4; }

object_type="$(git cat-file -t "refs/tags/$tag")"
[[ "$object_type" == tag ]] || { echo "release tag must be annotated (and protected/signed by repository policy)" >&2; exit 5; }

./scripts/validate-repository.sh
echo "release preflight passed for $tag at $tag_commit"

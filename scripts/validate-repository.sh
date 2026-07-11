#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

required=(
  .github/CODEOWNERS
  .github/dependabot.yml
  .github/pull_request_template.md
  .github/workflows/ci.yml
  .github/workflows/release.yml
  Config/dependencies-allowlist.json
  docs/architecture.md
  docs/privacy.md
  docs/security/threat-model.md
  docs/diagnostics.md
  docs/support-bundle.schema.json
  docs/compatibility.md
  docs/release/release-checklist.md
  docs/operations/cloudflare-pages.md
)

for path in "${required[@]}"; do
  [[ -s "$path" ]] || { echo "missing required file: $path" >&2; exit 1; }
done

python3 -m json.tool Config/dependencies-allowlist.json >/dev/null
python3 -m json.tool docs/support-bundle.schema.json >/dev/null
python3 -m json.tool docs/support-bundle.example.json >/dev/null
python3 - <<'PY'
import json
import pathlib
import re

schema = json.loads(pathlib.Path("docs/support-bundle.schema.json").read_text())
example = json.loads(pathlib.Path("docs/support-bundle.example.json").read_text())
try:
    import jsonschema
except ImportError:
    required = schema.get("required", [])
    missing = sorted(set(required) - example.keys())
    if missing:
        raise SystemExit(f"support bundle missing required keys: {missing}")
else:
    jsonschema.validate(example, schema)

missing_links = []
for document in pathlib.Path(".").rglob("*.md"):
    if any(part in {".git", ".build", "build", "dist", "node_modules"} for part in document.parts) or "build plan" in document.parts:
        continue
    text = document.read_text()
    for target in re.findall(r"(?<!!)\[[^]]+\]\(([^)]+)\)", text):
        if "://" in target or target.startswith("#") or target.startswith("mailto:"):
            continue
        path_part = target.split("#", 1)[0].replace("%20", " ")
        if path_part and not (document.parent / path_part).resolve().exists():
            missing_links.append(f"{document}: {target}")
if missing_links:
    raise SystemExit("missing local Markdown links:\n" + "\n".join(missing_links))
PY

if command -v ruby >/dev/null && ruby -e 'require "yaml"' 2>/dev/null; then
  while IFS= read -r yaml; do
    ruby -e 'require "yaml"; YAML.safe_load(File.read(ARGV[0]), [], [], true)' "$yaml"
  done < <(find .github -type f \( -name '*.yml' -o -name '*.yaml' \) -print)
fi

if command -v shellcheck >/dev/null; then
  shellcheck scripts/*.sh
else
  for script in scripts/*.sh; do bash -n "$script"; done
fi

if command -v markdownlint-cli2 >/dev/null; then
  markdownlint-cli2 '**/*.md' '#build plan/**'
else
  echo "note: markdownlint-cli2 unavailable; Markdown lint remains enforced when installed/CI provisioned"
fi

echo "repository validation passed"

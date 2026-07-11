#!/usr/bin/env bash
set -euo pipefail

output="${1:-dist/koru.cdx.json}"
mkdir -p "$(dirname "$output")"

if command -v syft >/dev/null; then
  syft dir:. -o "cyclonedx-json=$output"
  exit
fi

python3 - "$output" <<'PY'
import datetime
import json
import pathlib
import subprocess
import sys

output = pathlib.Path(sys.argv[1])
components = []
resolution = pathlib.Path("Package.resolved")
if resolution.exists():
    data = json.loads(resolution.read_text())
    for pin in data.get("pins", data.get("object", {}).get("pins", [])):
        state = pin.get("state", {})
        version = state.get("version") or state.get("revision") or "unresolved"
        components.append({
            "type": "library",
            "name": pin.get("identity") or pin.get("package") or "unknown",
            "version": version,
            "purl": f"pkg:swift/{pin.get('identity', pin.get('package', 'unknown'))}@{version}",
        })

commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
document = {
    "bomFormat": "CycloneDX",
    "specVersion": "1.5",
    "serialNumber": f"urn:uuid:{commit[:8]}-{commit[8:12]}-4{commit[13:16]}-8{commit[17:20]}-{commit[20:32]}",
    "version": 1,
    "metadata": {
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "component": {"type": "application", "name": "Koru", "version": commit},
        "properties": [{"name": "koru:generator", "value": "fallback Package.resolved generator; install syft for binary analysis"}],
    },
    "components": components,
}
output.write_text(json.dumps(document, indent=2) + "\n")
PY
echo "wrote $output (source dependency SBOM fallback; install syft for artifact analysis)"

# Release process

Status: scaffold only. The app, signing identity, notarization credentials, protected environments, branch/tag rules, and release artifacts do not exist yet.

## Repository-local flow

1. Complete [release checklist](release-checklist.md) and sign-off record with real evidence.
2. Ensure a clean checkout, committed dependency resolution, approved allowlist, passing CI, changelog, compatibility matrix, rollback compatibility, and no Critical/High defect.
3. Create a protected annotated and signed semantic `v*` tag under maintainer policy.
4. A release owner manually dispatches `Protected release candidate` with that existing tag.
5. Preflight validates tag/commit and repository policy without secrets.
6. The `macos-release` protected environment requires manual reviewer approval before exposing signing/notarization secrets.
7. Build the universal archive, sign nested code then the app with Hardened Runtime and secure timestamp, notarize/staple, package DMG, and verify.
8. Generate `SHA256SUMS`, dependency manifest, CycloneDX SBOM, and provenance. Upload an immutable workflow artifact.
9. A separately protected `release-publication` approval may create a **draft** GitHub Release only. Publication remains a manual action after clean-download verification.

Fork pull requests cannot trigger this `workflow_dispatch` path, receive protected environment secrets, or deploy previews from repository workflow code. `persist-credentials` is disabled in checkout steps. Do not introduce `pull_request_target` for building untrusted changes.

## Local commands

```sh
./scripts/validate-repository.sh
./scripts/release-preflight.sh vX.Y.Z
./scripts/generate-sbom.sh dist/koru.cdx.json
./scripts/generate-checksums.sh dist
./scripts/verify-release.sh dist/Koru.dmg dist/SHA256SUMS
```

`sign-and-notarize.sh` is intentionally fail-closed until the real app and reviewed release marker exist. Secrets belong only in the protected environment, never `.env`, source, artifacts, logs, caches, fork workflows, or pull-request comments.

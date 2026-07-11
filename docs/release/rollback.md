# Rollback and withdrawal

Rollback is a release decision, not merely reinstalling an older `.app`.

## App

1. Stop publication and mark the affected release withdrawn without deleting incident evidence.
2. Recommend the previous notarized artifact and its immutable checksum.
3. Determine schema/ciphertext compatibility. An older binary must refuse a newer schema; never point it at data it cannot understand.
4. Restore only a compatible encrypted pre-migration backup through the reviewed recovery flow. App rollback does not automatically roll back data.
5. Re-run quarantine, signature, notarization, Gatekeeper, upgrade/restore, and core smoke tests.
6. Publish a security notice when confidentiality, integrity, signing, or update trust may be affected.

## Website

1. Identify the last verified Cloudflare production deployment ID and source commit.
2. Use Cloudflare dashboard/API rollback only with explicit release-owner authorization.
3. Verify canonical URL, download link/digest, headers, redirects, 404, sitemap, and no unsupported claim.
4. Record old/new deployment IDs and reason in the sign-off/incident record.

Certificate or notarization credential compromise requires Apple's revocation/incident process, secret rotation, audit of releases, and new verified artifacts. The repository scripts do not automate that external decision.

# External and unfinished-app gates

Repository-local scaffolding is complete only when validation passes. The following remain explicitly outside that claim:

- Build an actual macOS app/Xcode project, committed package resolution, tests, strict-concurrency-clean code, diagnostics UI/exporter, watchdogs, encryption, permissions, and recovery actions.
- Decide exact diagnostics/log retention and close clipboard retention decision D-001.
- Review final bundle ID, paths, Keychain service, entitlements, archive/export options, DMG layout, and release signing implementation.
- Configure GitHub teams/CODEOWNERS validity, labels, Discussions, private vulnerability reporting, branch protection, signed/protected tag policy, required checks, and protected environments/reviewers/secrets.
- Obtain/store Developer ID and App Store Connect notary credentials; perform signing, notarization, stapling, Gatekeeper, universal, quarantine, reproducibility, provenance, clean-download, and clean-room tests.
- Implement and validate `website/`; create/connect Cloudflare Pages; verify previews, production, Pages URL/domain/DNS/TLS/headers/redirects/cache/404/analytics choice; rehearse rollback.
- Execute permission, app/OS/hardware compatibility, accessibility, performance, migration, update/rollback, install/uninstall, security review, beta, launch metric, and final release gates.
- Publish a release or deploy a website only after separate explicit authorization.

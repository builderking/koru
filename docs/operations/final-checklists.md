# Operations and launch checklists

These templates are not evidence that a release or website exists.

## Release-day sign-off

- [ ] Final [release sign-off](../release/sign-off-template.md) is complete and publication approved by named maintainers.
- [ ] Public repository settings, vulnerability route, support ownership, download, website, checksums, source tag, notes, compatibility, and rollback points are live and mutually consistent.
- [ ] Synthetic clean-user install → permission choice → save → recall → explicit insert → export → Delete All Data → uninstall path passes.
- [ ] Monitoring uses website availability/release integrity and explicit content-free local diagnostics; no automatic app telemetry/content collection was added.

## 24-hour review

- [ ] Reverify public artifact digest/signature/notarization and website download link.
- [ ] Triage crashes, text loss, mid-writing invocation, secure/excluded observation, migration, and privacy reports first.
- [ ] Check support volume, compatibility regressions, and permission confusion with no private content copied into tracking.
- [ ] Decide continue, withdraw/rollback, or publish correction; record owner/evidence.

## 7-day review

- [ ] Review Critical/High status, unwanted-surface and insertion-failure evidence, migration/recovery outcomes, app/OS matrix gaps, dependency alerts, and support response health.
- [ ] Confirm public copy still describes only shipped behavior and matches ADR-001's locked Clipboard defaults.
- [ ] Test app and website rollback readiness again.

## 30-day review

- [ ] Evaluate activated-user value/retention evidence against the launch plan without adding content analytics.
- [ ] Review accessibility sessions, Hotkey-only users, compatibility distribution, issue themes, maintenance load, dependency/security posture, and documentation gaps.
- [ ] Record continue/invest/reposition/stop decision and any ADRs; do not treat download count alone as success.

# Koru Launch Plan and Success Metrics

## 1. Launch objective

Launch Koru as a trustworthy, free, open-source macOS writing memory whose core behavior is demonstrably safer and more useful than exact keyboard replacement:

- capture useful writing in place;
- recall it from an imperfect initial fragment;
- explicitly choose and insert beside the caret;
- access temporary clipboard history through the same compact surface;
- keep all core content local.

The launch should validate the product behavior, not maximize download count. A stable release is justified only if people repeatedly reuse permanent saved items and the automatic initial-matching rule is reliable and welcome.

## 2. Positioning

### Primary statement

> Koru is a local writing memory for macOS. Save useful text, remember any fragment, and insert it where you are writing.

### Supporting message

- Free and open source.
- No account.
- No cloud required.
- Nothing is replaced until you choose it.
- Saved writing and temporary clipboard history in one native Mac utility.

### Demonstration sequence

The launch demo should show the product loop without relying on abstract explanation:

1. Write a useful block in a real Mac app.
2. Select all and save it as a saved item.
3. Focus a new empty field and type `pus`.
4. See relevant matches without changing `pus`.
5. Explicitly choose one and see only `pus` replaced.
6. Focus another empty field, type `clp`, and choose a mixed clipboard result.
7. Invoke manual recall in the middle of an existing paragraph.
8. Show local settings, exclusions, pause, and export.

Avoid leading with “prompt manager,” AI, automation, or a feature checklist.

## 3. Target launch cohort

Recruit individual Mac users who repeatedly write across several apps:

- developers and technical operators;
- founders and product professionals;
- support, sales, consulting, and marketing professionals;
- heavy users of AI assistants who reuse instructions across tools;
- existing users of text replacement, snippet, or clipboard utilities who can compare workflows.

The validation cohort should include:

- keyboard-first power users and ordinary Mac users;
- users of VoiceOver or Full Keyboard Access;
- international keyboard and input-method users;
- users who refuse Input Monitoring and therefore test Hotkey-only mode;
- both native and browser/Electron destination apps.

## 4. Distribution plan

### Primary distribution

- Public source repository with build instructions, license, security policy, privacy statement, and contribution guide.
- Developer ID-signed app with Hardened Runtime, distributed in a signed and notarized disk image attached to a versioned GitHub Release.
- Checksums for release assets.
- Release notes that distinguish behavior changes, data migrations, permission changes, and compatibility fixes.

Apple explains that notarization checks Developer ID-signed macOS software for malicious components and code-signing issues before direct distribution; see [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). GitHub documents Releases as a way to package software, release notes, and binary assets in [About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).

### Secondary distribution

- Homebrew Cask after the signed update path and stable release process are proven.
- Mac App Store only if sandbox and review constraints preserve the agreed interaction model and local-first behavior.
- No account-gated download.
- No paid tier, donation interruption, or feature limitation in the product's core flows.

## 5. Release stages and gates

Stages are readiness-based. This plan intentionally does not attach calendar estimates.

### Stage A — technical proof

Purpose: prove that the product's safety contract is technically achievable.

Required scenarios:

- detect a newly focused empty field without treating mid-writing as eligible;
- keep `pus` and `clp` untouched while suggestions are visible;
- replace only the verified initial fragment after explicit selection;
- manually recall and insert at a caret or replace an active selection;
- position near the caret or use a stable fallback;
- detect secure/protected contexts;
- handle permission denial and revocation;
- capture and present mixed pasteboard types;
- preserve the destination and use the defined pasteboard behavior during compatibility fallback; do not race the destination app with automatic clipboard restoration.

Target app matrix:

- native macOS text field and text view;
- Safari;
- Chrome;
- Mail;
- Messages or another native composer;
- ChatGPT, Claude, and Gemini web composers;
- Slack;
- Google Docs;
- Notion;
- VS Code;
- Xcode;
- Terminal.

Exit gates:

- Every typed-panel opening proves that focus began on a verified empty editable field at caret zero and the current prefix has a qualifying local saved-item match or is the reserved `clp` command.
- Empty focus alone, nonqualifying prefixes, and established writing produce no typed panel in the matrix.
- No destination mutation without explicit selection.
- At least 95% successful verified insertions across supported matrix scenarios.
- Unsupported scenarios fall back to Copy without text loss.
- Secure-field exclusion passes all defined tests.

### Stage B — contributor alpha

Purpose: make the product usable by maintainers and technically confident contributors.

Required scope:

- local Saved library;
- Saved text, Quick replacement, and Template behaviors;
- initial typed matching and manual recall;
- `clp` mixed Clipboard results;
- save selection paths;
- retention, exclusions, pause, clear, and export;
- permission-health and Hotkey-only mode;
- crash and local diagnostic capture that excludes content.

Exit gates:

- All product-requirement acceptance tests pass for the supported subset.
- Database migrations have backup and recovery tests.
- Accessibility hierarchy is inspectable and keyboard flows complete.
- Privacy/network inspection confirms no content egress.
- Known unsupported apps and limitations are documented.

### Stage C — closed validation beta

Purpose: validate value, trust, terminology, and interaction with representative users.

Research tasks:

- Observe installation and permission decisions without coaching.
- Ask users to save real repeated writing and later retrieve it from an imperfect fragment.
- Compare typed initial matching with manual recall.
- Observe whether `clp` is understandable without documentation.
- Test the select-all save icon against shortcut-only capture.
- Test Saved text, Quick replacement, and Template labels.
- Include users who keep Hotkey-only mode.
- Conduct accessibility sessions with VoiceOver and Full Keyboard Access.

Exit gates:

- Quantitative thresholds in Section 8 are met by activated beta users.
- No unresolved critical privacy, text-loss, or secure-context defect.
- At least 80% of observed users correctly explain that a result must be selected before replacement.
- At least 80% distinguish permanent Saved from temporary Clipboard after onboarding.
- Permission copy accurately predicts what users see in System Settings.

### Stage D — public beta

Purpose: validate compatibility, open-source contribution, migration, support load, and distribution at broader scale.

Required launch assets:

- signed and notarized binary;
- public privacy and security model;
- installation and uninstall instructions;
- permission guide;
- compatibility matrix;
- keyboard reference;
- data location, export, backup, and restore guide;
- issue templates that request environment/state without asking users to paste private content;
- responsible security-reporting route;
- contributor setup and architecture overview;
- short demo video and screenshots based on the approved visual design.

Exit gates:

- Reliability, privacy, performance, habit, and unwanted-surface thresholds hold across two consecutive public beta releases.
- Upgrade and rollback paths preserve saved items.
- Permission revocation and OS-update recovery are documented and tested.
- Issue volume shows no repeated unresolved text-loss or mid-writing activation pattern.
- Community support and contribution paths are functioning.

### Stage E — stable release

Purpose: declare the core interaction dependable and the data format supportable.

Stable-release gates:

- all release-level acceptance criteria in the product requirements are met;
- supported macOS versions and app compatibility are explicit;
- no critical or high-severity privacy, text-loss, secure-field, or migration defect is open;
- signed/notarized release and manual upgrade verification pass;
- export format is documented and tested against restore;
- VoiceOver, Full Keyboard Access, Reduce Motion, Increase Contrast, and Reduce Transparency QA pass;
- the product meets the success thresholds rather than only download targets.

## 6. Installation and first-run plan

### Installation

1. Download the notarized disk image from the official GitHub Release or project site.
2. Drag Koru to Applications.
3. Open Koru and verify the signed release in the first-run experience.
4. Choose Full mode or Hotkey-only mode.
5. Grant only the permissions required by that choice.
6. Enable Clipboard separately and choose retention.
7. Complete a local capture-and-recall exercise.
8. Optionally enable Launch at Login.

### Permission communication

Before each request, explain:

- what capability the permission enables;
- what stops working if it is declined;
- that content remains local;
- how to revoke the permission later;
- that Hotkey-only mode remains available when applicable.

Apple describes Input Monitoring as allowing an app to monitor input devices across other apps in [Control access to input monitoring on Mac](https://support.apple.com/guide/mac-help/mchl4cedafb6/mac). Because that permission is broad, Koru must not describe it as a harmless implementation detail.

### First-value exercise

The onboarding exercise should use a safe practice field and the user's own locally entered sample:

1. Enter a short reusable sentence.
2. Save it.
3. Focus a new empty field.
4. Type an initial fragment.
5. Explicitly choose the saved result.
6. Undo once to prove normal document control remains available.

No sample content needs to be uploaded or persisted after onboarding unless the user chooses to keep it.

## 7. Measurement model and privacy

### Measurement principles

- Never collect saved content, clipboard content, queries, template values, destination text, file names, URLs, or screenshots.
- The initial public binary makes no background analytics, crash-upload, remote-configuration, or automatic-update request.
- Product behavior is measured through moderated research, content-free local counters that participants explicitly export, and clearly separated opt-in research builds when a study requires aggregate events.
- Any research build is labeled as such, previews exactly what it records, and limits events to anonymous counters, durations, result positions, generic content classes, success/failure codes, and coarse app compatibility identifiers.
- GitHub download counts, issues, discussions, and release health complement but do not replace product-behavior research.
- Accessibility and trust findings require moderated qualitative sessions, not only event data.

### Core definitions

| Metric term | Definition |
| --- | --- |
| Installed | Koru has completed first launch. |
| Onboarded | User has selected a mode and completed or skipped each permission decision knowingly. |
| Activated | User permanently saves at least one item and later inserts a saved item successfully. |
| Successful recall | A recall session ends in explicit insertion or intentional Copy after a destination limitation. |
| Successful saved reuse | A permanent saved item is explicitly selected and inserted. |
| Unwanted surface | User dismisses an automatic initial-match panel and marks it unwanted, or disables the matching source from that context. |
| Insertion failure | An explicit selection does not produce the intended destination result and is not handled as a known Copy fallback. |
| Retained activated user | An activated user completes at least one successful saved reuse during the measured return window. |

### North-star metric

**Weekly successful saved-item reuses per activated user.**

This measures the permanent writing-memory value. Clipboard insertions are tracked separately and do not count toward the north star.

## 8. Success thresholds

### Onboarding and activation

- At least 75% of validation users complete onboarding without assistance.
- Median time from first launch to first successful saved-item insertion is under 5 minutes.
- At least 65% of onboarded validation users activate.
- At least 80% can state that Koru never replaces initial text until they select a result.
- At least 80% can distinguish Saved from Clipboard.

### Recall quality and speed

- At least 75% of Saved recall sessions end in an explicit successful reuse.
- Median time from recall invocation or qualifying fragment to explicit selection is under 3 seconds for previously used items.
- The item the user ultimately chooses appears in the first three results in at least 80% of successful Saved recalls.
- At least 30% of newly created saved items are reused within 7 days by activated validation users.
- Activated users reach a median of at least 5 successful saved-item reuses per active week.

### Habit and retention

- At least 35% of activated users return for a successful saved reuse in the 7-day window.
- At least 25% of activated users return for a successful saved reuse in the 28-day window.
- At least 40% of retained users say they would be very disappointed to lose Koru's recall flow.

### Safety and trust

- Zero confirmed destination mutations without explicit result selection.
- Zero secure-field captures in the defined security test suite.
- Zero saved or clipboard content egress in network inspection.
- Fewer than 1 reported unwanted automatic panel per 200 eligible initial input sessions in the validation cohort.
- Fewer than 5% of users disable initial typed matching specifically because it interrupted established writing.
- At least 85% of interviewed validation users correctly describe Koru as local-first after onboarding.

### Reliability and performance

- At least 98% successful direct insertions across supported app scenarios.
- At least 99.5% crash-free sessions in the consenting beta cohort.
- p95 local result response below 150 ms for the supported dataset target.
- 100% of known unsupported insertion contexts retain source text and present a safe Copy fallback.
- No saved-item loss across supported upgrade, migration, backup, restore, and rollback tests.

### Open-source health

- Reproducible contributor build instructions pass on a clean supported environment.
- Every stable release has source, signed binary, checksums, release notes, and migration notes when applicable.
- Security and contribution policies are visible before public beta.
- At least two maintainers can independently produce and verify a release before stable launch.
- User-facing issues receive a reproducible label or a request for non-content diagnostics; issue templates never solicit private writing by default.

## 9. Decision and kill criteria

### Remove or demote automatic initial typed matching if

- the technical proof cannot confine it to fresh empty sessions across the supported app matrix;
- unwanted automatic surfaces exceed 1 per 100 eligible sessions after tuning;
- more than 15% of validation users disable it because it feels intrusive;
- fewer than 25% of successful Saved recalls use initial matching among users who enabled Full mode;
- permission refusal or revocation makes the interaction unavailable to most target users.

In that case, Hotkey-only manual recall becomes the primary interaction. Koru must not preserve typed matching merely because it is distinctive.

### Reposition or stop the product if

- fewer than 20% of activated validation users reuse a permanent saved item in the 28-day window;
- fewer than 15% of captured saved items are ever reused;
- more than 80% of successful actions are Clipboard-only and permanent saved-item reuse remains below target;
- users consistently describe Koru as interchangeable with their existing clipboard manager or launcher;
- the median saved recall is not materially faster than opening the user's current storage location;
- users will not trust the required permissions even with Hotkey-only mode and transparent local behavior.

### Block stable launch if

- any typed panel opens from empty focus alone, a nonqualifying prefix, an unverified/nonempty start, a caret position other than zero, or established writing;
- any path changes destination text without explicit selection;
- detectable secure/protected contexts enter matching, selection capture, or recall signals, or clipboard changes observed while an excluded app is frontmost enter Clipboard history;
- supported-app direct insertion success remains below 98%;
- migration or update tests can lose permanent saved items;
- content appears in telemetry or network traffic;
- keyboard-only or VoiceOver users cannot complete a core flow;
- the signed/notarized binary cannot be traced to its tag, independently rebuilt from the documented source environment, and verified through recorded provenance.

## 10. Launch feedback loops

### In-product

- Report a problem action with optional content-free diagnostics preview.
- Per-result “Wrong match” action that updates only local ranking unless the user submits an anonymous counter.
- Compatibility report that includes app/version, invocation mode, permission state, and generic failure code but no content.
- Clear route to disable matching for the current app.

### Community

- GitHub Issues for reproducible defects.
- GitHub Discussions for product questions and use cases.
- Security policy with a private vulnerability-report route.
- Request-for-comment process for changes to the initial matching contract, data model, permission use, or telemetry.
- Public compatibility matrix maintained from verified reports.

### Research

- First-use observation.
- Follow-up after users have created their own library.
- Retrieval tasks using intentionally imperfect fragments.
- Trust interview covering permissions, local storage, Clipboard retention, and source distinction.
- Exit interviews with users who disable Full mode, stop using Saved, or uninstall.

## 11. Public launch assets

- concise product page and repository README;
- short behavior-first demo;
- screenshots based on an approved design, not speculative mockups;
- install and uninstall guide;
- Full mode versus Hotkey-only explanation;
- permission and privacy guide;
- “How automatic matching works” page with the empty-input-only rule;
- Saved versus Clipboard explanation;
- saved-item behavior guide;
- keyboard reference;
- compatibility matrix;
- data location, retention, export, backup, restore, and deletion guide;
- contribution, code of conduct, security, and release-verification documentation;
- known limitations and non-goals.

## 12. Post-launch product decisions

Prioritize after stable launch only when evidence supports them:

1. Improve compatibility and insertion reliability.
2. Improve imperfect-fragment ranking and local learned recall.
3. Reduce permission and onboarding friction.
4. Improve template completion.
5. Improve import/export portability.
6. Consider OCR, sync, or additional platforms only after the core Saved reuse metric is healthy.

Do not add AI generation, team features, nested organization, automation, or permanent media archival to compensate for weak core reuse. Weak reuse is a product-signal problem, not a feature-count problem.

## References

- [Apple Developer Documentation: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple Developer: Security overview](https://developer.apple.com/security/)
- [Apple Support: Control access to input monitoring on Mac](https://support.apple.com/guide/mac-help/mchl4cedafb6/mac)
- [GitHub Docs: About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)

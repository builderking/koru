# Koru delivery roadmap: zero to 100

Status: gated delivery sequence
Planning unit: evidence, not elapsed time
Source of truth for locked behavior: 00-index.md

## How to use this roadmap

The numbers are completion gates, not time estimates. Koru is not “40 percent done” because code exists for four phases; it reaches a gate only when every exit criterion is met and evidence is linked from the repository.

Rules:

- phases are completed in order unless an explicit decision record changes a dependency;
- a later demo cannot waive an earlier privacy, platform, or behavior gate;
- failed feasibility work changes scope before production architecture is frozen;
- remote creation, deployment, release, or announcement still requires the explicit action defined in the relevant runbook;
- each phase closes with a written decision, test result, artifact, or review record;
- unresolved Critical or High defects prevent advancement;
- all claims remain private until they are proven in a tagged build.

## 0 — Product contract accepted

### Outcome

The project has one coherent answer to what Koru is, who it serves, and how V1 behaves.

### Work

- approve the plan index and locked decisions;
- reconcile product vision, market, requirements, flows, information architecture, privacy, architecture, quality, and definition of done;
- define the permanent object as one **saved item** with one of three behaviors: Saved text, Quick replacement, or Template;
- define Recent clipboard entries as a separate temporary layer whose content can be saved as a new permanent saved item without extending the original entry;
- define the fresh-input session precisely:
  - automatic typed matching starts only at position zero in a fresh, initially empty input;
  - Koru does not open merely because a field is empty;
  - unrelated typing ends eligibility for that input session;
  - a matching fragment may open the result panel;
  - insertion always requires explicit user choice;
  - the global hotkey may open immediately anywhere supported;
- lock **clp** as the V1 default that enters clipboard scope under the same fresh-input rule;
- approve V1 non-goals and supported-media expectations;
- record who can approve changes to locked behavior.

### Exit criteria

- [ ] No build-plan file contradicts the 00-index.md locked decisions.
- [ ] Every V1 requirement has a stable identifier and at least one acceptance test.
- [ ] “Prompt” is documented as a use case, not a required content type.
- [ ] Saved-item behaviors and temporary Recent storage are unambiguous in product, UX, data, and technical documents.
- [ ] Typed activation, clp, hotkey, explicit insertion, and selection capture have state diagrams or testable flow descriptions.
- [ ] Open questions that can change architecture are listed in 17-risks-decisions-and-open-questions.md.
- [ ] A named product owner signs the gate record.

## 10 — Public-project foundation

### Outcome

The repository can safely host product development without pretending the app is ready.

### Work

- create the agreed native project and package skeleton;
- add Apache-2.0 LICENSE, NOTICE, README, CONTRIBUTING, CODE_OF_CONDUCT, GOVERNANCE, SECURITY, and SUPPORT files;
- configure issue forms, Discussions categories, pull request template, CODEOWNERS, and branch protection;
- add Swift formatting, linting, unit-test, secret-scan, and dependency-review checks;
- add the static website/ Astro skeleton without publishing it;
- add architecture decision record and compatibility-evidence templates;
- scan history and assets for secrets, personal data, and unlicensed content;
- document alpha status and the absence of a supported release.

### Exit criteria

- [ ] A clean checkout builds the empty native shell and static website.
- [ ] Required checks run on a pull request without signing credentials.
- [ ] The repository contains the full Apache-2.0 license and valid project notice.
- [ ] Private vulnerability reporting is enabled and SECURITY.md links to it.
- [ ] No credential, production user content, or unlicensed asset is present in history or generated artifacts.
- [ ] main is protected and release-sensitive paths have owners.
- [ ] Public documentation clearly says that no stable release exists.

## 20 — Native feasibility proven

### Outcome

A disposable harness proves that the locked interaction is technically viable on the required macOS and application matrix before the production design is frozen.

### Work

- build the Koru Integration Harness with controlled AppKit and SwiftUI text fields;
- spike global event observation and permission behavior;
- prove the public global-hotkey registrar works independently of the typed-event tap and Input Monitoring on macOS 13 through the current supported release;
- detect focus, role, secure state, current value, selection, and position zero through Accessibility where available;
- implement the fresh-input session state machine in isolation;
- prove a matching typed fragment can show a panel only in an eligible session;
- prove clp enters clipboard scope only under the same eligibility rules;
- anchor a compact panel to the caret, then exercise control-relative and screen-safe fallbacks;
- test explicit keyboard and pointer selection;
- test insertion tiers without silent replacement;
- test selection capture through Accessibility, global shortcut, and macOS Service fallbacks;
- inspect general pasteboard changeCount, supported types, multi-item events, file/media references, and permission prompts;
- measure behavior in the applications named by the plan index.

### Required evidence

- application-by-application capability matrix;
- screen recordings for success and fallback paths using synthetic content;
- permission-state notes for supported macOS versions;
- failure taxonomy for WebViews, terminals, secure fields, rich editors, and unsupported controls;
- latency, CPU, and event-tap health measurements from release-style builds;
- decision record confirming or narrowing the first supported matrix.

### Exit criteria

- [ ] Zero mid-writing automatic openings occur across the generated state-machine suite.
- [ ] A matching fragment at position zero in a fresh input can open results in the launch-critical host categories.
- [ ] Koru never opens solely because a field is empty.
- [ ] clp enters clipboard scope and does not silently insert an item.
- [ ] Every insertion requires an explicit user action.
- [ ] Secure fields and excluded contexts produce no typed session or capture.
- [ ] Caret anchoring has a safe visible fallback when precise bounds are unavailable.
- [ ] Selection capture has a documented non-destructive fallback.
- [ ] Denied and revoked permissions degrade features without blocking Library access.
- [ ] Manual recall and Save Selection hotkeys register, report conflicts, and remain invokable with Input Monitoring denied; Accessibility-dependent target actions still degrade safely.
- [ ] The team either proves the planned architecture or updates scope through an approved decision record.

## 30 — Local encrypted foundation

### Outcome

Koru can store and search synthetic saved items and temporary Recent entries locally without plaintext content leaking to disk or logs.

### Work

- implement the repository actor around SQLite;
- generate and retain the master key in the macOS data-protection Keychain without iCloud synchronization;
- encrypt record payloads and assets with CryptoKit AES-GCM;
- keep only approved low-sensitivity operational metadata plaintext;
- build the in-memory search index after vault unlock;
- implement schema versioning, atomic migrations, recovery, and test backup handling;
- model saved items with behavior Saved text, Quick replacement, or Template;
- model temporary Recent clipboard events separately, including multi-item events and the save flow that creates a separate permanent saved item;
- implement default expiry, count, and asset-size limits from the privacy plan;
- implement exclusions, pause, clear history, delete all data, export, and key-loss behavior;
- implement content-free structured diagnostics.

### Exit criteria

- [ ] Known synthetic saved and clipboard strings cannot be found in the database, WAL, temporary files, assets, backups, logs, or crash diagnostics.
- [ ] Keychain deletion, locked Keychain, corrupt ciphertext, interrupted migration, and disk-full states fail safely.
- [ ] Migration tests preserve every saved-item behavior and relationship.
- [ ] Saving a Recent entry creates one separate permanent saved item; the original temporary entry keeps its existing expiry.
- [ ] Retention applies transactionally using all documented limits.
- [ ] Searchable plaintext exists only in bounded process memory and is removed on lock or termination.
- [ ] Export excludes clipboard history by default and clearly marks unencrypted output.
- [ ] The app performs no content-bearing network request.
- [ ] A security review signs off the storage and lifecycle design.

## 40 — Saved writing loop complete

### Outcome

A user can create, edit, organize, recall, and insert permanent writing through the Library and hotkey without clipboard history enabled.

### Work

- implement Library views for saved items;
- support all three saved-item behaviors without separate user-facing databases:
  - Saved text for durable recall;
  - Quick replacement with explicit match terms;
  - Template with V1-approved fields;
- implement title, body, match terms, and flat tags only to the approved V1 extent;
- implement deterministic lexical and fuzzy ranking from title, match terms, tags, body, explicit-selection recall signals, usage, and recency as defined by the requirements;
- add the public registered global-open hotkey, independent of the typed-event tap, and explicit result selection;
- make the manual panel and insertion transaction accept an invocation context directly, without depending on the fresh-input state machine delivered at Phase 50;
- add insertion fallbacks and copy-only recovery;
- add edit, duplicate, delete, undo where specified, import, and export;
- add keyboard navigation, VoiceOver labels, Dynamic Type-equivalent macOS text scaling support, contrast, and reduced-motion behavior;
- add bundled synthetic examples that contain no private data.

### Exit criteria

- [ ] The full save → find from imperfect fragment → choose → insert loop works offline.
- [ ] Exact triggers are optional accelerators, not the only retrieval path.
- [ ] No ranking completion, timeout, blur, or top-result state causes insertion.
- [ ] Hotkey retrieval works when typed monitoring is unavailable.
- [ ] A failed explicitly requested insertion leaves content available through an explicit copy path.
- [ ] All saved-item behaviors use one canonical permanent model and round-trip through export/import.
- [ ] Keyboard-only and VoiceOver users can complete the core loop.
- [ ] Search quality passes the agreed synthetic and dogfood corpus evaluation.

## 50 — Fresh-input typed recall complete

### Outcome

Koru's signature fragment-first activation works conservatively beside the caret without interrupting ordinary writing.

### Work

- productionize the event-tap and Accessibility bridges behind tested protocols;
- implement the approved fresh-input state machine;
- connect the typed-session invocation adapter to the already working manual panel and insertion transaction without making manual recall depend on typed monitoring;
- maintain only the minimum bounded in-memory keystroke buffer;
- end eligibility on unrelated text, caret movement, selection, focus change, deletion pattern, unsupported context, or security uncertainty as specified;
- show results only when a matching fragment exists;
- remove or replace the typed fragment only after explicit result choice;
- preserve undo behavior and target-application expectations;
- implement panel positioning, screen bounds, multiple displays, Spaces, full screen, and fallback placement;
- surface permission education only when the user enables typed recall;
- provide a one-action pause and a clear status indicator.

### Exit criteria

- [ ] Generated state-machine tests complete at least the release-plan sequence count with all regression seeds preserved.
- [ ] No panel opens in the middle of existing text across the release compatibility matrix.
- [ ] No panel opens from an empty field before the user types a matching fragment.
- [ ] No raw keystroke or typed query is persisted or emitted in diagnostics.
- [ ] Explicit choice produces one insertion and preserves a usable undo path.
- [ ] Permission denial, revocation, event-tap timeout, unsupported AX control, and secure input produce safe fallback behavior.
- [ ] p95 eligible-prefix search and panel presentation meet the quality budgets.
- [ ] Automatic typed recall can be disabled without disabling Library or hotkey use.

## 60 — Clipboard recall and clp complete

### Outcome

Opt-in temporary clipboard memory works as a bounded, private layer and is reachable through the locked clp flow and hotkey.

### Work

- add explicit clipboard-history onboarding and disclosure before monitoring;
- monitor pasteboard changeCount only while enabled;
- capture supported text, rich text, images, files, and V1-approved media references as logical clipboard events;
- apply observed-frontmost-app exclusions and retention before persistence, without claiming macOS proves the clipboard source application;
- label result types without eagerly loading large payloads;
- implement clp at position zero in a fresh input as the default clipboard-scope command;
- implement a dedicated clipboard hotkey fallback;
- support search, explicit insert/copy, delete, clear, and save-as-new-saved-item;
- avoid recapturing Koru-originated insertion events;
- preserve bounded assets and clean orphaned files;
- explain Universal Clipboard and secret-detection limits honestly.

### Exit criteria

- [ ] Clipboard capture remains off until explicitly enabled.
- [ ] clp works only under the fresh-input rule and opens clipboard scope without silent insertion.
- [ ] The global clipboard hotkey works independently of typed activation.
- [ ] One copy operation becomes one logical event, including supported multi-item content.
- [ ] Default expiry, event count, and asset cap all enforce the privacy-plan limits.
- [ ] Clipboard changes observed while an excluded app is frontmost create no retained event; arbitrary secret-detection and source-attribution limits remain documented.
- [ ] Pasteboard denial stops new capture and preserves existing retained entries safely.
- [ ] Text, images, files, and approved media references insert or fall back predictably.
- [ ] Saving creates one canonical saved item with an explicitly selected behavior, while the original clipboard entry keeps its existing expiry.
- [ ] Idle CPU, capture-to-search latency, memory, and disk use meet quality budgets.

## 70 — Capture, onboarding, and product shell complete

### Outcome

A new user can install Koru, understand its permissions, save writing at the moment of creation, and recover from limitations without developer help.

### Work

- implement first-run explanation without requesting every permission at launch;
- request Accessibility, Input Monitoring, and pasteboard access only when the corresponding feature is enabled and the supported macOS version exposes that request path; registered global hotkeys alone must not trigger an Input Monitoring request;
- add permission status, deep links to System Settings, denial guidance, and recheck behavior;
- implement Save Selection through the global shortcut;
- implement the macOS Service fallback;
- prototype the small select-all affordance only for controls where it is reliable and non-obstructive;
- ensure the selection affordance never appears in secure or excluded contexts;
- implement menu-bar state, Library, settings, exclusions, retention, pause, clear, export, diagnostics, and uninstall guidance;
- add launch-at-login through SMAppService;
- add compatibility status and fallback explanations;
- test fresh installation, upgrade, and complete removal with synthetic data.

### Exit criteria

- [ ] A first-time tester completes the first save and insertion without maintainer intervention.
- [ ] No broad permission is requested before its feature is explained and chosen.
- [ ] Save Selection preserves the original text and current clipboard unless the user chooses a clipboard-changing action.
- [ ] Shortcut and Service fallbacks work according to the documented host matrix; when neither path exposes the selection, Koru explains the limitation without modifying source text or the general clipboard.
- [ ] The affordance never appears in secure fields, excluded apps, or uncertain security contexts.
- [ ] Every permission state has a visible recovery path.
- [ ] Pause, history-off, typed-recall-off, exclusions, and app quit have distinct understandable effects.
- [ ] Uninstall and delete-all instructions remove the documented local data.
- [ ] Onboarding and settings pass keyboard, VoiceOver, contrast, zoom, and reduced-motion checks.

## 80 — Trusted alpha and private beta passed

### Outcome

The integrated app is reliable enough for external testing and produces evidence for a release decision.

### Work

- run internal dogfood using non-sensitive test material first;
- run security, privacy, migration, data-loss, recovery, performance, and accessibility reviews;
- execute the supported macOS, hardware, permission, and host-application matrices;
- test Intel and Apple Silicon universal builds;
- test macOS 13, the specified pre-Liquid-Glass version, and current stable macOS;
- recruit a bounded private beta across the primary market segments;
- collect opt-in surveys, issue reports, and local diagnostic exports without content telemetry;
- evaluate fragment recall, accidental activation, capture-to-reuse, clipboard promotion, permission comprehension, and fallback success;
- fix all Critical and High defects and disposition Medium defects;
- freeze the V1 storage schema and compatibility contract;
- exercise artifact signing and notarization in a non-public release candidate.

### Exit criteria

- [ ] Core loops pass the full compatibility and permission matrices.
- [ ] Zero known content leaks, silent insertions, mid-writing activations, or data-loss defects remain.
- [ ] Critical and High defect count is zero.
- [ ] Performance and reliability budgets pass on reference hardware.
- [ ] Upgrade from a populated earlier vault succeeds and rollback/recovery behavior is documented.
- [ ] Beta participants can explain what Koru captures and how to pause, exclude, clear, and delete.
- [ ] Evidence supports the “writing memory” position rather than a generic snippet or clipboard clone.
- [ ] A release candidate passes signature, Hardened Runtime, notarization, stapling, and Gatekeeper checks.
- [ ] Product, security, and release owners sign the beta gate.

## 90 — Public release system and site staged

### Outcome

The code, community, release pipeline, and marketing site are public-ready, but production publication still waits for the final release action.

### Work

- complete README, user guide, architecture, privacy, security, compatibility, contribution, and support documentation;
- audit dependency licenses, generate notices and SBOM, and verify source provenance;
- configure the tagged release workflow with protected signing and notarization credentials;
- produce a draft GitHub pre-release from the release candidate with DMG, checksum, notes, and compatibility matrix;
- complete the marketing site with real screenshots and only verified claims;
- finish Koru trademark and Māori cultural review or execute an approved rename;
- build website/ locally with npm ci and npm run build;
- run accessibility, performance, security-header, metadata, and link checks;
- perform the approved Cloudflare MCP read-only preflight;
- after explicit authorization, create the Pages project with the configuration in 13-cloudflare-pages-publishing.md;
- verify a pull-request preview and its noindex behavior;
- prepare launch, incident, withdrawal, support, and rollback checklists;
- rehearse production deployment and rollback only through an explicitly approved release exercise.

### Exit criteria

- [ ] Public repository health and security files are complete and current.
- [ ] Apache-2.0 license, NOTICE, dependency notices, and SBOM are correct.
- [ ] The release workflow cannot expose signing secrets to pull requests.
- [ ] The candidate artifact installs from quarantine and matches its published checksum.
- [ ] The site builds to website/dist without a runtime function or secret.
- [ ] Every marketing claim maps to a test or tagged candidate behavior.
- [ ] Brand, trademark, and cultural-review gates are closed.
- [ ] A Cloudflare preview matches the reviewed commit and is non-indexed.
- [ ] Production and app rollback targets are identified and rehearsed.
- [ ] Support and private vulnerability-reporting routes have named owners.
- [ ] No “Download” action points to an unsigned, unnotarized, or missing artifact.

## 100 — V1 publicly released and operable

### Outcome

Koru is a signed, notarized, public open-source macOS product with a verified download, live truthful website, supported issue path, and tested recovery procedures.

### Final release actions

- approve the exact release commit and version;
- run all release-blocking checks;
- build the universal arm64 and x86_64 artifact;
- sign the app, package and sign the DMG, submit the final deliverable for notarization, staple and validate it, then publish its checksum;
- publish the GitHub Release with notes, SBOM, notices, compatibility matrix, and known limitations;
- install and smoke-test from the public release URL on clean supported systems;
- merge the reviewed website commit to main through the approved workflow;
- verify the Cloudflare production deployment matches that commit;
- verify download, source, privacy, security, license, metadata, headers, analytics state, and responsive behavior;
- make the approved launch announcements;
- activate support, incident, vulnerability, withdrawal, and rollback ownership;
- record final evidence in the release issue.

### Exit criteria

- [ ] Every item in 19-definition-of-done.md is complete or explicitly rejected through a release-blocking decision; unresolved release requirements cannot be silently waived.
- [ ] The public DMG is signed, notarized, stapled, checksum-verified, and Gatekeeper-tested.
- [ ] The public source tag matches the release record.
- [ ] The installed app works offline for save, recall, explicit insert, selection capture fallback, and Library management.
- [ ] Fresh-input matching, clp, hotkey fallback, and clipboard opt-in behave exactly as locked.
- [ ] Website production comes from main, shows only verified claims, and points to the exact release.
- [ ] A known-good app artifact and successful Pages production deployment are available for rollback.
- [ ] Security reporting, issue triage, support, and release ownership are active.
- [ ] The launch record contains approvers, commit, tag, artifact, checksum, notarization result, website deployment, compatibility evidence, and accepted limitations.

## Post-100 change rule

After V1, new work enters through evidence and a decision record. The following are not implied by completion and require separate product, privacy, and architecture approval:

- cloud sync or accounts;
- iOS or Windows clients;
- remote or cloud-AI ranking;
- team libraries;
- a prompt marketplace;
- plugin or public automation APIs;
- an automatic updater;
- Mac App Store distribution;
- browser extensions;
- persistence of video payloads;
- default analytics or crash-content collection;
- changing clp or fresh-input behavior;
- splitting Saved text, Quick replacement, and Template into separate permanent stores.

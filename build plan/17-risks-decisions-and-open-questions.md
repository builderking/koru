# Koru risks, decisions, and open questions

Status: active decision-control register
Authority: 00-index.md, unless an approved decision record explicitly supersedes it
Review points: every roadmap gate, release candidate, and security incident

## 1. Purpose

This file separates four things that are often blurred during implementation:

1. **locked decisions** — the team must implement and test them;
2. **adopted implementation decisions** — current architecture, changeable only through an architecture decision record;
3. **open questions** — a named decision is still required;
4. **risks** — uncertain events that require mitigation and evidence.

An implementation difficulty does not silently turn a locked decision into an open question. If a spike disproves feasibility, record the evidence, describe the smallest viable scope change, and obtain an explicit decision.

## 2. Status and severity language

### Decision status

- **Locked:** product-level commitment in 00-index.md.
- **Adopted:** approved in a supporting plan and binding on implementation unless an ADR changes it.
- **Open:** unresolved and assigned to a decision gate.
- **Deferred:** explicitly outside V1; not permission to build it opportunistically.
- **Rejected:** considered and not part of the current direction.

### Risk scales

**Likelihood**

- Low — plausible but not expected under the current design.
- Medium — credible in normal development or use.
- High — already observed in comparable integrations or inherent to the platform.

**Impact**

- Low — local inconvenience with a clear fallback.
- Medium — meaningful workflow or support cost without data loss or exposure.
- High — blocks the product promise, distribution, or a large supported segment.
- Critical — may expose private content, insert or destroy text without consent, corrupt durable data, or compromise release integrity.

Any open Critical risk and any unmitigated High risk blocks stable release.

## 3. Locked product decisions

The following are not open design prompts.

| ID | Locked decision | Consequence |
| --- | --- | --- |
| L-001 | Koru is free and open source under Apache-2.0. | No proprietary-core pivot or source-available substitute without an explicit project-level decision. |
| L-002 | Koru is a local-first native macOS utility, useful without an account or cloud AI. | Core save, search, clipboard recall, and insertion work offline. |
| L-003 | Automatic typed matching uses a complete assigned tag suffix of at least three characters at a left boundary anywhere in writing. | Existing text and caret position do not disable matching; partial, fuzzy, derived-label, content, and stale-generation matches do not open the panel. |
| L-004 | Koru does not open merely because a field is focused or text resembles saved content. | A complete exact assigned tag or reserved `clp` is required; the global hotkey is the immediate fuzzy-browse path. |
| L-005 | Koru never silently replaces or inserts text. | Showing, focusing, ranking, timeout, blur, or exact match cannot insert. Explicit choice is always required. |
| L-006 | Automatic recall is exact and manual recall is fuzzy. | Automatic matching reads assigned tags only; manual ranking searches tags, content, and approved local signals. |
| L-007 | clp is the V1 reserved clipboard command at a left boundary anywhere. | clp enters clipboard scope, leaves the typed characters untouched until explicit selection, and may become configurable only after V1. |
| L-008 | The global hotkey remains available everywhere the platform permits as a fallback. | Manual commands use a registered-hotkey path independent of Input Monitoring and the typed-event tap; Accessibility remains optional or required according to the downstream caret, selection, and insertion capability. |
| L-009 | The permanent object is one saved item containing reusable text plus one or more exact tags. | Do not require a user-authored title, behavior subtype, match-term mode, template schema, or competing libraries. |
| L-010 | Recent clipboard content is a separate temporary layer. | Promotion creates a saved item; temporary retention is not silently extended. |
| L-011 | Selecting all may expose a small save affordance only where reliable and safe. Global shortcut and macOS Service are required fallbacks. | The floating affordance is opportunistic, not a universal compatibility claim. |
| L-012 | Product vocabulary is neutral; prompt is a use case, not a required type. | Marketing and UI cannot narrow Koru to “AI prompt manager.” |
| L-013 | The quick interface is compact, native, keyboard-first, and low-copy. | Detailed visual polish follows native prototypes; no web-style command center is required for recall. |
| L-014 | Raw keystrokes are never persisted; Koru adds no automatic-recall secure-field or per-app exclusion; clipboard capture remains opt-in with separate exclusions. | macOS Secure Input and protected surfaces remain hard platform limits, and every unsupported insertion path must preserve text or fall back to Copy. |
| L-015 | The first supported release is directly distributed as a signed and notarized macOS app. | Mac App Store constraints are not a V1 requirement. |
| L-016 | The launch website is static Astro in website/, with Cloudflare Pages production from main and pull-request previews. | No launch CMS, SSR, account backend, or Pages Function is needed. |
| L-017 | Planning and implementation do not themselves authorize Git push, Cloudflare mutation, deployment, release, or announcement. | Each remote action follows its explicit approval gate. |

### Behaviors that are explicitly not open

- automatic opening of Koru on focus of an empty field;
- automatic expansion after an exact trigger;
- changing clp into a tentative example;
- requiring people to classify saved content as a prompt;
- restoring title/behavior/template classification to the canonical saved-item schema;
- enabling clipboard history by default;
- making cloud sync or remote AI necessary for core retrieval;
- claiming universal host-application compatibility;
- adding an automatic updater to V1.

## 4. Adopted implementation decisions

These are binding implementation choices in the current supporting plans. Change them only through an ADR that includes migration, privacy, compatibility, and release impact.

| ID | Adopted decision | Source and reason |
| --- | --- | --- |
| A-001 | Native Swift menu-bar application with AppKit for system integration and SwiftUI for ordinary product surfaces. | 07-technical-architecture.md; matches macOS event, Accessibility, pasteboard, Services, and window needs. |
| A-002 | One signed application process; no helper, daemon, input method, extension, kernel extension, or system extension in V1. | Reduces install, security, and communication complexity. |
| A-003 | Minimum deployment target macOS 13; release artifact is universal arm64 and x86_64. | Preserves a meaningful Intel path while using modern ServiceManagement. |
| A-004 | SQLite stores ciphertext and minimal operational metadata; CryptoKit AES-GCM encrypts record payloads; the master key is in the data-protection Keychain. | 07 and 09; makes local privacy inspectable and avoids plaintext full-text storage. |
| A-005 | Searchable content index exists only in memory after decryption. | Prevents a plaintext body index on disk. |
| A-006 | Event-tap and Accessibility integration bind every automatic match to a frontmost process, input generation, exact tag, and AX range/digest when available. | Koru does not security-gate automatic recall, but stale or uncertain insertion context fails without modification. |
| A-007 | Initial release makes no background network request and contains no analytics, crash upload, remote config, sync, AI service, or automatic update feed. | 09 and 10; keeps the V1 trust contract narrow. |
| A-008 | Check for Updates opens the official release page after explicit action. | Avoids an unreviewed update channel in V1. |
| A-009 | Clipboard files and videos are references; Koru does not archive large video binaries in V1. | Bounds storage and avoids misrepresenting temporary references as durable media. |
| A-010 | Static Astro output deploys from website/ with npm run build to dist; no Cloudflare adapter or Function. | 12 and 13; keeps hosting portable and low-risk. |
| A-011 | Official releases use vX.Y.Z Git tags, signed and notarized DMG assets, SHA-256 checksums, release notes, notices, compatibility evidence, and SBOM. | 10 and 11; provides traceability and supply-chain evidence. |
| A-012 | No CLA or DCO enforcement at initial public contribution. | 11; avoids unnecessary contribution friction, subject to later governance review. |
| A-013 | Manual global commands use a dedicated `GlobalHotKeyRegistrar` backed by the public `RegisterEventHotKey` path; the Core Graphics event tap is limited to typed matching and automatic-panel navigation. | 07, 08, and 16; shortcut registration receives discrete command IDs without Input Monitoring, while Accessibility remains capability-specific. See Apple's archived [Carbon Event Manager Reference](https://developer.apple.com/library/archive/documentation/Carbon/Reference/Carbon_Event_Manager_Ref/Reference/reference.html). |
| A-014 | Automatic lookup is complete exact-tag suffix matching with a three-character minimum and left boundary; manual lookup remains fuzzy. | Makes inline behavior predictable while preserving discovery through the shortcut panel. |

## 5. Closed reconciliation decision

### D-001 — Clipboard default limits

Accepted on 2026-07-11 by `docs/architecture/adr-001-v1-clipboard-retention.md`:

- 500 logical clipboard events;
- seven-day expiry;
- 256 MB total encrypted clipboard assets;
- 25 MB per retained image;
- files and videos stored as references.

These are the locked V1 defaults. Clipboard remains opt-in, the first reached boundary evicts oldest temporary events, and changes require a replacement ADR.

## 6. Open-question register

Open questions are decision tasks, not a speculative feature backlog.

| ID | Question | Recommended starting position | Owner | Must close by | Required evidence |
| --- | --- | --- | --- | --- | --- |
| OQ-001 | Can Koru be used as the product name respectfully and legally? | Keep as working name; use neutral wordmark; obtain trademark search, legal review, and Māori cultural guidance before public branding. | Product and brand | Roadmap 90 | Search report, advisor feedback, written go/rename decision |
| OQ-002 | What are the default global shortcuts for recall, clipboard recall, and Save Selection? | Choose conflict-tested, configurable `GlobalHotKeyRegistrar` chords after the host-app spike; do not override macOS or common editor shortcuts and do not use the event tap as a conflict workaround. | UX and platform | Roadmap 20 | Registration/conflict matrix across supported macOS versions and keyboard layouts, plus keyboard-accessibility review |
| OQ-004 | Which host applications and field types receive “Supported” status in V1? | Publish only the matrix proven by the feasibility harness; label fallbacks and exclusions explicitly. | QA and platform | Roadmap 20 | Versioned application/capability matrix |
| OQ-005 | Which pasteboard representations are inserted versus copied, dragged, revealed, or rejected? | Support ordinary text, rich text, URL, image, and file references only where round-trip tests are reliable; never eagerly load large media. | Platform and security | Roadmap 60 | UTType matrix, size tests, per-host insertion evidence |
| OQ-007 | Where is the select-all save affordance allowed? | Start with an allowlist derived from stable AX selection and bounds; keep shortcut and Service as primary fallbacks elsewhere. | UX and platform | Roadmap 70 | False-positive/occlusion tests across host matrix |
| OQ-008 | Which import formats ship in V1? | Guarantee Koru's own open export first; add Apple or competitor import only if fixtures and licensing support a reliable migration. | Product and data | Roadmap 70 | Format samples, round-trip tests, failure messaging |
| OQ-009 | What public domain should the website use? | Launch on the verified pages.dev host until name, trademark, ownership, DNS, and recovery are settled. | Brand and operations | Roadmap 90 | Domain decision, ownership record, DNS and rollback plan |
| OQ-010 | Who owns project, repository, Cloudflare, signing, notarization, and security recovery access? | Name primary and backup operators; use least privilege; keep signing access narrower than repository access. | Project lead | Roadmap 10 for repo, 90 for release systems | Access inventory and recovery drill |
| OQ-011 | What private security-reporting contact supplements GitHub private vulnerability reporting? | Use an actively monitored BuilderKing address with documented backup ownership. | Security | Roadmap 10 | Verified route and response drill |
| OQ-012 | What is the first public-release URL and artifact host? | Use GitHub Releases as the initial source of truth unless a security or availability review chooses another signed channel. | Release | Roadmap 90 | Quarantined-download verification and checksum match |
| OQ-013 | Which beta cohort and evidence are sufficient to stabilize positioning? | Recruit repeated-writing Mac users across development, product/operations, and client-facing work; evaluate behaviors, not download volume. | Product research | Roadmap 80 | Interview notes, anonymized measures, decision summary |
| OQ-014 | Which maintainers can merge security-sensitive paths and publish releases? | Require explicit CODEOWNERS and at least one independent review; keep publication manually approved. | Project lead | Roadmap 10 and 90 | Governance record and protected workflow test |
| OQ-015 | How should local learned recall signals be reset and explained? | Keep them local, content-minimized, resettable independently, and incapable of automatic insertion. | Search and privacy | Roadmap 40 | Data inventory, reset test, user copy review |
| OQ-016 | Is a custom Koru glyph justified before cultural review? | Use a neutral writing/recall symbol or wordmark; avoid koru-derived spirals until informed review. | Brand | Roadmap 90 | Asset provenance and cultural approval |

### Deferred, not open for V1

- cloud sync and accounts;
- remote semantic search or cloud AI;
- team libraries;
- iOS, Windows, or browser clients;
- prompt marketplace;
- public plugin API;
- automatic update framework;
- Mac App Store distribution;
- permanent video archive;
- default background telemetry;
- changing the reserved clp command;
- template variables or executable saved-item behavior.

## 7. Risk register

### R-001 — Permission trust prevents adoption

**Likelihood:** High
**Impact:** High
**Owner:** Product, platform, privacy
**Gate:** 20, 70, 80

Koru's useful cross-application behavior may require Accessibility, Input Monitoring, and pasteboard access. These permissions resemble the capabilities of a keylogger even when implementation is careful.

Mitigations:

- request each permission only after the user enables the feature that needs it;
- show a plain explanation before the system prompt;
- keep registered Hotkey-only commands and Library use valuable when typed monitoring is disabled; never request Input Monitoring merely to register a shortcut;
- keep clipboard history separately opt-in;
- expose pause, exclusions, retention, clear, and delete-all controls;
- publish source and an exact data-flow document;
- make the V1 binary perform no background network request;
- let Diagnostics prove permission state without showing content.

Release evidence:

- first-run comprehension study;
- permission grant, denial, revocation, and regrant matrix;
- independent privacy/security review;
- network-capture test showing no background traffic.

### R-002 — Cross-application behavior is less universal than the promise

**Likelihood:** High
**Impact:** High
**Owner:** Platform and QA
**Gate:** 20, 80

Native AppKit, SwiftUI, browsers, Electron apps, WebViews, terminals, and rich editors expose different Accessibility and insertion behavior.

Mitigations:

- build the disposable integration harness before production architecture;
- test versions and field types, not only app names;
- fail closed when context is uncertain;
- support caret-relative, control-relative, and safe-screen panel positions;
- retain hotkey, copy-only, Service, and Library fallbacks;
- test registered-hotkey delivery independently from event-tap and Input Monitoring state;
- publish a versioned compatibility matrix with limitations.

Release evidence:

- required host matrix passes;
- each unsupported capability has a usable fallback;
- marketing names only verified support.

### R-003 — Automatic matching interrupts ordinary writing

**Likelihood:** Medium
**Impact:** Critical
**Owner:** Platform, search, QA
**Gate:** 20, 50, 80

A false panel without a complete assigned tag undermines the defining predictability promise. A panel in established writing is correct when the exact tag rule is satisfied.

Mitigations:

- require a complete assigned tag of at least three characters at a left boundary;
- never use prefix, fuzzy, derived-label, content, or learned matches for automatic opening;
- prefer committed AX text and caret state when available;
- bind rolling-suffix fallback to the frontmost process and input generation;
- invalidate the panel on further typing, focus/app/caret change, click, paste, or uncertain composition;
- provide a global automatic-matching disable control;
- preserve failing generated-test seeds.

Release evidence:

- zero openings without a complete exact tag in generated sequences and the host matrix, with positive coverage at field start and during established writing;
- explicit beta unwanted-surface review;
- content-free diagnostics can distinguish why a session was ineligible.

### R-004 — Koru changes or loses destination text

**Likelihood:** Medium
**Impact:** Critical
**Owner:** Insertion and QA
**Gate:** 20, 40, 50, 60

Focus changes, asynchronous paste behavior, rich editors, stale selections, or broad replacement ranges may corrupt writing.

Mitigations:

- never insert from mere focus, rank, timeout, or blur;
- revalidate target, selection, and exact matched tag range immediately before insertion;
- replace only the exact active tag suffix at its actual range;
- cancel when the destination changed;
- preserve the inserted pasteboard item rather than racing to restore it;
- validate process/generation before the synthetic Backspace-and-paste tier and provide Copy when safe insertion cannot be proved;
- test native undo behavior and multi-format paste.

Release evidence:

- no silent insertion or overbroad replacement in compatibility tests;
- insertion failure leaves source and destination recoverable;
- undo and copy fallback pass per-host tests.

### R-005 — Caret anchoring is unavailable or visually wrong

**Likelihood:** High
**Impact:** Medium
**Owner:** Platform and UX
**Gate:** 20, 50

Some controls do not expose reliable caret bounds; multiple displays, scaling, Spaces, and full-screen windows complicate placement.

Mitigations:

- use standardized Accessibility bounds where reliable;
- fall back to control-relative or safe visible-screen placement;
- clamp to the active display;
- disclose fallback rather than pretending the panel is anchored;
- preserve keyboard flow regardless of panel position.

Release evidence:

- multi-display and scaling matrix;
- no off-screen or input-obscuring panel in supported hosts;
- VoiceOver navigation does not depend on spatial placement.

### R-006 — Sensitive content enters typed state or clipboard history

**Likelihood:** Medium
**Impact:** Critical
**Owner:** Security, privacy, platform
**Gate:** 20, 30, 60, 80

macOS does not provide a universal signal that arbitrary clipboard content is a password or token, and Secure Input does not guarantee that a third-party utility will receive key, AX, or posting capabilities consistently.

Mitigations:

- apply no Koru secure-field or app exclusion to automatic exact-tag recall;
- keep the rolling suffix bounded, transient, and absent from logs, diagnostics, persistence, and network traffic;
- treat Secure Input and protected authorization surfaces as OS limitations that may suppress matching or insertion;
- ship visible clipboard-sensitive-app exclusions by bundle identifier;
- let users add Never Save Clipboard From entries;
- make capture opt-in and retention conservative;
- provide pause and clear actions;
- never treat heuristic secret detection as a guarantee;
- keep source rules local and versioned with signed releases.

Release evidence:

- secure/password-field compatibility tests proving no unintended modification under each exposed capability;
- clipboard-excluded-app negative tests;
- adversarial clipboard fixtures;
- deletion and retention tests;
- public privacy copy explains the detection limit.

### R-007 — Local encryption creates corruption or key-loss failure

**Likelihood:** Medium
**Impact:** Critical
**Owner:** Data and security
**Gate:** 30, 80

Encryption reduces disclosure risk but makes key, migration, and recovery mistakes more consequential.

Mitigations:

- use one repository actor and authenticated encryption;
- version encrypted envelopes;
- perform atomic migrations with bounded backups;
- test Keychain lock, deletion, corruption, and access-change states;
- distinguish vault reset from ordinary deletion;
- provide explicit unencrypted export warnings;
- never invent data recovery that bypasses the missing key.

Release evidence:

- fault-injection and interrupted-migration suite;
- plaintext scan;
- populated-vault upgrade test;
- documented key-loss behavior.

### R-008 — Search quality does not support imperfect memory

**Likelihood:** Medium
**Impact:** High
**Owner:** Search and product
**Gate:** 40, 50, 80

Automatic matching deliberately requires an exact tag, so manual fuzzy recall must remain good enough when a person forgets it.

Mitigations:

- evaluate exact tag, prefix/contained tag, content, fuzzy, and local learned signals in manual recall only;
- keep deterministic explainable ranking in V1;
- measure relevant result position, false openings, and successful explicit choices;
- let users assign multiple memorable phrase tags to the same content;
- keep learned signals local and resettable;
- do not claim semantic recall until implemented and evaluated.

Release evidence:

- representative synthetic and consented dogfood corpus;
- fuzzy manual-recall retrieval thresholds;
- beta interviews show recovery without exact abbreviation.

### R-009 — Clipboard media causes storage or performance failure

**Likelihood:** High
**Impact:** High
**Owner:** Data, platform, performance
**Gate:** 30, 60, 80

Images, multi-item copies, and video/file references can be large, slow, stale, or unsupported by the destination.

Mitigations:

- enforce age, count, total-size, and per-item limits;
- store files and videos as references;
- render bounded thumbnails and type labels;
- never load a full video to display a result;
- expose missing-reference state;
- clean orphaned assets transactionally;
- fall back to Copy, Drag, or Reveal based on representation.

Release evidence:

- maximum-limit load test;
- missing and moved file tests;
- memory, disk, idle CPU, and capture latency budgets pass.

### R-010 — Multilingual input and IME composition break the state model

**Likelihood:** Medium
**Impact:** High
**Owner:** Platform, accessibility, localization
**Gate:** 20, 50, 80

Composed input, dead keys, right-to-left text, non-Latin scripts, and alternate keyboard layouts can make an event-level suffix differ from committed text.

Mitigations:

- suspend automatic matching during active composition;
- derive committed field state through Accessibility where possible;
- test multiple layouts and representative IMEs;
- keep manual recall fully functional;
- do not normalize or replace text beyond the verified exact tag.

Release evidence:

- keyboard-layout and IME matrix;
- no premature panel or replacement during composition;
- literal input remains unchanged on cancel.

### R-011 — The product is perceived as a commodity clone

**Likelihood:** High
**Impact:** High
**Owner:** Product and marketing
**Gate:** 0, 80, 90

Apple, Typinator, TextExpander, Raycast, Alfred, Paste, PastePal, and Espanso already cover significant parts of snippets, prompts, clipboard recall, cursor surfaces, and selection capture.

Mitigations:

- position Koru as local writing memory;
- demonstrate exact-tag inline recall plus fuzzy manual recall;
- show one content-plus-tags saved-item model plus temporary Recent recall;
- make selection capture and promotion part of the same loop;
- avoid “first” and generic AI claims;
- validate multi-tool replacement rather than feature awareness.

Release evidence:

- user can explain the distinction after the demo;
- beta users reuse and promote content through Koru;
- public copy passes the market truth checklist in 02.

### R-012 — Apple raises the platform baseline

**Likelihood:** High
**Impact:** Medium
**Owner:** Product
**Gate:** Every release

macOS already provides text replacements and newer Spotlight clipboard history. Those capabilities may improve.

Mitigations:

- do not compete on basic clipboard retention or exact replacement alone;
- track official macOS release notes and compatibility;
- preserve open export and local portability;
- focus on unified recall, explicit capture, fragment search, and caret workflow;
- reassess the wedge during each major macOS beta.

Release evidence:

- current Apple capability review before launch;
- positioning comparisons use current official sources.

### R-013 — Koru name or visual identity causes legal or cultural harm

**Likelihood:** Medium
**Impact:** High
**Owner:** Product, brand, legal
**Gate:** 90

Koru is a Māori word and visual concept. Casual use of a spiral or invented cultural story could be disrespectful, difficult to register, or publicly harmful.

Mitigations:

- keep the name provisional until review;
- obtain trademark search and advice in target markets;
- engage an appropriate Māori advisor;
- use a neutral wordmark and writing-recall glyph meanwhile;
- avoid faux Māori art and unverified meaning claims;
- rename before public identity if approval is not clear.

Release evidence:

- written cultural and legal go/rename record;
- asset provenance and brand-use guidance.

### R-014 — Open-source supply chain compromises a sensitive utility

**Likelihood:** Medium
**Impact:** Critical
**Owner:** Security and release
**Gate:** 10, 80, 90, 100

Koru observes input context and clipboard content. A compromised dependency, workflow, release key, or binary would have severe trust impact.

Mitigations:

- minimize runtime dependencies;
- pin lockfiles and GitHub Actions by immutable SHA;
- use least-privilege workflow permissions;
- isolate signing and notarization from untrusted pull requests;
- require CODEOWNERS review for capture, storage, release, and workflow paths;
- generate SBOM, notices, and checksums;
- retain reproducible evidence and immutable release artifacts;
- maintain a private vulnerability route and credential-rotation plan.

Release evidence:

- dependency and workflow audit;
- secret scan;
- signed/notarized quarantined artifact verification;
- release approval record.

### R-015 — Open-source maintenance exceeds available ownership

**Likelihood:** Medium
**Impact:** High
**Owner:** Project lead
**Gate:** 10, 90, ongoing

Issues, compatibility reports, security response, dependencies, macOS changes, and releases create continuing work.

Mitigations:

- publish scope and support boundaries;
- route questions to Discussions and reproducible defects to Issues;
- use structured forms and compatibility evidence;
- name primary and backup maintainers;
- document succession and maintenance-only status;
- avoid promising response or release times;
- close unsupported feature requests without expanding V1.

Release evidence:

- named ownership rota;
- triage and security exercise;
- governance describes inactive-project behavior.

### R-016 — Website claims drift from product behavior

**Likelihood:** Medium
**Impact:** High
**Owner:** Product, documentation, website
**Gate:** 90, every release

Screenshots, privacy copy, compatibility, download links, and structured data can become false after product changes.

Mitigations:

- link claims to tagged release evidence;
- update product documentation and website in the same change;
- generate version/download details from the release source where practical;
- avoid universal and absolute privacy claims;
- use real screenshots and current permission prompts;
- make claim review part of release approval.

Release evidence:

- claim-to-test checklist;
- broken-link, metadata, and compatibility checks;
- public download matches the tagged artifact.

### R-017 — Cloudflare configuration creates unintended publishing

**Likelihood:** Low
**Impact:** High
**Owner:** Website and operations
**Gate:** 90, 100

A wrong repository ID, branch, root directory, or Git setting could publish the wrong content or connect unwanted automatic deployments.

Mitigations:

- follow docs → search → read-only execute → approval → write → read-only verification;
- check for an existing koru project before creation;
- resolve GitHub numeric IDs through the repository API;
- lock root website, build npm run build, output dist, and production main;
- omit path filters initially;
- restrict the GitHub App to the intended repository;
- keep previews public-safe and non-indexed;
- identify a known-good production rollback target.

Release evidence:

- returned project configuration matches the approved payload;
- preview and production commits match GitHub;
- rollback rehearsal succeeds.

### R-018 — Accessibility is sacrificed for compactness

**Likelihood:** Medium
**Impact:** High
**Owner:** UX and QA
**Gate:** 40, 50, 70, 80

A tiny caret-side surface can create small targets, weak contrast, poor VoiceOver order, or focus traps.

Mitigations:

- use native controls and focus effects;
- preserve full keyboard operation;
- provide accessible names for source, content preview, tags, type, and actions;
- respect Increase Contrast, Reduce Transparency, Reduce Motion, and system accent;
- use opaque fallback when glass harms readability;
- keep primary rows and targets at accessible sizes;
- test with VoiceOver and Full Keyboard Access on every supported visual generation.

Release evidence:

- accessibility acceptance matrix;
- manual assistive-technology review;
- no information encoded only by color or location.

### R-019 — Supporting Intel and macOS 13 expands the test burden

**Likelihood:** High
**Impact:** Medium
**Owner:** Release and QA
**Gate:** 80, every release

Universal distribution and multiple visual generations increase compatibility and CI cost.

Mitigations:

- isolate platform adapters;
- use standard AppKit and SwiftUI behavior;
- test Intel on the release-blocking matrix;
- publish the exact supported range;
- collect evidence before any future minimum-version increase;
- do not let newer Liquid Glass behavior change information hierarchy.

Release evidence:

- one universal artifact passes on the required Intel and Apple Silicon systems;
- compatibility and visual-fallback tests pass.

### R-020 — Low evidence leads to premature stable launch

**Likelihood:** Medium
**Impact:** High
**Owner:** Product and release
**Gate:** 80, 100

A polished demo can hide low repeat use, misunderstood clp behavior, permission rejection, or weak fragment recall.

Mitigations:

- treat technical proof, contributor alpha, closed beta, public beta, and stable as separate gates;
- measure successful reuse and safety rather than downloads;
- use the kill and demotion criteria in 18-launch-plan-and-success-metrics.md;
- allow hotkey-only recall to become primary if automatic matching is not welcomed;
- block stable release on privacy, data-loss, or compatibility failures.

Release evidence:

- beta behavior and interview summary;
- launch threshold report;
- explicit stable go/no-go decision.

## 8. Cross-risk release blockers

Stable release is blocked if any of the following is true:

- a typed panel can open from focus alone, a partial or sub-three-character tag, a missing left boundary, a fuzzy/derived-label/content match, or a stale process/generation;
- a result can insert without explicit choice;
- registered manual recall fails solely because Input Monitoring is denied or the typed-event tap is unavailable;
- Secure Input or a protected surface can cause unintended modification, automatic typed suffixes can be persisted/logged/transmitted, or a clipboard-excluded app can create clipboard history;
- saved or clipboard content appears in logs, telemetry, network traffic, plaintext disk storage, or public issue templates;
- durable saved items can be lost or corrupted through a supported upgrade;
- a release artifact is unsigned, unnotarized, unstapled, checksum-mismatched, or built from an unidentified commit;
- signing or Cloudflare credentials are available to untrusted pull requests;
- the supported application matrix is not executed on the required macOS and hardware range;
- the public site claims behavior, privacy, compatibility, or availability that the release does not prove;
- the name and public visual identity have not passed the brand decision gate;
- support and private vulnerability reporting have no active owner;
- no known-good app or website rollback target exists.

## 9. Decision-record template

Create a numbered record under docs/decisions/ for any change to a locked or adopted decision.

    # ADR-NNN: Short decision title

    Status: Proposed | Accepted | Rejected | Superseded
    Owners:
    Date:
    Supersedes:
    Affects:

    ## Context
    What verified problem or platform fact requires a decision?

    ## Constraints
    Which locked behaviors, privacy promises, and release requirements apply?

    ## Options
    Include the status quo and the smallest viable change.

    ## Decision
    State one unambiguous result.

    ## Consequences
    Product, UX, compatibility, accessibility, privacy, security, migration,
    testing, documentation, website, and operations effects.

    ## Evidence
    Links to spikes, tests, research, incidents, or user findings.

    ## Rollback or migration
    How can this decision be reversed safely?

    ## Follow-up
    Named tasks and gate.

Required approvers:

- product owner for user behavior or scope;
- platform owner for macOS integration;
- security/privacy owner for capture, storage, permissions, networking, or telemetry;
- release owner for signing, distribution, update, or remote deployment;
- brand owner and appropriate external advisor for name or cultural identity.

## 10. Risk-review protocol

At every roadmap gate:

1. confirm locked decisions still match all plan files;
2. close, split, or escalate open questions due at that gate;
3. update likelihood and impact from actual evidence;
4. link tests or research to mitigations;
5. add new risks discovered by incidents, platform betas, or competitor changes;
6. refuse release waivers for privacy exposure, silent insertion, data loss, or supply-chain compromise;
7. record accepted residual risk with owner and user-visible disclosure;
8. review market and Cloudflare facts against current official sources before public claims or remote operations.

An old risk register is not evidence that a risk is controlled.

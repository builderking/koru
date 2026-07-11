# Koru open-source governance

Status: proposed repository policy
Repository: builderking/koru
License decision: Apache License 2.0

## Decision

Koru will be a public, free and open-source project under the **Apache License 2.0**.

Apache-2.0 is a good fit because it:

- permits private, commercial, and open-source use, modification, and distribution;
- includes an explicit patent license from contributors;
- defines conditions for redistributed notices and modified files;
- is familiar to companies that may want to audit, package, or contribute to a local productivity tool;
- does not require derivative applications to adopt the same license.

The project's competitive advantage should come from product quality, community trust, and execution, not from restricting downstream use.

The authoritative texts are the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) and Apache's [guidance for applying the license](https://www.apache.org/legal/apply-license).

This plan is not legal advice. Before the first public binary, BuilderKing should confirm that it owns or has permission to publish every included source file, asset, font, fixture, name, and third-party dependency.

## Repository license implementation

The root of the repository should contain:

- **LICENSE** — the complete, unmodified Apache License 2.0 text;
- **NOTICE** — project identity and notices that must accompany distributions;
- **README.md** — a visible license summary linking to LICENSE;
- machine-readable package metadata using the identifier **Apache-2.0**;
- dependency attribution generated from the release dependency graph;
- an acknowledgements view or bundled acknowledgements file in distributed macOS builds when required by dependency licenses.

New source files may use the compact header:

    SPDX-License-Identifier: Apache-2.0
    Copyright 2026 BuilderKing and Koru contributors

Do not add a long boilerplate block to every file. Do not add headers to generated files, vendored sources, fixtures that must preserve exact bytes, or files whose upstream license requires its own header.

The NOTICE file is not a substitute for third-party license compliance. The release process must identify all bundled code and assets and preserve their required license and copyright notices.

## What the license does not grant

Apache-2.0 covers copyrighted project materials and its stated patent license. It does not automatically grant:

- rights to Apple trademarks, interface assets, or proprietary frameworks;
- rights to third-party names, screenshots, icons, fonts, sample content, or user data;
- ownership of the Koru name, logo, or domains;
- permission to imply endorsement by BuilderKing;
- guarantees, support, or fitness for a particular purpose.

A lightweight trademark and brand-use policy should be added before third parties distribute materially modified binaries under the Koru name. Until that review, repository documentation should ask downstream distributors to make modifications clear and avoid implying official endorsement.

## Governance model

Koru begins with a **maintainer-led, contribution-friendly** model.

### Roles

**Users**

- install and use releases;
- report bugs and request capabilities;
- participate in Discussions;
- do not receive repository permissions by default.

**Contributors**

- submit documentation, code, tests, designs, translations, or verified compatibility reports;
- follow the contribution and conduct policies;
- retain copyright in their contributions and license them under Apache-2.0 by submitting them.

**Triagers**

- reproduce issues, improve labels, close duplicates, and help route support questions;
- cannot merge protected branches unless separately assigned as maintainers.

**Maintainers**

- review and merge changes;
- manage releases and security response;
- make product-scope and architecture decisions;
- disclose conflicts of interest;
- may delegate ownership for defined paths or subsystems.

**Project lead**

- resolves decisions that do not reach maintainer consensus;
- appoints or removes maintainers based on sustained, trustworthy contribution;
- is accountable for release signing credentials and final security decisions.

The first GOVERNANCE.md should name the current project lead and maintainers rather than leaving authority implicit.

### Decision process

Use the smallest process appropriate to the consequence:

| Change | Process |
| --- | --- |
| Typo, test, small bug, compatibility fix | Pull request and maintainer review |
| New user-facing setting or contained behavior | Issue or Discussion with accepted behavior, then pull request |
| New permission, data collection, network access, storage migration, plugin API, or major dependency | Public RFC in Discussions and an architecture decision record |
| License, governance, data-use, release channel, or core product-scope change | Explicit maintainer decision recorded in GOVERNANCE.md or a decision log |
| Vulnerability | Private security process until coordinated disclosure |

Consensus is preferred but not mandatory. The responsible maintainer records the chosen option, rejected alternatives, and reason when a decision is consequential.

## Required community files

Before public contribution is invited, add:

- **README.md** — product promise, current status, supported macOS range, screenshots, installation, privacy model, build instructions, and honest limitations;
- **CONTRIBUTING.md** — setup, architecture orientation, tests, style, pull request flow, licensing, and accessibility expectations;
- **CODE_OF_CONDUCT.md** — a recognized community code with reporting contact;
- **GOVERNANCE.md** — roles, decision rights, maintainer changes, and conflict handling;
- **SECURITY.md** — supported release policy, private reporting route, response process, and safe-harbor language reviewed by counsel where needed;
- **SUPPORT.md** — questions and troubleshooting route, distinct from bug reports;
- **CHANGELOG.md** — user-visible changes organized by release;
- **docs/privacy.md** — exact capture, retention, exclusion, storage, deletion, export, and network behavior;
- **docs/architecture/** — architecture decisions, especially permissions, data storage, ranking, and update behavior.

GitHub documents how community health files can be stored in a repository's root, docs, or .github directory through its [community profile guidance](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions).

## Issues, Discussions, and support

Use each channel for a distinct job.

### GitHub Issues

Issues are for reproducible work:

- confirmed bugs;
- application compatibility failures;
- accessibility defects;
- scoped feature work accepted into the product direction;
- documentation corrections;
- build and release infrastructure problems.

Use GitHub issue forms so reporters provide structured evidence. GitHub's [issue and pull request template documentation](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/about-issue-and-pull-request-templates) is the implementation reference.

Recommended forms:

- **bug.yml** — Koru version, macOS version, application and version, activation method, expected and actual result, reproducibility, permission state, logs with a redaction warning, and screenshots;
- **compatibility.yml** — host application, input surface, caret anchoring, insertion, selection capture, rich content, and secure-field behavior;
- **feature.yml** — user problem, current workaround, affected workflow, privacy or permission implications, and proposed outcome;
- **config.yml** — links questions and ideas to Discussions, support to SUPPORT.md, and vulnerabilities to private reporting.

Do not accept vulnerability reports or private clipboard contents in public issues.

### GitHub Discussions

Discussions are for open-ended participation:

- **Announcements** — maintainer-written release and project news;
- **Q&A** — setup and usage questions;
- **Ideas** — problems and concepts not yet accepted as roadmap work;
- **Design and RFCs** — interaction, architecture, privacy, and API proposals;
- **Show and Tell** — useful workflows, templates, integrations, and community experiments.

GitHub's [Discussions quickstart](https://docs.github.com/en/discussions/quickstart) and [repository enablement guide](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/enabling-or-disabling-github-discussions-for-a-repository) are the operational references.

### Support

SUPPORT.md should make clear:

- GitHub Issues are not a private help desk;
- usage questions belong in Q&A;
- sensitive reports use the security channel;
- maintainers may close unsupported-version, duplicate, or unredacted-sensitive-data reports;
- response and resolution are best effort, without promised turnaround times.

## Labels and project hygiene

Use a compact, composable label set rather than dozens of near-duplicates.

### Type

- type: bug
- type: feature
- type: docs
- type: security
- type: refactor
- type: research

### Area

- area: activation
- area: caret
- area: capture
- area: clipboard
- area: saved
- area: quick
- area: search
- area: storage
- area: privacy
- area: onboarding
- area: website
- area: release

### Status

- status: needs-triage
- status: needs-reproduction
- status: needs-design
- status: needs-decision
- status: ready
- status: blocked

### Contributor

- good first issue
- help wanted

Avoid public “urgent” or numeric priority labels unless a maintainer has committed to a scheduling process. Severity is appropriate for security and data-loss impact; priority is a product decision.

Stale automation may comment on inactive issues but should not automatically close confirmed bugs, accessibility issues, security-adjacent reports, or accepted RFCs.

## Pull request convention

Every pull request should explain:

- the user problem or maintenance reason;
- the behavioral change and explicit non-goals;
- tests run and host applications checked;
- privacy, permissions, storage, migration, network, and accessibility effects;
- screenshots or a short recording for visible behavior;
- release-note impact;
- linked issue or decision record where applicable.

Rules:

- keep pull requests reviewable and single-purpose;
- add or update tests for behavior changes;
- do not include real clipboard data, credentials, signing material, or user databases;
- preserve compatibility evidence in a test matrix;
- update public documentation in the same change when user-visible behavior changes;
- generated lockfiles and project files are committed when they are part of reproducible builds;
- avoid drive-by dependency upgrades mixed with product behavior.

Human-readable pull request titles are required. Conventional Commits may be used but are not required for contribution. Release notes should not depend solely on commit-title syntax.

## Branch protection and ownership

Protect **main** with:

- pull requests required;
- at least one approving review;
- dismissal or renewal of approval after material new changes;
- required status checks;
- resolved review conversations;
- no force pushes;
- no branch deletion;
- administrator bypass limited and auditable;
- signed commits considered for maintainers and release commits, without blocking first-time contributors unless the team can support it reliably.

Use CODEOWNERS for paths with elevated consequences, such as:

- permissions and event capture;
- local persistence and migrations;
- update and release infrastructure;
- signing/notarization scripts;
- privacy and security documentation;
- GitHub workflows;
- the website deployment configuration.

CODEOWNERS does not replace active review. GitHub's [CODEOWNERS documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners) and [protected branch documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) are the references.

## Security reporting

Enable GitHub private vulnerability reporting and link to it from SECURITY.md. GitHub documents the capability in [Privately reporting a security vulnerability](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately) and [Configuring private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting).

The policy should:

- identify supported release lines;
- ask for affected version, impact, reproduction, and safe diagnostic evidence;
- warn reporters never to include real clipboard contents or credentials unless an encrypted channel is agreed;
- acknowledge the report without promising a public fix date;
- keep exploitation details private while risk remains;
- use a GitHub security advisory fork for coordinated fixes where appropriate;
- credit reporters who want attribution;
- publish a clear advisory and upgrade guidance when disclosure is safe;
- state that good-faith research is welcome within defined boundaries.

Security contacts and signing keys must be controlled by more than a single undocumented personal account. The specific private contact address remains an open operational decision.

## Dependency and supply-chain policy

Koru observes sensitive input and clipboard material, so dependency minimization is part of the product promise.

- prefer Apple frameworks and small, auditable libraries;
- document why each runtime dependency exists;
- pin reproducible versions through lockfiles;
- enable Dependabot or an equivalent scanner after ownership is assigned;
- require review for GitHub Actions permission changes;
- pin third-party GitHub Actions by immutable commit SHA, with a comment naming the release;
- use least-privilege workflow permissions;
- generate a software bill of materials and third-party notices for releases;
- run secret scanning and dependency review;
- prevent untrusted pull requests from accessing signing secrets;
- keep release signing and notarization separate from ordinary pull request checks.

## Release conventions

Use Semantic Versioning with a pre-1.0 contract:

- **0.y.z** — public alpha and beta behavior may change, but migrations and breaking changes must be documented;
- **1.0.0** — the first stable compatibility, storage, privacy, and update contract;
- patch releases fix compatible defects;
- minor releases add compatible behavior;
- major releases change stable contracts.

Git tags and GitHub Releases use the **vX.Y.Z** form. Mark non-stable releases as GitHub pre-releases.

Each release should contain:

- signed and notarized macOS artifact;
- checksum file;
- release notes grouped by user impact;
- supported macOS range;
- known compatibility limitations;
- privacy or permission changes called out prominently;
- upgrade and rollback notes for storage migrations;
- source archive provided by GitHub;
- third-party notices and SBOM;
- link to the exact tag and changelog.

GitHub explains the relationship between tags, release notes, and distributable assets in [About releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).

Release channels:

- **pre-release** for contributor and opt-in testing;
- **stable** for general use.

Nightly artifacts may be added later, but must not be represented as supported releases. Do not implement a silent update mechanism. The eventual update channel, signature verification, and rollback design require a dedicated security decision.

## Contributor certificate and CLA decision

Koru will not require a Contributor License Agreement at launch. A CLA adds legal and contribution friction that is not justified for the initial maintainer-led project.

Contributions are accepted under Apache-2.0 through the repository's contribution terms. A Developer Certificate of Origin sign-off is also not required initially. Revisit DCO enforcement if contribution volume, organizational policy, or provenance risk makes it useful. Any future change applies prospectively and must be documented before enforcement.

## Maintainer succession and project continuity

GOVERNANCE.md should define:

- how a contributor becomes a triager or maintainer;
- how inactive maintainers step down or become emeritus;
- how emergency access to release, signing, domain, and hosting systems is recovered;
- how the project lead role transfers;
- what happens if BuilderKing stops distributing official binaries;
- how archived or maintenance-only status is announced.

At least two trusted maintainers should eventually be able to recover repository administration and hosting, while signing credentials remain tightly controlled.

## Definition of “open-source ready”

The project is ready to invite public contribution only when all are true:

- LICENSE and NOTICE are correct;
- repository history contains no secrets or private user data;
- all assets and dependencies have documented provenance;
- build instructions work on a clean supported Mac;
- tests and required checks run on pull requests;
- privacy behavior and current permissions are documented;
- SECURITY.md and private vulnerability reporting are active;
- issue forms and Discussions routes are configured;
- named maintainers and decision rights are published;
- the app has an explicit alpha-quality warning if compatibility or data migration is not stable.

## Open governance questions

- Who is the initial project lead and who holds backup administrative access?
- Which private security contact and PGP or equivalent channel will be maintained?
- Is a separate brand/trademark policy needed before the first binary?
- Will official binaries be distributed only by BuilderKing or may community distributors use the Koru name?
- Which release-signing workflow will be used, and should a separately reviewed automatic-update framework be considered after V1?
- At what contribution scale, if any, should DCO sign-off become mandatory?
- Which paths require two approvals rather than one?

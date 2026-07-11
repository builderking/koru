# Koru build plan

This directory is the source of truth for taking Koru from product definition to a signed, public, open-source macOS release and a live marketing website.

## 1. Product decision

Koru will be a **private writing-memory layer for macOS**. It helps people capture text worth keeping, recall it from an imperfect fragment, and insert it beside the cursor without leaving the app where they are writing.

Koru is not positioned as a prompt manager. Prompts are an important use case, alongside commands, instructions, replies, code fragments, checklists, addresses, and templates. The permanent object is a **saved item**; its behavior can be **Saved text**, **Quick replacement**, or **Template**. Clipboard history is a separate temporary layer.

## 2. Locked product decisions

These decisions remain fixed unless an explicit decision record replaces them:

1. Koru is free and open source under Apache License 2.0.
2. The native app is local-first, useful without an account, and does not require cloud AI.
3. Automatic typed matching runs only after a qualifying fragment is typed at the beginning of a fresh, empty input session; focusing an empty field alone never opens Koru, and matching does not interrupt the middle of writing.
4. Matching never silently replaces text. The user must explicitly choose an item.
5. A remembered fragment such as `pus` can show multiple relevant saved items without requiring the exact original abbreviation.
6. Typing `clp` at the start of a fresh input opens the clipboard scope; a global hotkey remains available where macOS permits as a fallback.
7. Selecting all text may expose a very small save affordance where the target app supports it. A global shortcut and macOS Service provide fallback paths, subject to the host application's selection support.
8. Core product language is neutral. The interface does not require users to classify content as a prompt.
9. The quick interface is minimal, native, keyboard-first, compact, and low-copy. Detailed visual design is deliberately deferred to native prototypes.
10. Raw keystrokes are never persisted, secure fields are ignored, clipboard capture is opt-in, and sensitive apps can be excluded.
11. The first supported release is distributed directly as a signed and notarized macOS app. Mac App Store distribution is not a V1 requirement.
12. The marketing site is a static Astro site in `website/`, published from `main` through Cloudflare Pages with preview deployments for eligible same-repository pull requests; fork previews are not guaranteed.
13. V1 Clipboard history remains opt-in and defaults to 7 days, 500 logical events, 256 MiB total encrypted assets, and 25 MiB per retained image; files and videos remain references. D-001 is closed by `docs/architecture/adr-001-v1-clipboard-retention.md`.

## 3. Plan map

Read the files in this order:

| File | Purpose | Primary output |
|---|---|---|
| [01-product-vision-and-principles.md](01-product-vision-and-principles.md) | Product truth | Audience, jobs, principles, non-goals |
| [02-market-and-positioning.md](02-market-and-positioning.md) | Market truth | Competitive gap and positioning |
| [03-product-requirements.md](03-product-requirements.md) | Product contract | V1 requirements and acceptance criteria |
| [04-interaction-model-and-user-flows.md](04-interaction-model-and-user-flows.md) | Behavior contract | Recall, clipboard, capture, onboarding, fallback flows |
| [05-information-architecture-and-content-model.md](05-information-architecture-and-content-model.md) | Domain contract | Saved items, match terms, templates, clipboard entries, tags |
| [06-ux-design-system-and-accessibility.md](06-ux-design-system-and-accessibility.md) | Experience constraints | Minimal native direction and accessibility rules |
| [07-technical-architecture.md](07-technical-architecture.md) | System design | Native modules, storage, event flow, insertion strategy |
| [08-macos-integrations-and-permissions.md](08-macos-integrations-and-permissions.md) | Platform contract | Accessibility, input, clipboard, Services, permissions |
| [09-data-security-and-privacy.md](09-data-security-and-privacy.md) | Trust contract | Threat model, encryption, exclusions, retention |
| [10-testing-quality-and-release.md](10-testing-quality-and-release.md) | Quality contract | Test matrix, CI, signing, notarization, release gates |
| [11-open-source-governance.md](11-open-source-governance.md) | Community contract | License, contribution, issue, security, release governance |
| [12-marketing-website-and-brand.md](12-marketing-website-and-brand.md) | Public story | Landing-page structure, copy, SEO, assets, truth rules |
| [13-cloudflare-pages-publishing.md](13-cloudflare-pages-publishing.md) | Hosting runbook | Cloudflare MCP project creation, Git integration, verification |
| [14-delivery-roadmap.md](14-delivery-roadmap.md) | Gated sequence | Zero-to-100 implementation phases and exit criteria |
| [15-engineering-task-breakdown.md](15-engineering-task-breakdown.md) | Execution backlog | Epics, ordered tasks, dependencies, acceptance checks |
| [16-observability-support-and-operations.md](16-observability-support-and-operations.md) | Operating model | Diagnostics, support, privacy-safe telemetry, maintenance |
| [17-risks-decisions-and-open-questions.md](17-risks-decisions-and-open-questions.md) | Decision control | Risks, mitigations, ADRs, unresolved choices |
| [18-launch-plan-and-success-metrics.md](18-launch-plan-and-success-metrics.md) | Launch contract | Beta, release, adoption, retention, stop/reposition criteria |
| [19-definition-of-done.md](19-definition-of-done.md) | Final release gate | Complete product, site, documentation, and operations checklist |

## 4. Delivery gates

No phase is considered complete until its evidence is recorded in the repository.

### Gate A — problem and behavior

- The target user and primary jobs are validated.
- The fresh-input activation rule is unambiguous and testable.
- V1 scope and non-goals are approved.
- The terminology works for prompts and non-prompt content.

### Gate B — native feasibility

- A spike proves trigger detection, caret positioning, explicit insertion, clipboard capture, and selection capture across the required app matrix.
- Failures fall back to a hotkey, control-relative panel, or copy-only flow without data loss.
- Permission explanations and privacy behavior are understandable to test users.

### Gate C — trusted alpha

- The encrypted local vault, exclusions, retention, pause control, and clear-history behavior pass security review.
- The core save → recall → insert loop works without network access.
- No raw keystroke or saved-content data appears in logs, analytics, or crash reports.

### Gate D — private beta

- Compatibility, accessibility, performance, migration, update, and rollback tests pass.
- Beta users can grant permissions and complete the first insertion without help.
- Accidental invocation and insertion-failure thresholds meet the launch plan.

### Gate E — public release

- The app is signed, notarized, reproducibly built, and published with checksums and release notes.
- The public repository contains source, license, contribution, security, architecture, and privacy documentation.
- The landing page is live on Cloudflare Pages, points to verified downloads and source, and makes no unsupported claim.
- Support, vulnerability reporting, incident response, and rollback paths are active.

## 5. Working rules

1. Product behavior is specified before visual polish.
2. A native feasibility spike precedes broad feature implementation.
3. Privacy-sensitive behavior defaults to off or local-only.
4. Platform limitations are disclosed, not hidden behind a universal-compatibility claim.
5. Every epic has a user-visible acceptance criterion and a failure fallback.
6. The marketing site can describe only behavior proven in a tagged release.
7. Pull requests remain small enough to review and include tests or evidence.
8. Remote deployments and releases require an explicit release action even when CI is configured.

## 6. Repository target structure

```text
koru/
├── Koru.xcodeproj
├── Packages/
│   ├── KoruCore/
│   ├── KoruPlatform/
│   └── KoruUI/
├── Tests/
├── website/
├── docs/
├── build plan/
├── scripts/
├── .github/
├── README.md
├── CONTRIBUTING.md
├── SECURITY.md
└── LICENSE
```

The implementation may refine module names, but the separation between native app, reusable packages, website, operational scripts, and planning documentation should remain.

## 7. First implementation decision

The first code written after this plan is approved should be a disposable native feasibility harness—not the production app. It must measure actual behavior in Safari, Chrome, Codex/ChatGPT, Claude, Slack, Mail, Google Docs, Notion, VS Code, Xcode, Terminal, and native AppKit/SwiftUI text fields before architecture is frozen.

# Koru

Koru is a free and open-source macOS writing-memory utility: save useful text with one or more trigger tags, recall it where you write, and insert it without leaving the current field.

This repository contains a locally functional unsigned macOS 13+ menu-bar alpha, modular Swift packages, an encrypted persistent vault, clipboard and selection integrations, product surfaces, deterministic tests, a universal build, a static website, and an integration harness. It is not a signed or supported public release.

## Product promise

Koru should make reusable writing feel native to the cursor:

- Type a complete assigned tag of 3–64 characters anywhere in text. It must end at the caret and start at the beginning or after a non-letter/non-number; then choose the matching saved item.
- Type `clp` with the same left-boundary rule anywhere in text to recall recent clipboard content.
- Select valuable text and save it for reuse without leaving the current app.
- Keep writing and clipboard content private, local, understandable, and under the user's control.

Koru never replaces text merely because a tag matched: insertion requires explicit selection. It prefers direct Accessibility replacement, then uses a verified keyboard replacement fallback where the host does not expose writable text through Accessibility.

Koru is not an AI assistant, prompt marketplace, automation platform, or cloud account. Prompts are one important use case, but the product works with any reusable text, command, response, or instruction.

## Build plan

The complete zero-to-release plan is in [`build plan/00-index.md`](build%20plan/00-index.md).

Repository-local CI, release, governance, diagnostics, security, support, and operations scaffolding is present. It is deliberately fail-closed where a real app, credentials, protected GitHub settings, or a Cloudflare project is required. Start with [Architecture](docs/architecture.md), [Privacy](docs/privacy.md), [Threat model](docs/security/threat-model.md), [Diagnostics](docs/diagnostics.md), and [manual gates](docs/operations/manual-gates.md).

Validate the current repository with:

```sh
./scripts/validate-repository.sh
```

## Project status

- Product definition: complete; human approval remains a release gate
- Feasibility: disposable native harness implemented; external application matrix still requires manual execution
- Native app: locally buildable alpha; external TCC, compatibility, accessibility, and signed-release qualification remains
- Marketing website: implemented and locally verified
- Cloudflare Pages project: not created
- Public release: not started

## Open source

Koru is licensed under the Apache License 2.0. See [LICENSE](LICENSE), [CONTRIBUTING.md](CONTRIBUTING.md), [GOVERNANCE.md](GOVERNANCE.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), [SUPPORT.md](SUPPORT.md), and [SECURITY.md](SECURITY.md).

## Build locally

Koru requires Xcode with the macOS SDK. Signing credentials are not required for contributor builds.

```sh
./scripts/bootstrap
./scripts/check
swift run Koru
swift run KoruIntegrationHarness
```

See [docs/native-foundation.md](docs/native-foundation.md) for scope and locked safety boundaries.

## Repository

Copyright BuilderKing contributors.

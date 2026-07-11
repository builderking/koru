# Koru

Koru is a free and open-source macOS writing-memory utility: save useful text where you write it, recall it from a fragment you remember, and insert it without leaving the current field.

This repository is currently in the product-definition and engineering-planning stage. No production application or website has been implemented yet.

## Product promise

Koru should make reusable writing feel native to the cursor:

- Type a qualifying fragment at the beginning of a fresh, empty input and choose a matching saved item.
- Type `clp` at the beginning of a fresh, empty input to recall recent clipboard content.
- Select valuable text and save it for reuse without leaving the current app.
- Keep writing and clipboard content private, local, understandable, and under the user's control.

Koru is not an AI assistant, prompt marketplace, automation platform, or cloud account. Prompts are one important use case, but the product works with any reusable text, command, response, instruction, or template.

## Build plan

The complete zero-to-release plan is in [`build plan/00-index.md`](build%20plan/00-index.md).

Repository-local CI, release, governance, diagnostics, security, support, and operations scaffolding is present. It is deliberately fail-closed where a real app, credentials, protected GitHub settings, or a Cloudflare project is required. Start with [Architecture](docs/architecture.md), [Privacy](docs/privacy.md), [Threat model](docs/security/threat-model.md), [Diagnostics](docs/diagnostics.md), and [manual gates](docs/operations/manual-gates.md).

Validate the current repository with:

```sh
./scripts/validate-repository.sh
```

## Project status

- Product definition: in progress
- Feasibility: researched; implementation spike not started
- Native app: not started
- Marketing website: not started
- Cloudflare Pages project: not created
- Public release: not started

## Open source

Koru is licensed under the Apache License 2.0. See [LICENSE](LICENSE), [CONTRIBUTING.md](CONTRIBUTING.md), [GOVERNANCE.md](GOVERNANCE.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md), [SUPPORT.md](SUPPORT.md), and [SECURITY.md](SECURITY.md).

## Repository

Copyright BuilderKing contributors.

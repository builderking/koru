# Contributing to Koru

Koru is an early alpha open-source project. Contributions are welcome, and the build plan remains the source of truth.

## Before contributing

1. Read [`build plan/00-index.md`](build%20plan/00-index.md).
2. Check the locked decisions and non-goals before proposing a new feature.
3. Search existing issues and discussions before opening a duplicate.
4. Keep proposals focused on a user problem and a testable outcome.

## Contribution flow

1. Open an issue for substantial product, security, privacy, or architecture changes.
2. Fork the repository and create a focused branch.
3. Add or update tests with implementation changes.
4. Keep commits small and explain behavior changes in the pull request.
5. Confirm that no private clipboard content, prompts, credentials, logs, or signing material are included.
6. Run `./scripts/validate-repository.sh` and complete the pull-request trust review.

Fork pull requests build without release credentials. Never ask a maintainer to expose signing, notarization, deployment, or environment secrets to a fork. Release candidate and publication workflows are manual, protected, and separate from pull-request CI.

New runtime dependencies require an allowlist update and review of license, maintenance, security, privacy, network behavior, and release impact. Commit `Package.resolved` once Swift dependencies exist. Swift code is expected to pass strict concurrency, formatting, lint, unsigned build, and tests.

## Local verification

Run `./scripts/bootstrap` once to regenerate the Xcode project, then run `./scripts/check` before submitting changes. The check builds the Swift package, runs deterministic tests, and builds the unsigned Koru and integration-harness app targets. Contributor builds require macOS 13+ and Xcode, but never release signing credentials.

## Product constraints

Contributions must preserve these principles:

- local-first and useful without an account;
- no persisted raw keystroke stream;
- no automatic text replacement without an explicit user action;
- no behavior in secure text fields;
- minimal, native, keyboard-first interaction;
- accessible behavior and transparent fallbacks when a target app is incompatible;
- no cloud AI dependency in the core product.

## Licensing

By submitting a contribution, you agree that it is licensed under the repository's Apache License 2.0.

See [Architecture](docs/architecture.md), [Privacy](docs/privacy.md), [Compatibility](docs/compatibility.md), and the [executable threat model](docs/security/threat-model.md) for implementation contracts.

## Community conduct

Be respectful, specific, and constructive. Product disagreement is expected; personal attacks, harassment, and disclosure of another person's private data are not accepted.

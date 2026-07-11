# Contributing to Koru

Koru is currently a planning-stage open-source project. Contributions are welcome, but the build plan is the source of truth until the first implementation milestone is approved.

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

## Community conduct

Be respectful, specific, and constructive. Product disagreement is expected; personal attacks, harassment, and disclosure of another person's private data are not accepted.

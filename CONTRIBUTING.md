# Contributing to @hmkit/form

Thanks for contributing. Please start with a concrete HarmonyOS form use case and keep 0.1.x changes backward compatible.

## Before opening a change

- Search existing issues and read `API.md`, `API-FREEZE.md` and `COMPATIBILITY.md`.
- Use an issue to discuss new public APIs or behavior that affects multiple consumers.
- Never include credentials, production data, signing files or proprietary form schemas.

## Local setup

Requirements are DevEco Studio with HarmonyOS SDK API 12 or later and the bundled OHPM/Hvigor tools.

```bash
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install
./scripts/test-local.sh
./scripts/build-release.sh
./scripts/scan-har.sh
./scripts/check-api-freeze.sh
./scripts/verify-registry-consumer.sh
```

For UI changes, run the relevant Demo and Showcase flows on an emulator or device. `HMKIT_RUN_SIMULATOR=1 ./scripts/release-dry-run.sh` executes the complete release gate when a Pura 90 emulator is connected.

## Compatibility rules

- 0.1.x accepts fixes and compatible additions only.
- Do not update `api/0.1.0-declarations.sha256` merely to make CI green. Review the generated declaration diff and compatibility impact first.
- Keep `@hmkit/validator` as a registry dependency; publishable packages must not contain `file:` dependencies.
- Update tests, `API.md` and `CHANGELOG.md` with user-visible behavior.

## Pull requests

Keep changes focused, explain the real project need, and include exact validation evidence. Public pull requests run only static checks; a maintainer runs the trusted Harmony build on a self-hosted Mac after review.

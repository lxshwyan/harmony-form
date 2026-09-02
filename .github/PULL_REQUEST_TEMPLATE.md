## What changed

Describe the user-visible behavior and the project use case.

## Validation

- [ ] `./scripts/check-public-metadata.sh`
- [ ] `./scripts/test-local.sh`
- [ ] `./scripts/build-release.sh && ./scripts/scan-har.sh`
- [ ] `./scripts/check-api-freeze.sh`
- [ ] Relevant Demo or Showcase flow verified when UI behavior changed

## Compatibility and safety

- [ ] The change is backward compatible with the frozen 0.1.x public API, or the proposal explicitly targets a later minor version.
- [ ] Public API and behavior changes are documented in `API.md` and `CHANGELOG.md`.
- [ ] No generated build output, local dependency, credential or private business data is included.

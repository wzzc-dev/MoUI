# Compatibility And Ecosystem Policy

MoUI publishes the machine-readable source of truth in
[`checks/compatibility-policy.json`](../checks/compatibility-policy.json) and
[`checks/component-quality.json`](../checks/component-quality.json). This page
explains how package consumers should use it.

## Versioning

MoUI uses SemVer for published modules. Patch releases contain fixes and docs;
minor releases add backward-compatible app APIs; major releases may change
public APIs, package boundaries, or host wire contracts. During the `0.x` line,
a minor release can still contain a breaking change, but it must ship an
upgrade note and a migration example in the same release.

## Deprecation

An API deprecation records its replacement, the release where the notice began,
the planned removal release, and a migration description. The default notice is
at least two releases and six months. Security or legal removals may shorten the
window only with an ADR and a release note explaining the impact.

## Quality Levels

`stable` means focused tests, documentation, and a maintained consumer/example
exist. `preview` means the API is public but host coverage or behavior remains
incomplete. `experimental` is diagnostic or platform-specific and carries no
product-readiness commitment. Evidence paths are validated by
`node scripts/validate-ecosystem-metadata.mjs`.

## Consumer Gate

Every package change should be checked from outside the repository with:

```sh
node scripts/validate-ecosystem-metadata.mjs
node scripts/external-consumer-ci.mjs --source package --profile base
```

The gate resolves a staged package closure, rejects monorepo source paths,
checks the dependency closure, and compiles/tests an external consumer. CI runs
the gate across the base, Skia, and Web profiles where the source is available.
Use the extension templates in [`docs/templates.md`](templates.md) for new
controls and host services.

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

A patch release that needs a public symbol, package boundary, host wire
contract, or app-import change is out of scope. Move the change to the next
minor; no patch exception ledger is maintained.

## 0.8.x Line

The current synchronized line is `0.8.x`. `0.8.0` ("Markdown input surface")
advances every public module together and publishes the WYSIWYG markdown input
path the first-party apps had duplicated: block and selection targets, edit
history with selection snapshots, the opt-in wiki-link surface, and the editor
chrome (context menu, format bubble) in `moui_richtext` and `moui_markdown`.
Every new parameter carries a default and no existing symbol, package
boundary, or host wire contract changes, so the release adds public symbols
only. The pre-1 policy is unchanged: a 0.x minor may break with an upgrade
note and migration example, and the external consumer gate still runs.
`checks/compatibility-policy.json` `currentReleaseLine` is the machine-readable
source of truth; the docs, module manifests, and
`docs/compatibility-matrix.md` must agree with it.

## 0.7.x Line

`0.7.x` is closed: `0.7.0` advanced every public module together, and `0.7.1`
(font candidates), `0.7.2` (asset download), `0.7.3` (macOS dev hot-reload)
were patches with no public API, package boundary, or wire-contract change.

## 0.4.0 Architecture Program

`0.4.0` is a declared breaking architecture program on the normal `0.x` minor
path: the pre-1 policy permits breaking changes when the release ships an
upgrade note and migration examples. No SemVer exception is recorded for this
program. The release still moves the synchronized line and every public module
to `0.4.x` together, and it still passes the external consumer gate. The
synchronized-line policy (ADR 0065) continued on the `0.5.x` line, then the
`0.6.x` line, the `0.7.x` line, and now the `0.8.x` line: each minor advances
every public module together with the features recorded in
`docs/releases/0.5.0.md`, `docs/releases/0.6.0.md`, `docs/releases/0.7.0.md`,
and `docs/releases/0.8.0.md`.

The program does not keep a compatibility layer. Moved public symbols are
removed from their old package in the same release; in-tree call sites and the
external consumer fixture move with them.

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

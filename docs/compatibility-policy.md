# Compatibility And Ecosystem Policy

MoUI publishes the machine-readable source of truth in
[`checks/compatibility-policy.json`](../checks/compatibility-policy.json) and
[`checks/component-quality.json`](../checks/component-quality.json). This page
explains how package consumers should use it.

## Versioning

MoUI uses SemVer for published modules, in two stages. From `1.0.0` on, patch
releases contain fixes and docs only, minor releases add backward-compatible
app APIs, and major releases may change public APIs, package boundaries, or
host wire contracts. Before `1.0.0` — the current `0.x` line — the rules are
looser: a release may change public APIs, breaking ones included, as long as
that same release ships an upgrade note with a migration example. The
allowance covers patches as well as minors while the line is pre-1.0.

A breaking change needs no separate exception ledger: the upgrade note is the
ledger. `checks/compatibility-policy.json` records the two-stage reading in
`versioning.patch` and `versioning.pre1Policy`, and `1.0.0` restores the strict
post-1.0 rules.

## 0.9.x Line

The current synchronized line is `0.9.x`. `0.9.0` ("Navigation surface")
advanced every public module together with the keyboard and pointer surface a
workbench shell needs: tree navigation targets, the tab strip, command-menu
navigation and type-ahead, a keyboard-only focus ring, and a compact find bar.
Every new parameter carried a default, no enum gained a variant, and nothing
existing changed.

`0.9.1` uses the line-level pre-1.0 allowance above for the first time: it is a
patch that adds public API — the `SemanticsRole` variants `TabList`,
`Toolbar`, and `MenuItem`, `inline_edit`, generic drag and drop, focused-text
selection (`select_focused_text_all`, `place_focused_text_caret`,
`set_focused_text_selection`), and the Linux view-level context-menu fallback.
No package boundary and no host wire contract changes, and the release ships
its own `0.9.1` release note with the upgrade note and migration examples the
policy requires.

`checks/compatibility-policy.json` `currentReleaseLine` is the machine-readable
source of truth; the docs, module manifests, and `docs/compatibility-matrix.md`
must agree with it.

## 0.8.x Line

`0.8.x` is closed: `0.8.0` ("Markdown input surface") advanced every public
module together and published the WYSIWYG markdown input path the first-party
apps had duplicated — block and selection targets, edit history with selection
snapshots, opt-in wiki links, and editor chrome — with defaults throughout.

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
`0.6.x` line, the `0.7.x` line, the `0.8.x` line, and now the `0.9.x` line:
each minor advances every public module together with the features recorded in
`docs/releases/0.5.0.md`, `docs/releases/0.6.0.md`, `docs/releases/0.7.md`,
`docs/releases/0.8.0.md`, and `docs/releases/0.9.0.md`.

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

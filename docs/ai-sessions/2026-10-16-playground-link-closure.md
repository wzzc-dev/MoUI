# 2026-10-16 — Playground in-browser link closure fix

- Workspace: MoUI, `main`.
- Trigger: user report "playground 构建报错" — the Playground editor showed
  `Core link failed (5 packages): 0,248,Assert_failure,-11,0,lib/xml/mir/monofy_analyze.ml,51,6`
  for the default hello example.

## Summary

The toolchain upgrade that moved the workspace package graph to
`_build/<target>/<cfg>/build/all_pkgs.json` (commit `2e585cc7b`) silently
changed its shape: entries now carry only `root/rel/artifact` and no `deps`.
`generate-playground-assets.mjs` read `pkg.deps || []`, so the compiler
manifest shipped every package with an empty dependency list. In the browser,
`reachablePackageIds` walked those empty edges and handed `linkCore` only the
five roots (user `moui`/`views` imports + runtime + backend/web + web
renderer); the missing cores made moonc panic inside `monofy_analyze.ml`
instead of failing cleanly.

Fixed by deriving the dependency edges from the compiler's own plan: the
generator runs `moon build <path> --target wasm-gc --release --strip --dry-run
-v` for every required package and parses each printed `moonc build-package`
line's `-i <build-dir>/<id>/<stem>.mi:<alias>` arguments (stdlib `$MOON_HOME`
entries skipped). Manifest schema bumped to v2; the worker now refuses stale
v1 manifests with a clear "redeploy" diagnostic and errors when a package
lacks `deps`; `test-playground-assets.mjs` validates closure completeness.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `scripts/generate-playground-assets.mjs` | `releaseDependencyEdges()` via dry-run parsing; closure built from parsed edges; `schemaVersion: 2` | Graph file lost deps; empty edges collapsed the link closure to the roots |
| `website/playground/host/compiler-worker.js` | Manifest schema check; missing-deps error in `reachablePackageIds` | Stale assets must surface as readable diagnostics, not moonc panics |
| `scripts/test-playground-assets.mjs` | Assert v2 schema, edge completeness, non-empty runtime deps, transitive closure membership | Packaging-time regression guard |
| `memories/repo/playground-compiler-assets.md` | Durable facts | See Promote |

## Discoveries

- `moon build --dry-run -v` prints the planned `moonc build-package` command
  for every closure package **including cache-fresh ones**, with each direct
  import as `-i path.mi:alias`. It is the only machine-readable per-package
  dependency source in the current toolchain (no `generate-makefile` subcommand,
  no `pkg.info` artifacts, `.mi` files are binary MINTF).
- Registry packages (e.g. `wzzc-dev/window`, `Milky2018/css`) build under the
  same `_build/...` tree, so the `-i` path → id mapping is uniform for local,
  path, and registry deps.
- moonc `linkCore` with a too-small core set aborts via OCaml
  `Assert_failure` in `monofy_analyze.ml` rather than a `Key_not_found` —
  treat any such panic as an input-set problem first.

## Validation

```sh
node scripts/generate-playground-assets.mjs --out dist/playground   # ok, 60 packages in manifest
node scripts/test-playground-assets.mjs --root dist/playground      # ok
# offline replay of the worker compile(): buildPackage user + runner,
# walk closure (56 reachable), linkCore → wasm 458869 bytes, no panic
node scripts/validate-maintenance-baseline.mjs && \
node scripts/validate-api-surface.mjs && \
node scripts/validate-release-module-closures.mjs && \
node scripts/validate-guidance-consistency.mjs && \
node scripts/validate-renderer-capability-consistency.mjs && \
node scripts/validate-doc-references.mjs
```

## Follow-Up

- [ ] The deployed GitHub Pages playground still ships the v1 manifest until
  this lands and `pages.yml` rebuilds assets; workers hitting it keep the
  panic until then (a v1 manifest from the *new* worker errors cleanly).
- [ ] Upstream moonc: `linkCore` should raise a diagnosable error (missing
  package core) instead of an OCaml `Assert_failure` — worth a bug report.

## Promote

- [x] Durable facts → `memories/repo/playground-compiler-assets.md`
- [ ] No ADR needed (tooling fix, no contract change)
- [x] Stale guidance checked: `docs/testing.md` / playground docs do not
  describe the manifest schema version, nothing to correct.

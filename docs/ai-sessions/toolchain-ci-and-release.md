# Toolchain, CI and release (2026-06 → 2026-11)

Durable summary of the toolchain upgrades, the feature-proof CI system and the
release arcs. Canonical: `docs/development.md`, `docs/testing.md`,
`docs/feature-proof-matrix.md`, `docs/release-readiness.md`.

## 2026-06-29 — CI feature proof system

- Three-layer proof: L1 package tests on every PR; L2 real-Skia platform smoke
  (paths-filtered on `moui_skia/**`); `feature-proof-summary.yml` aggregates job
  statuses after `ci.yml` via `workflow_run`.
- `workflow_run` only fires from the default branch; PR-only workflows must be
  verified after merge. `paths` filters apply to the PR head, so workflow files
  themselves must be included.
- When `moui_skia` is unchanged, L2 features are `skipped`, not `gap`
  (`skiaSmokeTriggered`). Prebuilt Skia provider avoids a 90-min source build.
- Node helpers: `generate-feature-proof-report.mjs`, `verify-feature-proof-coverage.mjs`.

## 2026-07-14 — MoonBit 0.10.4

- Pin `moonc v0.10.4+ade96c819` (`.moonbit-toolchain`). Fixed empty-brace
  ambiguity (`Map([])`, `Json::empty_object()`, `{ () }`), multi-window `Size`
  typing, and vendored `third_party/mizchi_image` (0.4.2 needs a `Debug` patch for
  the new `assert_eq : Eq + Debug` requirement).
- Warnings stayed non-fatal for pre-existing unused imports / Show→Debug migration.

## 2026-10-16 — playground link closure

- Toolchain change `2e585cc7b` reshaped `_build/<target>/<cfg>/build/all_pkgs.json`
  (no `deps` field), so the playground manifest shipped empty dependency edges and
  `linkCore` panicked inside `monofy_analyze.ml` instead of failing cleanly.
- Fix: derive edges from `moon build <path> --target wasm-gc --release --strip
  --dry-run -v`, parsing each `moonc build-package` line's
  `-i <build-dir>/<id>/<stem>.mi:<alias>` arguments (stdlib skipped). Manifest
  schema v2; worker rejects stale v1 with a readable "redeploy" diagnostic.
- Lesson: a `linkCore` panic with a too-small core set is an input-set problem, not
  a compiler bug; `--dry-run -v` is the only machine-readable per-package dep source
  in this toolchain.

## 2026-11-06 — MoonBit 0.10.20 / release 0.3.2

Outcome: workspace and Studio on `moonc 0.10.20+65efd5b93`, 0 warnings / 0 errors;
25 public modules and Studio 0.1.5 published.

- 1,244 first-party derive sites became `#derive(...)`; `generate_core_derives`
  stages the attribute before binding and rejects the deprecated suffix syntax.
- `to_json().stringify()` → `Json(value).stringify()`; JSON interfaces name
  `@json.Json`. Boolean `inspect` assertions use `assert_true`/`debug_inspect`;
  `not(expr)` → `!expr`; test roots carry explicit `View[Unit]` types;
  `String::offset_of_nth_char` uses `start=`/`end=`.
- Not adopted (no beneficiary): `reb"..."` byte regex, top-level `declare let`,
  `Float::total_compare`. Keep `Int` in generated ABI strings where it is an alias;
  new FFI/wire code uses explicit `Int32`/`UInt32`.
- Release evidence: `wzzc-dev/MoUI#10`, `wzzc-dev/moui_studio#1`.

## 2026-10-25 — governance tax: studio budgets out of the main repo

- Failure mode: the maintenance baseline measured `moui_studio`, which is a gitlink
  (`160000 commit ef2a56f12` since `80317ec80`); the local directory is tracked by
  no git here, so CI was green while every local maintainer saw a red gate whose fix
  lived in another repository. Lesson: when a gate fails where you cannot fix it,
  first check whether it measures content git here does not own.
- `checks/source-file-policy.json` ratchets: removed the shrink-failure branch;
  ceilings are now quanta (`budgetStepLines = 25`, rounded up, 612 lines of
  headroom). The modulo rule is load-bearing — otherwise the registry re-pins itself
  to measured values. A new `.mbt` file over `hardLimitLines` (1200) still needs
  human classification.
- Two JS validators documented as "every commit" but absent from
  `checks/profiles.json` were green by hand and wired into `pr`; a "runtime-neutrality
  validator" citation was a rename, not a missing gate.

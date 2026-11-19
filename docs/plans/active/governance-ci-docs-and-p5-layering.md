# Plan: Governance self-tests, CI wall-clock, documentation budget, and p5 layering

- **Status**: active
- **Goal**: Pay down four debts that compound each other, without changing runtime
  behaviour: the validators that gate the repository are mostly untested, CI spends
  most of a pull request on jobs whose signal does not change per review, `docs/`
  grew to 58,459 lines with no ceiling, and the p5 creative-coding slice lives in
  `examples/p5_sketch/p5` while p5-shaped types leak into `moui/core`.
- **Non-goals**: no runtime or renderer behaviour change; no new platform route; no
  package split of `moui/core`; no public API break in this plan (the
  `KeyboardEvent.code` -> `PhysicalKey` break stays with
  [architecture-review-followups](architecture-review-followups.md)); no rewrite of
  pages the diet did not retire.

## Workstreams

### 1. Governance self-tests

- `tools/moui` has 44 packages; 30 had no `*_wbtest.mbt`. Every package gets a
  3-6 assertion whitebox suite over its decision logic (threshold arithmetic,
  path/scope matching, deterministic ordering, failure-message construction).
- Ratchet: `checks/tool-test-coverage.json` + `tools/moui/validate_tool_test_coverage`
  fails when any tool package has no test file (`maxUntestedPackages: 0`), wired into
  the `pr-static` profile and the pre-push list.
- The per-package `moon test tools/moui/<tool>` steps in `pr-static` collapse into one
  `moon -C tools test --target native`, so a new suite cannot exist unexecuted.

### 2. CI wall-clock

Measured at run 44267566443: Linux platform 75s, PR profile 272s (macOS), macOS
packaging 95s, workspace baseline 561s, Windows MSVC 208s, API surface 135s, agent
smoke 88s, benchmark 421s.

- `checks/profiles.json` splits `pr` into composite `pr-static` (host-independent
  validators, tool tests, format) + `pr-native` (workspace check, interface drift,
  package matrix, Web builds). Local `--profile pr` still runs both halves in order.
- `ci.yml`: `pr-static` on ubuntu-24.04; `pr-profile` on macOS reuses one `_build`
  for the native half plus the 316-package sweep (three compile graphs -> one).
  Every job carries an explicit `timeout-minutes`.
- Landing-only jobs: `macos-packaging` and `benchmark-scaffold` are push/dispatch
  only. A docs-only change skips the compile jobs; `pr-static` still runs.
- `dev` gets the same push/pull-request gates as `main`.
- `feature-proof-summary` follows the rename: `pr-static` owns the API-surface row,
  and by-design skips (push-only jobs on a PR, compile jobs on a docs-only change)
  reach the generator as `--event`/`--docs-only` instead of counting as gaps.

### 3. Documentation budget

- Baseline measured at `cef78422`: 58,459 lines across 347 tracked `docs/**/*.md`.
- `checks/doc-budget.json` + `tools/moui/validate_doc_budget` count only `docs/`
  (the generated website mirror and `memories/repo` stay outside), gate in
  `pr-static`, and AGENTS.md lists the command pre-push.
- Diet in this order: retire `docs/ai-sessions/**` into six themed summaries; replace
  `docs/plans/done/*` bodies with one row per plan in `done/INDEX.md`; shrink the
  zh-Hans mirror to the published catalog set (option B: parity over the published
  get-started/guides/examples pages, English-only pages listed as `excluded`).
- Ceiling ratchets from 58,459 to 40,000.

### 4. p5 layering

- `examples/p5_sketch/p5` becomes the `moui_p5` addon: `moui_p5/moon.mod` shaped like
  `moui_markdown`, registered in `moon.work`, `checks/release-modules.json`,
  `checks/portfolio-governance.json`, `checks/source-file-policy.json`, and the
  maintenance-baseline scan scope; the demo depends on the addon.
- No `moonbitlang/x/fs` in the addon: file IO goes through injected source/sink ports
  (`FilePorts`); PNG decode/encode stay in the addon, and the framework keeps a
  neutral RGBA buffer + public encode entry instead of p5 types.
- p5-shaped names (`PixelFrame`, `RgbaImage`) stop being framework API once the
  neutral buffer covers them.

## Acceptance

- [x] `node scripts/validate-tool-test-coverage.mjs` green with ceiling 0, and
      `moon -C tools test --target native` green.
- [x] Full pre-push static list green; `sh scripts/check.sh --profile pr` green.
- [x] `ci.yml` has dev triggers, per-job timeouts, one compile graph per PR, and
      push-only packaging/benchmark; feature-proof summary maps the new job ids.
- [x] `node scripts/validate-doc-budget.mjs` green with `maxLines: 40000` and the
      diet's line counts reported per directory.
- [x] `moui_p5` registered in all five places, `moon check moui_p5` and
      `moon test moui_p5 --target native` green, no `@fs` in the addon.
- [ ] Windows evidence build runs without `MOON_CC=clang-cl.exe` after the Skia C++
      stub moves out of the `mbt` compile (prebuilt Release asset + `build.mbtx`),
      with `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` as the escape hatch.

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-19 | Skia D8016: take option 1 (prebuilt C++ stub in the existing `wzzc-dev/skia` Release, `build.js` -> `build.mbtx` in the same change, move the stub back in-tree when the official `stub-cxx-flags` split lands); options 2 and 3 rejected as moon-side or flag-replica maintenance. |
| 2026-11-19 | zh-Hans: option B (published catalog set only) over deleting the locale entirely or English fallback; the website reader requires a per-locale catalog entry, so a fallback path would need new front-end code. |
| 2026-11-19 | PR gate split across runners: `pr-static` on ubuntu, `pr-native` + sweep on macOS; landing-only packaging and benchmark jobs leave the PR path. |
| 2026-11-19 | Prebuilt stub stays best-effort in `auto`: the provider fetch falls back to the in-tree `native/*.cpp` compile when the release asset is absent (publishing the stub zip remains an optimization), `prebuilt` still hard-fails, and `build` skips the stub download entirely. |\n| 2026-11-19 | Windows CI pins its vcpkg `builtin-baseline` in the generated manifest instead of resolving the latest registry revision; the window-package half of `validate-window-lifecycle-boundary` prints a skip note when the optional `window` submodule is absent (ubuntu PR-static). |

## Progress

| Date | Note |
|------|------|
| 2026-11-19 | Profile split + doc-budget + tool-test-coverage gates landed locally; docs diet 58,459 -> 38,669 lines (347 -> 217 files); `moui_p5` addon extracted and registered; feature-proof summary accepts by-design skips. |
| 2026-11-19 | `moui_p5` extracted (41 root + 15 adapter + 2 loader tests) and added to `pr-native`; framework give/take in flight with the keyboard/`PathSpec` items explicitly deferred to architecture-review-followups. |
| 2026-11-19 | Skia D8016 option 1 landed locally: `build.js` -> `build.mbtx` in `moui_skia`/`moui_skia_renderer`, C++ stub compiled by the prebuild (`/std:c++20`), `native/moon.pkg` carries only `${build.MOUI_SKIA_CC_LINK_FLAGS}`, the platform evidence scripts export the provider environment instead of patching packages, and Windows CI no longer needs `MOON_CC=clang-cl.exe`; remote Windows evidence run still pending. Manual smoke runners tracked in [skia-manual-smoke-prebuild-migration](../debt/skia-manual-smoke-prebuild-migration.md). |
| 2026-11-19 | Docs re-measured at 38,799 lines / 218 files (ceiling 40,000) after the p5 move and generated-doc refresh; all nine pre-push static guards green. |
| 2026-11-19 | Local gate sweep: nine pre-push static guards green, `sh scripts/check.sh --profile pr` green, `sh scripts/check.sh --profile daily` green after two Node-18 compatibility fixes (`moui_web_renderer`/`moui/backend/web` declare `"type": "module"` for their ESM `.js`; Skia-dependent p5 raster and renderer font tests skip under the plain stub), and `moon -C tools test` 314/314. Windows evidence still needs the pushed CI run. |
| 2026-11-19 | First pushed CI run exposed three host assumptions: the unpublished macOS stub asset 404 broke every Skia prebuild job, ubuntu PR-static has no `window` submodule, and vcpkg's moving baseline switched zlib to 1.4. All three are handled in-tree now (local compile fallback, printed skip, pinned baseline); rerun pending. |
| 2026-11-19 | Daily rerun green end-to-end: `parse_table` self-test in `tools_product/moui/validate_renderer_capability_consistency` now fixtures the current 8-column capability table (Terminal cell ANSI + Native direct GPU) instead of the retired 6-column shape; docs refreshed at 38,859 lines / 219 files, portfolio governance and doc-budget guards green. |

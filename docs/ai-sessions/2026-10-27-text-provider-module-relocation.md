# 2026-10-27: L0.5 — move the text providers out of the wgpu module

- **Agent**: Qoder Desktop agent (main session, MoonBit-native work)
- **Goal**: The user's directive after ADR 0044 reopened the Metal-direct route:
  "把文本 provider 从 wgpu 模块搬出，然后实现 moui_metal_renderer". This session is
  the first half. The blocker was structural, not technical: P14
  (`docs/invariants.md:30`) forbids a `role: "renderer"` module from importing
  another renderer module, so while `coretext` sat inside `moui_wgpu_renderer` no
  `moui_metal_renderer` could reuse it — however clean the provider's own imports
  were after L0.2.
- **Outcome**: Delivered. `wzzc-dev/moui_text_providers` is a new published module
  holding the five packages; no renderer code was written, so L1 is still ahead.

## Summary

`git mv` of `coretext` / `cosmic_text` / `directwrite` / `fontconfig` /
`text_protocol` into `moui_text_providers/`, with the `build.js` prebuild hook, the
`--moonbit-unstable-prebuild` option and the `Milky2018/moon_cosmic` / `moon_swash`
pins travelling with them. `moui_wgpu_renderer` is now a renderer-only module: it no
longer owns a platform text link config and has no prebuild hook at all. Seven
consumer packages were repointed (import paths plus the `@wgpu_*` → `@text_*`
aliases), and the module was registered in every gate that enumerates modules.

## Changes Made

| File | What Changed | Why |
|---|---|---|
| `moui_text_providers/{moon.mod,build.js,README.mbt.md,LICENSE}` | New module: `version 0.2.2`, native-only, the five packages, DirectWrite/Fontconfig `link_configs` + `MOUI_LINUX_FONTCONFIG_STUB_CC_FLAGS` | Providers must be reachable without depending on a renderer |
| `moui_text_providers/*/moon.pkg` | `text_protocol` imports re-keyed to the new module | The three platform providers still share the payload protocol |
| `moui_wgpu_renderer/{moon.mod,build.js}` | Cosmic/Swash pins and the whole prebuild hook removed; `build.js` deleted | A renderer module owning text link configs is what the move exists to end |
| `moon.work`, `checks/release-modules.json` | `./moui_text_providers` member; `public` / `binding` / `base-bindings` row | Registration the release-closure and guidance gates read |
| `tools/moui/validate_api_surface/main.mbt:606-607` | `text_protocol` PackageBudget path + `package_token` re-keyed | The budget must follow the file, and its 58/23 is still inside 60/23 |
| `tools/moui/validate_maintenance_baseline/scan_scope.mbt` | `monitored_roots` gained the module | Otherwise the moved files leave the maintenance scan entirely |
| `checks/source-file-policy.json` | `roots` gained the module | **Missed by the pre-move survey**: without it `cosmic_text.mbt` (1,148 lines) is outside the file-size gate |
| `checks/backend-common-ownership.json` `sourceRoots`, `tools/moui/validate_renderer_provider_manifests/main.mbt:62`, `tools/moui/validate_runtime_state_render_ownership/validation.mbt:223`, `scripts/external-consumer-ci.mjs` (`base`/`skia`/`web` forbidden closures) | Four more explicit module enumerations gained `moui_text_providers` | Each one previously reached the provider files through the `moui_wgpu_renderer` name; leaving them alone would have narrowed a gate rather than failing |
| `scripts/test-moui-prebuild.mjs` | WGPU ownership assertions re-labelled to the text providers, plus a new `existsSync("moui_wgpu_renderer/build.js")` rejection | The assertions were about *ownership*, so they had to be renamed, not just re-pathed |
| `examples/showcase/*_wgpu`, `moui_tests/{wgpu_renderer_smoke,text_conformance}` | Import paths + `@wgpu_*` → `@text_*` aliases, `moon.mod` pins | Consumers of the moved packages |
| `docs/{architecture,architecture-map,text-system,repository-facts,platform-notes-*,renderer-capability-report}.md`, `docs/zh-Hans/*`, `skills/moui-framework-development-skill/SKILL.md`, both module `README.mbt.md` files | Provider paths, the `@text_*` alias in the entrypoint snippet, "sibling" wording, ownership-table row | Root `docs/` is the source of truth; website mirror re-synced |
| Plan `no-third-party-gpu-route.md`, ADR 0044, `memories/repo/renderer-route-economics.md` | L0.5 recorded as delivered; residual claims rewritten from "still blocked" to "closed, and here is what it does not buy" | The route decision page must not keep a stale blocker |

## Key Decisions

- `role: "binding"`, not `role: "renderer"`. A renderer-role module would have made
  `moui_wgpu_renderer` the P14 violator; `binding` is the topology `moui_skia` (292
  externs) and `moui_sun` already use for native bindings outside a renderer.
- Not inside `wzzc-dev/moui` either: the providers carry `moon_cosmic` / `moon_swash`,
  which hard-fails `validate_base_closure` (`main.mbt:127`).
- No compatibility re-export shims at the old paths. `examples/momark` and
  `moui_studio` are submodules resolving the already-published
  `wzzc-dev/moui_wgpu_renderer@0.2.2` from the registry, so a shim would pay for a
  local dependency that does not exist; their import update is a pin-bump follow-up.
- P6's "native bindings live in `moui_*_renderer` modules" clause was read, not
  rewritten: it scopes *renderer-specific* bindings. The invariant table is not
  edited unilaterally, so the reading is recorded in the plan's L0.5 block instead.

## Discoveries

- **A `daily` gate step has been red since 2026-08-12 and `pr` cannot see it.**
  `scripts/test-moui-prebuild.mjs` asserts "Skia binding prebuild must leave link
  ownership to moon.pkg", but `af9bafa6c` (2026-08-12) deliberately restored a
  `wzzc-dev/moui_skia/native` `link_configs` entry that the earlier `3df372319` had
  forbidden. `pr` has 0 prebuild steps; only `daily`/`full` run it. Verified as
  independent of this move two ways: HEAD's own `moui_skia/build.js` emits
  `link_configs.length == 1` under exactly the env the test passes, and excising
  only that block makes the re-labelled script print `split module prebuild tests:
  ok`. Left unfixed — deciding which side wins is an owner call, and this session
  does not quietly change an unrelated gate's expectation.
- **`roots` coverage is invisible when you add a module.** Nothing fails if a new
  top-level directory is absent from `checks/source-file-policy.json` and
  `scan_scope.mbt`; the files simply stop being measured. That is a silent loss,
  unlike `moon.work` or `release-modules.json` which fail loudly.
- **Three places the module was *not* registered, each ruled out by a check rather
  than by taste.** `checks/backend-common-ownership.json` `rendererModules` — it is
  not a renderer. The same file's `packageRules` `forbiddenImports` for `moui/render`
  and `moui/render/common` — `has_default_import`
  (`tools/moui/validate_backend_common_boundary/validation.mbt:192-194`) probes a
  fully quoted token, so `"wzzc-dev/moui_wgpu_renderer"` never matched the providers'
  subpackage imports even before the move, and `moui_text_providers/` has no root
  `moon.pkg` for a bare token to match; the live guard for "a provider leaks into the
  base module" is `validate-release-module-closures` failing on the cosmic/swash
  pins. `checks/compatibility-policy.json` `apiTiers` — the key has no reader at all
  (a repo-wide search for `apiTiers` returns only its own definition and the
  2026-10-25 session note that already flagged it), and `moui_skia` / `moui_sun`
  carry no row.
- Line citations drift in ways unrelated to formatting: L0.2 inserting
  `render/native_text` at `moui_wgpu_renderer/moon.pkg:5` pushed `Milky2018/wgpu_mbt`
  to `:6-7`, invalidating ADR 0044's `:5-6` citation. Re-checked rather than trusted.
- `docs/zh-Hans/repository-facts.md` is labelled "generated by
  tools/moui/generate_repo_docs; DO NOT EDIT" but the generator writes only the
  English file; the zh copy was last touched 2026-09-07 and its interface counts are
  far behind (root facade 29/7/0 vs 43/14/0). Pre-existing debt, not touched here.

## Validation

`--target native` throughout, per package: `cosmic_text` 23, `coretext` 20,
`text_protocol` 14, `fontconfig` 6, `directwrite` 8, `moui_wgpu_renderer` 61,
`moui/render/native_text` 8, `moui_tests/text_conformance/native` 10 — 0 failures.
`moon build examples/showcase/macos_wgpu --target native` links (111 tasks). All six
pre-push static validators green after the final doc edits, plus
`validate-backend-renderer-boundary`, `validate-renderer-provider-manifests` and
`validate-runtime-state-render-ownership` after their own registration edits,
`moon fmt --check` clean (2,456 tasks), `check.sh --profile pr` green (199 steps,
"MoUI pr checks passed." — the step the pre-move run lacked is the L0.2
`native text model tests` entry). `node scripts/generate-repo-docs.mjs
--write` refreshed `docs/repository-facts.md` and the website mirror (50 entries).
No committed performance baseline moved; no `packageBytes` number was re-measured,
because the benchmark binary links both renderers and cannot price a provider swap.

## Follow-Up

- `examples/momark` and `moui_studio` need their provider imports repointed at the
  next pin bump; nothing in this repo blocks on it.
- The `daily` prebuild assertion above needs an owner decision (fix the assertion to
  the current intentional `link_configs`, or restore "leave link ownership to
  moon.pkg" in `moui_skia/build.js`).
- `docs/zh-Hans/repository-facts.md` should either be generated or stop claiming to
  be.
- L1 (`moui_metal_renderer`) is the next stage of the plan and is now structurally
  unblocked.

## Promote

`memories/repo/renderer-route-economics.md` carries the durable facts: the module's
registration shape, why `role: "binding"` is the only gate-clean choice, the
`roots`-coverage trap, and the pre-existing `daily` red with its commit pair.

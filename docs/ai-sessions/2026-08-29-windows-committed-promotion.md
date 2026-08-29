# 2026-08-29: Windows promoted to committed product class

- **Agent**: ZCode (GLM) via ZCode
- **Goal**: Promote Windows from `committed_with_gaps` to `committed` by
  producing the missing matching-host L3 evidence, using
  `scripts/window-dev-mode.sh` for window-library work and committing in
  slices.
- **Outcome**: Success. Windows is now `committed`
  (`checks/platforms/windows.json` `runtimeL3=passed`,
  `checks/platform-matrix.json` `productClass=committed`), backed by a
  matching-host capture on this machine.

## Summary

Captured the full Windows L3 evidence chain locally (Win32 runtime smoke
transcript + Showcase `windows_skia` first frame), repairing three defects
that blocked it: missing Win32 FFI implementations in the window library,
a NOMINMAX macro collision in the Windows accessibility host, and the
Windows first-frame evidence script never injecting real-Skia link flags
into the executable package. Restored the lost Windows smoke driver scripts
into the canonical window submodule and recorded the promotion across
checks, docs (EN/zh-Hans), and a new ADR.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `window/scripts/{ci_host,check_moui_runtime_log,check_moui_windows_smoke,capture_moui_runtime_evidence,record_moui_evidence}.sh` | Restored from window git history (cb35185/b2441ca), adapted to `modules/` layout + `native_window_handle`/`rwh_06_*` API | Driver scripts were dropped in the window workspace module split |
| `window/scripts/check_ci.sh`, `window/scripts/check_examples_build.sh` | Host-aware gates: non-Darwin hosts run the host backend subset and skip macOS-importing examples | Full-package builds fail on Windows (macOS/iOS native stubs); pre-split script was host-aware |
| `window/modules/window/windows/native_{window,monitor}.c` | Real `mbw_hinstance_handle` (GetModuleHandleW) and `mbw_current_monitor_handle` (MonitorFromWindow) implementations | dd8f96e added only the non-Windows stubs; real-Win32 links failed with LNK2019 |
| `moui/backend/windows/windows_accessibility_host.cpp` | `#define NOMINMAX` | `std::max` broke under `windows.h` macros when `CL` flag is absent |
| `scripts/windows-platform-evidence.sh` | Step 3 injects generated stub-cc-flags/cc-link-flags into the showcase executable package; backs it up/restores it | MSVC final link only receives flags via the prebuild link_configs carrier, which `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` empties |
| `checks/platforms/windows.json`, `checks/platform-matrix.json` | `runtimeL3=passed`, `productClass=committed`, `evidenceRequired=L3` | The promotion itself |
| `docs/decisions/0031-windows-committed-product-class.md`, `0011` amendment, decisions README | ADR for the promotion | Governance trail |
| `docs/platform-readiness-declaration.md` (+zh), `README*.md`, `docs/zh-Hans/moui-readme.md`, `docs/release-readiness.md` (+zh) | Windows status wording | Normative status surfaces |
| `docs/repository-facts.md` | Regenerated | Generated from checks |

## Key Decisions

- Promote on the local matching-host capture rather than waiting for CI —
  the weekly Windows workflow only covers the first-frame smoke, and local
  matching-host citations have precedent (Linux WSL2 evidence, 2026-07-11)
  (→ ADR 0031).
- Restore the smoke drivers into the canonical window repo (adapted) instead
  of resurrecting the deprecated `.local_repos/window` copy (which holds a
  divergent, older history and was deleted).
- Keep tier 2, `ready=true`, and the `release-l2-first-frame` gate unchanged —
  the platform-matrix validator locks those for Tier 2 routes.

## Discoveries

- `platform-runtime-evidence.json` (schema v2 manifest pipeline) was deleted
  in `7b48bd5e` (2026-06-12); several docs still reference it. Windows L3
  status now lives solely in `checks/platforms/windows.json`.
- MoonBit native dead-code elimination masked the window FFI link breakage:
  `rwh_06_display_handle`/`current_monitor` were unreferenced by prior
  binaries, so only the smoke example (which calls them) exposed LNK2019.
- moon on MSVC ignores `moui_skia/native/moon.pkg` `cc-link-flags` at final
  link time; the prebuild `build.js` `link_configs` carrier is what reaches
  `is-main` links, and `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` empties it unless
  `MOUI_SKIA_CC_LINK_FLAGS` is set. The Linux evidence script's pattern of
  injecting flags into the executable package is the working workaround.
- `validate-renderer-capability-consistency.mjs` cannot run on a bare
  Windows host: it compiles the wgpu_mbt mooncake C shim, which needs
  `/experimental:c11atomics` (the known Windows check-wrapper gap tracked in
  `docs/testing.md`). Unrelated to this change.
- `.local_repos/window` was an old divergent checkout (no shared history
  with the canonical submodule tip) and is now deleted; the canonical
  `window` submodule on `moui-support` is the single source of truth.

## Validation

```sh
# window repo (MSVC vcvars shell)
bash scripts/check_moui_windows_smoke.sh --run          # transcript + verifier passed
bash scripts/capture_moui_runtime_evidence.sh windows   # check_ci + smoke + verifier + evidence entry
# MoUI (MSVC vcvars shell)
bash scripts/windows-platform-evidence.sh               # first-frame marker verified, exit 0
moon test moui/backend/windows --target native          # 26/26 passed
# static gates
node scripts/validate-platform-matrix.mjs               # 14 routes valid
node scripts/validate-doc-references.mjs                # all references resolve
node scripts/validate-guidance-consistency.mjs          # ok
node scripts/validate-maintenance-baseline.mjs          # ok
node scripts/validate-api-surface.mjs                   # ok
node scripts/validate-release-module-closures.mjs       # ok
node scripts/generate-repo-docs.mjs --check             # current
```

Evidence artifacts (gitignored): `artifacts/platform-evidence/windows/`
(`moui-windows-runtime.log`, `showcase-windows-skia-first-frame.log`,
`windows-platform-evidence-{preflight,summary}.log`).

## Follow-Up

- [ ] Publish a window release containing the Win32 FFI fix
      (`13b15f7`) so the published `wzzc-dev/window` pin converges with the
      submodule.
- [ ] Extend `moui-windows-platform-evidence.yml` to fold the full runtime
      smoke transcript into scheduled CI (currently first-frame only).
- [ ] Windows check wrapper (`scripts/windows/check.ps1`) still lacks MSVC
      env wiring for validators that compile native C (`docs/testing.md`).
- [ ] Remaining stale references to the deleted schema-v2
      `platform-runtime-evidence.json` pipeline in Web-evidence prose
      (`moui/README.mbt.md`, framework SKILL.md) predate this change.

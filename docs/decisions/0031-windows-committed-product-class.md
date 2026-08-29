# ADR 0031: Windows promoted to committed product class

- **Date**: 2026-08-29
- **Status**: Accepted
- **Deciders**: Agent-assisted (wzzc-dev)
- **Related**: ADR 0011 (product-class matrix; amended in part), ADR 0021 (mobile downgrade precedent), `docs/platform-readiness-declaration.md`, `checks/platform-matrix.json`, `checks/platforms/windows.json`

## Context

ADR 0011 classified Windows as `committed_with_gaps`: usable as a product
mainline at L0–L2 (renderer evidence on real Skia with the `d3d12-direct`
presenter route), but with the full L3 platform-runtime suite
(`checks/platforms/windows.json` `runtimeL3=partial`) unrecorded on a matching
host. The gap was evidence, not capability: the window library already ships
the Win32 backend, the platform evidence workflow
(`moui-windows-platform-evidence.yml`) covers the Showcase first-frame smoke,
and the MoUI smoke driver scripts for a full Win32 runtime transcript were
lost in the window workspace module split.

Three defects blocked producing the missing evidence on a matching MSVC host:

1. `window` module: commit dd8f96e added the `mbw_hinstance_handle` and
   `mbw_current_monitor_handle` externs with only non-Windows stub fallbacks,
   so any executable referencing `rwh_06_display_handle` or
   `current_monitor_for_window` failed to link on real Win32
   (LNK2019; latent because MoonBit dead-code elimination kept prior binaries
   from reaching these symbols).
2. `moui/backend/windows/windows_accessibility_host.cpp` used `std::max`
   after including `windows.h` without `NOMINMAX`; build paths that do not set
   the `CL` flag (the platform evidence workflow runs bare `vcvarsall.bat`)
   failed with C2589.
3. `scripts/windows-platform-evidence.sh` configured only
   `moui_skia/native/moon.pkg`, but the MSVC final link receives link flags
   through the prebuild `link_configs` carrier, which
   `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` empties; the Showcase executable
   package never received the real-Skia link flags (the Linux evidence script
   already injects them into the executable package).

## Decision

1. Restore the Windows smoke driver scripts in the window repository
   (`check_moui_windows_smoke.sh`, `check_moui_runtime_log.sh`,
   `capture_moui_runtime_evidence.sh`, `record_moui_evidence.sh`,
   `ci_host.sh`), adapted to the canonical `modules/` layout and current
   handle API names.
2. Fix the three defects above (window `13b15f7`, MoUI `a4ced1fa`).
3. Record the matching-host evidence collected on 2026-08-29 and promote the
   `windows-skia` route: `checks/platforms/windows.json`
   `runtimeL3=passed`, `checks/platform-matrix.json`
   `productClass=committed`, `evidenceRequired=L3`. Tier 2, `ready=true`, and
   the `release-l2-first-frame` release gate are unchanged.
4. Update the readiness declaration, READMEs (EN/zh-Hans), and the ADR 0011
   product-class matrix accordingly. Linux remains `committed_with_gaps`;
   mobile remains `experimental`.

## Options Considered

### Option A: Promote on the captured matching-host evidence (chosen)

- Pros: honest evidence loop; matches the Linux precedent of citing local
  matching-host captures (WSL2/Wayland 2026-07-11) alongside scheduled CI;
  the weekly `moui-windows-platform-evidence.yml` workflow keeps verifying the
  first-frame route.
- Cons: the full runtime transcript is a local capture, not a GitHub Actions
  artifact; raw logs stay under gitignored `artifacts/`.

### Option B: Wait for the weekly CI workflow to go green first

- Pros: GitHub Actions provenance for the promotion.
- Cons: the workflow only runs the first-frame smoke and still does not
  collect the runtime-service transcript; blocking the promotion on CI
  provenance adds no additional L3 coverage.

### Option C: Keep Windows at `committed_with_gaps` despite passing evidence

- Pros: no status churn.
- Cons: contradicts the recorded evidence and the declaration's own
  completion plan (§6.1); leaves the product-class matrix misleading.

## Rationale

The repo rules forbid raising `runtimeL3` without new evidence; this decision
is gated on exactly that evidence. The captured transcript satisfies the
`check_moui_runtime_log.sh windows` contract end to end (surface, HWND/
HINSTANCE with raw handle identity, monitor/current-monitor probes, cursor,
the 8-field IME probe line, resize/redraw delivery, pointer, keyboard
`key=a`, IME `text=a` before `ready`, and `destroy requested` → `destroyed` →
`finished`), and the Showcase presents its first frame with
`MOUI_FIRST_FRAME_EXIT=1`. With the evidence loop repaired end to end,
holding the old class would misstate reality.

## Consequences

- Windows joins macOS and Web as product mainlines; Tier 2 now contains one
  `committed` (Windows) and one `committed_with_gaps` (Linux) route.
- The Linux interactive-L3 gap (ADR 0011 amendment by 0021) remains the only
  non-mobile product-class gap.
- Follow-up: the window repository should publish a release containing the
  FFI fix so downstream pins converge; the platform-evidence workflow can be
  extended to fold the runtime transcript into scheduled CI.
- The GPU seven-gate quality claim (ADR 0006) remains unclaimed for Windows;
  this decision does not touch it.

## Agent Notes

- **Session context**: user asked to promote Windows from
  `committed_with_gaps` to `committed`, using `scripts/window-dev-mode.sh`
  for window-library work and committing in slices.
- **Agent model**: ZCode (GLM).
- **Key instruction**: “将 windows 从 committed_with_gaps 升级到 committed。
  ps. 涉及 window 库修改时 使用 scripts\window-dev-mode.sh 使用本地 window
  库，每完成一部分 commit 一下”
- **Validation**: `check_moui_windows_smoke.sh --run` (transcript accepted by
  `check_moui_runtime_log.sh windows`), `capture_moui_runtime_evidence.sh
  windows` full chain including `check_ci.sh`, first-frame run with marker,
  `validate-platform-matrix.mjs`, `generate-repo-docs.mjs --check`.

## References

- `checks/platforms/windows.json` — promoted status record
- `checks/platform-matrix.json` — `windows-skia` route product class
- `artifacts/platform-evidence/windows/` — captured transcripts (gitignored)
- window repo: `13b15f7` (Win32 FFI fix), `a7a1f5c` (restored smoke drivers)
- MoUI: `a4ced1fa` (evidence path fixes), `212477d3` (status flip)

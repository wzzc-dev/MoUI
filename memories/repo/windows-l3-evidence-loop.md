# Windows L3 evidence loop

- Windows is `productClass=committed` (ADR 0031, 2026-08-29);
  `checks/platforms/windows.json` `runtimeL3=passed`. Tier 2 and the
  `release-l2-first-frame` gate are unchanged.
- The matching-host evidence chain: `window/scripts/capture_moui_runtime_evidence.sh
  windows` (check_ci + `check_moui_windows_smoke.sh --run` +
  `check_moui_runtime_log.sh windows`) for the Win32 runtime transcript, plus
  `scripts/windows-platform-evidence.sh` for the Showcase first-frame marker.
  Raw logs live in gitignored `artifacts/platform-evidence/windows/`.
- The smoke driver scripts (check_moui_windows_smoke / check_moui_runtime_log /
  capture / record / ci_host) were restored into the canonical `window`
  submodule after the workspace module split dropped them; the transcript
  sentinel contract (`MOUIWindowsSmoke: ...`) is unchanged from the old repo.
- moon on MSVC reaches Skia link flags only through the prebuild `build.js`
  `link_configs` carrier; `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` empties it, so
  `windows-platform-evidence.sh` injects the generated flags into the
  showcase executable package (same pattern as
  `scripts/linux-platform-evidence.sh`).
- `window` FFI externs must exist in BOTH the `#ifdef _WIN32` real branch and
  the `#else` stub branch of the windows package C files; dd8f96e added two
  externs with stubs only, which broke real-Win32 linking of anything that
  references `rwh_06_display_handle` or `current_monitor` (masked for years by
  MoonBit dead-code elimination).
- `validate-renderer-capability-consistency.mjs` cannot compile native C on a
  bare Windows host (wgpu_mbt shim's `<stdatomic.h>` needs MSVC C11 mode;
  `/experimental:c11atomics` alone does not define `__STDC_VERSION__`);
  it runs on Linux/macOS CI. On Windows, source
  `moui/scripts/windows/msvc_env.ps1` (shared CL carries
  `/experimental:c11atomics /utf-8`) and call
  `Enable-MsvcGlobalC11ModeForCOnlyStubs` before WGPU-native builds
  (`moon run examples/showcase/windows_wgpu --target native` then builds end
  to end). `/std:c11` must stay OUT of the shared CL default: cl rejects it on
  the same command line as `moui_skia`'s `/std:c++20` Skia stub flags (D8016),
  which broke the skia showcase build on 2026-08-30; the build/package helpers
  add `/std:c11` only for packages that import the WGPU provider.
- `.local_repos/window` was a stale divergent checkout and is deleted; the
  `window` submodule (`moui-support`) is the only canonical window source.
  Toggle local resolution with `scripts/window-dev-mode.sh on|off`
  (`off` + `moon install` before committing; the pr gate enforces mooncakes
  mode).

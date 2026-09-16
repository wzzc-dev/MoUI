# Plan: moui_cli desktop command surface (run/build/package for all platforms)

- **Status**: done
- **Goal**: Extend `moui build|run|package` from mobile-only to the full
  platform set (macos/windows/linux/web + existing android/ios/harmonyos),
  following the Flutter-style unified `<platform> <app>` argument shape:
  `run` = dev loop (build + env-constructed launch), `build` = raw artifact,
  `package` = distributable (absorbing the PowerShell/shell packaging
  helpers). Windows builds auto-configure the MSVC environment in-process so
  `msvc_env.ps1` sourcing is no longer required.
- **Non-goals**: Linux bundle packaging (host-required placeholder only), code
  signing/notarization (stay host-required), mobile pipeline changes, in-process
  hot reload (`moui dev` stays the dev loop), CLI version bump.

## Delivery sequence

1. Shared desktop target resolution (`desktop_target.mbt`): platform ->
   entrypoint package (`<platform>_skia|_wgpu|_sun`, `web_wasm`) with renderer
   mapping and artifact path derivation.
2. MSVC environment construction (`windows_env.mbt`): vswhere -> cl.exe ->
   CC/CXX/CL/LINK/PATH derived in-process (aligned with
   `moui/scripts/windows/msvc_env.ps1`), injected into moon child processes
   only on Windows when the user has not preset CC/CL. Doctor msvc check
   upgraded to validate the auto-configuration.
3. `moui build` desktop: native targets via `moon build --target native`
   (Windows env injection), web via `--target wasm-gc` (+`--release --strip`).
4. `moui run` desktop: build unless `--no-build`, spawn the executable with a
   constructed child environment, `--` passthrough; `web` delegates to the
   dev runner. Mobile pipeline untouched.
5. `moui package` real packaging: windows portable folder + run.cmd + schema-1
   manifest, macOS .app bundle (Info.plist), web bundle via the existing Node
   packager; linux reports host-required. Planner mode preserved when no
   positional `<platform> <app>` arguments are given; `--dry-run` available on
   the packaging path.
6. `moui devices` lists the host desktop as a run target; doctor gains a web
   check; docs (getting-started, app-templates, examples, development,
   moui_cli/README) updated with CLI-first desktop commands.
7. wbtests for the pure derivation functions; focused tests; real-run
   verification on the current host (macos build/run/package, web package);
   static gates; archive the plan.

## Acceptance

- [x] `moui run|build <platform> <app>` accepts macos/windows/linux/web and
  fails with clear messages for unknown platforms; mobile behavior unchanged.
- [x] `moui build windows ...` succeeds without sourcing `msvc_env.ps1`
  (toolchain permitting) and prints the artifact path.
- [x] `moui run macos|windows ...` launches the built executable with a
  constructed child environment; `moui run web ...` starts the dev runner.
- [x] `moui package windows|macos|web <app>` produces the same layout and
  validated `moui-package.json` as the shell helpers; legacy planner mode and
  `--dry-run` preserved.
- [x] `moui devices` reports the host desktop; `moui doctor` validates the
  Windows auto-config.
- [x] wbtests pass (`moon test moui_cli --target native`); real-run checks on
  the current host pass; static gates (release closures, maintenance
  baseline, guidance, doc references, fmt/interfaces) pass.

## Decision log

| Date | Decision |
|------|----------|
| 2026-09-16 | Unified `<platform> <app>` positional style (Flutter-like) instead of platform-suffixed subcommands; mobile shape unchanged. |
| 2026-09-16 | Real packaging lives in `moui package <platform> <app>`; the existing release planner is preserved as the no-positional-argument mode and exposed as `--dry-run`. |
| 2026-09-16 | First batch: windows/macos/web fully implemented; linux run/build pass-through real, linux package host-required (no existing script, unverifiable on this host). |
| 2026-09-16 | MSVC env is derived in-process from vswhere (no vcvarsall capture) and injected only when CC/CL are not preset. |

## Progress

| Date | Note |
|------|------|
| 2026-09-16 | Plan established after CLI + desktop-workflow exploration; command surface, packaging absorption targets, and MSVC derivation approach fixed. |
| 2026-09-16 | Implemented `desktop_target.mbt`, `windows_env.mbt`, `desktop_build.mbt`, `run_desktop.mbt`, `package_build.mbt`; extended build/run/devices/doctor and the package dispatcher. 202/202 CLI tests pass (10 new wbtests). |
| 2026-09-16 | Real-run verification on macOS host: `devices` lists the desktop host; `build macos examples/counter` produces the executable; `package macos` writes a .app whose manifest passes the official Node validator; `package web` writes the gzip/brotli bundle; `run macos` launches the GUI process end-to-end; legacy planner behavior unchanged. |
| 2026-09-16 | Environmental caveats (pre-existing): global `moon fmt` drifts on moui_richtext/input under the local toolchain (reverted, out of scope); scoped fmt on moui_cli passes. |

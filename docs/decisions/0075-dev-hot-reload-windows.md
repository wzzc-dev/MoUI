# 0075: Windows native dev hot reload — MSVC plugin DLL over the same bridge host

- **Date**: 2026-11-25
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: `dev-hot-reload-windows` (active plan), ADR 0072, ADR 0073,
  `docs/platform-notes-windows.md`

## Context

ADR 0072/0073 gave macOS and Linux in-place hot reload: a generated bridge host
owns the window, renderer, input and platform services, while the app is
rebuilt as a `foreign_library` and linked into a uniquely named plugin loaded
over ABI v1. `moui dev --hot` rejected Windows, so the canonical Windows route
(`moui/backend/windows` + `moui_skia_renderer`) restarted and recreated the
window on every edit.

Windows differs in three places. MoonBit's native Windows toolchain is MSVC
(`clang-cl` is accepted); `foreign_library` emits a static `plugin.lib` archive
and generated C compiles to `plugin.obj` — there is no shared-library package
type. Generated C does not `__declspec(dllexport)` `#export_name` functions;
only `moonbit_init` is exported by `moonbit.h`, so a naive DLL link exposes no
`dev_*` entries. MSVC native builds use `/MT` static CRT, skip
`libmoonbitrun.o`, and load with `LoadLibraryW`/`FreeLibrary` rather than
`dlopen`/`dlclose`.

## Decision

Port the bridge-host design to Windows without a second protocol or ABI.

- The generator accepts `--platform windows` (and maps `process.platform ===
  "win32"`). The generated host imports `wzzc-dev/moui/backend/windows` as
  `@windows_backend`, polls through `@windows_backend.windows_timer_source()`,
  paints `DevBridgeView` through `@render_skia.from_env(platform=Windows)`, and
  runs with `@windows_backend.entry()`.
- The app plugin stays a `foreign_library`; its `moon.pkg` omits POSIX
  `link.native.cc-flags: "-fPIC"`, which MSVC objects reject as
  already position-independent.
- For each generation the runner links the archive with MSVC `link.exe`
  (override: `MOUI_HOT_LINKER`):

  ```text
  link.exe /NOLOGO /DLL /OUT:gen-<n>/plugin.dll
           /WHOLEARCHIVE:.../dev_hot/plugin/plugin.lib
           /EXPORT:dev_abi_version ... /EXPORT:dev_resize
           .../dev_hot/plugin/plugin.lib
           libcmt.lib oldnames.lib kernel32.lib shell32.lib user32.lib
           dbghelp.lib uuid.lib
  ```

  `/WHOLEARCHIVE` keeps every runtime member and `/EXPORT` publishes the nine
  generated entry points; `moonbit_init` arrives through its existing
  `__declspec(dllexport)`. The library list mirrors moon's native executable
  link so plugin and host agree on the static CRT and system libraries.
  `link.exe` also reads the `LINK` environment variable; the workspace MSVC
  helper sets it to the windowed executable recipe (`/ENTRY:mainCRTStartup`),
  so the runner clears `LINK` for the plugin spawn. Otherwise that inherited
  entry point pulls `libcmt.lib(exe_main.obj)` and the link fails with an
  unresolved `main`.
- `moui_devhost/host/moui_devhost_bridge.c` gains a `_WIN32` branch:
  `LoadLibraryW` (UTF-8 via `MultiByteToWideChar`), `GetProcAddress`,
  `FreeLibrary`, `GetLastError` diagnostics, and a Toolhelp32 module-count
  probe reporting `images=`. POSIX keeps `dlopen`/`dlsym`/`dlclose` and its
  existing log text.
- Swap order is unchanged from ABI v1: load the new image and resolve every
  symbol, call `moonbit_init`, require `dev_abi_version == 1`, flush the old
  session, `dev_create` the new session, then destroy and unload the old image.
  Any earlier failure unloads the new image and leaves the previous generation
  interactive. Only UTF-8 JSON and copied byte buffers cross the boundary.
- A bounded reload budget re-execs the host with its original command line
  (`CommandLineToArgvW` + `_wexecv`, falling back to exit code 75). The runner
  keeps `MOUI_HOT_RELOAD_LIMIT=32` on Windows because `FreeLibrary` image
  retention is unmeasured on a real host.
- The fast rebuild plan normalizes backslashes and matches
  `__moonbit_link_core__/plugin.obj` and the MSVC archiver
  (`lib.exe`/`llvm-lib.exe` with `/Out:`), so a same-shape edit cannot silently
  reuse the previous generation's object.
- Dry-run steps replay through `cmd.exe /d /s /c` with verbatim arguments, and
  `$MOON_HOME` resolves via `os.homedir()` because `HOME` is normally unset.
  `moui_cli` accepts Windows for `--hot`; Web/wasm remain rejected at parse
  time and in the runner.
- An opt-in dev-only offscreen entry (`MOUI_HOT_OFFSCREEN=1`) lets the generated
  Windows host run without an HWND. `moui_devhost/host/offscreen.mbt` builds a
  CPU-presented `HostSurface` (no native surface), resolves the same
  `@render_skia` provider through `@apphost.resolve_renderer_session`, and drives
  the same `DevBridgeView` frame tree through `@apphost.HostRuntimeDriver`, so
  `augment_frame`, platform views, semantics and full damage behave as in the
  windowed host. The host tick is a dev-owned `offscreen_timer_source()` pumped
  synchronously on the drawing thread with `QueryPerformanceCounter`
  milliseconds; the platform timer source would report time zero and freeze
  plugin timers. The loop calls `poll_reload()` and `poll_injected_events()`
  directly, so `MOUI_HOT_INJECT_FILE` needs no window message loop. The bridge
  ABI is unchanged, the windowed default is byte-for-byte unchanged, and the
  mode is not selectable in production entrypoints.

## Verification status (important)

Verified here / on Linux:

- `node --test scripts/moui-dev-hot-plan.test.mjs` covers `win32` mapping,
  `plugin.dll`, the MSVC link args, and `.obj`/`.lib`/backslash fast-plan
  matching.
- The generator emits a Windows host with `@windows_backend.entry()` and
  `platform=Windows`, and a plugin `moon.pkg` without `-fPIC`; Linux and macOS
  output is unchanged. The POSIX bridge still builds (`moon build
  moui_devhost/host --target native`).
- `moon test moui_devhost/host --target native` covers offscreen env parsing
  (unset/empty/`0` keep the windowed default), the CPU-only offscreen surface
  and presenter, the offscreen timer pump firing on host monotonic time, and
  the complete-line synthetic-input hook with exactly-once delivery.
- Moon's Windows lowering was inspected directly: `.lib` archives,
  `lib.exe /Out:`, `.obj` generated C, no `libmoonbitrun.o`, `/MT` CRT, and the
  default library list above.

Not verified here (no Windows host in this environment):

- The `_WIN32` branch has not been compiled or linked with MSVC, and the
  plugin DLL recipe has not run end-to-end.
- Whether `FreeLibrary` unmaps the MoonBit image (`images=1`) is unmeasured;
  the 32-swap budget stays until a matching host records it.
- `scripts/windows-hot-reload-smoke.ps1 -Run` has not been run on a matching
  interactive desktop here. It remains the manual matching-host gate for the
  windowed path; `moui-windows-platform-evidence.yml` does not execute an
  interactive HWND/Skia hot smoke, matching the Linux gate. No windowed claim
  should be promoted until the log shows `reload-old FreeLibrary=1 rc=0
  images=1` plus the same PID/generation sequence.
- `moui dev --hot` must run from a Developer Command Prompt (`vcvarsall.bat
  x64`) so `moon`, `cl.exe`, `lib.exe` and `link.exe` share the MSVC
  environment; a plain shell is expected to fail at plugin link. That is an
  environment error, not a silent degradation. CI provides that environment for
  the offscreen job; interactive HWND renderer evidence there remains unproven
  because hosted runners are Session 0.

## Evidence: hosted offscreen smoke (CI)

`.github/workflows/ci.yml` carries the `windows-hot-reload-offscreen` job on
`windows-latest`. It runs for pull requests whose base is `main` and for
`workflow_dispatch` when `run_windows_hot_reload_offscreen` is true (default
true). The job reuses the Windows MSVC/Skia setup steps, sources
`scripts/windows/msvc_env.ps1`, enables MSVC C11 atomics, then runs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/windows-hot-reload-smoke.ps1 -Run -Offscreen
```

The `-Offscreen` switch exports `MOUI_HOT_OFFSCREEN=1` to the dev runner, points
`MOUI_HOT_INJECT_FILE` at `artifacts/windows-hot-reload/events.jsonl`, and runs
the seven probe legs headless: offscreen surface/host startup; generation 1
frame vocabulary (`unsupported=0`) with advancing ticks; a synthetic click
(`Count: 1`); generation 2 after an app edit with `Count: 1` preserved, plus
`reload-old FreeLibrary=1 rc=0 images=1` and a cache-reset marker; generation 3
after editing the imported widget package; a compile error that keeps generation
3 live; and generation 4 recovery with state intact. Every leg failure reports
the leg name plus the last matching frame/log line. The job uploads
`artifacts/windows-hot-reload/` as CI evidence; those files stay out of git.
This is hosted offscreen evidence, not a replacement for the manual windowed
matching-host gate.

## Options Considered

- **`cl.exe /LD`, a `.def` file, MinGW, or a Windows-only protocol.** Rejected:
  the `/DLL /WHOLEARCHIVE /EXPORT` argv mirrors moon, the archive is MSVC COFF,
  and ABI v1 stays the single surface.
- **No re-exec, or worker-thread polling.** Rejected: POSIX shows images
  accumulate, and the timer callback only posts `Poll`, so the swap stays on
  the UI thread.

## Consequences

- With vcvars, edits should keep the window and PID and swap
  `gen-<n>/plugin.dll` through the same window; failure retention and
  state/transient handoff are unmodified.
- A failed plugin link or load keeps the previous generation live and reports
  through `.moui/dev-status.json` as on macOS/Linux.
- Core, renderer, backend and ABI edits still restart; IME/semantics/platform
  views remain Phase 2. macOS, Linux and Web behaviour is unchanged.

## Agent Notes

- Keep `/WHOLEARCHIVE` before the export list; without it the linker can drop
  runtime or app members referenced by the `dev_*` wrappers. Add new ABI
  entry points to `WINDOWS_PLUGIN_EXPORTS` in `scripts/moui-dev-hot-plan.mjs`
  and to the bridge.
- Re-run the PowerShell smoke from vcvars; capture `smoke.log` and
  `smoke.err.log` under `artifacts/windows-hot-reload/` as evidence, not
  source. If `images` stays above 1 after `FreeLibrary=1 rc=0`, keep the
  32-swap budget and update this ADR before relaxing the smoke.

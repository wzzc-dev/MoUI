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

## Verification status (important)

Verified here / on Linux:

- `node --test scripts/moui-dev-hot-plan.test.mjs` covers `win32` mapping,
  `plugin.dll`, the MSVC link args, and `.obj`/`.lib`/backslash fast-plan
  matching.
- The generator emits a Windows host with `@windows_backend.entry()` and
  `platform=Windows`, and a plugin `moon.pkg` without `-fPIC`; Linux output is
  unchanged. The POSIX bridge still builds (`moon build moui_devhost/host
  --target native`).
- Moon's Windows lowering was inspected directly: `.lib` archives,
  `lib.exe /Out:`, `.obj` generated C, no `libmoonbitrun.o`, `/MT` CRT, and the
  default library list above.

Not verified here (no Windows host in this environment):

- The `_WIN32` branch has not been compiled or linked with MSVC, and the
  plugin DLL recipe has not run end-to-end.
- Whether `FreeLibrary` unmaps the MoonBit image (`images=1`) is unmeasured;
  the 32-swap budget stays until a matching host records it.
- `scripts/windows-hot-reload-smoke.ps1` has not been run. It is a manual
  matching-host gate; `moui-windows-platform-evidence.yml` exists but does not
  execute an interactive HWND/Skia hot smoke, matching the Linux gate. No
  Windows claim should be promoted until the log shows `reload-old
  FreeLibrary=1 rc=0 images=1` plus the same PID/generation sequence.
- `moui dev --hot` must run from a Developer Command Prompt (`vcvarsall.bat
  x64`) so `moon`, `cl.exe`, `lib.exe` and `link.exe` share the MSVC
  environment; a plain shell is expected to fail at plugin link. That is an
  environment error, not a silent degradation. CI can provide the environment,
  but interactive renderer evidence there remains unproven.

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

# 0075: Windows native dev hot reload — MSVC plugin DLL over the same bridge host

- **Date**: 2026-11-25
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: `dev-hot-reload-windows` (active plan), ADR 0072, ADR 0073,
  `docs/platform-notes-windows.md`

## Context

ADR 0072 and ADR 0073 brought in-place native hot reload to macOS and Linux.
On both hosts a generated bridge host owns the window, renderer, input and
platform services, while the app is rebuilt as a `foreign_library` and linked
into a uniquely named plugin image loaded over ABI v1. `moui dev --hot`
rejected Windows, so the canonical Windows route
(`moui/backend/windows` + `moui_skia_renderer`) still restarted and recreated
the window on every edit.

Windows differs from the POSIX hosts in three places:

1. MoonBit's native Windows toolchain is MSVC (with `clang-cl` as an accepted
   variant). `foreign_library` still emits a static archive, named
   `plugin.lib`, and the generated C is compiled to `plugin.obj`. There is no
   shared-library package type.
2. Generated C does not mark `#export_name` functions with
   `__declspec(dllexport)`; only `moonbit_init` is exported by the
   `MOONBIT_FFI_EXPORT` declaration in `moonbit.h`. A DLL linked naively from
   the archive would expose no `dev_*` entry points.
3. MSVC native builds are `/MT` (static CRT), do not link
   `libmoonbitrun.o`, and use `LoadLibraryW` / `FreeLibrary` rather than
   `dlopen` / `dlclose`.

## Decision

Port the bridge-host design to Windows without a second protocol or ABI:

- The generator accepts `--platform windows` (and maps `process.platform ===
  "win32"`). The Windows host is a normal MoUI entrypoint that imports
  `wzzc-dev/moui/backend/windows` as `@windows_backend`, drives the
  250 ms generation poll through `@windows_backend.windows_timer_source()`,
  paints `DevBridgeView` through
  `@render_skia.from_env(platform=Windows)`, and runs with
  `@windows_backend.entry()`.
- The app plugin remains a `foreign_library`. Its generated `moon.pkg` omits
  the POSIX `link.native.cc-flags: "-fPIC"`; MSVC objects are already
  position-independent and reject `-fPIC`.
- For each generation the runner links the archive directly with MSVC
  `link.exe` (override: `MOUI_HOT_LINKER`):

  ```text
  link.exe /NOLOGO /DLL /OUT:gen-<n>/plugin.dll
           /WHOLEARCHIVE:.../dev_hot/plugin/plugin.lib
           /EXPORT:dev_abi_version ... /EXPORT:dev_resize
           .../dev_hot/plugin/plugin.lib
           libcmt.lib oldnames.lib kernel32.lib shell32.lib user32.lib
           dbghelp.lib uuid.lib
  ```

  `/WHOLEARCHIVE` keeps every runtime member. `/EXPORT` publishes the nine
  generated entry points; `moonbit_init` arrives through its existing
  `__declspec(dllexport)`. The explicit library list mirrors moon's own native
  executable link, so the plugin and host agree on the static CRT and system
  libraries.
- `moui_devhost/host/moui_devhost_bridge.c` gains a `_WIN32` branch:
  `LoadLibraryW` (UTF-8 path converted with `MultiByteToWideChar`),
  `GetProcAddress`, `FreeLibrary`, `GetLastError` diagnostics, and a
  Toolhelp32 module-count probe that reports `images=`. The POSIX branches keep
  `dlopen`/`dlsym`/`dlclose` and their existing log text unchanged.
- Swap order is unchanged from ABI v1: load new image, resolve all symbols,
  call `moonbit_init`, require `dev_abi_version == 1`, flush the old session,
  `dev_create` the new session, then destroy and unload the old image. Any
  failure before the new create unloads the new image and leaves the previous
  generation interactive. Only UTF-8 JSON and copied byte buffers cross the
  boundary.
- A bounded reload budget re-execs the host with its original command line
  (`CommandLineToArgvW` + `_wexecv`, falling back to exit code 75). The runner
  keeps `MOUI_HOT_RELOAD_LIMIT=32` on Windows because `FreeLibrary` image
  retention has not been measured on a real host yet.
- The fast rebuild plan normalizes backslashes and additionally matches the
  Windows generated-C object (`__moonbit_link_core__/plugin.obj`) and the
  MSVC archiver (`lib.exe`/`llvm-lib.exe` with `/Out:`), so a same-shape edit
  cannot silently reuse the previous generation's object.
- Dry-run steps on Windows are replayed through
  `cmd.exe /d /s /c` with verbatim arguments. The runner uses
  `os.homedir()` for `$MOON_HOME`, because `HOME` is normally unset on
  Windows.
- `moui_cli` accepts Windows for `--hot`; Web/wasm and non-native package
  combinations are still rejected at parse time and in the runner.

## Verification status (important)

Verified in this repository / Linux environment:

- `node --test scripts/moui-dev-hot-plan.test.mjs` covers `win32` mapping,
  `plugin.dll`, the MSVC link args (exports, whole-archive, default libs), and
  backslash/`.obj`/`.lib` fast-plan matching.
- The generator emits a Windows host with `@windows_backend.entry()` and
  `platform=Windows`, and a plugin `moon.pkg` without `-fPIC`; the Linux host
  output is unchanged.
- The POSIX branch of the bridge still compiles (`moon build moui_devhost/host
  --target native`).
- Moon's Windows lowering was inspected directly: `.lib` archives,
  `lib.exe /Out:`, `.obj` generated C, no `libmoonbitrun.o`, `/MT` CRT, and
  the default library list used above.

Not verified here (no Windows host in this environment):

- The `_WIN32` branch has not been compiled or linked with MSVC; the plugin DLL
  recipe has not been executed end-to-end.
- Whether `FreeLibrary` actually unmaps the MoonBit image (`images=1`) is
  unmeasured. The conservative 32-swap budget stays until a matching host
  records it.
- `scripts/windows-hot-reload-smoke.ps1` has not been run. It is a manual
  matching-host gate; the `moui-windows-platform-evidence.yml` workflow exists
  but does not currently execute an interactive HWND/Skia hot smoke, matching
  the Linux gate's manual status. No Windows claim should be promoted from it
  until the log shows `reload-old FreeLibrary=1 rc=0 images=1` plus the same
  PID/generation sequence.

Known host requirement / potential blocker: `moui dev --hot` must run from a
Developer Command Prompt (`vcvarsall.bat x64`) so `moon`, `cl.exe`, `lib.exe`
and `link.exe` share the MSVC environment. Running from a plain PowerShell
window is expected to fail at plugin link; that is an environment error, not a
silent degradation. The Windows CI runner can provide that environment, but
interactive renderer evidence there remains unproven.

## Options Considered

- **`cl.exe /LD /Fe:plugin.dll` instead of `link.exe`.** Workable, but the
  explicit `link.exe /DLL /WHOLEARCHIVE /EXPORT` invocation is smaller and
  mirrors the exact MSVC linker surface moon uses. Rejected for clarity.
- **A `.def` file for exports.** Equivalent, but requires another generated
  file; `/EXPORT:` keeps the recipe in one argv list. `moonbit_init` is left to
  the existing `dllexport` to avoid LNK4197 duplicate-export warnings.
- **A MinGW/clang GNU-style link.** The archive is MSVC COFF and the canonical
  Windows route is MSVC; adding a second toolchain would create a second
  unverified recipe. Rejected.
- **No re-exec on Windows.** Rejected until FreeLibrary unload is measured; the
  POSIX lesson is that unreleased images accumulate.
- **A Windows-only plugin protocol.** Rejected; the existing ABI v1 and
  host/protocol packages remain the single surface.
- **Polling the marker from a worker thread.** Rejected; the timer callback only
  constructs the `Poll` message, and the swap runs in the host `update` on the
  UI thread, so plugin code is never called concurrently with rendering.

## Consequences

- On a Windows host with vcvars, edits should keep the window and PID and swap
  `gen-<n>/plugin.dll` through the same window, with failure retention and
  state/transient handoff unmodified.
- A failed plugin link or load keeps the previous generation live; the runner
  reports the error through `.moui/dev-status.json` as on macOS/Linux.
- Core, renderer, backend and ABI edits still require a restart.
  IME/semantics/platform-view state remains Phase 2, as on macOS/Linux.
- macOS, Linux and Web behaviour is unchanged.

## Agent Notes

- Keep `/WHOLEARCHIVE` before the export list; without it the linker can drop
  runtime or app members that the `dev_*` wrappers reference.
- The nine `dev_*` exports are in `scripts/moui-dev-hot-plan.mjs`
  (`WINDOWS_PLUGIN_EXPORTS`); add new ABI entry points there and in the bridge.
- Re-run the PowerShell smoke from vcvars, not a bare shell. Capture
  `smoke.log` and `smoke.err.log` under `artifacts/windows-hot-reload/`; those
  are evidence, not source.
- If a real host logs `images` greater than 1 after `FreeLibrary=1 rc=0`,
  keep the 32-swap budget and update this ADR before relaxing the smoke.

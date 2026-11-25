# Plan: dev-hot-reload-windows

- **Status**: active
- **Goal**: `moui dev --hot` keeps the window, PID, renderer, input and
  platform services on native Windows, rebuilding only the app as a uniquely
  named `gen-<n>/plugin.dll` over ABI v1; the previous generation stays
  interactive on failure and opt-in state/transient handoff is preserved.
- **Non-goals**: a second plugin protocol; ABI changes; IME/semantics Phase 2;
  default daily Windows checks; Windows evidence without a real run;
  renumbering ADR 0074.

## Acceptance

- [x] Generator accepts `--platform windows` and emits a host using
  `@windows_backend.entry()` / `windows_timer_source()` /
  `@render_skia.from_env(platform=Windows)`, plus a `foreign_library` plugin
  without POSIX `-fPIC`.
- [x] Runner maps `win32`, publishes `gen-<n>/plugin.dll`, links with
  `link.exe /DLL /WHOLEARCHIVE /EXPORT`, replays dry-run steps through
  `cmd.exe`, and uses `os.homedir()` for `$MOON_HOME`.
- [x] Bridge `_WIN32` branch uses `LoadLibraryW` / `GetProcAddress` /
  `FreeLibrary` with the same load/swap/failure order as POSIX.
- [x] `moui_cli` accepts Windows for `--hot` and still rejects Web/wasm.
- [x] Unit tests cover Windows platform, plugin name, link args, and fast-plan
  matching; smoke script, smoke gate, ADR 0075, docs, and this plan landed.
- [x] A dev-only `MOUI_HOT_OFFSCREEN=1` entry renders the same bridge frame tree
  through a CPU-presented `HostSurface` on an offscreen timer source, so
  `windows-hot-reload-smoke.ps1 -Run -Offscreen` can run the seven probe legs
  on hosted Session 0 CI; windowed default and ABI are unchanged.
- [ ] Compile/link `_WIN32` with MSVC and run
  `scripts/windows-hot-reload-smoke.ps1 -Run` from vcvars, recording
  `artifacts/windows-hot-reload/smoke.log`.
- [x] Measure `FreeLibrary` image retention; the hosted offscreen smoke reports
  `images=1` after each of three swaps, so keep the 32-swap re-exec budget as a
  conservative bound until the windowed gate repeats it.
- [ ] Decide whether the Windows platform-evidence workflow should run the
  interactive hot smoke (currently manual, like Linux).

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-25 | Use MSVC `link.exe /DLL /WHOLEARCHIVE /EXPORT` on the MoonBit `plugin.lib`; rely on `moonbit.h` for `moonbit_init`'s export. |
| 2026-11-25 | Hosted offscreen shows `images=1` after three `FreeLibrary` swaps; keep `MOUI_HOT_RELOAD_LIMIT=32` as a conservative bound until the manual windowed gate repeats it. |
| 2026-11-25 | Keep ABI v1 and the host/protocol packages; Windows adds no wire fields. |
| 2026-11-25 | Match `plugin.obj` / `plugin.lib` and backslashes in the fast-plan filter. |
| 2026-11-25 | Offscreen CI reuses `HostRuntimeDriver` + a CPU-presented `HostSurface` and the same `dev_*` ABI; no second backend or diagnostics bus. |

## Progress

| Date | Note |
|------|------|
| 2026-11-25 | Generator, runner, bridge, CLI, tests, smoke gate, ADR and docs landed; Windows runtime evidence pending. |
| 2026-11-25 | Offscreen entry, timer pump and synthetic-input path added with Linux-runnable unit tests; hosted CI smoke wired. The first hosted run reached the plugin link and exposed the inherited MSVC `LINK=/ENTRY:mainCRTStartup`; the runner clears `LINK` for the plugin spawn and the plan test covers it. The second run linked, loaded and painted generation 1, then failed before leg 2 because a smoke helper bound `[int]$Pid`, which collides with PowerShell's read-only `$PID`; the parameter is now `$ProcessId`, unexpected errors report leg/frame/log, and a Node test scans smoke parameters for automatic-variable collisions. |
| 2026-11-25 | The hosted offscreen smoke then passed all seven legs on `windows-latest`: generation 1 frames with `unsupported=0` and advancing ticks, synthetic `Count: 1`, generations 2-4 with state preserved through the app and shared-widget edits plus compile-error retention, three `reload-old FreeLibrary=1 rc=0 images=1` swaps, and cache resets. |
| 2026-11-25 | The next run exposed a log-read race in leg 2: `WaitForFrameAfter` inspected only the newest raw line, which is often a partial trace while the host writes, so complete frames above it were ignored and the leg timed out. The wait now requires a `]`-terminated complete trace and checks the newest few complete frames after `StartLine`; the needles and `AssertKinds` are unchanged. |

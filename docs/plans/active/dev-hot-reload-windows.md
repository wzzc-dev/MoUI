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
- [ ] Measure `FreeLibrary` image retention; revisit `MOUI_HOT_RELOAD_LIMIT`
  if `images` stays above 1.
- [ ] Decide whether the Windows platform-evidence workflow should run the
  interactive hot smoke (currently manual, like Linux).

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-25 | Use MSVC `link.exe /DLL /WHOLEARCHIVE /EXPORT` on the MoonBit `plugin.lib`; rely on `moonbit.h` for `moonbit_init`'s export. |
| 2026-11-25 | Keep the conservative 32-swap re-exec budget until `FreeLibrary` unload is measured. |
| 2026-11-25 | Keep ABI v1 and the host/protocol packages; Windows adds no wire fields. |
| 2026-11-25 | Match `plugin.obj` / `plugin.lib` and backslashes in the fast-plan filter. |
| 2026-11-25 | Offscreen CI reuses `HostRuntimeDriver` + a CPU-presented `HostSurface` and the same `dev_*` ABI; no second backend or diagnostics bus. |

## Progress

| Date | Note |
|------|------|
| 2026-11-25 | Generator, runner, bridge, CLI, tests, smoke gate, ADR and docs landed; Windows runtime evidence pending. |
| 2026-11-25 | Offscreen entry, timer pump and synthetic-input path added with Linux-runnable unit tests; hosted CI smoke wired, Windows execution pending. |

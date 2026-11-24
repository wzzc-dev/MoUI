# Plan: dev-hot-reload-windows

- **Status**: active
- **Goal**: Make `moui dev --hot` keep the window, PID, renderer, input and
  platform services on a native Windows host, rebuilding only the app as a
  uniquely named `gen-<n>/plugin.dll` loaded over ABI v1, with the previous
  generation staying interactive on build/link/load failure and opt-in
  state/transient handoff preserved.
- **Non-goals**: A second plugin protocol; changing ABI v1; IME/semantics
  Phase 2 state; making Windows a default daily check; claiming Windows
  matching-host evidence without a real run; renumbering ADR 0074.

## Acceptance

- [x] Generator accepts `--platform windows` and emits a host using
  `@windows_backend.entry()` / `windows_timer_source()` /
  `@render_skia.from_env(platform=Windows)`, plus a `foreign_library` plugin
  without POSIX `-fPIC`.
- [x] Runner maps `win32`, publishes `gen-<n>/plugin.dll`, links with
  `link.exe /DLL /WHOLEARCHIVE /EXPORT`, replays dry-run steps through
  `cmd.exe`, and uses `os.homedir()` for `$MOON_HOME`.
- [x] Bridge has a `_WIN32` branch using `LoadLibraryW` / `GetProcAddress` /
  `FreeLibrary` with the same load/swap/failure order as POSIX.
- [x] `moui_cli` accepts Windows for `--hot` and still rejects Web/wasm.
- [x] Unit tests cover Windows platform, plugin name, link args, and fast-plan
  matching (`node --test scripts/moui-dev-hot-plan.test.mjs`).
- [x] Manual smoke script, smoke catalog gate, ADR 0075, development/testing
  docs, and this plan are landed.
- [ ] Compile and link the `_WIN32` branch with MSVC on a real Windows host.
- [ ] Run `scripts/windows-hot-reload-smoke.ps1 -Run` from vcvars and record
  `artifacts/windows-hot-reload/smoke.log`.
- [ ] Measure `FreeLibrary` image retention; revisit `MOUI_HOT_RELOAD_LIMIT`
  if `images` stays above 1.
- [ ] Decide whether the Windows platform-evidence workflow should run the
  interactive hot smoke (currently manual, like the Linux gate).

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-25 | Use MSVC `link.exe /DLL /WHOLEARCHIVE /EXPORT` on the MoonBit `plugin.lib`; rely on `moonbit.h` for `moonbit_init`'s export. |
| 2026-11-25 | Keep the conservative 32-swap re-exec budget on Windows until `FreeLibrary` unload is measured. |
| 2026-11-25 | Keep the existing ABI v1 and host/protocol packages; Windows adds no new wire fields. |
| 2026-11-25 | Match `plugin.obj` / `plugin.lib` and backslashes in the shared fast-plan filter. |

## Progress

| Date | Note |
|------|------|
| 2026-11-25 | Generator, runner, bridge, CLI, tests, smoke script, smoke gate, ADR 0075 and docs landed; Windows runtime evidence remains pending. |

# Plan: Native dev hot reload on Linux

- **Status**: active
- **Goal**: `moui dev --hot` keeps the window and PID on the canonical Linux
  route (`moui/backend/linux` + `moui_skia_renderer`), swapping the app plugin
  into a generated bridge host, matching the macOS design in ADR 0072 while
  reusing `moui_devhost` host/bridge/protocol, ABI v1 and both dev transports.
- **Non-goals**:
  - Windows or Web hot reload; Web keeps its reload-page path.
  - In-process reload of core, renderer, backend or ABI changes.
  - IME/semantics/platform-view state across swaps (Phase 2, as on macOS).
  - A second Linux-only protocol or a MoonBit interpreter path.

## Acceptance

- [x] Generated Linux host is a normal MoUI entrypoint owning window, renderer,
      input and services, painting `DevBridgeView`; generator accepts
      `--platform macos|linux` and keeps macOS wiring unchanged.
- [x] App plugin builds as a `foreign_library`; each generation is
      `gen-<n>/plugin.so`, linked from a PIC-rewritten archive with
      `-Bsymbolic`/`--whole-archive`; the marker is atomically renamed.
- [x] Host `dlopen`s a generation, calls `moonbit_init`, checks ABI v1, flushes
      the old session before create, and `dlclose`s the old image; a failed
      build/load keeps the old UI interactive.
- [x] Linux timer subscriptions tick: the backend pumps the GLib default
      context and schedules the next `WaitUntil`, so the 250 ms marker poll runs.
- [x] `moui dev --hot` accepts Linux and macOS native hosts, rejects Web/wasm
      combinations at parse and runner level, and the help text is updated.
- [x] Unit tests cover CLI gating/parsing, the fast-plan filter, link recipes and
      the Linux GLib timer pump; `moon test moui_cli` and
      `moon test moui/backend/linux` pass.
- [x] Matching-host runtime evidence: window/PID retained across edits; UI
      updated; forced build error retained the old UI and interactivity; fix
      recovered; 20-reload run recorded warm timing, RSS and `dlclose` retention.
- [x] Docs: ADR 0073, `docs/development.md`, `docs/tea-program-model.md`,
      `docs/platform-notes-linux.md` and this plan updated.
- [x] Path-triggered smoke entry exists in `smoke/gates.json` and
      `scripts/linux-hot-reload-smoke.sh`, outside the default daily gate.
- [ ] Retire this plan to `docs/plans/done/INDEX.md` with the landing sha.

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-24 | Reuse the macOS host/bridge/ABI rather than a Linux-specific protocol. |
| 2026-11-24 | Link Linux plugins by copying `plugin.a` and recompiling its MoonBit runtime members with `-fPIC`; rejected the `MOON_CC` wrapper because it changes the allocator and drops `libmoonbitrun.o`. |
| 2026-11-24 | Pump GLib timers from the Linux backend's wait hook; without it `TimerSource` subscriptions never tick in the X11/Wayland loop. |
| 2026-11-24 | Include the generated-plugin C compile in the fast plan; the previous filter silently archived the old `plugin.o`. |
| 2026-11-24 | Linux runner sets `MOUI_HOT_RELOAD_LIMIT=0`; measured `images=1` after every swap, so no re-exec budget is needed. macOS keeps 32. |

## Evidence (matching Linux host, 2026-11-24)

- Host: `examples/counter` under Xvfb `:99`, X11 backend, `skia-raster` debug
  build. Generated host/plugin from `moui_devhost/dev_hot/`.
- Warm reloads: n=20, p50 8.426 s, min 8.224 s, max 8.627 s
  (edit → published generation; dominated by gcc on `plugin.c`).
- Host PID stayed `1150561` across 22 swaps; count/state survived; titles
  `MoUI Counter v2`, `v3`, `v4` appeared after their reloads.
- Forced unbound-symbol error: runner status `ok=false/phase=error`, generation
  stayed 2; the old UI accepted a click (count 2 → 3). Fixing it published
  generation 3 in 8.28 s with the same PID.
- 20-reload retention: RSS 27.6 → 32.8 MB; `reload-old ... images=1` on every
  swap (Linux `dlclose` unmaps the image).
- Smoke: `scripts/linux-hot-reload-smoke.sh --run` passed (generation 1 → 2,
  error retention, recovery to generation 3, host PID retained).

## Progress

| Date | Note |
|------|------|
| 2026-11-24 | Ported generator, runner link path, bridge C, CLI gate and timer pump; matching-host evidence recorded. |
| 2026-11-24 | Added unit tests, smoke entry and documentation; plan ready to retire on landing. |

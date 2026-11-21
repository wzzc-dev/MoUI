# Plan: Native dev hot reload — bridge host + app plugin

- **Status**: active — Phase 0 and Phase 1 gates passed (macOS, 2026-11-22)
- **Goal**: add an opt-in same-window, state-preserving dev reload for native MoUI apps: a long-lived host keeps the window, renderer, input and platform services; a rebuilt app plugin replaces only the app layer. Restart + snapshot remains the fallback.
- **Non-goals**: release/production reload; embedded iOS/Android/HarmonyOS code loading; live reload of renderers, backends, platform services or framework ABI; a general MoonBit interpreter; function-level patching; full Web parity in the first slice.

## Context
The restart loop watches, rebuilds, kills and respawns the app; `ProgramStateTransport` restores the model and `MOUI_DEV_TRANSIENT_FILE` restores scroll/focus/caret without replaying callbacks (ADR 0068). MoonBit is AOT with no interpreter, hot-reload command or supported shared-library output; the native ABI is callable from C after `moonbit_init`, but each dylib carries its own MoonBit runtime and layout table, so MoonBit objects cannot cross safely.

## What the frameworks actually do
Flutter swaps kernel code and reassembles the Element tree (state survives, `initState` does not); React Native Fast Refresh and JVM Compose hot reload preserve some component state but reset globals/native modules; SwiftUI/InjectionIII, QML and Slint load a rebuilt dylib or replay a document; Elm/Vite/egui/iced keep only their model or restart. All inject code, retain an object graph and rebuild the UI; AOT native without an interpreter has no injection point, so the viable form is a stable host + replaceable plugin with explicit state handoff.

## Feasibility evidence (macOS, 2026-11-22)
- A `foreign_library` dylib loaded and ran exported functions; two versions coexisted and `dlclose` worked. Link recipe: `cc -shared -Wl,-force_load,_build/.../<pkg>.a "$MOON_HOME/lib/libbacktrace.a" -lm -o app.dylib`; the host must call `moonbit_init()` before any export.
- A real counter plugin importing `wzzc-dev/moui@0.7.2`, the app and `moui/runtime` compiled as a `foreign_library`; the warm plugin is ~2.2 MiB and decodes 11 draw commands for the counter view. MoonBit objects cannot cross the boundary: the plugin owns `AppRuntime` and exchanges only primitive buffers.

## Decision
Use a **bridge host + app plugin dylib**. The host is a generated normal MoUI app that keeps the ordinary platform entrypoint and renderer; its only view is a full-window `DevBridgeView` that forwards `AppEvent`s and paints decoded plugin commands. The plugin is a generated `foreign_library` containing the app's `Program` and its own `AppRuntime`, with no platform frameworks. This reuses the existing window, input and renderer instead of duplicating a host shell; a dedicated native host loop stays deferred.

## Implementation shape
1. **Packages**: dev-only `moui_devhost` module with `protocol`, `host` and `plugin`; generated `moui_devhost/dev_hot/` is gitignored and excluded from the watcher. The host explicitly imports the selected renderer and platform backend; apps keep their dependency boundary.
2. **Plugin lifecycle**: the runner builds the plugin, links a dylib, and atomically publishes `gen-<n>/plugin.dylib` via a marker. The host checks `dev_abi_version`, creates a session, restores state and swaps; failures keep the old plugin.
3. **ABI**: `dev_abi_version`, `dev_create`, `dev_destroy`, `dev_event`, `dev_frame`, `dev_frame_len`, `dev_frame_release`, `dev_flush`, `dev_resize`. Phase 1 uses UTF-8 JSON for frames/events and host-owned byte copies; a binary frame is a later optimization.
4. **State**: reuse `ProgramStateTransport` when the app exposes `program_with_dev_state` (otherwise start from `program()`); plugin create installs both file transports. Flush before destroy; restore without callbacks; stale payload falls back to `init`.
5. **Host loop**: the generated host polls the marker with a timer subscription and forwards pointer/key/scroll/text events. Phase 1 does not bridge IME, caret/selection, semantics, cursor or platform views; those apps stay on restart until Phase 2.

## Phases and kill gates
| Phase | Slice | Gate |
|---|---|---|
| 0 | macOS spike: host/plugin, counter frame + click, reload, state files, codec | same window after 20 reloads, model preserved, no crash/leak trend, same control tree (text parity is Phase 2); unsafe unload needs periodic hard restart |
| 1 | `moui dev --hot` macOS: runner, atomic generation, failure retention, status/DevTools, counter regression | build+link p50 under 1 s warm; build failure leaves the old UI interactive; generated packages stay out of app packages |
| 2 | text/IME/caret, scroll, animation clock, theme/environment, semantics/cursor/platform views | parity smoke for a text-input and a scrollable app; unsupported features fail closed to restart |
| 3/4 | Web wasm-gc module swap, then Linux/Windows after per-host `dlopen`/PIC/`LoadLibrary` evidence | Web no longer reloads; only promote a desktop platform with matching-host smoke |

## Acceptance
- [x] Phase 0 spike runs as a generated host/plugin pair; no production entrypoint changes.
- [x] Phase 1 `moui dev --hot examples/counter` rebuilds on a view edit, keeps the window alive, retains the counter model with `program_with_dev_state`, and keeps the old UI on a compiler error.
- [x] Protocol tests cover every `DrawCommand` variant used by the counter plus corrupt/old-ABI/invalid config/event payloads; runtime tests cover the invalid state fallback; `moon test moui_devhost/protocol --target native` passes (4 tests).
- [x] `docs/development.md`, `docs/tea-program-model.md` and ADR 0072 record the dev-loop contract; Web/embedded claims are unchanged.
- [x] Pre-push guards pass, including `node scripts/validate-doc-budget.mjs`.

## Evidence (2026-11-22)
- 20 reloads on one host: same PID and window rect `700,180 520x392`, count stayed 2, title alternated; RSS 88→128 MB (~1.9 MB/reload) and `dlclose` rc=0 without unmapping, which motivated the re-exec budget (tested at limit 3: same PID, count preserved, window recreated).
- Phase 1: same PID `26356` and window `53073` across generations; warm generations `649, 611, 633, 572, 632, 614, 658, 830, 644 ms` (p50 ≈ 0.63 s); a compile error kept phase `error` and generation 9 while the UI still clicked (count 2→3); fixing it published generation 10 with the count retained.
- Unique dylib paths are required: reloading the same path reuses the loaded image and produced a blank window before the `gen-<n>` scheme. `MOUI_HOT_RELOAD_LIMIT=0` disables the re-exec for a single spike; the default 32 bounds retained images.

## Validation
`moon test moui/runtime --target native`; `moon test moui/views --target native`; `moon test moui_devhost/protocol --target native`; `moon test moui_cli --target native`; `moon test examples/counter/app --target native`; `moui dev examples/counter --hot` (manual same-window check); `node scripts/validate-doc-references.mjs`; `node scripts/validate-doc-budget.mjs`.

## Decision log
| Date | Decision |
|---|---|
| 2026-11-22 | Choose bridge host + app plugin dylib; reject interpreter-driven reload and a dedicated native host before Phase 0. |
| 2026-11-22 | Keep restart + state/transient transports as fallback; hot mode is opt-in and dev-only. |
| 2026-11-22 | Web wasm module swap is a separate track; do not block native evidence on it. |
| 2026-11-22 | Unique generation paths and a re-exec budget are mandatory on macOS; Phase 2 owns IME/semantics parity. |

## Progress
| Date | Note |
|---|---|
| 2026-11-22 | Framework survey and dylib/app-plugin probes complete; plan written before coding. |
| 2026-11-22 | Phase 0 gate passed: counter bridge, 20-reload run, leak measured and bounded. |
| 2026-11-22 | Phase 1 gate passed: `--hot` runner, fast path, error retention, docs and ADR 0072. |

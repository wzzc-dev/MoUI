# 0074: Native dev hot reload Phase 2A — any workspace app, full fidelity, live time

- **Date**: 2026-11-25
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: ADR 0072, ADR 0073, ADR 0068, plan
  [`dev-hot-reload-phase2a`](../plans/active/dev-hot-reload-phase2a.md), PR #34

## Context

ADR 0072/0073 built the native bridge host: the window, renderer, input and
platform services stay in a host process while the app is rebuilt as a
`foreign_library` and loaded from a new `gen-<n>/plugin.dylib|so`. The
counter-only slice left four gaps: the plugin imported whichever app
`moui_devhost/moon.mod` listed; the bridge carried only counter's paint/event
subset; the plugin had no `FrameTick`, timers or clock; and the watcher ignored
shared packages outside the app module. Phase 2A closes those for any repository
app on macOS/Linux. IME, semantics, platform views, Windows and Web remain 2B.

## Decision

**Standalone generated module.** `scripts/moui-dev-hot-generate.mjs` writes
`wzzc-dev/moui_dev_hot` under gitignored `moui_devhost/dev_hot/` with its own
`moon.mod` (`wzzc-dev/moui`, `moui_devhost`, `moui_skia_renderer`,
`moui_devtools`, the app module) and a nested `moon.work` listing `.` plus every
repository workspace member by relative path. The plugin imports
`<app-module>/app` directly; `moui_devhost/moon.mod` no longer imports counter.
The generator prefers `program_with_dev_environment` (passing
`@devplugin.hot_environment()`), then `program_with_dev_state`, then `program`.
External workspace modules are rejected explicitly: the nested workspace mirrors
the repository root and cannot address an out-of-root module.

**Full ABI v1 fidelity.** The wire stays v1 (additive; both images are generated
together and `dev_abi_version` rejects mismatch). Every `DrawCommand` variant
crosses — all 28, including brush fills/strokes, shadow, image, rect/rounded/path
clips, transforms, opacity, layers, retained layers, filters, paths and shader
effects — with full `Brush`, `ShadowSpec`, `LayerSpec`, `FilterEffect`,
`PathSpec`, `ShaderEffectSpec`, `RetainedLayerSpec` and `ImageRun` fields. The
payload carries `clear_color`; the host prepends `Clear` when the stream does not
start with one. All 10 `AppEvent` and 8 `TextInputEvent` variants cross with full
payloads. Encoders are exhaustive; decoders keep the original kind names as
aliases. `moui_devhost/protocol/protocol_test.mbt` round-trips every variant,
clear color, legacy names and version/shape rejection.

**Host-owned time.** The generated host sends `FrameTick(frame)` every 16 ms
(`--frame-interval-ms`) and polls injected events plus the generation marker
every 250 ms, forwarding host `Resize`. The plugin's `hot_environment()` provides
an `AppEnvironment` whose timer source registers app subscriptions and whose
clock reads the latest host frame. `Session::dispatch_json` calls
`advance_hot_time` before dispatching the tick, so due timers fire before that
tick's frame, the runtime animation clock advances, and a stalled host does at
most one catch-up per timer. On Linux, `linux_timer_source` now passes
`linux_frame_clock()`; without it interval frames reported `time_ms=0` and
time-driven updates froze.

**Dependency-closure watch.** The runner parses root `moon.work` and module
names, walks the app package's `moon.pkg` imports breadth-first through local
workspace modules, and watches those package directories. Change detection uses
a source stamp with mtimes and sizes; the fast-build plan keeps a path-only shape
so an in-place edit reuses cached compile/link steps. Registry dependencies are
outside the boundary.

**Swap, state and failure model.** Publish `gen-<n>`, atomically repoint the
marker, `dlopen`, check the ABI, flush the old session, create the new one, then
destroy/`dlclose` the old image. A failed build keeps the previous generation
interactive; ADR 0068 state/transient transports are unchanged.
`MOUI_HOT_INJECT_FILE` dispatches complete JSON `AppEvent` lines once for smoke
input; `MOUI_HOT_FRAME_TRACE_INTERVAL` samples debug traces. `dlopen` keys images
by path, so publish a new directory per reload; reset the plugin timer registry
per generation.

**Evidence.** `examples/hot_reload_probe` exercises count, ticks, image,
divider, shadow, clip, brush and a paint clock; `StatusCard` lives in
`examples/hot_reload_widgets`. Linux and macOS smokes assert rich frame
`unsupported=0`, advancing ticks, injected click, generation 2 with pre-swap
`Count: 1`, generation 3 from the imported widget package, failed-build
retention, and generation 4 recovery with state intact and the same host pid;
Linux also asserts `dlclose ... images=1`. `smoke/gates.json` carries both
manual matching-host gates.

**Asset-cache follow-up.** The host renderer caches images, typefaces, shaping
and layers by path/identity for the process lifetime, so a changed asset with an
unchanged path can stay stale after a swap. There is no public invalidation hook
and recreating the renderer needs an apphost/renderer lifecycle change. Phase 2A
records this as explicit debt (cache reset, mtime invalidation, or recreate)
rather than claiming it solved.

## Consequences

- Any repository app with a recognized factory runs under `moui dev --hot` on
  macOS/Linux without devhost edits; apps wanting host time expose
  `program_with_dev_environment`, and Linux timer sources now carry the
  monotonic clock for ordinary apps too.
- Full fidelity costs JSON size/decode work. The probe traces 37 commands with
  `unsupported=0`; the plugin is ~5.1 MiB. Linux warm generations measured
  11.29–11.45 s on 2026-11-25 (initial 16.53 s), versus ADR 0073's counter-only
  p50 8.43 s; the gap is the richer app, not a workload regression.
- Registry deps and dependency-declaration edits are not watched; asset/font/
  layer caches may serve stale content until follow-up. IME, semantics,
  platform views, Windows and Web remain Phase 2B; core, renderer, backend and
  ABI edits still restart.

## References

- ADR 0072, ADR 0073, ADR 0068; `docs/plans/active/dev-hot-reload-phase2a.md`,
  `docs/development.md`, `docs/testing.md`
- `moui_devhost/{protocol,host,plugin}/`, `scripts/moui-dev*.mjs`,
  `examples/hot_reload_probe/`, `examples/hot_reload_widgets/`

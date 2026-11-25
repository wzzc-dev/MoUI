# Plan: Native dev hot reload Phase 2A — general apps, full fidelity, live time

- **Status**: active
- **ADR**: [0074](../../decisions/0074-native-dev-hot-reload-phase2a.md)
- **Goal**: `moui dev --hot` is the daily loop for any repository app on native
  macOS/Linux — no hand-edited devhost module, every paint/input variant across
  the boundary, host frames driving timers and the paint clock, imported-package
  edits rebuilding the plugin, and opted-in model state surviving a swap.
- **Non-goals**: IME, semantics/platform views, Windows/Web, external workspace
  apps, registry watching, asset-cache invalidation, release/publish changes.

## Delivery

1. Standalone generated `wzzc-dev/moui_dev_hot` under gitignored
   `moui_devhost/dev_hot/` with nested `moon.work` and app dependency; factory
   order `program_with_dev_environment` → `program_with_dev_state` → `program`;
   drop counter from `moui_devhost/moon.mod`.
2. Additive ABI v1: 28 `DrawCommand` variants with all spec fields, clear
   color, 10 `AppEvent` and 8 `TextInputEvent` variants, legacy aliases, tests.
3. Host decodes/paints, prepends clear, forwards events/resize, traces kinds and
   unsupported counts, exposes injection.
4. 16 ms host `FrameTick`; plugin hot-time environment fires due subscriptions
   before dispatch; Linux timer source gets the monotonic clock.
5. Watch local dependency closure from `moon.work`/`moon.mod`/`moon.pkg`
   imports with mtime/size stamps; keep a path-only fast-plan shape.

## Acceptance

- [x] Counter and the probe run without editing `moui_devhost/moon.mod`.
- [x] Protocol tests cover every command/spec/event/clear/legacy/version case
      (6/6); probe paints the rich vocabulary with `unsupported=0` and
      advancing timers/clock.
- [x] App edit → generation 2, same pid, pre-swap `Count: 1` preserved;
      imported widget edit → generation 3.
- [x] Compile error retains generation 3; recovery → generation 4 with state and
      Linux `images=1` unmap marker.
- [x] Linux smoke passes (2026-11-25, ticks 296→340, generations 1–4); macOS
      smoke script and both `smoke/gates.json` entries are in place.
- [ ] Run macOS smoke on a matching host and record it.
- [ ] Phase 2C asset/font/layer cache invalidation (TODO below).
- [ ] Phase 2B: IME/semantics/platform views, then Windows/Web.

## Asset-cache TODO

Trigger: after a successful swap, an image/font changed in place with the same
path, changed shaping or cached layer content still renders from the host cache.
No invalidation hook exists; recreating the renderer needs a lifecycle change.
Target Phase 2C (after Phase 2B): a cache-reset entry point called after a swap,
mtime invalidation, or a wholesale recreate preserving window/input/state. Do
not claim asset invalidation until implemented and smoked.

## Boundary notes

- Repository workspace apps only; external modules are rejected explicitly.
- Watcher covers local packages imported by the app; registry deps and
  dependency-declaration edits are outside the watch set.
- ABI stays v1 (additive, generated together, version-checked); core, renderer,
  backend and ABI edits still restart.

## Evidence

- Linux: `artifacts/linux-hot-reload/smoke.log` (not committed); 16534 ms
  initial, 11290/11447/11286 ms warm; plugin 5.1 MiB; 37 commands,
  `unsupported=0`. macOS: `artifacts/macos-hot-reload/smoke.log` on a matching
  host, via `scripts/macos-hot-reload-smoke.sh --run`.

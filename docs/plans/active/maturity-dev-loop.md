# Plan: Dev loop maturity — transient handoff and DevTools

- **Status**: active
- **Goal**: Make `moui dev` preserve framework-owned transient state across a
  restart, and give DevTools a real read-only protocol/client over the existing
  inspector, trace, and diagnostics data.
- **Non-goals**: in-process hot reload, interpreter/wasm module swap, editable
  DevTools, production I/O in `moui/runtime`, a second diagnostics bus.

## W1.1 Transient handoff

Reuse `ProgramStateTransport`, `ViewStateSlot`, `ScrollRuntimeState`,
`RouteHistoryState`, `AppRuntime::focus_key`, and the existing native file
transport. Add a second dev-only transport so the model file stays unchanged.

1. `moui/runtime/dev_transient.mbt`: versioned `DevTransientSnapshot` with
   scroll, focus, and focused text-input entries; explicit `ElementNode.key`
   paths first, structural paths as best-effort fallback.
2. `AppRuntime::capture_dev_transient()` / `restore_dev_transient()`: capture
   after committed updates and frame end; restore after first layout; never
   emit `on_scroll`/`on_change`.
3. `AppRuntime::new_program` gains optional `transient_transport~`; model
   persistence is untouched.
4. `dev_state_transport.mbt` adds `dev_transient_transport_path()` and
   `dev_transient_transport(path)` over `MOUI_DEV_TRANSIENT_FILE`.
5. `scripts/moui-dev.mjs` and the generated `.moui/dev.mjs` set the file;
   `.moui/dev-transient.json` is gitignored.
6. Tests: capture/restore, keyless fallback, no-callback restore, corrupted
   payload fallback, and a Showcase scroll/focus integration.

## W1.2 DevTools protocol and client

Reuse `InspectorReport`, `DevtoolsTrace`, `DiagnosticSink`, and the
`moui_agent_mcp` NDJSON pattern.

1. `moui_devtools/protocol`: versioned read-only messages
   (`hello`/`snapshot`/`trace`/`diagnostics`/`subscribe`/`ping`).
2. `moui_devtools/server`: provider closures for snapshot/trace/diagnostics;
   Unix socket on macOS/Linux, localhost TCP on Windows; no runtime I/O.
3. `moui_cli inspect`: `--once`, `--json`, `--section`; prints existing
   text/JSON renderers.
4. `moui dev --inspect`: runner sets `MOUI_DEVTOOLS_ADDR` and proxies the
   socket to a minimal browser page; `MOUI_DEVTOOLS_OVERLAY=1` optionally
   attaches the existing overlay.
5. Diagnostics: `WindowFrameState::finish_submission` collects
   `RenderFrameResult.diagnostics`; apphost owns the sink; the protocol exposes
   it. Add full-damage/semantics/effect producers.

## Acceptance

- [ ] `moon test moui/runtime --target native` covers transient capture,
      restore, key fallback, and corrupted payloads.
- [ ] `moon test examples/showcase/app --target native` covers a scroll/focus
      capture-restore round-trip.
- [ ] `moon test moui_devtools --target native` covers protocol round-trips,
      server providers, and diagnostics forwarding.
- [ ] `moon test moui_cli --target native` covers `moui inspect` parsing and
      fake-socket output.
- [ ] Manual: `moui dev examples/showcase` keeps scroll/focus/caret after an
      edit; `moui inspect --once` returns a live snapshot.
- [ ] `moui_devtools` stays an addon; no base-module dependency is added.

## Decision log

| Date | Decision |
|---|---|
| 2026-11-10 | Separate transient file instead of changing the model payload format |
| 2026-11-10 | Navigation stays app-owned; Showcase persists `RouteHistoryState` in its model |
| 2026-11-10 | DevTools is read-only and caller-owned; no dispatch/edit surface |

## Progress

| Date | Note |
|---|---|
| 2026-11-10 | Plan created; implementation starts with transient capture/restore. |
| 2026-11-10 | Spring wiring landed: `View::transition`/`View::presence` accept `elapsed_ms` and use spring sampling without re-easing/clamping; core spring tests added and `moon test moui/core` (180 tests) passes. |
| 2026-11-10 | Transient handoff landed: `ViewStateEntry`/`entries`/`from_entries`, `dev_transient.mbt` capture/restore (scroll/focus/caret), `MOUI_DEV_TRANSIENT_FILE`, debounced frame-end save, counter/Showcase macOS wiring, and runtime round-trip tests. PR profile passes. |

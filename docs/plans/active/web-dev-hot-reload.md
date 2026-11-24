# Plan: Web state-preserving dev hot reload

- **Status**: active
- **Goal**: Make `moui dev --web --hot` rebuild the app on edit and refresh
  the page with the opted-in model and the framework transient snapshot
  (focus, caret, scroll) intact, for a general app package, without changing
  production Web entrypoints.
- **Non-goals**: In-process wasm instance swap (rejected in ADR 0078),
  watching core/renderer/backend packages (a dev-loop restart still covers
  them), and changing the native hot paths.

## Contract shape

1. `moui/backend/web` gains dev-only `dev_state_transport()` /
   `dev_transient_transport()` over the existing `localStorage` settings seam
   (keys `moui.dev.state`, `moui.dev.transient`), both
   `@core.ProgramStateTransport`.
2. `scripts/moui-dev-web-generate.mjs` emits the gitignored
   `moui_devhost/dev_web/` composition root from the app's `web_wasm`
   entrypoint: one program function (`program_with_dev_state` by default),
   title and dimensions read from the app, both transports wired, and a
   `web_dev_flush` export for the pre-unload transient save.
3. `scripts/moui-dev.mjs` `--web --hot`: validate the app module is in
   `moui_devhost/moon.mod`, generate, build `dev_web` for wasm-gc atomically
   to `/__moui/app.wasm`, bump the served generation, and watch the app
   project. The served page rewrites its wasm URL and polls the generation.
4. Shared `moui_web_renderer/runtime.js` calls `web_dev_flush` on `pagehide` /
   hidden visibility and records `__mouiDevHost.paintedAt`; inert without the
   export.

## Acceptance

- [x] `moui_tests/web_hot_fixture` opts in and builds for wasm-gc; production
      `web_wasm` behavior is unchanged.
- [x] `scripts/web-hot-reload-smoke.sh --run` passes headless: model survives,
      focus and scroll flush/restore, snapshot stable across two refreshes,
      N-run latency recorded.
- [x] p50/p95 edit-to-paint measured and reported (see Progress).
- [x] `docs/development.md`, `docs/testing.md`, ADR 0078, and the smoke
      catalog describe the flag, opt-in, invocation, and evidence.
- [x] Static guards and generated interfaces pass.

## Progress

| Date | Note |
|------|------|
| 2026-11-25 | Implemented and verified on the fixture: 10 runs, p50 1838 ms, p95 2068 ms edit-to-paint; all checks in `artifacts/web-hot-reload/report.json` pass. Added `moui_tests@0.0.0` and `moui_web_renderer@0.9.1` to `moui_devhost/moon.mod` (additive shared seam, called out in the PR). |

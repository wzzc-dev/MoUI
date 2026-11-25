# 0078: Web dev hot reload keeps the page and hands state across a refresh

- **Date**: 2026-11-25
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: `web-dev-hot-reload` (plan row in `docs/plans/active/`), ADR 0068, ADR 0072, ADR 0073

## Context

Native `moui dev --hot` keeps the window and process and swaps only the app
plugin (ADR 0072, ADR 0073). The Web dev loop still called `location.reload()`
after a successful build, so the model and all transient state were lost on
every edit.

The Web host has no in-process equivalent today. A MoonBit wasm-gc app is one
executable instance: `bootMouiWasmGcApp` creates the window/web imports,
instantiates, runs `_start`, and has no teardown. Event listeners, animation
frames, the GPU device, semantics DOM and per-import surface handles stay bound
to that instance, and MoonBit values cannot cross instances. ADR 0068 therefore
kept a Web module-reload experiment as a plan item and defined the
framework-owned transient snapshot that a restart-based loop can carry.

## Decision

Keep the dev page refresh, but make it state-preserving:

- `moui dev --web --hot` generates a dev composition root under the gitignored
  `moui_devhost/dev_web/` (`scripts/moui-dev-web-generate.mjs`). It builds the
  app's `program_with_dev_state()` with `@web.dev_state_transport()` and
  `@web.dev_transient_transport()` — the same `ProgramStateTransport` opt-in
  native hot reload uses, backed here by `localStorage`.
- The runtime saves the committed model after every update. Before the page
  unloads, the shared Web renderer calls the dev-only `web_dev_flush` export,
  which writes the ADR 0068 transient snapshot (focus, scroll, text selection).
  The rebuilt instance restores both at startup.
- The dev server serves the rebuilt wasm at `/__moui/app.wasm`, rewrites the
  `web_wasm.wasm` URL in the served page, and bumps the generation the injected
  client polls. A failed rebuild leaves the previous served wasm interactive;
  core/renderer/backend edits still need a dev-loop restart because the watcher
  follows the app project.
- Production Web entrypoints are untouched: only the generated dev root
  imports the dev transports. The renderer hook is inert when `web_dev_flush`
  is absent.
- The app opts in by exposing `pub fn program_with_dev_state()`, exactly as
  native `--hot` requires.

## Options Considered

- **Swap a newly built wasm module into the same page (a).** Rejected for now:
  it needs a teardown/lifecycle contract (`dispose` for the event loop, DOM
  listeners, GPU device and imports), a cross-instance model representation,
  and a second app lifecycle in `apphost`/`moui_web_renderer`. That is not a
  dev-path-only change, and MoonBit objects cannot be handed between
  instances without serialization anyway.
- **Service-worker or ES-module style replacement.** Rejected; wasm-gc has no
  module-swap semantics for a running instance, and the page would still leak
  the old instance's listeners.
- **`sessionStorage` instead of `localStorage`.** Rejected; both are
  synchronous across a reload, and `localStorage` matches the existing Web
  settings prefix and survives a tab close.
- **Persist only the model.** Rejected; focus/scroll/caret are framework-owned
  and already have a documented snapshot (ADR 0068).

## Rationale

The native design already isolates everything that must survive an edit; on
Web the equivalent boundary is the page. Persisting the two opt-in seams and
reloading is the smallest change that restores model, focus and scroll without
touching production entrypoints or inventing a wasm lifecycle.

## Consequences

- Warm edits refresh the fixture app with the model, focus and scroll intact.
  Ten runs on the dev host measured edit-to-paint p50 1.84 s, p95 2.07 s
  (includes the 250 ms watcher and a ~1.5 s wasm rebuild).
- A forced compile error keeps the last served wasm interactive and overlays
  the diagnostics; saving the fix advances the generation and refreshes.
- The model handoff is app-owned JSON via `with_state_persistence`, so an app
  that does not opt in still reloads but starts from `init`.
- The dev root rebuild covers the whole workspace build closure, so renderer or
  core edits made before a restart are picked up by the next app edit; they are
  not watched by themselves.
- `moon info` skips wasm-gc-only packages, so the new dev transports do not
  appear in the tracked `pkg.generated.mbti`; this is a pre-existing generator
  gap.

## Agent Notes

- Keep `web_dev_flush` in the generated exports; without it the renderer hook
  neither flushes on `pagehide` nor records the paint marker.
- The generated package must import the app by MoonBit module name
  (`wzzc-dev/moui_tests/web_hot_fixture/app`), not by workspace directory.
- The dev server injects its client at `</body>`; appending to `document.body`
  from `<head>` aborts the poll loop.
- Add new app modules to `moui_devhost/moon.mod`; `--web --hot` reports it
  explicitly instead of failing in the build.

## References

- `docs/decisions/0068-dev-transient-handoff.md`
- `docs/decisions/0072-native-dev-hot-reload.md`
- `docs/decisions/0073-linux-native-dev-hot-reload.md`
- `docs/plans/active/web-dev-hot-reload.md`
- `docs/development.md`, `docs/testing.md`

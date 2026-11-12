# 0068: Dev restart keeps framework-owned transient state, not in-process reload

- **Date**: 2026-11-10
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted maturity review)
- **Related**: plan `maturity-program`, plan `maturity-dev-loop`, RFC
  `in-process-hot-reload-rfc`, ADR 0056

## Context

`moui dev` is a restart-based loop: the runner watches sources, rebuilds, stops
the app, and starts a new process. The existing
`ProgramStateTransport` / `MOUI_DEV_STATE_FILE` handoff preserves only the
application `Model`. Runtime-owned transient state — scroll offsets, keyboard
focus, caret/selection/composition, pointer captures, overlay stack — resets on
every restart, even when the app is otherwise unchanged.

The hot-reload RFC records three options: (1) keep restart-based and extend the
handoff with transient state, (2) interpreter-driven in-process reload, and
(3) wasm-gc dynamic module reload. MoonBit compiles AOT native/wasm-gc and has
no sanctioned dynamic-reload story; the interpreter path exists only inside
Studio.

## Decision

MoUI keeps the restart-based dev loop and adds an **opt-in transient handoff**:

- A second dev-only transport, `MOUI_DEV_TRANSIENT_FILE`, carries a versioned
  `DevTransientSnapshot` (scroll, keyboard focus, focused text input
  caret/selection/composition).
- The snapshot is captured after committed updates/frames and restored after
  the first layout of the next process. Restoration never emits user
  callbacks (`on_scroll` / `on_change`).
- Stable identity prefers explicit `ElementNode.key` paths; nodes without keys
  use a structural path and are documented as best-effort across tree-shape
  changes.
- Navigation remains app-owned. Apps that keep `RouteHistoryState` in `Model`
  (or in a future app transient hook) preserve it; the runtime does not learn
  navigation.
- In-process interpreter/wasm reload is **not** part of this decision. The web
  module-reload experiment remains a plan item, not a product claim.

## Consequences

- Restarting after a source edit keeps the developer's scroll/focus/edit
  context for keyed UI; no process model change and no production dependency.
- Apps must opt in through their composition root; absent transport is a
  zero-cost no-op.
- Keyless nodes may not restore across structural changes; this is an explicit
  limitation, not a silent guarantee.
- The RFC is narrowed to the web experiment and any future native dynamic
  reload work; option 1 is no longer an open question.

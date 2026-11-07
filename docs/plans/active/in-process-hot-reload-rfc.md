# Plan: In-process hot reload — RFC

- **Status**: active (RFC required before any implementation)
- **Goal**: Decide — via an ADR/RFC — whether and how MoUI gains an
  in-process hot reload, replacing the documented restart-based dev loop,
  and if yes, deliver the smallest viable slice.
- **Why an RFC**: `docs/development.md` and `docs/tea-program-model.md`
  explicitly state the dev loop is "a restart-based handoff, **not an
  in-process hot reload**", and `moui_cli dev` already preserves model state
  across restarts via `MOUI_DEV_STATE_FILE` +
  `ProgramStateTransport` (plan `dev-state-persistence`). An in-process loop
  reverses a recorded architecture decision, so it needs an ADR under
  `docs/decisions/`, not a silent code change.

## Starting point (verified 2026-11-07)

- Current loop: `moui_cli dev` watches sources, rebuilds, restarts the
  process, and restores model state through `ProgramStateTransport`.
- The restart cost is process spawn + re-layout, typically sub-second for
  the counter/settings scale; what restarts cannot preserve is transient
  runtime state (scroll offsets, focus, navigation stack) — exactly what
  `WidgetHarness`-style assertions and the dev loop's state transport do not
  cover.
- MoonBit compiles AOT (native) / wasm-gc; there is no sanctioned
  dynamic-reload story in the toolchain. Studio already runs an interpreter
  sandbox for its dual-track execution (`moui_studio` services), which is
  the only in-process evaluation path in the repo.

## RFC options to evaluate (with the trade-offs spelled out)

1. **Keep restart-based, close the gap on transient state**: extend
   `ProgramStateTransport` with opt-in runtime-transient snapshots (scroll,
   focus, navigation) so a restart is visually seamless. Cheapest, no
   architecture change; honest about limits.
2. **Interpreter-driven in-process reload (Studio path generalized)**: run
   the dev app against an interpreted declaration feed so edited views swap
   without a process restart, model intact. Highest fidelity, but ties the
   dev loop to the interpreter's capability envelope and needs a
   production-grade interpreter story (currently Studio-internal).
3. **wasm-gc dynamic module reload (web first)**: reload the page-scoped
   module with state handoff through the browser host — web-only fidelity,
   native unchanged.

## Acceptance

- [ ] ADR recorded with a chosen option, the rejected alternatives, and the
      dev-loop contract update (`docs/development.md`,
      `docs/tea-program-model.md`).
- [ ] If option 1: transient-state transport slices shipped with L1 tests
      and `moui_cli dev` restart asserting scroll/focus restoration.
- [ ] If option 2/3: a running dev loop with in-process view swap, model
      continuity, and a documented capability envelope.

## Validation

```sh
moon test moui_cli --target native
moon test moui/runtime --target native
moui dev examples/counter   # manual loop check
```

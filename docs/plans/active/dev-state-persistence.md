# Plan: State-preserving dev restart (file-based model handoff)

- **Status**: active
- **Goal**: Make the `moui dev` native restart loop state-preserving. The CLI
  already passes `MOUI_DEV_STATE_FILE` (default `.moui/dev-state.json`) to the
  spawned app; today nothing reads it. Applications should opt in once, and
  every restart restores the previous `Model` instead of re-running `init`.
- **Non-goals**: in-process hot reload, runtime-owned file I/O (runtime stays
  I/O-free and cross-target), Web/terminal routes, snapshotting runtime-slot
  state (hover/focus/scroll/selection stay transient per the TEA model).

## Contract shape

1. `moui/core` (pure contract, no I/O): `ProgramStateTransport`
   (`read : () -> String?`, `write : (String) -> Unit`) and
   `ProgramStatePersistence[Model]` (`save : (Model) -> String`,
   `load : (String) -> Model?`). `Program` gains a `state_persistence` field
   with `Program::with_state_persistence` and a `runtime_state_persistence`
   accessor, mirroring the existing `runtime_*` accessor pattern.
2. `moui/runtime`: `AppRuntime::new_program` and the public
   `new_program` / `new_program_with_dimensions` wrappers gain an optional
   `state_transport~` parameter. When persistence and transport are both
   present, construction restores the model from the transport payload after
   `init` (init effects still run; a failed or missing read falls back to the
   init model), and every committed `update` writes the serialized model back
   through the transport.
3. `moui/backend/common/services/native` (native-only, owns `@fs` and env
   precedent): `dev_state_transport_path()` reads `MOUI_DEV_STATE_FILE` via
   `moonbitlang/core/env`, and `dev_state_transport(path)` builds the
   transport over `moonbitlang/x/fs` text read/write with failures swallowed
   (dev-only convenience).
4. `examples/counter/app` demonstrates the opt-in
   (`program_with_dev_state()`), and `examples/counter/macos_skia/main.mbt`
   wires the transport at the composition root — platform entrypoints stay the
   only place platform-specific I/O is declared.

## Acceptance

- [x] `moon test moui/core --target native` covers the persistence builder and
      accessor round-trip.
- [x] `moon test moui/runtime --target native` covers restore-on-construct,
      save-on-update, fallback on missing/invalid payload, and no-op when the
      transport or persistence is absent.
- [x] `moon test moui/backend/common/services/native --target native` covers
      transport write/read round-trip and unset-path behavior.
- [x] `examples/counter` round-trips its model through
      `program_with_dev_state()`.
- [x] `docs/development.md` and `docs/tea-program-model.md` describe the
      opt-in contract and the still-true "not in-process" boundary.
- [x] `moon info` + committed `pkg.generated.mbti` diffs; static validators
      (`validate-api-surface`, `validate-guidance-consistency`,
      `validate-maintenance-baseline`, `validate-doc-references`) pass.

## Progress

| Date | Note |
|---|---|
| 2026-11-10 | Model handoff completed and verified; the separate transient transport (ADR 0068) extends the same opt-in pattern with scroll/focus/caret, without changing this plan's not-in-process boundary. |

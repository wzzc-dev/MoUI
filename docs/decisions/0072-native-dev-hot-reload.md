# 0072: Native dev hot reload — bridge host + app plugin dylib

- **Date**: 2026-11-22
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted)
- **Related**: plan `native-dev-hot-reload` (`docs/plans/done/INDEX.md`), ADR 0068

## Context

`moui dev` restarts the native process on every change; the state and transient
transports restore the model, focus and scroll, but the window and platform
services are recreated. MoonBit is AOT with no interpreter or supported shared
library (`foreign_library` emits a static archive), and each dylib links its own
MoonBit runtime, so MoonBit objects cannot cross the boundary.

## Decision

Use an opt-in **bridge host + app plugin dylib** on macOS. A generated host owns
the window, renderer and input and paints a full-window `DevBridgeView`; a
generated `foreign_library` owns the app `Program` and its `AppRuntime`. The
runner links each build to a uniquely named `gen-<n>/plugin.dylib` and atomically
repoints a marker. The host `dlopen`s it, calls `moonbit_init`, checks
`dev_abi_version` (1), flushes the old session, creates the new one, then closes
the old image; a failure keeps the old generation interactive. UTF-8 JSON
crosses through `dev_event`/`dev_frame` only. State reuses
`program_with_dev_state` and both transports; generated sources stay under
`moui_devhost/dev_hot/` (gitignored) in a dev-only workspace module. The
interpreter and wasm swap alternatives were rejected as unavailable or Web-only.

## Consequences

- Edits keep the window and PID; the plugin rebuilds the control tree, so only
  transport-backed state survives and IME/semantics/platform views stay Phase 2.
- `dlopen` keys images by path, so each reload publishes a new file.
- macOS `dlclose` retains MoonBit dylibs (measured ~1.9 MB per swap); the host
  re-execs after 32 swaps (`MOUI_HOT_RELOAD_LIMIT`, `0` disables).
- Core, renderer, backend and ABI edits still require a restart.

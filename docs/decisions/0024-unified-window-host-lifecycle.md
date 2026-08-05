# ADR 0024: Unified MoUI window-host lifecycle owner

- **Date**: 2026-08-05
- **Status**: Accepted
- **Supersedes**: ADR 0020 clauses that place the logical embedded lifecycle in `wzzc-dev/window` or place `WindowCoordinator` in `moui/runtime`.

## Decision

`wzzc-dev/window` is the physical host. It owns the OS event loop, public
`HostCmd` ABI, native queue, raw surface handles, and ordered
`ApplicationHandler` callback dispatch. It does not own MoUI logical phase,
surface generation, primary-window selection, detach policy, or application
exit intent.

MoUI owns one logical host layer at
`moui/backend/common`:

- `WindowCoordinator` adapts macOS, Windows, Linux, and Web windows;
- `EmbeddedWindowCoordinator` adapts Android, iOS, and HarmonyOS callbacks;
- `FrameCoordinator` is the shared begin/present-completion/redraw/IME
  and image-repaint state machine.

`moui/backend/common/embedded` is a session capability layer. It
owns renderer binding, transport/session generation, embedded services, IME,
semantics, and platform views. It consumes the window-host hooks and does not
implement a second lifecycle or image frame loop.

## Consequences

The runtime package remains the owner of `AppRuntime`, scene resolution, and
`HostRuntimeDriver`, but no longer exports window-host slots, surface actions,
or a host coordinator. `backend` remains contracts-only. The two host
adapters stay separate because their physical callback shapes differ, while
all logical state and frame completion behavior are shared.

The window sub-repository can be tested independently: repeated or reordered
callbacks are dispatched in arrival order, while MoUI decides whether a
callback is stale for its current surface generation. OS destroy is physical;
MoUI disposal and application exit happen before the event loop is stopped.

## Migration and validation

The migration is one-time and has no deprecated aliases. Local window sources
are enabled only with `window-dev-mode.sh on`; the published dependency is
restored before commit. `validate-window-lifecycle-boundary` guards the seven host
imports, the absence of the old state owner, and the runtime/backend package
boundaries.

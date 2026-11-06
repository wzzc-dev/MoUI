# 0059: Host orchestration moves to `moui/apphost`

- **Date**: 2026-11-06
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: ADR 0018, ADR 0027, plan
  `architecture-hardening-program` (W1), structure trigger 19 in
  `docs/golden-principles.md`

## Context

`moui/runtime` is the tree/state engine, but it also owns the host pump:
`HostRuntimeDriver` translates `@backend_host.Event` into runtime events,
`AppBuilder`/`run_app` hand a provider list and `WindowRequests` to a platform
entry, and `HostPlatformEventSources` adapt backend subscriptions. Those four
files are the only reason `moui/runtime` imports `moui/backend` and
`moui/render`.

In the other direction, `moui/backend/common` stores `AppRuntime` in window
slots and scene instances, and imports `moui/runtime` in 13 production files.
The resulting graph has no literal package cycle because root `backend` never
imports `backend/common`, but runtime is conceptually a middle layer between
the tree engine and the host implementation. The reverse edge is pinned by
`checks/backend-common-ownership.json` and is the trigger-19 seam review named
in `docs/golden-principles.md`.

ADR 0018 put the driver in `moui/runtime` when the alternative was a
host-driver package. The dependency shape has since changed: runtime is now
also imported by protocol and renderer-neutral code, and the host pump carries
platform-event and renderer-provider knowledge that the tree engine does not
need.

## Decision

Add `moui/apphost` as the single host-orchestration package and move the host
pump there:

- `HostRuntimeDriver`, `RedrawScheduler`, `AppBuilder`/`AppLaunchRequest`/
  `PlatformEntry`/`run_app`, the backend event subscriptions, and the platform
  view plugin install/sync helpers live in `moui/apphost`.
- `moui/runtime` production imports only `moui/core`. `AppRuntime`, the
  element/layout/render/semantics trees, input dispatch, and the semantics DTOs
  stay in runtime.
- `moui/apphost` depends on `moui/runtime`, root `moui/backend`, and
  `moui/render`. Root `backend` and root `render` must not import `apphost`;
  the dependency validator enforces the one-way edge.
- `moui/backend/common` imports `moui/apphost` instead of `moui/runtime`.
  `apphost` re-exports the runtime types the common owners need
  (`AppRuntime`, `SemanticsRead`, `PerformSemanticsActionRequest`, and related
  receipt/error values). If MoonBit cannot re-export associated functions
  through `pub using`, `apphost` provides explicit forwarding functions; it
  does not leave a direct `backend/common -> runtime` import.
- No compatibility layer: the moved symbols are deleted from `moui/runtime` in
  the same 0.4.0 change, and every composition root, CLI template, test, and
  external consumer fixture moves to `@apphost.run_app` / `@apphost.HostRuntimeDriver`.

## Options Considered

### Option A: keep host orchestration in `moui/runtime`

- Pros: no migration; existing ADR 0018 package path remains true.
- Cons: runtime keeps backend/render knowledge, the reverse edge remains, and
  the runtime public surface keeps host-only symbols. Every host change still
  touches the tree engine's package.

### Option B: create `moui/runtime/host_driver` as a subpackage

- Pros: smaller diff; the code stays under the runtime tree and ADR 0018's
  permitted subpackage path.
- Cons: `backend/common` would still import runtime (the subpackage) for the
  driver, so the conceptual inversion remains. The tree engine's package still
  owns host policy, just in a subdirectory.

### Option C: create top-level `moui/apphost` (chosen)

- Pros: one-way graph (`apphost -> runtime + backend + render`), runtime
  production imports are core-only, host orchestration is independently
  testable, and the package name states its role. The existing `@host` alias
  for `moui/backend` is untouched because the new default alias is `@apphost`.
- Cons: a cross-package move touching roughly 60 composition roots, 26 platform
  files, 40 test files, CLI templates, validators, and documentation.

## Rationale

The tree engine should not know how a host pumps events or binds a renderer.
`apphost` is the composition seam: it may know both sides, while runtime and
the protocol packages stay one-way. Re-exporting the small runtime type set the
common owners already use keeps the common layer from importing runtime
directly without moving `AppRuntime` or the semantics protocol, which are
produced by runtime internals.

## Consequences

- `moui/runtime`'s public interface shrinks by roughly 90 declarations; its API
  budget is lowered in the same change.
- `moui/apphost` becomes the canonical entrypoint for desktop, Web, embedded,
  terminal, CLI templates, and Studio.
- Root `backend`/`render` gain a forbidden `apphost` import; the
  backend-common ownership JSON flips from "runtime allowed" to "apphost
  required, runtime forbidden".
- `HostWallClock` stays in runtime: it is a pure value type with no host-pump
  dependency, and moving it would add a platform-backend edge without removing
  one.
- The external consumer fixture and every example move in the 0.4.0 release
  window; no deprecated re-export is kept.

## References

- `moui/runtime/host_runtime_driver.mbt`, `moui/runtime/app_builder.mbt`
- `moui/backend/common/moon.pkg`
- `checks/backend-common-ownership.json`
- `docs/plans/active/architecture-hardening-program.md` (W1)

# ADR 0028: Runtime neutrality, state ownership, and render resources

- **Date**: 2026-08-07
- **Status**: Accepted
- **Supersedes**: RFC 0002 clauses permitting a second generic mutable app
  state path; ADR 0015 component watch/binding/effect/saveable state clauses;
  ADR 0027 frame/image clauses that expose renderer resource snapshots,
  callbacks, loaders, or backend repaint revisions.
- **Preserves**: ADR 0027's `RendererProvider -> RendererSession` topology and
  opaque host-surface boundary.

## Decision

Runtime contains only platform-neutral semantics, tree, layout, event, damage,
and Program execution. AccessKit conversion and bridge lifecycle belong to a
backend adapter; platform accessibility availability and bindings remain in
concrete backends.

Application state changes only through typed Program messages. Effects and
subscriptions are the only app-side side-effect paths. Element interaction
transients use typed slots scoped to stable element identity and runtime
lifetime. Slots cannot retain service, runtime, renderer, task, or cleanup
capabilities. Controlled controls accept values and message constructors, not
setters. Scroll and focus expose immutable request IDs when an app needs
programmatic control.

Runtime computes draw commands and damage. A renderer session owns every
render resource and cache. Backend frame state owns current `FrameToken` and
pending/completion ordering; backend image state owns cancellable host I/O
tasks and no resource status or revision. Renderer image requests and
completions use opaque tokens and renderer-selected decoders.

Retained-layer begin/end commands include a complete current-frame payload.
Renderer-local algorithms decide hit, update, and eviction. Runtime does not
track admission/residency, and backend does not keep a command cache or image
resource mirror.

## Consequences

There is one auditable application mutation/effect loop without misclassifying
caret, IME, hover, or ordinary scroll as business state. Runtime's dependency
closure and public vocabulary become platform-neutral. Renderer caches can
evolve independently without cross-layer revision protocols, while frame and
image completion have explicit stale/disposed outcomes.

The migration removes public mutable state/component APIs and old renderer
image/cache contracts atomically. MoonBit-backed validation prevents platform
accessibility from returning to runtime, app packages from using low-level
slots or mutable framework holders, backend owners from storing renderer
resource state, runtime from storing renderer residency, and removed renderer
lifecycle layers from reappearing.

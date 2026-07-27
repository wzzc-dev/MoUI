# 0016: Declaration invalidation and committed Agent semantics

- **Date**: 2026-07-27
- **Status**: Accepted
- **Deciders**: Repository maintainer, agent-assisted
- **Related**: [RFC #5](https://github.com/wzzc-dev/MoUI/issues/5),
  [implementation plan](../plans/done/agent-semantic-actions.md),
  [ADR 0005](0005-mobile-host-channel-ownership.md),
  [ADR 0015](0015-public-view-node-trait.md)

## Context

MoUI's public `ViewNode` contract uses lazily sampled `String` revisions and a
separate paint revision. Producers build these values through interpolation,
rounded numbers, partial field lists, JSON, and mutable-handle reads. Distinct
declarations can therefore compare equal, while wrapper modifiers can
invalidate unrelated work. The representation cannot express independent
layout, paint, semantics, and platform-view changes precisely.

Semantics has a second set of ownership problems. Reading semantics can force a
render pass; the runtime and platform hosts maintain overlapping revisions and
validation; Agent actions scan by `ElementId` and may simulate a center-point
pointer event. Host-local identity and revision state can diverge from the
runtime tree, and consumers cannot make a generation-checked action against one
atomically committed snapshot.

The Agent product surface also exposes diagnostic operations beside semantic
operations. That makes coordinates, commands, runtime state, and paint details
appear to be stable product contracts even though they are implementation and
diagnostic concerns.

## Decision

1. Replace `ViewNode::revision()` and `paint_revision()` with
   `declaration() -> ViewDeclaration`. Its conservative trait default is fully
   `Uncacheable`; performance-sensitive nodes opt into independent layout,
   paint, semantics, and platform channels using `Constant`,
   `Exact(DeclarationKey)`, or `Uncacheable`. The only automatic dependency is
   that layout invalidation also invalidates paint, semantics, and platform
   work.
2. Make `DeclarationKey` an opaque canonical byte encoding with type tags,
   length framing, exact integer and floating-point representations, and
   structural encodings for optional, array, and record data. Complete bytes
   determine equality; formatted strings and JSON are not declaration keys.
3. Freeze node identity, declaration, semantics metadata, action handlers, and
   static children once in `View::from_node`. `View::map` preserves those
   snapshots. Nodes contain immutable declaration data; application model
   mutation remains in TEA `update`, while runtime-owned node slots are limited
   to transient UI state.
4. Introduce opaque `SemanticId`, session-local monotonic
   `SemanticsNodeId`, and `UInt64`-backed `SemanticsGeneration`. Absence uses
   `SemanticId?`, never an empty string. Remove `ElementId` from Agent and
   platform wire protocols.
5. Use explicit `Transparent`, `Boundary`, `MergeDescendants`, and `Hidden`
   semantic composition. Remove automatic first-child semantic inheritance.
   Typed handlers are the source of advertised action capabilities, and
   payload-bearing actions such as `SetText(String)` and typed-direction
   `Scroll` dispatch directly to runtime state and TEA messages without
   synthesizing pointer or keyboard events.
6. Make runtime the sole owner of committed semantics. It publishes immutable
   flat snapshots atomically after rebuild, layout, dirty semantic recompute,
   ID/action index update, and delta creation. Public content changes alone
   advance generation. Runtime maintains O(1) unique/ambiguous semantic-ID and
   node-route indices plus a 64-commit delta journal; reads return full, delta,
   or unchanged results without triggering paint.
7. Require every semantic action to name a typed target/action and an exact or
   explicit-latest generation precondition. Runtime validates closed state,
   generation, uniqueness, enabled state, capability, and handler acceptance
   before mutation. Rejection is side-effect free. Acceptance commits local
   state, queues typed messages FIFO, drains synchronous TEA work, recommits
   semantics, and returns before/after generations plus pending-work state.
8. Restrict `moui/backend/host` to transport. AccessKit, Web, and mobile use
   runtime-owned node IDs, generations, and deltas, and do not keep another
   semantics revision or repeat action validation. Semantics-only Web changes
   are synchronized without requiring redraw.
9. Restrict the default `AgentHost` and MCP surface to `read_semantics` and
   `perform_action`. Raw input, global commands, runtime state, and paint
   summaries belong to a separate opt-in `AgentDiagnosticsHost` and diagnostic
   MCP profile. A single typed MCP registry owns schema, decoding, and routing;
   tool results use structured success/error envelopes, text fallback, and
   `isError`.
10. Perform the migration as one breaking contract change with no compatibility
    layer. `wait_for`, screenshots, authorization, cross-window IDs, and Theme
    ownership are separate decisions. `moui_webview` remains an addon and
    platform hosts remain opt-in.

### Superseded portions of prior decisions

This ADR supersedes only the following earlier choices:

- In ADR 0005, it supersedes revisioned flattened semantics as a host-local
  traffic authority and semantic action validation/dispatch by `ElementId`.
  Runtime-owned generations, node IDs, and deltas now cross the transport
  boundary. ADR 0005's ownership of the shared mobile host channel, native
  conversion, asynchronous service/session identity, and disposal behavior
  remains accepted.
- In ADR 0015, it supersedes `revision` as part of the public
  message-independent `ViewNode` behavior, including the `String revision` and
  `paint_revision` implementation introduced by that refactor. ADR 0015's
  object-safe public trait, typed `View` adapters, private runtime tree,
  node-scoped transient state, and commit-before-message principles remain
  accepted.

Neither ADR 0005 nor ADR 0015 is superseded in full.

## Options Considered

### Keep strings but standardize producers

- Pros: smallest code change and familiar diagnostics.
- Cons: cannot make encoding structurally exact, cannot enforce channel
  independence, and leaves lazy mutable sampling and sentinel conventions in
  the public contract.

### Use a single numeric generation or hash per view

- Pros: compact comparison and wire representation.
- Cons: still conflates four invalidation domains; a hash cannot be the source
  of equality; caller-managed generations can miss mutations or over-invalidate
  unchanged declarations.

### Rebuild and compare full semantic JSON at each host

- Pros: simple adapters and no explicit delta protocol.
- Cons: couples reads to full-tree work, duplicates revision authority, loses
  stable runtime identity, and cannot provide atomic generation preconditions.

### Dispatch semantic actions through input simulation

- Pros: reuses existing pointer and keyboard routes.
- Cons: depends on geometry and hit testing, fabricates observable input,
  cannot express payloads precisely, and weakens rejection atomicity.

### Runtime-owned declarations and committed semantics

- Pros: exact cache decisions, independent work channels, one semantics
  authority, stable indexed addressing, deterministic deltas, typed actions,
  and a narrow product automation surface.
- Cons: broad breaking migration, more explicit producer work, persistent
  per-element metadata, and bounded journal/index memory.

## Rationale

MoUI needs correctness before caching convenience. Canonical declaration bytes
make equality exact while channel policies let producers state when caching is
not provably safe. A single committed runtime snapshot aligns what consumers
read with what actions target, and a generation precondition turns read/action
into an explicit transaction boundary. Stable semantic identity is appropriate
for product automation; coordinates and renderer/runtime internals are not.

The design preserves TEA because semantic handlers produce typed messages and
runtime slots hold only transient control state. Application state still
changes only through `update`; the runtime owns lifecycle, focus, and other
node-local interaction mechanics.

## Consequences

- Exact declaration producers must classify all observable fields by channel.
  Nodes that do not provide that cache proof remain correct through the fully
  `Uncacheable` trait default.
- Semantics reads and semantics-only updates no longer require paint, while
  hosts consume one runtime-owned generation/delta protocol.
- Duplicate semantic IDs remain observable but cannot accidentally dispatch an
  action.
- Action failures become deterministic and side-effect free; successful
  receipts describe synchronous runtime/TEA completion without claiming that
  asynchronous effects finished.
- Agent integrations gain a stable two-tool default surface. Diagnostic input
  remains possible only through explicit diagnostic configuration.
- The runtime pays bounded storage for indices and 64 deltas and must test
  content equality, incremental recomputation, and cursor expiry carefully.
- Existing revision, `ElementId` wire, optional action payload, host-local
  revision, activation-state Agent host, and coordinate-simulation APIs are
  deleted rather than deprecated.

## Agent Notes

- **Session context**: Terminal refactor of declaration invalidation, committed
  semantics, Agent host ownership, and MCP semantic actions.
- **Agent model**: OpenAI Codex.
- **Key prompt or instruction**: Ignore compatibility and implement the
  architecture best aligned with MoonBit's typed APIs and TEA ownership.
- **Validation**: RFC #5 was accepted by the repository maintainer. The linked
  active plan defines focused native/wasm-gc tests, generated API review,
  static validators, Theme profile, and Daily profile required before closure.

## References

- [RFC #5: declaration invalidation and committed agent semantics](https://github.com/wzzc-dev/MoUI/issues/5)
- [Completed implementation plan](../plans/done/agent-semantic-actions.md)
- [ADR 0005: Mobile Host Channel Ownership](0005-mobile-host-channel-ownership.md)
- [ADR 0015: Public object-safe ViewNode with typed View adapters](0015-public-view-node-trait.md)

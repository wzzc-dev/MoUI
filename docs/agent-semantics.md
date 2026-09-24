# Committed Semantics And Agent Actions

MoUI exposes automation and accessibility from the runtime's committed
semantics state. Agent code never targets screen coordinates or `ElementId`,
and reading semantics does not force paint.

## Runtime Pipeline

```text
ViewDeclaration
  -> reconcile
  -> LayoutTree / RenderTree / SemanticsTree / PlatformTree
  -> committed SemanticsSnapshot + generation + indices
  -> typed SemanticsAction
  -> TEA Msg
  -> next atomic commit
```

`ViewNode::declaration` assigns `layout`, `paint`, `semantics`, and `platform`
channels independently. Each channel is `Constant`, an exact canonical
`DeclarationKey`, or `Uncacheable`; only a layout change implicitly invalidates
the other three channels. Nodes that omit `declaration` conservatively default
all four channels to `Uncacheable`; exact declarations are an opt-in cache
proof, not a correctness prerequisite. `View::from_node` samples identity,
declaration, semantics metadata, action handlers, and static children once.
`View::map` preserves those snapshots and maps only typed messages.

The runtime publishes an immutable `SemanticsSnapshot` after rebuild, layout,
dirty semantics recomputation, index replacement, and delta construction have
all completed. A generation changes only when the public snapshot changes.
Paint-only work and repeated reads do not advance it. The latest 64 committed
deltas are retained, so `read_semantics(since=...)` returns `Full`, `Delta`, or
`Unchanged`; an expired cursor recovers with `Full`.

## Identity And Composition

`SemanticId` is an optional, application-owned stable address. It is exact and
case-sensitive, contains 1 to 255 UTF-8 bytes, and rejects whitespace and
control characters. Dotted names such as `counter.increment` are a convention,
not a namespace. Duplicate IDs remain visible as snapshot issues, but every
action through an ambiguous ID is rejected without dispatch. UI code declares
the value inline through `View::semantic_id`; `SemanticId::new` aborts on an
invalid literal at the first view construction, and `SemanticId::parse` stays
the fallible form for values that originate outside the program.

`SemanticsNodeId` is allocated monotonically for one runtime session and is not
reused after an element lifetime ends. It is the transport identity used by
Web, native accessibility, and mobile hosts. `SemanticsGeneration` and node IDs
use decimal strings on wire boundaries so JavaScript cannot lose `UInt64`
precision. `ElementId` remains runtime-internal.

A `ByPath` target walks the committed semantics hierarchy instead of naming an
identity. Each step selects the `index`-th matching child of the current node,
and its `role`, `label`, `value`, and `semantic_id` fields are optional filters;
an absent filter matches anything. A step that supplies no filter addresses a
position rather than a node: the wire decoder rejects it as `invalid_arguments`
and runtime resolution refuses it, so an agent cannot request the N-th child
regardless of what it is. Path resolution shares the disabled, capability, and
handler chain of every other target, and an unmatched step or an out-of-range
index resolves to `target_not_found` rather than wrapping or clamping.

Path addressing is for finding a node inside the tree the agent already reads;
`SemanticId` remains the handle a reusable script addresses. Position-derived
paths shift silently when the tree changes, and such a path can point an action
at a different business object while still reporting success.

Views compose semantics explicitly with `Transparent`, `Boundary`,
`MergeDescendants`, or `Hidden`. A semantics modifier overlays the effective
logical boundary. It never copies a first child's role, label, value, state, or
actions into an unrelated wrapper, and `semantic_id` never inherits to an
ancestor or sibling.

## Action Transaction

Capabilities use `SemanticsActionKind`; invocations use the payload-bearing
`SemanticsAction`, including `SetText(String)` and
`Scroll(SemanticsScrollDirection)`. Runtime derives advertised capabilities
from typed handlers. Focus is runtime-owned; other actions return transient
state invalidation and typed messages directly rather than fabricating pointer
or keyboard events.

Every action requires `Exact(generation)` or explicit `Latest`. The runtime
first commits pending semantics, then checks the generation, target uniqueness,
enabled state, capability, and handler in that order. Rejections deliver no
message and do not mutate runtime focus or transient state. Handler callbacks
are proposal-only: mutable UI handles are returned as deferred commits and must
not be changed while constructing a proposal. A successful action applies
runtime-local state and deferred UI-state commits, enqueues messages FIFO,
drains synchronous TEA work, and commits semantics again. Its receipt contains
`before`, `after`, and `pending_work`; equal generations are valid and do not
imply completion of an asynchronous effect.

## Agent And MCP Boundary

`AgentHost` owns only `read_semantics` and `perform_action`. A
`RuntimeAgentHost` is permanently tied to one `AppRuntime`; after destruction,
both operations return `host_closed`. Coordinate events, global commands,
runtime counters, and paint summaries belong to the separate
`AgentDiagnosticsHost` contract.

The default MCP router exposes exactly:

- `read_semantics`
- `perform_action`

The diagnostics router is an explicit opt-in profile. Tool arguments and
business rejections return normal MCP tool results with `structuredContent`, a
text fallback, `isError`, and stable `{ "ok": true, "value": ... }` or
`{ "ok": false, "error": ... }` envelopes. JSON-RPC errors are reserved for
malformed JSON-RPC or `tools/call` envelopes.

Stable addressing is not authorization. Applications still implement
confirmation and high-risk business rules in their UI and TEA `update`.

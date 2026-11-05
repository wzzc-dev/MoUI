# 0058: `View::map` keeps the recursive typed adapter

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W1.3 / N2),
  ADR 0049, ADR 0057

## Context

`View::map` changes the message type of a complete view tree. The current
implementation creates one mapped adapter for the root, maps every typed
semantics action, recursively maps every child, and wraps event and text-command
results. Typed event, text-command, semantics-action, and child contracts are
preserved, but each map layer copies the complete adapter tree.

W1.3 asked for a message-transform chain that removes those recursive copies
without changing public behavior. N2 required three alternatives to be
compared: a typed transform chain, a generated/reified adapter, and retaining
the recursive adapter. The N2 outcome was explicitly allowed to be negative.

## Decision

Keep the recursive typed `ViewAdapter::map` implementation.

No transform-chain or reified-adapter implementation is accepted from this
spike. The recursive adapter remains the only proven-correct way to preserve
all four typed surfaces without unchecked casts or type-erased dispatch.

### Rejected design A: existential typed transform chain

The root could retain the source view plus a composed `(SourceMsg) -> RootMsg`
function, and materialize mapped children only when traversal needs them. This
requires storing a source view whose message type is hidden while a later
operation supplies a transform over that hidden type. In other words it needs
one of:

- an existential `View[?]` that carries its hidden source-message type;
- an associated source-message type on a mapped-view trait; or
- a trait object whose transform method is polymorphic over the target type.

The MoonBit `0.1.20261016` compiler does not provide a supported combination of
those features:

- Generic trait methods parse with `fn[Next]` syntax, but a trait used as an
  object type cannot expose a polymorphic method: E4038 reports
  `Trait object ... is not allowed: Method ... is polymorphic`.
- An associated type declaration inside a trait is not supported by the current
  parser; `type Source` in a trait is rejected.
- Without either facility, the hidden source type can only be reconstructed
  with an unchecked identity cast or a message-erased dispatch path. Both are
  excluded by the N2 acceptance contract and would move a compile-time typing
  failure into runtime dispatch.

A lazy implementation that merely defers `children_snapshot.map(...)` does not
remove the work. Rebuild traversal still materializes `Array[View[RootMsg]]`,
so the copy moves from view construction into traversal rather than disappearing.

### Rejected design B: generated/reified adapter

Generating one adapter type per source/destination message pair does not make a
heterogeneous child tree homogeneous. Each generated adapter still has to
produce `Array[View[RootMsg]]` for its parent. It can either:

- recursively materialize mapped child adapters, which reproduces the current
  cost with more generated code; or
- move the transform into a runtime/element traversal that carries type-erased
  dispatch, which violates the no-erasure requirement.

Code generation therefore changes where the adapter is written, not the
representation limit that causes the copy.

### Retained design C: recursive typed adapter

The current implementation:

- preserves typed event messages;
- preserves typed text-command results;
- maps typed semantics actions;
- maps every child tree;
- snapshots identity, declaration, semantics, focus, and trap state exactly
  once at `View::from_node`; and
- requires no unsafe cast, global registry, runtime message store, or hidden
  lifecycle.

Its cost model is therefore explicit: one adapter copy per node per map layer.
This is retained without claiming that the cost no longer exists.

## Evidence

The native Skia raster leaf benchmark now runs the same 1k/10k trees with one
and two map layers. The builder cache builds only the changed leaf and its
container, while the map copies still scale with layer count:

| Nodes | Map layers | Node builds, 30 frames | Adapter copies, 30 frames |
|---:|---:|---:|---:|
| 1,000 | 1 | 60 with builder cache | 30,060 |
| 1,000 | 2 | 60 with builder cache | 60,120 |
| 10,000 | 1 | 60 with builder cache | 300,060 |
| 10,000 | 2 | 60 with builder cache | 600,120 |

The direct construction rows show the same copy counts while rebuilding every
leaf. These counters are structural and deterministic. Frame timing on the
shared host is diagnostic only: the one-layer and two-layer deltas were within
normal host variance and cannot support a blocking timing ratchet.

The existing deep-tree `F-deep-click`/`G-deep-dblmap-click` comparison remains
the report-only wall-clock companion. Its adapter copy has the same linear
relationship; its host timing is not used as acceptance evidence.

## Consequences

- `View::map` remains a real composition boundary, not a free type coercion.
  Keep root-to-leaf map layers small.
- Applications should build child messages directly in the parent message type
  where practical. Use `map` only to mount a standalone feature whose view
  genuinely owns a different message enum.
- Construction caches (`ViewMemo`, `ViewBuilderCache`) are placed after the
  final mapped message type. They reduce builder work; they do not erase the
  map adapter copy.
- No public API changes, lazy-child mode, hidden type-erasure layer, or
  generated adapter framework is introduced.
- Reopen only if MoonBit gains a safe existential/associated-source mechanism
  or a measured product requirement makes a larger runtime traversal redesign
  worthwhile. The new design must still preserve typed event, text-command,
  semantics-action, and child mapping.

## References

- `moui/core/view_modifiers.mbt`
- `moui/core/view_node.mbt`
- `benchmarks/performance_budget/native/main.mbt`
- `benchmarks/full_cycle/native/main.mbt`
- `docs/views-api-guide.md`
- `docs/plans/debt/message-transform-chain.md`

# 0052: Feature scope identity namespaces lifecycle keys

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W3.1), ADR 0015,
  ADR 0028

## Context

MoUI's runtime already owns app-level Effect-task and Subscription lifecycle:
same-key tasks supersede, subscriptions are reused or canceled when the model's
subscription plan changes, stale dispatchers are ignored after completion,
cancellation, or runtime destruction, and diagnostics expose lifecycle entries.

`Feature::scope` is pure TEA composition: a lens pair, a message wrapper, and a
child `Feature`. It has no mount hook or persistent state. Before this decision,
two independently mounted features could both declare `key="refresh"` or
`key="tick"`; the runtime then treated them as one global identity. One
subscription was deduplicated and one effect task superseded the other, even
though the features were unrelated.

The missing concept is identity, not another lifecycle owner. Requiring every
reusable feature to invent globally unique keys pushes composition knowledge
into leaf modules and still fails when the same feature is mounted twice.

## Decision

`Feature::scope` accepts an optional stable `scope_id`.

- A non-empty id namespaces structured `Effect::run` / `Effect::task`
  descriptors and every Subscription source key in the mounted child.
- `%` and `/` in the id are escaped before a `/` separator is inserted. This
  makes the scope/key encoding unambiguous even when ids contain separators.
- An empty id is the root namespace and preserves the existing unscoped key.
  It is intended for a single legacy/root mount, not for reusable or
  multi-instance features.
- Scope ids are stable identities, not display labels. A model-derived id can
  distinguish instances; changing that id intentionally retires the old
  subscription and starts the new one.
- Nested composition prefixes each layer, so local keys remain local to their
  scope while lifecycle diagnostics retain a readable, unique key.
- The scope carries no state or lifecycle machine. There is no mount/unmount
  callback, component context, hidden model store, or new task owner.

Lifecycle semantics remain runtime-owned:

- Subscriptions are canceled when their scoped key disappears from the
  declarative plan, or when the runtime is destroyed.
- Effect tasks complete on first dispatch, are canceled by same-scope key
  supersession or runtime destruction, and ignore later dispatches.
- A one-shot Effect task is not canceled merely because a view subtree stops
  rendering. TEA effects are program work, not component-owned resources; an
  app that needs cancellation expresses it through an update and a new task
  state.

## Options Considered

### Option A: require globally unique leaf keys

- Pros: no API change.
- Cons: mounting the same reusable feature twice is impossible without a key
  parameter on every effect and subscription, and accidental collisions remain
  silent until diagnostics are inspected.

### Option B: add a runtime-owned component state/lifecycle store

- Pros: could model dynamic mount and unmount explicitly.
- Cons: introduces a second state model, contradicts the Feature-first TEA
  boundary, and is not justified by the concrete key-collision defect.

### Option C: namespace descriptors at the Feature mount

- Pros: fixes multi-instance collisions without changing scheduling or state
  ownership; preserves existing runtime lifecycle and diagnostics; works for
  both subscriptions and structured effects.
- Cons: callers must choose stable ids, and changing an id restarts its
  resources.

## Consequences

- Reusable and multi-instance features should pass `scope_id`; first-party
  examples provide canonical names.
- Existing `Feature::scope` calls remain source-compatible through the empty
  default, but they do not gain isolation until an id is supplied.
- Duplicate-key and supersession diagnostics now operate on scoped identities.
  A legitimate reuse inside one scope is still reported; the same local key in
  sibling scopes is not.
- Component-scoped persistent state remains open under W0.6/W3.2. This decision
  does not approve a state store.

## References

- `docs/plans/done/architecture-priority-execution.md`
- `docs/tea-program-model.md`
- `moui/core/feature.mbt`
- `moui/core/program.mbt`
- `moui/core/program_subscription.mbt`

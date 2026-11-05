# 0053: Component state remains Feature-first

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W0.6, W3.2),
  ADR 0028, ADR 0049, ADR 0052

## Context

MoUI has one application state and effect loop. `Program`/`Feature` models hold
business data, `update` is the only mutation path, and `Effect`/`Subscription`
describe follow-up work. `Feature::scope` is pure lens composition; its
`scope_id` namespaces lifecycle keys but owns no state.

Runtime-owned `ViewStateSlot` values cover transient interaction facts such as
hover, press, caret/selection, composition, drag, and ordinary uncontrolled
scroll. Those slots follow element identity and runtime lifetime. They are not
persistent component state and cannot be saved or restored.

The architecture review asked whether MoUI needs a runtime-owned typed
component store with mount/unmount, keyed identity, and save/restore. The
repository contains no remaining `ComponentContext`, binding, component-effect,
or `SaveableStateStore` implementation. First-party apps compose parent-owned
model slices with `Feature::scope`; Settings demonstrates an explicit
application-owned snapshot DTO for restore. Some old roadmap text still named
the removed APIs, which made the boundary look ambiguous.

## Decision

Persistent component state remains Feature-first:

- A reusable feature owns a plain child model type. The parent model owns every
  mounted instance, including keyed collections.
- Multi-instance identity is a stable model key. The parent selects the child
  model and passes a model-derived `scope_id` to `Feature::scope` so Effect and
  Subscription lifecycle keys are isolated.
- A scope id names lifecycle resources only. It is not a state key, a storage
  slot, or a save/restore mechanism.
- Save and restore are application-owned. Apps define explicit snapshot/wire
  DTOs and encode/decode the parent model; framework code does not retain a
  global or per-element component store.
- Runtime `ViewStateSlot` values remain limited to interaction transients.
  They are not observable business state and are not serialized.
- Effects and subscriptions remain runtime-owned lifecycle resources.
  Subscriptions follow the declarative plan; tasks complete, are superseded,
  or are canceled by runtime teardown. A view disappearing is not a component
  unmount callback.

No runtime-owned typed component store, hidden `ComponentContext`, binding,
arbitrary model setter, or saveable component registry is approved by this
decision.

## Options Considered

### Option A: Feature-first parent-owned models

- Pros: one auditably typed update path; natural keyed collections and
  serialization; no duplicate lifecycle; works with the existing view/render
  reconciliation model.
- Cons: apps write lens/update plumbing and explicit snapshot DTOs; automatic
  per-component builder reuse is not available.

### Option B: runtime-owned typed component store

- Pros: could centralize keyed mount state and saveable state access.
- Cons: introduces a second persistent-state owner, needs a codec and
  migration policy for every stored type, and conflicts with the current
  single-Model mutation boundary. No product evidence yet justifies it.

### Option C: persistent element slots

- Pros: keyed by view identity with little app plumbing.
- Cons: node identity is a rendering concern, slots are intentionally
  transient/non-serializable, and persistence would make reconciliation and
  save/restore semantics ambiguous.

## Consequences

- W3.2 is closed as a recorded product constraint, not implemented as a store.
- W1.2b automatic builder reuse is not enabled by this decision. The supported
  construction optimization remains the explicit, caller-keyed `ViewMemo`;
  automatic reuse would require a separate explicit builder-key contract/RFC.
- Keyed multi-instance state and persistence stay reviewable in ordinary app
  code and tests.
- Reconsider this decision only with external-consumer evidence showing
  repeated need across independent apps, or a MoonBit capability that makes a
  typed store substantially cheaper without creating a second mutation path.

## Validation

The 2026-11-05 `examples/custom_control/app` pilot exercises the boundary with
two initial keyed counters plus add, remove, reorder, auto-timer, and
save/restore behavior:

- The parent Model owns the counter array, edit counts, and auto flags. Child
  updates use `Feature::scope` with model-derived `custom-control/<id>` ids and
  copy-on-write writes; editing, reordering, or removing one instance cannot
  mutate or resurrect another.
- Both instances declare the same local `counter/auto` subscription key. Their
  scoped lifecycle descriptors remain distinct, removing an instance cancels
  only its subscription, and a stale timer dispatch is ignored.
- The app-owned snapshot preserves ids, order, values, edit counts, auto flags,
  and the fresh-id cursor. Restore rebuilds derived numeric values and skips
  duplicate/empty ids.
- The measured friction is the expected explicit work: a child update/lens,
  snapshot DTO, stable-id cursor, and optional host-source injection. It is
  linear and visible in app code; it does not justify a second persistence or
  lifecycle owner for the current product scope.

Evidence: `moon test examples/custom_control/app --target native` (6/6) and
`moon check examples/custom_control/app --target wasm-gc`. The decision remains
unchanged.

## References

- `docs/plans/done/architecture-priority-execution.md`
- `docs/tea-program-model.md`
- `docs/non-render-component-cookbook.md`
- `docs/custom-control-sdk.md`
- `examples/settings/app/app.mbt`
- `examples/settings/app/settings_app_test.mbt`
- `examples/custom_control/app/app.mbt`
- `examples/custom_control/app/custom_control_app_test.mbt`

# 0015: Public object-safe ViewNode with typed View adapters

- **Date**: 2026-07-26
- **Status**: Accepted
- **Deciders**: Repository maintainer, agent-assisted
- **Related**: [RFC #3](https://github.com/wzzc-dev/MoUI/issues/3),
  `docs/plans/active/view-node-trait-refactor.md`

## Context

The custom-view kernel is currently a private `ViewNode[Msg]` closure bundle
constructed through the large public `View::node` callback API. It preserves
typed TEA, but repeats the same forwarding surface in `View::map` and runtime
erasure, gives downstream packages no nominal custom-control protocol, and
stores runtime interaction state on the erased view description instead of the
reconciled element lifecycle.

MoonBit trait objects cannot express the complete generic node directly. The
current toolchain does not support `trait ViewNode[Msg]`, and polymorphic trait
methods cannot form trait objects. Object-safe methods must use `Self` exactly
once as the first parameter.

## Decision

1. Add a public open, object-safe `ViewNode` trait in `moui/core`. It owns only
   message-independent identity, revision, child transforms, layout, paint,
   text-input state, semantics, focus, and flex behavior.
2. Keep `View[Msg]` as the complete typed virtual view. `View::from_node`
   combines a concrete `ViewNode` with typed children, component-build, event,
   and text-command adapters.
3. Remove the public `View::node` callback constructor and all compatibility
   aliases. Private callback adapters may be used only inside `core`.
4. Keep high-level components as functions returning `View[Msg]`; `ViewNode`
   is a low-level renderer-neutral control protocol, not a component state
   model.
5. Replace the runtime erased closure record with a private object-safe
   `RuntimeViewNode` adapter. Runtime tree types remain private.
6. Move `ViewStateContext` into `ElementControlState`. Reconciliation preserves
   it for the same identity and resets it on remount.
7. Commit event-local state, dirty flags, focus, and capture before delivering
   typed messages to the program queue.

## Options Considered

### Keep the callback bundle

- Pros: complete typed representation and minimal conceptual layers.
- Cons: large constructor, repeated closure wrapping, weak downstream
  discoverability, and no nominal extension contract.

### Use a generic or polymorphic ViewNode trait

- Pros: one apparent abstraction for every node behavior.
- Cons: incompatible with current MoonBit trait syntax or trait-object safety.

### Erase messages inside the public trait

- Pros: simple trait object.
- Cons: loses `View[Msg]` static guarantees and weakens TEA composition.

## Consequences

- Third-party packages can implement low-level controls while returning typed
  `View[Msg]` values.
- Node configuration is immutable declaration data; business state remains in
  the app model and transient interaction state remains in runtime elements.
- The implementation gains a deliberate split between message-independent
  trait dispatch and typed adapters.
- This is a breaking API change and intentionally provides no migration shim.

## Validation

- Downstream black-box trait implementation and typed message mapping tests.
- Same-identity state preservation and changed-identity reset tests.
- Native, wasm-gc, and wasm checks plus API, maintenance, guidance, daily, Web,
  and native Skia validation.


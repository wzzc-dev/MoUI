# 0057: Multi-entry view construction uses explicit builder and content keys

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W1.2b / N1),
  ADR 0049, ADR 0053

## Context

The root view builder runs after every accepted program message. `ViewMemo`
already lets a call site skip one expensive subtree when an explicit
content-canonical `DeclarationKey` is unchanged, but its single-entry shape is a
poor fit for a keyed collection: a screen would need one memo object per item,
duplicate the collection traversal, and manually keep the memo array aligned
with the model.

Retaining many built views requires an ownership statement. The framework
cannot infer which model fields, environment values, conditional branches, or
message payloads a builder closure read. It also cannot infer when a keyed item
or conditional branch has been removed. ADR 0049 therefore kept `ViewMemo`
single-entry and left multi-entry reuse unapproved.

Keyed lists and conditional component slots now have enough first-party
evidence to approve a narrow primitive without introducing runtime-owned
component state. The primitive caches construction only and makes the complete
dependency set and lifetime caller responsibilities.

## Decision

Core provides an advanced, caller-owned `ViewBuilderCache[Msg]`:

```moonbit
cache.view(
  builder_key~,
  content_key~,
  build~,
) -> View[Msg]
```

An entry is stored under `builder_key` and additionally records `content_key`.
A lookup is a hit only when the builder key exists and its recorded content key
equals the supplied content key. A miss runs `build`, replaces that builder's
entry, and returns the new view.

### Builder key

`builder_key` is the stable logical identity of one construction slot within
the cache:

- It stays unchanged across frames while the same logical subtree remains
  mounted, including when a keyed item moves to a different array position.
- It distinguishes sibling instances, component types, conditional branches,
  and builder schema/version when those produce different view shapes.
- It is unique within one cache. A record key with an explicit type tag and a
  stable model-derived identity is the expected shape.
- It must not be the content key. Folding changing content into the map key
  would accumulate one entry per content revision instead of replacing the
  current entry.
- Array position is a valid builder key only for collections whose positions
  are stable. Reorderable or virtualized collections use the item's persistent
  identity so reordering does not discard construction reuse.

### Content key

`content_key` is the complete construction dependency key for that builder. It
must cover every input that can change the returned `View`, including:

- model values rendered by the builder;
- environment, viewport, theme, text-system, locale, scale, direction, and
  accessibility values read by the builder;
- the selected branch and every branch payload in a conditional;
- message payloads and other values captured by constructed event,
  text-command, or semantics-action handlers;
- values captured by a `View::map` transform, when the mapped view is cached;
- any other caller-owned value whose change must change the view.

An unchanging builder still supplies a content key, normally a constant
`DeclarationKey`. The cache does not compare `View` values, closures, or
rendered trees. An under-declared content key is a caller-visible stale-view
bug, exactly as with `ViewMemo`; conformance tests can exercise the changed
input and observe the stale output.

### Ownership and lifetime

- The cache caches construction, not application or component state. It does
  not own effects, subscriptions, runtime slots, element identity, layout,
  paint, or reconciliation.
- The caller owns the cache. Copying the handle aliases the same entries and
  counters. Keep one owner per screen/root or other clearly bounded collection.
- Removal is explicit. Call `remove(builder_key)` when a keyed item or
  conditional branch disappears, and `clear()` when the owning screen/root is
  torn down. The first slice has no automatic LRU, weak reference, garbage
  collector, or global registry.
- `stats()` reports successful builds, hits, misses, and the current entry
  count. Counters cover the cache's lifetime; `clear()` removes entries without
  resetting them. Counters remain caller-owned and are not registered in
  `RuntimeInspectorSnapshot`.
- The cache is advanced core and is not re-exported from the root `moui`
  facade. Apps should first compose ordinary `Feature`/`Program` views and
  adopt explicit construction caching only after measuring a repeated builder.

### Application adoption boundary

The first application review did not identify a responsible default adoption:

- the first-party data table renders three rows and is too small for the cache
  to repay key construction;
- the Excel grid has enough repeated builders, but no row/cell revision or
  dirty metadata. A complete key would have to reconstruct the full cell,
  format, selection, edit, heat-map, and theme dependency vector on every
  frame. Adding that machinery without a profile proving the residual builder
  cost would add a new stale-view risk at the hottest data structure; and
- no other first-party app has demonstrated that repeated builder construction
  is a material frame section after the W1.1 render-cache and W2 damage/scroll
  work.

`ViewBuilderCache` therefore stays an explicit advanced-core primitive. This
decision does not add a `views` re-export or a default Program cache. An app
uses it only when all of the following hold:

1. a profile attributes repeated builder construction to a material cost;
2. the collection has stable item identity and a bounded lifetime; and
3. the app can derive and review a complete content key more cheaply than it
   can rebuild the view.

The owning program factory should capture the cache so separate program
instances do not share retained views. The shape is:

```moonbit
fn program() -> @moui.Program[Model, Msg] {
  let cache = @core.ViewBuilderCache::new()
  // Capture `cache` in the view closure. Do not use a package-global cache.
  make_program(view=model => view_with_cache(model, cache))
}
```

This is caller-owned construction state, not a runtime service or component
store. A future convenience facade requires a second adopter and measured
evidence; it must not infer keys or lifecycle.

Follow-up (2026-11-09): RFC 0008 added that facade for the composition
boundary — `Feature::with_view_key` declares the content key next to the view
body, and `runtime_view_cached` / `ScopedFeature::view_cached` build through a
caller-owned `ViewBuilderCache`. It infers no keys and owns no lifecycle; the
second-adopter evidence was `examples/mo_workbench`'s hand-rolled
package-global memos, which are the shape this decision forbids.

### Relationship to existing primitives

- `ViewMemo` remains the single-entry primitive for one independently
  invalidated subtree.
- `ViewBuilderCache` is the multi-entry primitive for keyed collections and
  explicitly managed conditional slots.
- `Feature::scope` continues to own lifecycle-key namespacing only. It does not
  own a construction cache, and the cache adds no mount/unmount callback.
- `View::map` remains unchanged. Callers that want to reuse a mapped subtree
  build the complete mapped view inside the cached `build` closure and include
  the transform's captured inputs in `content_key`.

## Options Considered

### Option A: keep only `ViewMemo`

- Pros: no new API, no retention policy, and no collection-level identity
  question.
- Cons: keyed collections must own parallel memo arrays and duplicate
  traversal/removal logic at every hot call site.

### Option B: automatic runtime-owned subtree cache

- Pros: no call-site keys.
- Cons: requires implicit closure-read tracking or arbitrary closure equality,
  introduces hidden lifetime/invalidation state, and conflicts with the
  single explicit TEA projection boundary.

### Option C: explicit multi-entry caller cache

- Pros: stable keyed identity, reviewable dependencies, no second state owner,
  and one place to expose hit/miss/entry diagnostics.
- Cons: callers must declare both keys and remove deleted entries; an
  under-specified key can serve stale content.

## Consequences

- Dynamic collections get a framework-supported reuse primitive without a
  component store or runtime identity model.
- Cache lifetime is explicit. A caller that never removes deleted item keys
  retains their built views until `clear()`; this is a documented ownership
  cost, not hidden cleanup work.
- The content key can be as expensive as the dependency vector the caller
  chooses. Callers should encode named record fields and avoid unnecessary
  string formatting or JSON.
- Correctness remains testable at the call site: changing any declared input
  must change the key and rebuild; reordering stable identities must not.
- The implementation adds no second mutation path, hidden state, saveable
  registry, or runtime lifecycle hook.

## References

- `docs/plans/done/architecture-priority-execution.md`
- `docs/tea-program-model.md`
- `docs/decisions/0049-explicit-view-memo.md`
- `docs/decisions/0053-feature-first-component-state-boundary.md`
- `moui/core/view_builder_cache.mbt`
- `moui/core/view_builder_cache_test.mbt`
- `benchmarks/performance_budget/native/main.mbt`

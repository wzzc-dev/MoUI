# RFC 0008: Feature-level construction skipping

Status: Accepted (2026-11-09)

Author: plan `docs/plans/active/mature-framework-parity-optimizations.md` (point 4)

Related: ADR 0049 (`ViewMemo`), ADR 0053 (feature-first state boundary),
ADR 0057 (explicit builder cache)

## Context

A parent `Program` view runs after every accepted message. When it mounts
child features through `Feature::scope`, each `ScopedFeature::view` calls the
child's `view` function even when the lens read returns an unchanged child
model. The runtime then reconciles the rebuilt tree — cheaply after the
declaration-cache work, but the construction itself still runs.

Compose answers this with strong skipping: the compiler derives a stability
key for each composable's parameters and skips the body when they are
unchanged. MoUI cannot do that. `view` is an arbitrary closure; the framework
cannot infer which model fields, environment values, conditional branches, or
captured message payloads it reads.

ADR 0053 recorded the consequence: automatic builder reuse stays disabled
until "a separate explicit builder-key contract/RFC" exists. ADR 0057 then
supplied exactly that contract — `ViewBuilderCache` with a stable
`builder_key` and a complete `content_key` — but deliberately stopped at the
primitive:

> A future convenience facade requires a second adopter and measured
> evidence; it must not infer keys or lifecycle.

## Problem

The primitive is available but awkward at the composition boundary. A screen
mounting N scopes must, at every call site:

1. re-derive the child's dependency set, which only the feature author knows;
2. keep that derivation in sync with a `view` body defined in another module;
3. remember to include the `View::map` capture when caching a scoped view.

The demand evidence ADR 0057 asked for now exists.
`examples/mo_workbench/app` hand-rolls four package-global
`Ref` + `physical_equal` construction memos
(`view.mbt:547`, `view_message_body.mbt:98,261`, `view_messages.mbt:117`).
That is the anti-pattern ADR 0057 explicitly forbids — "Do not use a
package-global cache" — adopted because the supported shape was too far from
the code that owns the dependency set.

## Proposal

Move the **content key declaration** onto the `Feature`, and keep the
**cache ownership** with the caller. Three additions to `moui/core`:

```moonbit
Feature::with_view_key(view_key~ : (Model, ViewEnvironment) -> DeclarationKey)
Feature::runtime_view_cached(model, environment, cache~, builder_key~)
ScopedFeature::view_cached(parent, environment, cache~, builder_key~)
```

1. **`with_view_key` is a pure declaration.** It stores one more function on
   the `Feature` value. It creates no cache, holds no state, and adds no
   lifecycle hook. The key sits next to the `view` body that reads the inputs,
   so the dependency set is reviewable where it is authored.

2. **The caller owns the cache.** `runtime_view_cached` takes a
   `ViewBuilderCache[Msg]` and a `builder_key`. The declared key becomes the
   `content_key`. A feature with no declared key builds unconditionally —
   opting in is per feature, and forgetting to opt in costs performance,
   never correctness.

3. **One cache entry per mount, not per feature.** `builder_key` is supplied
   by the mount, so two instances of the same feature never share an entry.
   This is the keyed-multi-instance hazard ADR 0053's `custom_control` pilot
   exercised, and it is why the cache cannot live on the `Feature` value:
   `Feature::scope` is called on the same feature for every sibling.

4. **`ScopedFeature::view_cached` caches the mapped view.** The `build`
   closure produces `child_view.map(wrap)`, so the entry is already lifted to
   the parent's message type. `wrap` is fixed for the lifetime of a
   `ScopedFeature`, and `builder_key` identifies the mount, so the map
   capture ADR 0057 requires in `content_key` is covered by the builder key.

## Why this is not the rejected automatic reuse

ADR 0053 Option B and ADR 0057 Option B both rejected a runtime-owned cache
that infers keys. This proposal infers nothing:

- The dependency set is written by the feature author, in the open, as a
  `DeclarationKey` — the same reviewable artifact `ViewMemo` and
  `ViewBuilderCache` already require.
- Lifetime stays explicit. The caller creates the cache, removes entries for
  departed items, and clears it on teardown, exactly as ADR 0057 specifies.
- No second mutation path, no component store, no saveable registry, no
  mount/unmount callback. `Feature` remains a value that can be rebuilt at
  any time; only the caller's cache handle aliases entries.

An under-declared key remains a caller-visible stale-view bug with the same
conformance test shape ADR 0057 describes: change the input, observe the
stale output.

## Consequences

- A screen mounts N scopes with one cache and N stable builder keys, instead
  of N hand-rolled memos or N re-derived dependency vectors.
- `Feature` gains one optional function field. `Program::from_feature` is
  unaffected: `Program` has no cached-view path.
- The primitive stays advanced core. Nothing is re-exported from the root
  `moui` facade, matching ADR 0057's boundary for `ViewBuilderCache`.
- `examples/mo_workbench`'s package-global memos become migratable. This RFC
  does not migrate them; that is app work with its own measurement.

## Non-goals

- No inferred stability, closure-read tracking, or `Eq` bound on `Model`.
- No default Program cache and no `views` re-export.
- No change to `ViewMemo`, `ViewBuilderCache`, `View::map`, or
  `Feature::scope`'s lifecycle-key namespacing.

## Decision (2026-11-09)

Accepted. The explicit builder-key contract ADR 0053 asked for is ADR 0057's;
this RFC adds the composition-boundary facade over it and nothing else. The
second-adopter condition is met by `examples/mo_workbench`'s four hand-rolled
package-global memos, which are the forbidden shape rather than a supported
one.

Validation: `moon test moui/core --target native` covers hit-skips-build,
key-change-rebuilds, sibling builder keys staying independent, the
no-declared-key fallback, and the scoped path caching an already-mapped view.
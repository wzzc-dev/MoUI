# 0049: View construction memoization uses explicit content keys

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W1.2), ADR 0034, ADR 0048

## Context

`Program`/`Feature` views are pure projections, but the runtime invokes the
root view builder after every accepted message. A builder can therefore repeat
expensive construction work for subtrees whose inputs did not change, including
when a parent message only affects one leaf.

Implicit dependency tracking would require the framework to observe reads of
model fields, message captures, environment values, and control-local data. That
is not compatible with MoonBit's ordinary closures without either a second state
model or a runtime instrumentation layer. Automatic equality of arbitrary
`View[Msg]` values is also incomplete: closures and message handlers are part of
the declaration, not just the node payload.

## Decision

Core provides an explicit, single-entry `ViewMemo[Msg]`:

- `ViewMemo::view(key~, build~)` returns the cached `View[Msg]` when `key`
  compares equal to the previous key, otherwise it runs `build` and replaces
  the entry.
- The caller owns the memo and the key. The key is a content-canonical
  `DeclarationKey` covering every input read by the builder, including model
  values captured by event handlers and environment/theme values read directly.
- The memo caches construction only. Element identity, keyed reconciliation,
  layout, paint, transient control state, and retained rendering remain owned by
  the runtime.
- There is no implicit dependency collection, background invalidation, or
  lifecycle hook. A missing key component is a caller-visible correctness bug,
  not a framework guess.
- Use one memo per independently invalidated subtree. The single-entry shape is
  intentional: multi-entry retention would need an ownership and eviction policy
  that this slice does not justify.
- `ViewMemo` is a handle backed by a private cell. Copying it aliases the same
  entry; callers should keep one owner per subtree instead of sharing a memo
  across unrelated call sites.
- `ViewMemo::stats()` returns a caller-readable snapshot of successful builds,
  cache hits, and cache misses. The counters live in the same private cell as
  the entry, so handles share them. They are not registered globally and do not
  enter `RuntimeInspectorSnapshot`, which only observes runtime-owned caches.

`ViewMemo` is an advanced core API. It is not re-exported from the app-loop root
facade because ordinary apps should learn `Feature`/`Program` first and only opt
into reconstruction caching after measuring a hot builder.

## Options Considered

### Option A: implicit dependency tracking

- Pros: callers cannot under-specify a key.
- Cons: requires observing reads through closures, adds hidden semantic state,
  and would need a second invalidation model alongside runtime reconciliation.

### Option B: cache at the runtime adapter boundary without an explicit key

- Pros: no app API.
- Cons: the runtime cannot know whether a builder closure captured changed
  model or message payload; structural `View` comparison cannot prove it safe.

### Option C: explicit single-entry memo

- Pros: reviewable dependency set, no implicit runtime state, direct A/B
  measurement, and a reusable primitive for a future component/control SDK.
- Cons: callers can declare an incomplete key; one entry per memo can thrash
  when a subtree alternates between many states.

## Consequences

- A skip is only as correct as the key. Call sites must use named record fields
  so the dependency set is reviewable.
- The memo is not a model store: it must not be used for application state,
  effect lifecycle, or save/restore. Surviving a frame saves view construction,
  not runtime or control state.
- `View::map` still owns message lifting. A memo caches the unmapped or mapped
  view exactly as built; changing a map layer requires a new key or memo.
- Apps and benchmarks can read memo effectiveness without hidden dependency
  tracking. A memo miss is counted before `build`; a build is counted after it
  returns, so a failed builder cannot be reported as completed work.

## References

- `docs/plans/done/architecture-priority-execution.md`
- `moui/core/view_memo.mbt`
- `moui/core/view_memo_test.mbt`
- `benchmarks/performance_budget/native/main.mbt`

# 0056: Devtools trace is caller-owned, sampled, and bounded

- **Date**: 2026-11-05
- **Status**: Accepted
- **Deciders**: wzzc-dev (agent-assisted architecture review)
- **Related**: plan `architecture-priority-execution` (W4.4), ADR 0049,
  ADR 0050

## Context

`AppRuntime::inspector_snapshot()` already exposes point-in-time runtime,
view-tree, layout, render, and semantics sections. `moui_devtools` formats that
snapshot and Studio keeps a short history of formatted summaries, but neither
can answer an interaction-level question: which message/effect counters moved,
which frame phases ran, whether caches hit, and which semantics nodes changed
between two stable points.

A runtime-owned event log would put string labels, payload capture, ring-buffer
retention, and overhead into the hot path before the first tool proves which
data it needs. Keeping complete Inspector snapshots per history entry would
also multiply tree-sized allocations and make retention depend on tree size.

## Decision

The first devtools trace slice lives in `moui_devtools` and is caller-owned:

- `DevtoolsTrace` samples an existing `InspectorSnapshot` at explicit
  application/tool boundaries. The runtime remains the source of truth and does
  not gain a trace store, message interceptor, or source-rewrite hook.
- The first sample establishes a comparison baseline. Later samples record
  counter deltas and a semantics-tree diff against the previous sample.
- Message and effect data is counter-based plus the existing structured effect
  descriptors. This slice does not retain typed `Msg` values or infer message
  names. A labeled message trace needs a separate explicit app/tool contract.
- Frame-phase data always includes rebuild/layout/paint/draw pass deltas.
  Millisecond timing is present only when the caller records a
  `profile_draw_frame` result; the trace does not pretend that stale timing
  belongs to the current sample.
- `ViewMemoStats` may be supplied by the caller. Memo counters remain
  caller-owned and are not registered globally.
- Retention is bounded twice: by the number of trace entries and by the number
  of semantics changes retained per entry. The recorder keeps one previous
  Inspector snapshot as its watermark, not a full snapshot per history entry.
  Truncated diffs retain true added/removed/changed counts and an explicit
  dropped count.
- Semantics comparison is by Inspector node id and structured fields (role,
  label, value, frame, tree shape, actions, and state flags). It is an
  observability diff, not a reconciliation or accessibility-tree authority.
- Text and JSON reports are renderings of the same retained trace. They do not
  mutate runtime state and do not promise state-preserving reload.

## Options Considered

### Option A: runtime-owned trace ring buffer

- Pros: callers cannot forget to sample, and every event is observable.
- Cons: adds hidden retention and diagnostic overhead to the hot path, requires
  generic message-label plumbing or payload capture, and duplicates lifecycle
  ownership already held by the runtime.

### Option B: retain a full Inspector snapshot per history entry

- Pros: any later comparison is possible without resampling.
- Cons: memory grows with both history length and tree size; most sections are
  repeated between entries, and retention becomes difficult to bound.

### Option C: caller-owned sampled deltas with one watermark

- Pros: no runtime hot-path storage, bounded memory, explicit sampling points,
  and a direct JSON/text result for existing tooling.
- Cons: the caller chooses boundaries; event-level names are not captured, and
  a missed sample collapses multiple turns into one delta.

## Consequences

- Devtools consumers must sample after meaningful turns or frames. The
  Showcase Diagnostics probe demonstrates one complete interaction; Studio can
  adopt the same API without changing the runtime boundary.
- Counter resets are clamped to the current counter value instead of producing a
  negative delta. The trace reports observation, not an audit log.
- The default limits are 64 entries and 128 semantics changes per entry. Tools
  may choose smaller bounds; larger retained traces need a separate plan and a
  memory budget.
- `moui_devtools` now directly depends on `moui/core` for the caller-owned
  `ViewMemoStats` value. It still depends on `moui/runtime` only for read-only
  diagnostic snapshots, not runtime mutation.
- Event-level message names, payload capture, source rewriting, and hot reload
  remain out of scope for this slice.

## References

- `docs/plans/done/architecture-priority-execution.md`
- `moui_devtools/trace.mbt`
- `moui_devtools/trace_wbtest.mbt`
- `examples/showcase/diagnostics.mbt`

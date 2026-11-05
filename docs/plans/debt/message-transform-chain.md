# Debt: Non-copying typed `View::map` transform chain

- **Status**: debt, blocked by language representation limits
- **Owner**: core/view API
- **Decision**: [ADR 0058](../../decisions/0058-recursive-view-map-boundary.md)

## Current behavior

`View::map` recursively copies the mapped adapter tree once per layer. Typed
event, text-command, semantics-action, and child mapping remain correct.

The deterministic 1k/10k benchmark records the cost. With a two-layer map, the
adapter copy count doubles while builder-cache node construction remains
unchanged. The timing impact is report-only because shared-host variance is
larger than the measured map-layer delta.

## Why it is parked

Removing the copy requires hiding the source message type in a reused subtree
while preserving a typed transform to the parent message. The current MoonBit
compiler does not support the required existential view, associated
source-message type, or polymorphic trait-object method. The rejected designs
and compiler evidence are in ADR 0058.

A lazy child mapping is not accepted as a fix: runtime rebuild traversal still
materializes the mapped child array.

## Reopen triggers

- MoonBit adds a supported existential/associated-type mechanism that preserves
  the four typed mapping surfaces.
- A measured application path spends a material share of frame time in map
  adapter construction after build caches are applied.
- A runtime traversal redesign can remove the materialization without erasing
  message dispatch or changing public view behavior.

## Acceptance when reopened

- Event messages, text-command results, semantics actions, and child mapping
  remain statically typed.
- Nested map layers no longer copy children or semantics arrays.
- Public view/event semantics remain unchanged.
- One-layer and two-layer benchmarks record adapter and subtree-copy deltas.
- No unchecked cast, dynamic message registry, or hidden runtime state is added.

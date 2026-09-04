# Plan: View-state slot storage beyond copy-on-write Map

- **Status**: debt
- **Goal**: Replace `ViewStateSlots`' `Map[DeclarationKey, Bytes]` with a
  cheaper persistent representation (indexed vector + linear scan, or a
  structural-sharing map) if slot writes ever show up in event-path profiles.
- **Non-goals**: changing the immutable-proposal contract — `with_slot` /
  `without_slot` return new `ViewStateContext` values so runtimes can
  validate an event or semantic action before committing; that stays.

## Context

`moui/core/view_state_slot.mbt` stores node-scoped transient state as
`DeclarationKey -> Bytes` behind `ViewStateContext`. Every effective write
copies the whole map (`values = self.slots.values.copy()`), and every read/
write encodes/decodes through the `ViewStateValue` `Bytes` codec.

## Why deferred

- Slot population is tiny: 12 `ViewStateSlot::new` descriptor sites repo-wide,
  and a node typically holds 0–2 live slots (drag gesture, focus-like state),
  so the map copy is a handful of entries — replacing it buys microseconds
  while adding a custom storage to maintain in `moui/core`.
- The codec cost that remains (encode/decode per write/read) is bounded by the
  same small slot count, and the `Bytes` encoding keeps slot identity
  type-safe (`view_state_type_key` in the key) across element reuse.
- A benchmark proving dominance is the honest trigger; none exists today.

## Re-evaluate when

- `benchmarks/full_cycle` or a new event-path benchmark shows state-write
  copying or Bytes codec traffic dominating rebuild/event cost.
- Slot usage grows materially (many slots per node, or large payloads such as
  text-edit selections), making per-copy or per-codec costs superlinear in
  practice.
- Undo/rollback or time-travel of view state becomes a product need, where a
  purpose-built persistent store would pay for itself.

## Acceptance
- [ ] Benchmark evidence pinning the current cost on an event-heavy tree.
- [ ] Replacement storage keeps `ViewStateContext` immutability, passes the
  existing slot round-trip tests, and does not widen the public surface.

## Decision log
| Date | Decision |
|------|----------|
| 2026-09-04 | Recorded as debt from the implementation audit (view-framework-remediation); copy-on-write kept — small slot counts make the win speculative. |

## Progress
| Date | Note |
|------|------|
| 2026-09-04 | Debt note created; storage, codec, and copy sites measured by reading `moui/core/view_state_slot.mbt`. |

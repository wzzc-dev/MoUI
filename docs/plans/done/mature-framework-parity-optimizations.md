# Plan: mature-framework parity optimizations

- **Status**: done (2026-11-09, released as `0.6.0`)
- **Goal**: Close the six gaps found by comparing MoUI against Flutter,
  SwiftUI, Compose, Qt and iced. Each point lands as its own commit; the
  program ends with a synchronized release-line bump and release notes.
- **Scope**: `moui/runtime`, `moui/core`, `moui/views`, `moui_i18n`, plus
  RFC/ADR text where an invariant is involved.

## Starting point (verified 2026-11-08)

MoUI already has persistent element reuse, keyed diffing, event-driven
redraw, a real raster thread, a gesture arena and virtualization. The
gaps below are the ones that remain open, not re-implementations of
existing machinery.

## Points

1. **Declaration key re-encoding tax** — landed. Every reused node
   re-encoded the previous side's canonical `DeclarationKey` bytes on each
   reconcile even though `declaration()` is pure over stored fields.
   `ElementNode` now carries `declaration_cache`, assigned only at the two
   sites that assign `view_node` (mount and reconcile).
2. **`layout changed` → full damage** — landed. Layout moves clean subtrees
   that never enter the paint-dirty id set, so the pipeline used to force
   the whole surface whenever layout ran. `DamageIndex::placement_changes`
   now compares screen-space `paint_bounds` and overlay fade opacity per
   element id between the previous and current render trees and unions the
   moved ids' previous+current bounds. `full_damage_reason` split into an
   absolute class (structure, environment, viewport, activation, exit
   ghosts) and a placement class that move tracking may narrow.
3. **Retained layers re-emit full payload** — landed, no RFC needed. P16
   constrains the payload and its ownership, not how the runtime assembles
   it: the wire still carries `BeginRetainedLayer` + the complete payload +
   `EndRetainedLayer` every frame and renderer sessions still own
   hit/update/eviction. The avoidable cost was re-deriving that payload by
   walking the subtree when it had already been flattened at paint time.
   The flattening now uses the frame traversal itself, so the replayed
   bytes are the bytes the walk produced, and the second near-duplicate
   command walker was deleted. Empty overlay sources no longer emit no-op
   transform scopes — that is what previously made the two paths disagree.
4. **Feature-level skipping** — landed via RFC 0008. ADR 0057 already
   supplied the explicit builder-key contract ADR 0053:82-83 asked for;
   RFC 0008 adds the composition-boundary facade over it.
   `Feature::with_view_key` declares the content key next to the view body;
   `runtime_view_cached` / `ScopedFeature::view_cached` build through a
   caller-owned `ViewBuilderCache` with a per-mount builder key. Nothing is
   inferred and no lifecycle is owned. The second-adopter evidence was
   `examples/mo_workbench`'s four hand-rolled package-global
   `Ref` + `physical_equal` memos, which are the shape ADR 0057 forbids.
5. **RFC 0007 intrinsic sizing** — accepted and landed for `text()`.
   `size` is already a minimum, so defaulting width/height to zero makes
   the measured size win unless the caller asks for a deliberate fixed box.
   `wrap=true` now takes the incoming constraint as the line width instead
   of collapsing an unset width to a 1px floor. No declaration-schema
   change: `Text.layout` already keys on `size`. Proposals 2 (buttons and
   inputs) and the example pixel-size cleanup stay deferred.
6. **i18n too thin** — landed. `moui_i18n` now carries CLDR cardinal plural
   categories (zero/one/two/few/many/other, including the CLDR 42+
   exact-million `many` for fr/pt/es/it), locale integer/decimal formatting
   with `minimumGroupingDigits` and lakh/crore grouping, and locale date
   ordering. `Translator::translate_count` resolves through the category
   with an `.other` fallback instead of hardcoded en/zh branches.

## Validation

Smallest router loop per point (`moon test <pkg-dir> --target native`),
then `sh scripts/check.sh --profile pr` before each commit. Every point
landed with a mutation-sensitive test on the wired path: the declaration
cache, the placement scan, the retained-payload replay, and the feature
view key each have a test that fails when the optimization is disconnected.
Release closure follows ADR 0065 (synchronized line, staged publish).

## Closure (2026-11-09)

All six points landed as one commit each, then the synchronized line advanced
to `0.6.0` (`docs/releases/0.6.0.md`); ADR 0065's Status records the `0.6.x`
continuation.

| Point | Commit |
|---|---|
| 1 declaration cache | `493e0733c` |
| 2 placement-level damage | `15486a661` (+ showcase expectation `70ffa11a2`) |
| 3 retained-payload replay | `5f4bfbc0c` |
| 4 Feature skipping (RFC 0008) | `d8e514504` |
| 5 RFC 0007 intrinsic sizing | `1ab1e7934` |
| 6 CLDR i18n | `d7aadb8e6` |

Deferred, not silently dropped: RFC 0007 proposal 2 (button/input defaults)
and the example pixel-size cleanup; `examples/mo_workbench`'s four
package-global memos are now eligible to migrate onto RFC 0008 but that
migration is its own work, not part of this program.
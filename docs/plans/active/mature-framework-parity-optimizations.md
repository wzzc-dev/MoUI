# Plan: mature-framework parity optimizations

- **Status**: active
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
2. **`layout changed` → full damage** — `runtime_render_pipeline.mbt`
   forced the whole surface whenever layout ran, because layout moves
   clean subtrees that never enter the paint-dirty id set. Add
   placement-level move tracking: compare screen-space `paint_bounds`
   (and overlay fade opacity) per element id between the previous and
   current render trees, and union the moved ids' previous+current bounds
   into the damage region. Split `full_damage_reason` into an absolute
   class (structure, environment, viewport, activation, exit ghosts) and
   a placement class that move tracking may narrow.
3. **Retained layers re-emit full payload** — P16 requires the full
   declaration plus payload every frame and forbids `DrawCachedLayer`, so
   a cache hit still costs O(total commands). RFC required: the invariant
   is deliberate (renderer owns hit/update/eviction).
4. **Feature-level skipping** — Compose strong-skipping analogue at
   `Feature::runtime_view(Self, Model, ViewEnvironment)`. ADR 0053:82-83
   explicitly leaves automatic builder reuse behind a separate
   builder-key contract/RFC. `examples/mo_workbench` hand-rolls
   package-global `Ref` + `physical_equal` memos today, which is the
   demand evidence and the anti-pattern ADR 0057 forbids.
5. **RFC 0007 intrinsic sizing** — still Draft. `text()` defaults to a
   160x32 box used as a *minimum*, so short strings reserve dead space.
   Accept the RFC and make text content-sized by default.
6. **i18n too thin** — `moui_i18n/translator.mbt` hardcodes en/zh plural
   rules, with no CLDR coverage and no locale number/date formatting.

## Validation

Smallest router loop per point (`moon test <pkg-dir> --target native`),
then `sh scripts/check.sh --profile pr` before each commit. Points 3 and
4 additionally need the RFC accepted and the invariant table updated.
Release closure follows ADR 0065 (synchronized line, staged publish).
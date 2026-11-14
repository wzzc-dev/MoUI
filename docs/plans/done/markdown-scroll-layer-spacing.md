# Markdown scrolling layer spacing

- Status: complete (2026-11-14)
- Goal: preserve the heading-to-list distance while a retained rich-text block
  crosses the viewport origin in MoMark's native Skia editor.
- Scope: internal runtime paint-layer bounds; retain the proven rich-text
  blank-run window fix and add app coverage for the built-in sample.

## Diagnosis and implementation

1. Compare heading and first-list draw positions using the built-in sample.
2. Verify that retained layer bounds and their commands use the same owning-view
   coordinate system. A heading's insets must stay at a constant offset inside
   its cached layer as the layer moves across zero.
3. Fix only the mismatched bounds seed; preserve the cache key and revision so
   scrolling continues to reuse immutable layer content.

## Validation

- A runtime regression must fail before the fix, including positive and negative
  origins, heading insets, and command overflow.
- Run focused runtime, rich-text and MoMark app tests and native checks/build.
- Inspect the sample in the native editor while scrolling both directions.

## Result

The runtime seeded a paint layer's bounds at `(0, 0)` even though its commands
already used the owning view's coordinates. Near the viewport origin a heading
therefore moved inside a stationary retained frame without changing the cache
identity or content revision. Skia replayed pixels at the previous inset while
the following list kept moving. Seeding the bounds with `layer.frame` keeps the
cached content's local coordinates invariant and also avoids scroll-dependent
cache dimensions.

The sample app regression failed before the fix because the heading's offset
inside its retained frame changed from 169.11 to 165.11 on the first scroll.
After the fix it covers both caret positions from the screenshots and both
scroll directions, including a negative heading position. The runtime tests
cover positive/negative origins and preserve command overflow bounds.

- Native app, rich-text, and runtime suites: 1069 tests passed.
- Final focused regressions after formatting: 4 tests passed.
- Native checks, rich-text/runtime wasm-gc checks, and macOS Skia build passed.
- Rebuilt and repackaged the native app, then visually checked the sample as
  the heading moved through the top edge and returned. The heading and list
  moved together with stable spacing.

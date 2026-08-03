# Plan: Website scroll performance

- **Status:** completed
- **Goal:** Make Website canvas scrolling responsive by removing avoidable DOM and input work from the Web presentation path, while preserving text selection and accessibility.
- **Non-goals:** replacing the canvas renderer with browser-native scrolling, changing Website content/interaction design, or weakening semantic accessibility.

## Acceptance

- [x] The selectable-text layer reuses spans rather than replacing the full DOM layer on each frame.
- [x] A wheel event over selectable text reaches the canvas once, without an injected pointer-move event.
- [x] The semantic DOM reconciler avoids writes for unchanged geometry, attributes, values, and focus state.
- [x] Website showcase thumbnails are WebP assets sized for their rendered cards, with source generation and tests updated.
- [x] Focused Web/backend tests, Website tests/build, and browser smoke pass.

## Ownership

| Area | Owner |
|---|---|
| Text-selection DOM reconciliation and wheel forwarding | `moui/render/webgpu_adapter/runtime.js` |
| Semantic DOM reconciliation | `moui/backend/web/semantics_dom.js` |
| Screenshot asset generation and Website asset mapping | `scripts/gen-website-showcase-assets.mjs`, `website/app` |
| Product enablement of selectable text | `website/web_wasm` |

## Delivery sequence

1. Add testable, incremental reconciliation for selectable text and remove the redundant synthetic pointer move from wheel forwarding.
2. Add property-level semantic DOM reconciliation so scroll frames do not rewrite unchanged DOM state.
3. Generate resized WebP showcase thumbnails and update asset/source tests.
4. Run focused package, Website, generation, and browser smoke checks; record before/after DOM counts.

## Progress

| Date | Note |
|---|---|
| 2026-07-18 | Plan created after profiling showed full selectable-text replacement, full semantic DOM writes, and redundant wheel forwarding. |
| 2026-07-18 | Incremental selection/semantic reconciliation, WebP previews, package checks, and browser verification completed. |

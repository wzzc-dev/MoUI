# Plan: Web canvas input-router consolidation

- **Status:** completed
- **Goal:** Make `moui/backend/web` the single owner of trusted browser pointer
  routing, preserve canvas-first rendering/hit testing, and remove synthetic
  DOM input redispatch.
- **Non-goals:** changing the published `wzzc-dev/window` ABI, adding a DOM
  scroll model, or retaining mouse/touch fallback paths for browsers without
  Pointer Events.

## Acceptance

- [x] A canvas host routes each Pointer Events or wheel event directly to the
  MoUI wasm pointer ABI at most once.
- [x] Semantic and text-selection overlays no longer construct or dispatch
  synthetic PointerEvent, MouseEvent, or WheelEvent values.
- [x] The pointer ABI contains only values consumed by the MoUI runtime;
  browser-only pointer identity remains in the router for native capture.
- [x] Wheel default prevention follows the runtime result, preserving browser
  zoom and native marked controls.
- [x] Website and Playground wasm-gc builds and focused Web/runtime tests pass.

## Ownership

| Area | Owner |
| --- | --- |
| DOM event capture, coordinates, delta normalization, native capture, semantics DOM | `moui/backend/web` browser asset |
| Input consumption and capture result | `moui/runtime`; Web consumes it synchronously while `HostRuntimeDriver` retains redraw scheduling |
| Web-specific wasm export decoding | `moui/backend/web` MoonBit bridge |
| Website/Playground root exports and preview asset wiring | their thin `web_wasm` / host entrypoints |

## Delivery sequence

1. Reduce the synchronous pointer ABI to runtime-consumed values and make its
   result distinguish consumed scrolling from pointer capture.
2. Move semantic DOM management into the browser host asset and route canvas,
   semantics, and selection overlays through one capture-phase router.
3. Delete synthetic-input forwarding and obsolete no-Pointer-Events fallback
   code; retain native marked controls as an explicit browser escape hatch.
4. Update all Web wasm wrappers, Playground dynamic-compile source, assets,
   and tests; generate interfaces and run focused builds/tests.

## Decision log

| Date | Decision |
| --- | --- |
| 2026-07-19 | Keep the direct MoUI Web ABI. The repository Website resolves the published `window` dependency rather than the local `window/` submodule, so adding a second MoUI pointer ABI there would not simplify the deployed path. |
| 2026-07-19 | Keep three browser runtime assets: DOM host, WebGPU runtime, and lazy Canvas2D fallback. Merge the small semantics asset into the DOM host rather than mixing renderer and DOM-host ownership. |

## Verification

### CI postflight

- [x] Keep the established maintenance-line budgets unchanged by moving the
  runtime pointer-dispatch facade and Web pointer-ABI bridge into focused,
  package-local files.
- [x] Re-run the PR profile and the Website packaging check after the split.


- `node scripts/test-browser-runtime-events.mjs`
- `node scripts/test-web-semantics-dom.mjs`
- `moon test moui/runtime --target native`
- `moon test moui/backend --target native`
- `moon test moui/backend/web --target wasm-gc`
- `moon build website/web_wasm --target wasm-gc`
- `moon build website/playground/web_wasm --target wasm-gc`
- `moon build examples/showcase/web_wasm --target wasm-gc`
- `moon build examples/markdown_editor/web_wasm --target wasm-gc`
- `node scripts/generate-playground-assets.mjs --out <temporary-dir>` followed
  by `node scripts/test-playground-assets.mjs --root <temporary-dir>`

The browser presentation smoke rendered Showcase and observed the direct
pointer bridge without console errors. Its release-evidence mode remains
blocked by unrelated missing Showcase IME/grapheme markers, so it does not
constitute a passed full presentation-evidence run.

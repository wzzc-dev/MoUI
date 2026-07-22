# Plan: Website Showcases single-scroll presentation

- **Status:** completed
- **Goal:** Keep screenshot virtualization while making the Website Showcases
  page a single, clearly indicated scroll surface with accurate platform/source
  metadata.
- **Non-goals:** fabricate replacement screenshots or claim mobile Showcase
  runtime evidence that has not been recorded on matching devices.

## Delivery

1. Add an optional visible-indicator policy to `moui/views::lazy_grid`, with
   focused coverage and no behavior change for existing callers.
2. Make the Website Showcases route a fixed body without duplicating the
   top-navigation route title, while retaining concise explanatory copy; its
   `lazy_grid` owns the available body height and the only scroll state.
3. Add per-card status text, context-specific accessible source actions, and
   platform-specific source paths. Mark retained historical mobile captures as
   such rather than presenting them as current window-hosted evidence.
4. Keep the existing WebP assets until a reproducible capture run can replace
   them; validate package tests, Website wasm build, and release packaging.
5. Make lazy virtual lists observe their `ScrollState`, so scrolling rebuilds
   the rendered window instead of exposing the initial placeholder rows.

## Acceptance

- [x] Wheel/touch input over a card drives one visible, canvas-owned scroll
  viewport; there is no nested Website body scroll for this route.
- [x] The grid remains virtualized and has an enabled scroll indicator.
- [x] Each card conveys platform/evidence status and exposes a uniquely named
  source action targeting its owning entrypoint.
- [x] Existing historical screenshots are explicitly labelled, not represented
  as new platform-runtime proof.
- [x] Scrolling to the end replaces initial Showcase rows with the remaining
  cards on both wide and compact layouts.

## Verification

- `moon test moui/views --target native`
- `moon test website/app --target native`
- `moon build website/web_wasm --target wasm-gc`
- `node scripts/test-browser-runtime-events.mjs`
- `sh scripts/package-website-site.sh --out <temporary-dir>`

All verification commands passed on 2026-07-19. The Website runtime regression
test asserts that a wheel over a card updates `showcase_grid_scroll` without
rendering a duplicate Showcases page heading. Virtualized list controls also
watch their `ScrollState`, and the Showcase regression verifies that a wheel
to the end mounts the Android card that was not in the initial window.

# Plan: Mo Desktop Example

- **Status**: active
- **Goal**: Advance `examples/mo_desktop` from a runnable desktop simulation to a product-quality macOS-inspired UI: coherent system chrome, window behavior, controlled Finder/Safari/system surfaces, and reproducible Web plus macOS Skia presentation evidence, while preserving the shared app and thin-entrypoint boundary.
- **Non-goals**: Reimplement every reference app, add framework controls, or claim new renderer/platform capability.

## Acceptance

- [ ] The shared app provides a responsive lock screen and desktop shell.
- [ ] Finder, Safari, the app launcher, notifications, and Control Center have meaningful typed interactions.
- [ ] Light/dark appearance, Finder navigation/search/view mode, sliders, toggles, and window controls update through the model.
- [ ] Web wasm-gc and macOS Skia entrypoints remain thin runtime wiring.
- [ ] Focused native tests, Web build, native entrypoint build, static validators, and browser screenshots pass.

## Product-quality expansion (2026-07-18)

The original implementation establishes the product shape. The remaining work is
organized as vertical slices so visual polish and real interaction progress
together rather than accumulating static mock surfaces.

1. Capture current Web and native-Skia presentation baselines at desktop and
   compact sizes; record concrete interaction gaps before changing layout.
2. Make desktop-window behavior feel native: coherent traffic-light semantics,
   maximized/compact geometry, predictable overlay dismissal, and focused
   regression coverage for each transition.
3. Deepen Finder, Safari, launcher, Control Center, and Notification Center
   flows only where a model-owned interaction and a visible state change can be
   exercised end-to-end.
4. Refine typography, translucency, spacing, focus/accessibility affordances,
   and image-resource behavior against macOS reference captures without
   introducing platform implementation dependencies into `app/`.
5. Maintain native/wasm app tests, Web screenshot evidence, and macOS Skia
   build/real-renderer smoke evidence as each slice lands.

## Decision log

| Date | Decision |
|------|----------|
| 2026-07-17 | Use a shared `app` package plus `web_wasm` and `macos_skia` entrypoints. |
| 2026-07-17 | Reproduce the reference's primary workflows rather than create non-functional stubs for every dock app. |
| 2026-07-17 | Use an image asset for the wallpaper and MoUI views/canvas composition for all desktop chrome. |

## Progress

| Date | Note |
|------|------|
| 2026-07-17 | Reference lock screen, desktop, Finder, launcher, Control Center, dark mode, and Safari states captured and analyzed. |

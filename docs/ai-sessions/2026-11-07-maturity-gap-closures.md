# 2026-11-07: Maturity gap closures (15-commit arc)

- **Goal**: Work through the gap analysis against mature UI frameworks
  (Flutter / SwiftUI / Compose / Qt) — every session-feasible slice, one
  commit each.
- **Outcome**: 15 commits delivering the interaction feel, developer
  experience, regression infrastructure, and missing-control slices. The
  remaining recommendations require native FFI, matching-host/device
  evidence, or an architecture RFC and are now recorded as four active
  follow-up plans.

## Commits

| # | Commit | Slice | Key files |
|---|---|---|---|
| 1 | `fdf2784ac` | macOS a11y capability raised after the AX L2 probe pass | `moui/backend/macos` |
| 2 | `221c8f5c6` | Scroll fling inertia: runtime frame pump + offset-space velocity + decay physics | `moui/runtime/frame_pump.mbt`, `moui/views/controls/scroll_view_*` |
| 3 | `d0d1fbf75` | Golden image regression harness (Sun raster, hash baselines, pixelmatch gates, content probe) | `moui_tests/golden/` |
| 4 | `e991185a5` | `frame_trace_overlay` phase-stacked sparkline + p95 stats | `moui_devtools/overlay/overlay_frame.mbt` |
| 5 | `8a9309623` | `range_slider` two-thumb control (non-crossing drags, runtime drag slot) | `moui/views/slider/range_slider.mbt` |
| 6 | `7c25279a8` | §7 gestures end to end: `AppEvent::Gesture`, host decode, runtime pump dispatch, `View::on_gesture` | `moui/runtime/frame_pump.mbt`, `moui/core/event.mbt` |
| 7 | `79783b870` | Showcase trackpad-gesture evidence card + app-level assertions | `examples/showcase/app/diagnostics/` |
| 8 | `1b4573f02` | `inspector_tree_view` + `trace_timeline_view` visual surfaces | `moui_devtools/overlay/` |
| 9 | `facbbcc2c` | `carousel` swipeable page surface (windowed pages, paint-only pull, dots) | `moui/views/controls/carousel.mbt` |
| 10 | `f0bbfc8da` | `refresh_indicator` pull-to-refresh (damped pull, arming, spinner latch) | `moui/views/controls/refresh_indicator.mbt` |
| 11 | `7c0755186` | Automatic push/pop route transitions (`RouteTransition`, frame-tick stamping) | `moui/views/navigation/route_transition.mbt` |
| 12 | `36cc9a99d` | RTL step 1: `TextLayoutInput.direction` + fallback caret mirroring | `moui/core/text_layout.mbt` |
| 13 | `5c556797c` | RTL step 2: `views/text` consumes direction end to end | `moui/views/text/*` |
| 14 | `b386e5460` | Two-finger pinch/rotation recognizer (`View::on_pinch`, id-stream tracking) | `moui/core/modifier_pinch.mbt` |
| 15 | `14e8b526e` | `color_picker` token-grid control (contrast rings, hex semantics) | `moui/views/controls/color_picker.mbt` |

## Recurring patterns worth keeping

- **Frame pump reuse**: the §7-adjacent frame pump (dispatching
  `AppEvent::FrameTick` into latched subtrees) powered both the fling
  inertia and the automatic route transitions — the "authoritative state
  can only change through the event path" rule held throughout.
- **Runtime-owned transient slots** for pointer-driven state (carousel drag,
  range-slider thumb, refresh pull, pinch recognition) so model rebuilds
  mid-gesture never drop the gesture. Byte-length vs decode-check mismatches
  bit three times (carousel, pinch) — always derive the encoded length from
  the write sequence.
- **Eager-message trap**: `on_tap(fixed_message)` evaluates its argument at
  build time; per-tap payloads need `on_tap_with_frame`'s lazy handler.
- **Honesty preserved**: every known limit landed documented (refresh
  capture-composition limit, enter-only route transitions, RTL single-run
  contract, swatch-grid-only picker) rather than silently overclaimed.

## Remaining recommendations → follow-up plans

| Recommendation | Plan |
|---|---|
| Native text provider completion (DirectWrite/fontconfig + Windows IME evidence) | `docs/plans/active/text-provider-native-completion.md` |
| GPU inter-frame partial repaint | `docs/plans/active/gpu-partial-repaint.md` |
| In-process hot reload | `docs/plans/active/in-process-hot-reload-rfc.md` (RFC required) |
| RTL step 3: native base-direction plumbing | `docs/plans/active/rtl-step3-native-base-direction.md` |

These require Windows/Skia native builds, matching-host GPU evidence, or an
architecture ADR — outside a headless agent session.

## Validation state at archive

`moon check --target native` clean; core 171/171, views 39/39,
views/text 45/45, controls 51/51, backend/macos 50/50, backend/web 40/40
(wasm-gc), golden 4/4, devtools 5/5 + overlay 11/11, navigation 11/11 all
green. Static guards (guidance-consistency, api-surface,
maintenance-baseline, release-module-closures, doc-references) pass with
every budget ratchet carrying its reason.

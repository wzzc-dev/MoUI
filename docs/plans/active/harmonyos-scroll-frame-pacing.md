# Plan: HarmonyOS scroll frame pacing and a11y pump cost

- **Status**: active
- **Goal**: Make the HarmonyOS frame loop pace on the display refresh as
  intended, remove the per-pump full semantics projection from the a11y pump,
  and instrument the frame path so the device-observed "frames frozen while
  input flows" phenomenon can be attributed on the next capture.
- **Supersedes**: none. Extends the 2026-10-30 arc recorded in
  `memories/repo/harmonyos-window-hosted.md` ("Frame pacing",
  "Why wheel scrolling froze after a few pixels").
- **Non-goals**: full-surface redraw damage contract
  (`docs/plans/debt/full-surface-redraw-per-frame.md`), scroll-message
  batching / per-tick `request_root_rebuild` churn, C event-ring
  synchronization, any `window/` MoonBit source change (no window-dev-mode),
  downgrading `ViewLayoutDirty` on the scroll path (pinned by
  `moui/runtime/view_runtime_test.mbt`).

## Evidence (device captures 2026-11-02, showcase, EGL GPU route)

- **Frame pacing was the dominant fixed cost.** With `active_frame_ms=17`
  the vsync wait (60 Hz period 16.7 ms) timed out on essentially every frame
  and the fallback slept another 17 ms: a 34 ms pure-wait floor plus ~19 ms
  of present work locked every frame to a **53 ms median across 39k frames**
  (p90 54 ms, hourly buckets 14:27-14:56 all identical) — 19 fps with zero
  input, because the probe page keeps the runtime perpetually dirty
  (`needs=true` on every frame; damage reason rotates through
  "program model changed" / "dirty region covers most of the surface").
- **The MoonBit pipeline is not the bottleneck.** With the pipeline timed via
  `profile_draw_frame` (now wired to the host clock on all embedded
  platforms): build/layout/paint/draw average **0.6 ms** per frame.
- **The present path is.** Whole-`render_frame` wall time (Skia Ganesh
  full-surface raster of 2090x1324 + `eglSwapBuffers`):
  **p50 30.8 ms, p90 142.7 ms** — matching
  `docs/plans/debt/full-surface-redraw-per-frame.md`.
  Final attribution (2026-11-02 evening): the GPU is real hardware
  (Maleoon 916, OpenGL ES 3.2), `eglSwapBuffers` costs only **~1.2 ms**, the
  command list is tiny (**156 commands/frame**) — so the ~29 ms lives in the
  Ganesh encode + GL submit for a full-surface re-raster whose content did
  not change. Per-frame layout-cache behavior on the same page:
  **648-1906 misses vs ~24 hits** (origin-keyed place/render caches miss on
  every scroll tick) — the structural items below, cheap in the MoonBit
  pipeline but the reason every frame re-encodes everything on the GPU
  side.
- **Final attribution with exhaustive in-frame timing** (`frame=` field vs
  segment sums): the render pipeline itself has **zero unaccounted time**
  (in-frame gap = 0.0 ms on every sampled frame). The remaining jank is
  **intermittent allocation-driven GC pauses landing in the host arm tail**
  (first frame 73.8 ms after heavy startup allocations, ~27 ms on scroll
  frames): every frame allocates a fresh command array, a semantics delta,
  and diagnostic strings. The picture-cache/retained-layer fix reduces both
  the encode cost and this allocation churn with one mechanism.
- **Android is affected too, by a different route.** The Android window-hosted
  session runs the **CPU raster presenter** (`moui/backend/android/
  android_present.cpp`, no EGL-direct GPU surface route exists yet):
  SurfaceFlinger timestats on the emulator show the SurfaceView layer at
  **13-15 fps during active scrolling** (39-48 frames per gesture window,
  droppedFrames=0 — the compositor presents everything the app produces,
  the app just produces frames that slowly). The CPU route pays the
  full-frame readback + ANativeWindow copy per frame on top of the same
  full-surface raster. An Android GPU-direct surface route (ANativeWindow +
  EGL, mirroring the HarmonyOS host binding) is the parallel fix.
- Cross-platform summary: the full-surface redraw contract is shared code
  (`moui_skia_renderer`); desktop hardware absorbs it inside the vsync
  budget, both mobile platforms do not (HarmonyOS 19-30 fps via GPU direct,
  Android 13-15 fps via CPU raster on an emulator with a fast host GPU).
- The wheel dispatch chain was cleared end to end: host-sim test
  (`wheel dispatched` -> dirty -> frame presented), device queue probe
  (`pending=0 taken=1` per pump), and the a11y cursor publishing once at
  startup instead of per pump.

## Changes

- `moui/backend/harmonyos/window_hosted.mbt`
  - Pass `active_frame_ms=17` to `run_app_with_frame_pacing`: the cond-wait
    can now reach the next refresh boundary (60/90/120 Hz all arrive sooner
    than 17 ms). The wait stays gated on `needs_redraw`; idle keeps the 4 ms
    sleep. MoUI call-site change only — no `window/` source edit.
  - `pump_accessibility` keeps the last published `SemanticsGeneration`:
    `Unchanged` skips projection **and** publish (the native
    `mbw_harmonyos_accessibility_publish` unconditionally replaces the
    snapshot pointer — publishing the empty Delta/Unchanged projection would
    wipe the node table ArkUI is still reading). On change, publish the
    authoritative `Full` snapshot and advance the cursor.
  - New `RedrawRequested` arm in `handle_window_event` logging
    `frames=N→M needs=a→b` through the existing image-status hilog shim.
- `moui/backend/common/embedded/hosted_window_backend.mbt`
  - `read_semantics` gains `since~ : @core.SemanticsGeneration? = None`
    (pass-through to `AppRuntime::read_semantics`); existing callers stay
    source-compatible.

## Deferred (follow-up plans)

- Present-failure message surfacing (renderer records `RenderFrame` +
  `err.message()` internally; needs a renderer→backend diagnostic channel).
- Scroll rebuild churn: per-tick `on_scroll` → `request_root_rebuild`.
- Unsynchronized C event ring (`native_harmonyos_host.c`, drop-oldest at 256).

## Validation

- `moon test moui/backend/harmonyos --target native`,
  `moon test moui/backend --target native`,
  `moon test moui/backend/common/embedded --target native` (focused).
- `moon fmt`, `moon info` (public API change), then
  `node scripts/validate-api-surface.mjs`,
  `node scripts/validate-maintenance-baseline.mjs`,
  `node scripts/validate-guidance-consistency.mjs`.
- Manual matching-device capture (next session): scroll the Showcase images
  page, confirm `frames` advances per refresh during glide, and use the new
  `redraw frames=… needs=…` lines to attribute any remaining frozen-counter
  windows to "render attempted, not presented" vs "redraw not requested".

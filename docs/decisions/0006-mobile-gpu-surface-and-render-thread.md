# ADR 0006: Mobile GPU Surface And Render Thread Ownership

- Status: Accepted
- Date: 2026-07-11

## Context

The raster mobile route copies a complete pixel frame to each platform
presenter. iOS additionally constructs CoreGraphics/UIKit image objects. This
is useful for compatibility and testing but is not the final performance
architecture.

## Decision

`SkiaGpuNative` describes the direct `HostGpuSurface` route. It does not change
`SkiaRasterNative`. Platform templates expose `auto`, `skia-gpu`, and
`skia-raster`; `auto` remains raster until platform-specific promotion gates
pass.

The runtime/UI thread owns `AppRuntime`, layout, and event dispatch. A renderer
thread exclusively owns the GPU context, window surface, Skia GPU objects, and
persistent GPU caches. Immutable, deeply owned render packets cross a
capacity-two latest-wins mailbox. Lifecycle and context control messages are
ordered and never dropped.

Direct presentation means Metal drawable-backed Skia on iOS, Vulkan with GLES
fallback on Android, and EGL/GLES first on HarmonyOS. Full-frame readback or
platform image intermediates are forbidden on the GPU production path.

## Consequences

- Raster remains a tested fallback and can retain runtime state after GPU
  recovery failure.
- Cached layers, glyph atlases, images, and pipelines are generation-scoped,
  persistent, budgeted, and invalidated on context loss rather than resize.
- A descriptor, offscreen GPU smoke, or mailbox unit test is not GPU runtime
  completion. Promotion requires matching-device performance, memory,
  recreation, and context-loss evidence.

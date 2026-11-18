# Web canvas readback: a p5-local CanvasRasterizer for wasm

- **Status**: done (2026-11-17)
- **Goal**: Give the p5 Web entry the same `save_canvas` / `load_pixels` /
  `capture_image` readback the macOS entry has, without touching the shared
  web renderer runtime.

## Design

1. New example package `examples/p5_sketch/web_raster` (wasm-gc only):
   - Serializes the p5 command list into a compact, purpose-built JSON
     (clear/rect/rrect/stroked-rect/path/text/image/clip/transform/opacity/
     layer ops) with an own string escaper — no dependency on the derived
     `DrawCommand` JSON shape.
   - Externs against a **p5-local `"p5_raster"` import namespace**: string
     handle build, `capture(width, height, stringHandle) -> bytesHandle`,
     byte accessors. The namespace is supplied by the example's own
     `index.html` through `bootMouiWasmGcApp({ imports: { p5_raster } })`, so
     `moui_web_renderer/runtime.js` stays untouched.
   - JS capture parses the JSON, replays the ops onto an offscreen 2D canvas
     at scale 1 (source-over + `copy` for the Source layer), then
     `getImageData` hands straight RGBA back.
   - `install()` registers the rasterizer as the p5 default; `self_test()`
     rasterizes a 2x1 red/green scene and prints the pixels on the boot log.
2. `web_wasm/main.mbt` calls `install()` + `self_test()` before the runtime
   starts, mirroring the macOS entry's `skia_raster.install()`.
3. Text rendering uses `fillText`/`strokeText` with the serialized font size/
   weight (system fonts, same as the live canvas path).

## Verification results

- `moon test examples/p5_sketch/web_raster --target wasm-gc`: 2 passed —
  serializer covers clear/rect/path-clip/text/image/layer ops, string
  escaping, and brush fallback-color degradation.
- Browser (`?debug=1` boot log): `p5 web readback self-test: left=(255,0,0)
  right=(0,255,0)` — the full loop (MoonBit JSON → JS offscreen 2D →
  getImageData → byte handles → `Image::from_rgba`) returns correct pixels,
  and the app boots to Running with the three demos interactive.
- `moon build examples/p5_sketch/web_wasm --target wasm-gc` green.

## Follow-ups

- OffscreenCanvas worker path, device-pixel-ratio capture scale, and caching
  the encoded overlay across frames remain open.

# Web Renderer Path-Mesh Retention

- The `webgpu` host import module has **two** providers:
  `moui_web_renderer/runtime.js` (WebGPU) and
  `moui_web_renderer/canvas2d_runtime.js` (Canvas2D fallback). The fallback is
  swapped into an already-instantiated module through
  `stable.__moui_replace_imports`, so any import declared in
  `moui_web_renderer/adapter_host_imports.mbt` but missing from a provider
  breaks that provider at the first replaced call, not at instantiation.
  `scripts/test-webgpu-runtime-path-mesh.mjs` compares the declared imports
  against both providers; run it after adding or renaming a host import.
- `DrawPath` crosses the wasm-gc boundary as a comma-joined decimal payload:
  one `string_append_char` import per code point, ~150 calls per 15-double
  vertex, because wasm-gc has no shared linear memory. The adapter therefore
  keeps `path -> host mesh handle` in `webgpu_path_mesh_cache`
  (`moui_web_renderer/adapter_path_mesh_cache.mbt`); a hit costs one
  two-scalar call (`draw_path_mesh_cached`) instead of re-serializing and
  re-parsing. The host owns the parsed values and applies transform and opacity
  at push time, so a retained mesh stays correct under later state.
- Handle protocol: `upload_path_mesh` returns 0 only when the renderer is
  unknown (the adapter raises), `draw_path_mesh_cached` returns host status 6
  (`invalid resource`) for a handle the host dropped, and the adapter forgets
  that path and re-uploads in the same call. Never treat 6 as fatal geometry:
  it is the recovery path for a page runtime swap or device loss.
- Cache policy: bounded 256 entries, least-recently-used with dead slots first,
  keyed by exact structural `PathSpec` equality (no hash, so no collision risk).
  This is the one place where a linear-scan `Array` cache is acceptable even
  though `memories/repo/skia-renderer-perf.md` forbids reverting the Skia layer
  cache to `Array`: `PathSpec` derives `Eq` but not `Hash`, the scan is capped at
  256, and a miss costs the same transfer the old single-call path already paid.
  If this cache ever needs to grow, add a structural hash key first.
- Measured on a downstream animated scene (2026-10-30, Chrome headless WebGPU,
  1280x800, 4 interleaved rounds per variant): with path geometry repeated
  across frames the frame median went 417-433 ms -> 283 ms, 2.58-2.64 fps ->
  3.61-3.77 fps. With nearly every path regenerated each frame only ~10% of
  draws hit, median held at 50 ms and fps rose 19.75-20.34 -> 22.69-23.95.
  A one-slot cache measured the same as the pre-change baseline
  (20.00-20.42 fps), so splitting upload from draw is free; the gain comes from
  the retained handles.

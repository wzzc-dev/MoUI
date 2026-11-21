# Renderer and GPU route (2026-07 → 2026-11)

Durable summary of the renderer/GPU sessions. Canonical status lives in `docs/renderer-capability-report.md` and the ADRs; this page keeps the reasoning and the traps that are not visible in the code today.

## 2026-07-12 — Skia layer cache indexing + damage-region partial clear

Outcome: both optimizations landed, `moui/render/skia` 104/104, daily profile green.

- Layer cache moved `Array` → `Map` (O(1) lookup/eviction); separate identity index, byte-size accounting, bounded admission records (512).
- Renderer consumes `DrawFrame.damage` for partial surface clearing with conservative fallbacks (`Empty` → full surface, scope commands present → full surface, too many rects → full surface). Benefit is bounded until the runtime produces `Rects`.
- Benchmark (same fixture): cached-layer paint 4.75×–28.5× faster than full paint, but only 1/5 scenarios produced `Rects` damage. ADR 0007. MoonBit traps: `panic()` takes no args (use `abort`), `.is_some()` is deprecated, `Map.get` returns a mutable reference, no `Set`, `moui/render/skia` needs `--target native`.

## 2026-07-14 — DrawFrame damage clip fix

Outcome: fixed intermittent blank text in Markdown/Code editor on hover.

- Root cause: runtime supplied a leading full-surface `Clear` on top of partial clear and cached-layer skip. `DrawFrame.clear_color` is now the only clear authority; runtime's duplicate frame `Clear` was removed; command-only host/Web adapters lower an explicit clear. Skia clips the complete command stream to the damage rects after logical scaling.
- Added protocol/adapter/HiDPI/hover-cached-sibling pixel tests. ADR 0009.

## 2026-07-14 — GPU promotion Wave A + native GPU default

Outcome: Wave A tooling landed (macOS promoted; other platforms later); then product `auto` switched to `SkiaGpuNative` on all native Skia platforms when a host GPU surface exists (ADR 0006), matching-device seven-gate manifests demoted to evidence.

- `tools/moui/gpu_promotion_scaffold` writes schema-valid pending manifests, gap reports, gate inventory and smoke-log ingest; `scripts/record-gpu-promotion-smoke.mjs` stays a thin orchestrator.
- macOS 600 s Metal performance gate passed (samples 59873, p95 ≈ 10.96 ms, dropped ≈ 0.63 %, input proxy ≈ 0.66 VSync) before flipping `Macos.gpu_promoted=true`.
- `auto`/`skia-gpu` select GPU on mobile too; explicit `skia-raster` remains, sticky raster recovery after terminal GPU failure, fallback-Skia packaging stays raster.

## 2026-07-15 — HarmonyOS GPU direct present

Outcome: true HVD direct present (Skia → EGL window backbuffer → `eglSwapBuffers`), verified on a real HVD (`egl present ok=1 swap=1 w=2090 h=1324`).

- Root causes fixed: `GrBackendRenderTargets::MakeGL` argument order (`(w,h,samples,stencil)`, stencil ∈ {0,8,16}), `kTopLeft_GrSurfaceOrigin` (BottomLeft painted black), `eglSwapInterval(1)` + `eglMakeCurrent(window)` before flush, and sticky-raster only on PresentFailed/SurfaceUnavailable.
- Evidence log marker is `egl present ok=1 swap=1`; `present flushed` marks the fallback path.

## 2026-10-27 — ADR 0044 L0: instrument the renderer route, then stop it

Outcome: L0.1/L0.2 delivered, route parked at L0.

- L0.2: renderer-neutral native text model moved to `moui/render/native_text` (imports `moui/core` only); wgpu re-exports the moved names.
- L0.1: performance harness drives frames through the `RendererProvider` contract under `MOUI_PERFORMANCE_PROVIDER`; only the concrete Skia path stays budget-gated, control runs (`skia-neutral`, `sun`) emit their own runner identity and are never budget-validated.
- Kill-gate branch answered negatively for the direct-GPU route's performance case; two of three owner motives died in L0. ADR 0044.

## 2026-10-27 — L0.5: text providers leave the wgpu module

Outcome: new published module `wzzc-dev/moui_text_providers` holding `coretext`, `cosmic_text`, `directwrite`, `fontconfig`, `text_protocol`.

- Reason: P14 forbids a `role: "renderer"` module importing another renderer module, so the providers could never be reused by a second renderer while inside `moui_wgpu_renderer`. Role is `binding` (like `moui_skia`/`moui_sun`), not `renderer`.
- No compatibility shims at old paths; seven consumers were repointed. Registration had to reach every explicit module enumeration (release modules, API budget, maintenance scan, source-file policy roots, backend ownership, provider-manifest validators, external-consumer CI, prebuild ownership assertions). Lesson: a moved file leaves any gate that enumerates modules by name.

## 2026-10-27…28 — L1–L4: `moui_metal_renderer` (no Skia, no wgpu)

Outcome: delivered through the plan's L4 legs; product class `experimental` (ADR 0045, invariant R8). Final frame: 8–9 hand-written externs (image release moved it to 9), 53 mbti lines, 74 module tests + 23 CoreText provider tests + 11 shared text-conformance tests.

- Contract: `RendererProvider::bind` reads `surface.native_surface()`, builds two pipelines over one vertex layout (solid colour; same colour scaled by glyph coverage), presents drawables itself. Geometry comes from shared lowering (`lower_draw_commands`, `tessellate_path`); text coverage from the injected text engine.
- Identity: `RendererBackendKind::NativeDirectGpu` / `RendererFamily::DirectGpu`; the literal `Metal` name was rejected by the platform-surface guard in `moui/render`.
- Capability report now has a machine-checked Metal column; every one of 17 rows is checked against ink, and a second "consequence" probe asks what the row's op actually paints for all 17 features (clip cuts 64 px to ~16, blur puts light outside the shape, rounded-box corners 60/64, opacity at 128, …).
- Presentation gate reads real ink: the host copies the drawable and reports `MOUI-METAL-PRESENT … ink=` (60.6 % of a Retina surface); the gate rejects outside a 0.5 %–99.5 % band. That is coverage, not in-window pixel fidelity. Known limitation: the route ignores `frame.damage` and repaints the whole surface on load; partial repaint needs a retained backbuffer or `framebufferOnly = NO` plus a copy.
- Images: one texture per source with an LRU resident-bytes budget (`image_textures_released`); eviction under pressure, not reclamation on dispose (`evict_disposed` has no callers). `AsyncImage` scoping and `ShaderEffect` (four built-ins drawn in the fragment, no fallback) closed the remaining L4 rows. Release artifact 4,101,856 B, below the `sun` figure the route was priced against.

## Pitfalls worth keeping

- A green validator can hide a `scanned=0` hole; pair every gate with an end-to-end drill that deletes the thing it watches (`declaration-gate-pairing`).
- Benchmark runs on shared hosts swing ±40 %; compare warm second runs, never a single run (`benchmark-variance`).
- Provider-level text engines own shaping; renderers must not paint shaped glyph ids through an unrelated primary typeface (CJK blanking) — see `text-and-editors.md`. `packageBytes` in the performance harness links every renderer, so it cannot measure a route's size; use release artifacts.

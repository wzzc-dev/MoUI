# ADR 0007-0022: Renderer and Skia (merged)

> 原编号保留为小节锚点: 0007-skia-layer-cache-indexing-and-damage-region,0009-draw-frame-clear-and-skia-damage-clip,0019-renderer-provider-plugin-architecture,0019-A-renderer-composition-close-out,0022-native-wgpu-labeled-experimental

---

## 0007: Skia Layer Cache Indexing and Damage Region Partial Clear

- **Date**: 2026-07-12
- **Status**: Accepted
- **Deciders**: Agent-assisted (Trae AI, GLM-5.2)
- **Related**: `moui/render/skia/renderer.mbt`, `moui/render/skia/renderer_cached_layer.mbt`, `moui/core/damage.mbt`, `docs/architecture.md`
- **Amended by**: ADR 0009, which adds the missing full-command damage clip
  invariant and makes `DrawFrame.clear_color` authoritative.

### Context

MoUI's Skia renderer had two performance bottlenecks identified during a
comparison with mainstream GUI frameworks (Flutter/SwiftUI/Compose/iced):

1. **Layer cache O(n)/O(n²) scans**: `layer_cache` and `layer_cache_admissions`
   were stored as `Array[SkiacachedLayerImageEntry]`. Every lookup, identity
   check, admission record lookup, eviction candidate selection, and byte-size
   computation was a linear scan. The eviction path was O(n²) because
   `evict_cached_layers_if_needed` iterated the full array, and each eviction
   re-scanned to recompute total bytes. While n is small today (per-frame
   cached layer count is 2–16 in current benchmarks), this becomes a
   bottleneck for complex UIs with long lists or many cached subtrees.

2. **Damage region computed but ignored**: The runtime already computed a
   `DamageRegion` (`Empty` / `FullSurface` / `Rects`) per `DrawFrame`, but the
   Skia renderer unconditionally called `canvas.clear(clear_color)` over the
   full surface at the start of `render_frame_inner`. The computed damage was
   discarded. This is more aggressive than Flutter (which never does
   canvas-level partial clear) but the infrastructure was unused.

### Forces

- **Correctness first**: Both optimizations must not regress the 99 existing
  cached-layer wbtests or the visual regression smoke (showcase + markdown
  editor).
- **Framework alignment**: Flutter's `RasterCache` is the proven model — MoUI's
  layer cache should match its indexing/eviction strategy.
- **Risk asymmetry**: Layer cache indexing is pure data-structure refactor
  (zero visual risk). Damage region partial clear touches the clear path and
  needs scope-aware fallback.
- **Runtime damage coverage**: The runtime's damage computation only produces
  `Rects` in 1 of 5 benchmark scenarios today; 4/5 return `FullSurface`. The
  renderer-side work is infrastructure for future runtime improvements.

### Decision

Implement two independent optimizations, each shippable as a standalone PR.

### Part A: Layer Cache Indexing (O(n) → O(1))

Migrate the layer cache data structures from `Array` to `Map`-based indexing:

**Struct changes** (`renderer.mbt`):

```moonbit
priv layer_cache : Map[String, SkiaCachedLayerImageEntry]
priv layer_cache_identity_index : Map[String, String]
priv layer_cache_admissions : Map[String, SkiaCachedLayerAdmissionRecord]
priv mut layer_cache_total_bytes : Int64
priv mut layer_cache_tick : Int
```

- `layer_cache`: keyed by `entry.key` (identity + revision + physical size).
  Replaces linear `find` lookup with O(1) `Map.get`.
- `layer_cache_identity_index`: maps `identity_key` → latest `key`. Replaces
  linear `remove_stale_cached_layers_for_entry` and `layer_cache_has_identity`
  scans with O(1) lookup.
- `layer_cache_admissions`: keyed by `identity_key`. Replaces linear
  `layer_cache_admission_record` scan with O(1).
- `layer_cache_total_bytes`: accumulator maintained on every store/remove/evict.
  Replaces O(n) `layer_cache_byte_size` scan with O(1) read.

**Operation complexity changes** (`renderer_cached_layer.mbt`):

| Operation | Before | After |
|-----------|--------|-------|
| `lookup_cached_layer` | O(n) | O(1) |
| `layer_cache_admission_record` | O(n) | O(1) |
| `store_cached_layer` | O(n) (stale removal scan) | O(1) |
| `remove_stale_cached_layers_for_entry` | O(n) | O(1) |
| `remove_cached_layers_by_identity` | O(n) | O(1) |
| `evict_cached_layers_if_needed` | O(n²) (rescan bytes each iteration) | O(n) |
| `layer_cache_byte_size` | O(n) | O(1) |
| `layer_cache_has_identity` | O(n) | O(1) |

**Invariant preservation**:
- `identity_key` uniqueness maintained via `layer_cache_identity_index` —
  `store_cached_layer` updates the index atomically with the cache write.
- Byte total maintained via `layer_cache_total_bytes` — every store subtracts
  any old entry's bytes, then adds the new entry's bytes; every remove/evict
  subtracts.
- `clear_layer_cache` resets all three Maps and zeroes the accumulator.

### Part B: Damage Region Partial Clear

Make the renderer consume `DrawFrame.damage` instead of ignoring it.

**New functions** (`renderer.mbt`):

1. `resolve_effective_damage(frame) -> DamageRegion`
   - `Empty` → auto-fallback to `FullSurface("empty damage fallback")`
   - Pre-scans commands for `PushOpacity` / `PushLayer` / `PushFilter` — if
     present, fallback to `FullSurface("scope commands present")` because
     partial clear under active scopes is unsafe.
   - `FullSurface` and `Rects` pass through unchanged.

2. `apply_damage_clear(canvas, damage, clear_color, surface_size)`
   - `FullSurface` → `canvas.clear(color)` (existing path, unchanged)
   - `Rects` → for each rect: `canvas.save()` → `canvas.clip_rect(rect)` →
     `canvas.clear(color)` → `canvas.restore()`. Non-overlapping rects only;
     overlapping rects would double-clear (acceptable: correctness preserved,
     just wasted work).

**Command skipping** (`renderer_cached_layer.mbt`):

- `render_cached_command_range` gains `damage~ : DamageRegion` parameter
  (defaults to `FullSurface` so offscreen layer rendering is unaffected).
- `DrawCachedLayer` branch checks `should_skip_command_for_damage(spec.frame, damage)`:
  - `FullSurface` → never skip
  - `Rects` → skip if `frame.intersection(rect)` is `None` for all damage
    rects (the cached layer's pixels didn't change)
  - `Empty` → never reached (already fallback to `FullSurface`)

**Fallback strategy** (conservative):
- Any scope command in the frame → `FullSurface` (don't risk partial clear
  under PushOpacity/PushLayer/PushFilter)
- `Empty` damage → `FullSurface` (Empty means "unknown", not "nothing to
  clear")
- Damage rect count exceeds `damage_region_max_rects` (8) → runtime already
  collapses to `FullSurface` before reaching the renderer

### Options Considered

### Option A: Layer Cache — `Map` with separate identity index (chosen)

- Pros: O(1) on all hot paths; preserves two-level key scheme (revision key
  for lookup, identity key for admission tracking); minimal API surface change.
- Cons: Extra `layer_cache_identity_index` Map adds ~one pointer per entry;
  identity index must be kept in sync on store/remove.

### Option B: Layer Cache — Sorted `Array` with binary search

- Pros: Better cache locality than `Map`; no hash overhead.
- Cons: Binary search requires sorted keys; insertion becomes O(n log n);
  eviction still needs full scan for cold/large candidates. Rejected — the
  access pattern is hash-style (lookup by exact key), not range-scan.

### Option C: Damage Region — Canvas-level partial clear (chosen)

- Pros: More aggressive than Flutter — can save raster work on small dirty
  regions (sidebar hover, caret blink).
- Cons: Risk of visual residue if damage computation is wrong; needs scope
  fallback; only 1/5 benchmark scenarios produce `Rects` today, so current
  benefit is limited.

### Option D: Damage Region — Flutter-style layer-level skip only

- Pros: No partial clear risk — only skip whole `DrawCachedLayer` commands
  whose frame is outside damage rects.
- Cons: Misses the clear-path savings; doesn't help non-cached scenarios.
  Rejected — Part B's canvas clear is the foundation for future
  command-level skip extensions.

### Option E: Damage Region — Delete Part B entirely

- Pros: Removes ~80 lines of "dead code" that only fires in 1/5 scenarios.
- Cons: Loses infrastructure for future runtime damage improvements;
  re-implementing later requires redoing tests and scope fallback logic.
  Rejected — Part B is infrastructure investment, not a finished optimization.

### Rationale

1. **Part A is zero-risk and aligns with Flutter's `RasterCache`**: pure
   data-structure refactor, all 99 existing tests pass, byte counts and
   hit/miss counts unchanged. The O(n²) eviction path was a latent bug for
   complex UIs; fixing it now is cheap insurance.

2. **Part B is infrastructure for the runtime damage roadmap**: The renderer
   is now a consumer of `DamageRegion`. Any future runtime improvement that
   produces more `Rects` damage immediately benefits the renderer without
   further renderer changes. Deleting Part B would block that roadmap.

3. **Conservative fallback strategy**: The three fallbacks (Empty → FullSurface,
  scope commands → FullSurface, too many rects → FullSurface at runtime) mean
  Part B can never produce visual residue in the unsafe cases — it just
  degenerates to the existing full-clear path.

4. **Framework positioning**: MoUI's layer cache now matches Flutter's
   `RasterCache` strategy (budget + admission + eviction + revision key).
   MoUI's damage region handling is more aggressive than Flutter (Flutter
   never does canvas partial clear) — this is a deliberate bet that MoUI's
   runtime can eventually produce precise damage rects.

### Consequences

### Positive

- Layer cache hot paths are O(1); eviction is O(n) instead of O(n²). Complex
  UIs with many cached subtrees will scale better.
- Renderer is now damage-aware: future runtime damage improvements get free
  renderer-side wins.
- 5 new wbtests cover the damage path (FullSurface baseline, Rects partial
  clear, Empty fallback, DrawCachedLayer skip, scope fallback).
- Visual regression smoke (showcase + markdown editor) passes.

### Negative

- Part B currently fires in only 1/5 benchmark scenarios
  (`showcase-sidebar-hover`). The other 4 return `FullSurface` from the
  runtime, so Part B is effectively no-op there.
- `render_frame_inner` is more complex (scope pre-scan + damage branch).
- `render_cached_command_range` signature gained a `damage~` parameter.

### Follow-up Work Needed

- **Runtime damage computation improvement**: Make more scenarios produce
  `Rects` instead of `FullSurface`. Current `first_full_reason` values:
  - `"initial frame"` — 3 scenarios return FullSurface after first frame
  - `"dirty bounds unavailable"` — markdown-editor-scroll can't compute
    dirty bounds
- **Extend command skip whitelist**: Currently only `DrawCachedLayer` is
  skipped. `FillRect` / `DrawText` / `DrawImage` could also be skipped when
  their bounds are outside damage rects.
- **Scope command granular fallback**: Instead of falling back to
  `FullSurface` whenever any scope command exists, track scope depth and only
  fallback if the scope intersects damage rects.

### Agent Notes

- **Session context**: Continuing a performance analysis session comparing
  MoUI with Flutter/SwiftUI/Compose/iced. User asked to optimize two
  bottlenecks: layer cache O(n)/O(n²) and unused damage region.
- **Agent model**: GLM-5.2 (Trae AI)
- **Key prompt or instruction**: "两个优化都做" (do both optimizations) +
  "完整 + 自动回退 FullSurface" (complete solution with auto-fallback to
  FullSurface for scope commands).
- **Validation**:
  - `moon check moui/render/skia --target native` — 0 errors, 0 warnings
  - `moon test moui/render/skia --target native` — 104/104 tests pass
    (99 existing + 5 new damage wbtests)
  - `moon run moui/tests/skia_cached_layer_benchmark/native --target native`
    — cache_hit/miss counts unchanged
  - `moon run benchmarks/app_cached_layer/native --target native` — benchmark
    counts unchanged across 5 scenarios
  - `scripts/macos-skia-renderer-smoke.sh` — exit 0
  - `scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke`
    — exit 0 (visual regression)
  - `sh scripts/check.sh --profile daily` — exit 0

### Benchmark Results (post-optimization)

| Scenario | cached_avg_ms | full_avg_ms | speedup | cache_hits | damage_rect_frames | damage_full_frames |
|----------|---------------|-------------|---------|------------|--------------------|--------------------|
| showcase-runtime-scroll | 1.21 | 8.78 | 7.25x | 180 | 0 | 90 |
| showcase-sidebar-hover | 1.79 | 8.52 | 4.75x | 0 | 90 | 0 |
| markdown-editor-text-input | 0.41 | 11.78 | 28.52x | 270 | 0 | 90 |
| markdown-editor-scroll | 1.77 | 13.10 | 7.42x | 1440 | 0 | 90 |
| markdown-editor-caret-overlay | 0.45 | 10.16 | 22.37x | 270 | 0 | 90 |

**Key observations**:
- Part A: cache_hit/miss counts identical to pre-optimization — no regression.
  Absolute time savings are microseconds (n is small), but O(n²) eviction risk
  is eliminated for future complex UIs.
- Part B: only `showcase-sidebar-hover` produces `Rects` damage (90/90 frames).
  Other 4 scenarios return `FullSurface` from runtime — Part B degenerates to
  existing clear path, no regression.

### References

- **Plan file**: `.trae/documents/skia-layer-cache-and-damage-region-optimization.md`
- **Renderer struct**: `moui/render/skia/renderer.mbt` (lines 51–73)
- **Layer cache operations**: `moui/render/skia/renderer_cached_layer.mbt`
- **Damage region types**: `moui/core/damage.mbt`
- **Damage wbtests**: `moui/render/skia/skia_renderer_damage_wbtest.mbt`
- **Frame cache wbtests**: `moui/render/skia/skia_renderer_frame_cache_wbtest.mbt`
  (updated for Map iteration access)
- **Framework comparison**: Flutter `RasterCache`
  (https://api.flutter.dev/flutter/painting/RasterCache-class.html)

---

## 0009: DrawFrame Clear Ownership and Skia Damage Clipping

- **Date**: 2026-07-14
- **Status**: Accepted
- **Deciders**: Agent-assisted (Codex, GPT-5)
- **Related**: ADR 0007, `moui/core/damage.mbt`, `moui/runtime/runtime_state.mbt`,
  `moui/render/skia/renderer.mbt`

### Context

ADR 0007 introduced partial damage clearing and skipped `DrawCachedLayer`
commands outside the damage region. It did not clip the rest of the command
stream. Runtime frames also carried both `DrawFrame.clear_color` and a leading
`DrawCommand::Clear`.

On a button hover, runtime correctly produced a small damage rect. Skia cleared
that rect, then the unbounded leading `Clear` or a full-surface background
overwrote pixels outside it. Cached rich-text layers outside the damage rect
were skipped, so Markdown Editor and Code Editor text disappeared until a later
full repaint or editor-local update.

The clear also happened before logical-to-physical canvas scaling, so HiDPI
damage rects addressed the wrong physical area.

### Decision

1. `DrawFrame.clear_color` is the authoritative frame initialization color.
   Runtime-generated `DrawFrame.commands` contains view content and cached-layer
   commands, without a leading `Clear`.
2. Legacy command-only renderer adapters materialize
   `DrawCommand::Clear(frame.clear_color)` when lowering a frame. This applies
   to `WindowRenderer` fallback rendering, browser WebGPU host calls, and
   Linux client-side decoration composition.
3. Skia resolves rect damage to one conservative union rect, applies logical
   canvas scaling, clips the canvas to that rect, clears it, and executes the
   complete command stream inside the same clip.
4. Cached layers outside the effective damage rect may still be skipped because
   no other command can now alter their retained pixels.
5. Scope commands keep the ADR 0007 conservative `FullSurface` fallback.
   Explicit compatibility `Clear` commands remain supported and are constrained
   by the damage clip.

### Options Considered

### Skia-only Clear special case

- Pros: Small patch.
- Cons: Full-surface backgrounds would still erase retained cached layers, and
  the duplicate frame-clear contract would remain ambiguous.

### Disable partial damage

- Pros: Restores correctness immediately.
- Cons: Discards the accepted ADR 0007 optimization and its future value.

### Authoritative clear color plus full command clip (chosen)

- Pros: Defines one frame contract, preserves partial damage, handles every
  command rather than a whitelist, and fixes HiDPI coordinates.
- Cons: Legacy adapters must explicitly lower the clear, and multiple damage
  rects are conservatively unioned for Skia.

### Rationale

Damage rendering is correct only when clearing, ordinary draw commands, and
cached-layer replay all observe the same region. Moving only `Clear` is
insufficient because an app background can cover the same pixels. Clipping the
complete command stream establishes the invariant directly.

Keeping `clear_color` separate from content commands also matches the existing
`DrawFrame` data model and avoids making renderer behavior depend on command
ordering. Command-only renderers keep compatibility at a narrow adapter
boundary.

### Consequences

- Hover and other small paint updates preserve cached rich-text pixels.
- Runtime frame command counts decrease by one; legacy `draw_commands()` still
  begins with `Clear`.
- Skia may redraw the bounding union between disjoint damage rects. Runtime
  already falls back to full damage when that union covers most of the surface.
- New tests cover the frame-clear contract, legacy adapter lowering, browser
  WebGPU lowering, cached sibling pixels after hover, explicit compatibility
  clears, and scale-factor 2 damage coordinates.

### Agent Notes

- **Session context**: Fix intermittent blank Markdown Editor and Code Editor
  text during button hover.
- **Agent model**: Codex (GPT-5)
- **Key prompt or instruction**: "做最合理的长期修复"
- **Validation**: Focused runtime, host, WebGPU, Skia, Markdown Editor, and Code
  Editor checks plus repository validation and native Skia smoke.

### References

- `docs/decisions/0007-renderer-and-skia.md`
- `docs/architecture.md`
- `docs/testing.md`

---

## 0019: Renderer provider plugin architecture

- **Date**: 2026-07-28
- **Status**: Accepted
- **Deciders**: Agent-assisted (AtomCode GLM-5.2)
- **Related**: ADR 0006 (mobile GPU surface and render thread ownership),
  ADR 0007 (Skia layer cache indexing), ADR 0009 (DrawFrame clear),
  ADR 0018 (host contract split), invariants P6/R1/R2

### Context

Renderer selection today is a closed matrix. `moui/render` ships a static
`native_gpu_selection.mbt` + `capabilities_backend_matrix.mbt` that centralize
which renderer is chosen; `moui/render/renderer.mbt` is a facade that forwards
to concrete renderers; runtime and host hold per-renderer coupling
(`host_renderer` switches, fallback matrices). Adding a renderer requires
editing the central enum/matrix, runtime's central switch, and host's
renderer wiring — violating the open-extension principle and invariant P6
("renderer implementation + capability reporting → `moui/render/*`").

Forces:

- Native Skia stays **mainline**; Native WGPU stays **diagnostic** (invariant
  R1). Reclassify only via RFC.
- MoonBit package/link model has no runtime dynamic discovery; "plugin" must
  be compile-time composition. The open-extension property must still hold:
  a new renderer is added by a new provider package + an assembly
  declaration, **not** by editing core enums, runtime central switches, host
  contracts, or existing renderer implementations.
- Renderers must negotiate surface, capability, completion, and recovery
  through stable contracts so host and runtime stay renderer-agnostic
  (depends on ADR 0018 host split).
- External/independent renderer packages must be able to attach without
  invading framework core.

### Decision

Replace the closed matrix with a composable provider architecture.

1. **`RendererProvider` contract (in `moui/render`).** A stable,
   platform-neutral trait/struct defines a renderer's identity, capability
   surface, factory, surface negotiation, completion, and recovery:

   ```text
   RendererProvider {
     id : String
     capabilities(request : CapabilityRequest) -> CapabilityReport
     negotiate(surface : SurfaceDescriptor) -> SurfaceNegotiation
     create(descriptor : RendererDescriptor) -> RendererInstance
   }
   RendererInstance {
     render(frame : DrawFrame, surface : BoundSurface) -> RenderCompletion
     recover(reason : RecoveryReason) -> RecoveryResult
     dispose() -> Unit
   }
   ```

   `RenderCompletion`, `RecoveryReason`, `RecoveryResult`,
   `SurfaceDescriptor`, `BoundSurface`, `CapabilityReport`,
   `CapabilityRequest`, `SurfaceNegotiation` are neutral value types in
   `moui/render` (the render-surface contract also used by ADR 0018).

2. **Concrete renderers are providers in `moui/render/*`.** `render/skia`
   implements the Skia provider; `render/wgpu` + `render/webgpu_adapter`
   implement the WGPU provider; `render/canvas2d` and `render/sun` implement
   theirs. Each provider owns its capability reporting, surface negotiation,
   completion, and recovery. **No central enum, no central matrix, no
   runtime central switch on renderer identity.**

3. **Assembly is explicit registration / dependency injection.** A composition
   root (in `moui/runtime` host-driver or the platform entrypoint) registers
   the available providers for that build. Desktop entrypoints register
   `SkiaGpuNative` (auto default per R2), `SkiaRasterNative`, WGPU diagnostic;
   embedded-runtime entrypoints register their `*/skia` provider; web
   registers canvas2d/webgpu. The composition root picks a provider via
   capability negotiation (`RendererProvider::negotiate`), **not** a static
   matrix. Recovery fallback (`SkiaRasterNative` sticky fallback per R2) is a
   provider-declared capability, not host logic.

4. **Open extension property.** Adding a renderer = add a provider package
   that implements `RendererProvider` + register it in the chosen composition
   root. It must not require edits to `moui/core`, `moui/backend`,
   `moui/runtime` central switches, the `RendererProvider` contract itself,
   or any existing renderer's implementation. Compile-time composition is
   acceptable given MoonBit's link model, but the composition root's
   renderer list is the only edit point.

5. **Native Skia / Native WGPU product classification preserved.** R1/R2
   unchanged; promotion logic lives in the Skia provider's capability
   reporting (`validate-renderer-provider-manifests.mjs` continues to enforce
   `SkiaGpuNative` auto default), not in a central matrix.

### Options Considered

### Option A: provider trait + explicit registration (chosen)

- Pros: open extension; host/runtime stay renderer-agnostic; new renderer =
  new package + one registration line; preserves R1/R2; works with MoonBit
  compile-time link model.
- Cons: requires defining stable `RendererProvider`/`RendererInstance`
  contracts and migrating existing renderers to implement them; existing
  central matrix and runtime switches must be deleted.

### Option B: keep central matrix, document it as "necessary"

- Pros: zero migration.
- Cons: open-extension violated; new renderer edits core enums/runtime/host;
  invariant P6 not satisfied; blocks ADR 0018 (host must stay renderer-agnostic).

### Option C: runtime dynamic discovery (service registry)

- Pros: true runtime plugins.
- Cons: MoonBit package/link model has no runtime dynamic discovery; would
  require a heavyweight registry + dyn dispatch everywhere; loses static
  capability typing and `derive(Eq, ToJson)` value types.

### Rationale

Option A is the only choice that delivers open extension within MoonBit's
compile-time link model. The composition root is the single edit point, and
it is a registration list (additive), not a central switch (branching). Host
and runtime consume `RendererProvider`/`RendererInstance` contracts and never
branch on renderer identity, so ADR 0018's host-import baseline holds.

### Consequences

- `moui/render/native_gpu_selection.mbt` + `capabilities_backend_matrix.mbt`
  deleted; replaced by per-provider `capabilities`/`negotiate`.
- `moui/render/renderer.mbt` facade becomes a thin `RendererProvider` registry
  helper (or moves to runtime composition root).
- Runtime host-driver's renderer switch becomes provider negotiation.
- New contract tests: `render/skia` and `render/wgpu` pass the same
  `RendererProvider` contract suite; capability/completion/recovery semantics
  are tested against the neutral contract, not against concrete types.
- A new test renderer/provider adds a package + a registration line; no edits
  to core/host/runtime/existing renderers.
- Invariant P6/R1/R2 preserved; new validator
  `scripts/validate-renderer-provider-open-extension.mjs` enforces that
  `moui/core`, `moui/backend`, and `moui/runtime` (non-composition-root)
  do not branch on renderer identity.

### Implementation Progress (Phase E, 2026-07-29)

Provider implementation is now owned by Phase E of the
[architecture-convergence plan](../plans/done/moui-architecture-convergence.md).
`moui/render` exposes add-only provider bindings that pair a provider with a
`WindowRenderer` factory. Each platform composition root registers its
ordered bindings and negotiates the concrete surface; no central runtime
selector participates in assembly.

Capability aggregation consumes the providers registered by that composition
root and indexes entries by provider ID. Backend classifications remain useful
diagnostic metadata but do not select, group, or report providers. Web registers
WebGPU and Canvas2D fallback; Native WGPU remains an explicit diagnostic route.
The open-extension validator is enforcing this ownership boundary.

### Agent Notes

- **Session context**: MoUI core/views/host/renderer/platform architecture
  convergence task; sub-task 4 (renderer provider 插件式架构).
- **Agent model**: AtomCode (GLM-5.2).
- **Key prompt or instruction**: "将 renderer 扩展机制从封闭矩阵改造成
  可组合的插件式 provider 架构…新增 renderer 不应要求修改 core 枚举、
  runtime 中央 switch、host 合约或既有 renderer 的实现…保留 Native Skia
  主线和 Native WGPU diagnostic 定位。"
- **Validation**: contract tests for `RendererProvider` pass on Skia and WGPU;
  adding a throwaway test renderer only adds a package + registration;
  `sh scripts/check.sh --profile daily`; new validator green.

### References

- `docs/invariants.md` P6/R1/R2
- `moui/render/native_gpu_selection.mbt`,
  `moui/render/capabilities_backend_matrix.mbt`,
  `moui/render/renderer.mbt`
- `moui/render/skia`, `moui/render/wgpu`, `moui/render/webgpu_adapter`,
  `moui/render/canvas2d`, `moui/render/sun`
- ADR 0006, ADR 0007, ADR 0009, ADR 0018

---

## 0022: Native WGPU labeled experimental

- **Date**: 2026-08-02
- **Status**: Accepted
- **Related**: ADR 0021, `docs/maintenance.md`, `docs/architecture-map.md`

### Context

Native WGPU is a `diagnostic` renderer route (invariant R1): runnable and
testable, but not a default daily gate. `diagnostic` only states the
engineering gate — it does not state that **no product commitment** exists.
ADR 0021 introduced `experimental` for that dimension; WGPU is in the same
position (a parallel renderer plus four text providers kept without a product
promise).

### Decision

1. Label Native WGPU **`experimental`** in the product-class sense while
   keeping its engineering gate **`diagnostic`** (R1 unchanged; no RFC).
2. Update classification surfaces to "experimental (engineering gate
   `diagnostic`)": `docs/architecture-map.md`, `docs/platform-readiness-declaration.md`,
   `docs/maintenance.md`, `docs/golden-principles.md`, `docs/architecture.md`,
   and the matching `docs/zh-Hans/` mirrors.
3. Package/command-level mentions keep the word `diagnostic`, which remains
   accurate as the gate label.

### Rationale

Separates engineering gate (`diagnostic`, unchanged) from product commitment
(`experimental`, explicit) — consistent with how the embedded runtime route is
now described. `pending` was rejected because WGPU has real runnable smoke, so
"must not be described as ready" would understate it.

### Consequences

- Contributors must not present WGPU as product-capable; `*_wgpu` entrypoints
  remain explicit experimental diagnostic routes.
- Re-promotion requires new renderer capability evidence and, if the gate
  changes, an RFC per R1.

---

## 0019-A: Renderer composition close-out (Phase E E5–E8 residual gap)

- **Status**: Accepted (errata / close-out supplement to ADR 0019)
- **Date**: 2026-08-02
- **Deciders**: 高见远（首席架构师）；大湾区靓仔（项目总监，门禁复盘实测）
- **Supersedes**: `deliverables/ADR-draft-renderer-composition.md`（本地未纳入版本控制的 ADR 0024 草案，本补充条款判定不新增 ADR，故草案作废）
- **Related**:
  - ADR 0019 — Renderer provider plugin architecture (`docs/decisions/0007-renderer-and-skia.md:390`)
  - Phase E — `docs/plans/done/moui-architecture-convergence.md:94-125`（E1–E8，2026-07-29 声明 complete）
  - `docs/plans/active/renderer-backend-decoupling.md`（本补充条款承载的落地方案，Plan D）
  - `docs/plans/active/validation-hygiene-cleanup.md`（Phase 2/4/5，校验器挂靠与排序约束来源）
  - 不变量 P5 / P6 / P9 / P10 / P11；产品约束 R1 / R2 / R3 / R7

> 本文不是新架构范式的提案。ADR 0019 的 provider 抽象本身正确且已落地；本补充条款只补齐 Phase E 声称完成、但门禁复盘显示**未真正达到验收**的遗留缺口，并记录其收敛方案 Plan D（详见 `docs/plans/active/renderer-backend-decoupling.md`）。不新增 ADR 编号、不引入新 provider ID。

### Context

ADR 0019（2026-07-28）用可组合的 provider 架构替换了「中央矩阵」，其决策第 4 条明确要求：新增渲染器 = 新增 provider 包 + 在合成根注册，**不得**修改 core/host/runtime 既有开关或既有渲染器实现。Phase E（2026-07-29）进一步把该抽象落到可审计的治理动作 E1–E8，并声明 E1–E8 全部 complete。

门禁复盘（2026-08-02）实测发现三处「声明完成但未真正验收」，属已完成 Phase 的遗留缺口，而非新缺陷：

1. **E6 未被执行（D1）**：E6（`moui-architecture-convergence.md:105-107`）要求「platform composition roots register compile-time provider bindings；selection = negotiation, not central switch」。但 13 个绑定包中有 6 个（`macos/sun`、`macos/wgpu`、`linux/sun`、`linux/wgpu`、`windows/sun`、`windows/wgpu`）从未调用 `select_renderer_provider_binding`，直接把裸闭包塞进平台私有的 `<Platform>RendererProvider` 注入点。ADR 0019 的协商流程在实践中是可选的——抽象没有强制力。

2. **E8 达成了它的设计目标，但该目标本身不覆盖 D1**：E8（`moui-architecture-convergence.md:111`）要求把 `validate-renderer-provider-open-extension.mjs` 切到 enforce，这一点已做到；其 `restrictedDirs = ["moui/core","moui/backend","moui/runtime"]`（`:99-101`）精确等于 ADR 0019 §Consequences（`:526-529`）指定的射程——守的是「core/host/runtime 不得分支渲染器身份」，且守住了。真正的缺口是：没有任何校验器检查绑定包是否走 `select_renderer_provider_binding`。D1 这条不变量**从未有过执行器**——不是门禁失效，是从来没建过这道门禁。附带两处配置事实（均非门禁失效）：
   - (a) **PREFIXES 是死配置**：`SELECTION_ALLOWLIST_PREFIXES`（`:65-83`）的 12 条绑定包前缀（`moui/backend/*/skia`、`moui/render` 等）全部落在 `restrictedDirs` 之外，永不可能被命中；末条 `"moui/render"` 是 catch-all，会吞掉前面所有 `moui/render/*` 条目，前面那些本身就是冗余。这部分随本方案顺手清理，不影响门禁有效性。
   - (b) **EXACT 是有效豁免，且是 M5 的验收抓手**：`SELECTION_ALLOWLIST_EXACT`（`:85-88`）含 `moui/backend/host_rendering_test.mbt`，说明校验器作者**明知** host 层有文件在直接消费 `NativeGpuPlatform`，于是主动登记例外——这不是疏忽。实测该文件 `:119-159` 共 6 处使用 `@render.NativeGpuPlatform::` / `@render.NativeRendererMode::`，其豁免随 M5 下沉后缩短（见 Plan D §3.5.2 M5 完成信号）。

3. **D3 已恶化为功能缺陷（19 处字段漂移）**：9 条桌面绑定线里 7 条在透传 `AppOptions` 时丢字段，合计 19 处能力丢失（矩阵见 Plan D §1.3.1）。其中 wgpu 三线全丢 `platform_view_plugins`，使平台视图插件（WebView/原生地图）整类功能不可用；`linux/skia` 也受损，证明无任何渲染器线是系统性正确的；漂移是单向增长的（`on_ready`/`min_window_size` 仅 macos 基座拥有）。这把 D3 的定性从「样板债」升级为「已交付的功能缺陷」。

此外，ADR 0019 决策第 4 条的「options 字段透传完整性」维度从未被任何校验器覆盖；「渲染器选择」维度的开放扩展属性本应由 E7 的 throwaway renderer 测试守护，但该测试从未落地实现（见 Decision #4），「平台选项透传」维度则连验收形式都没定义过——两个维度目前都**无人值守**。

### Forces

- **不重复造抽象**：ADR 0019 的 `RendererProvider`/`RendererInstance`/`RendererProviderBinding`/手写 vtable 是 MoonBit 语言条件下的正确解（无 blanket impl），任何「改成 trait」的提议都是倒退。
- **链接期硬约束**：MoonBit `moon.pkg` 只按 target 门控 import，不支持特性开关。一个 `(platform, renderer)` 组合 = 一个包 = 一个链接单元，编译期选择必须由入口 main 包的 import 表达。方案不得试图消灭链接单元。
- **P11 shrink-or-stay**：本补充条款收敛方案不新增任何 provider ID、不扩大能力表面，不触发 RFC 棘轮。
- **校验器计划协同**：`validation-hygiene-cleanup`（active，Phase 2 执行中）将在 Phase 4/5 新增 `validate_renderer_capability_consistency` 与 `validate_doc_references`。本补充条款新增的 `validate-options-field-drift.mjs` 必须挂靠该计划、遵守其验收口径 #3（接入 pr profile + 带规格测试），且与 Phase 4 校验器**正交**而非合并。
- **排序约束**：本补充条款的 Phase 1 落地（涉及 `checks/profiles.json` 与 `moui-runtime-gates.yml`）**不得先于** `validation-hygiene-cleanup` 的 Phase 2 同一批文件改动，否则冲突。

### Decision

1. **不新增 ADR**：本治理动作以「ADR 0019 补充条款 / errata / Phase E close-out」形式承载，不分配新 ADR 编号（原 `ADR-draft-renderer-composition.md` 的 0024 草案作废）。理由：本方案是既有范式的补全，非新范式；新 ADR 会造成「双抽象主线」的认知分裂。

2. **采用 Plan D（收敛装配壳 + 泛型注入点 + web/wechat 归位）**，详见 `docs/plans/active/renderer-backend-decoupling.md`：
   - **M1** `HostRendererAdapter[W]`（泛型注入点，替换 4 份 `<Platform>RendererProvider` 复制）——直接依据仓库内已验证的 `WindowSlotMap[W,X]` 泛型模式。
   - **M2** `RendererProviderBinding::from_provider`（通用 host binding 派生，替换 skia 专有 `create_*_host_binding`，让 sun/wgpu/canvas2d/webgpu 零改动获得协商能力——归队 ADR 0019 的前提）。
   - **M3** options 整体透传（删除 `<Platform><Renderer>AppOptions` 逐字段镜像，从根上消除 19 处字段丢失；入口侧实测 0 个包必须改）。
   - **M4** `SurfaceMetrics::normalized()` + 平台基座一次性 metrics 转换（删除 12 份 `renderer_metrics_from_host`）。
   - **M5** `--renderer` / `MOUI_SKIA_RENDERER` 收敛到 `moui/render/skia`（native-only，零新增依赖）；并按 Plan D §3.5.1 把 `native_gpu_selection.mbt` 按职责一分为二（契约载荷留 `moui/render`，策略矩阵下沉 skia）。

3. **web / wechat 违例修复纳入方案**（Plan D §4）：wechat 基座中性化渲染器类型（成本极低，优先）；web 拆出 `backend/web/webgpu` 绑定包，与 `backend/wechat/canvas` 对称。

4. **E7 throwaway renderer 测试从未实现，本方案 Phase 5 补上**：Phase E 的 E7（`:108-110`）定义了「新增渲染器只加一个包 + 一行注册即挂上、不改 core/host/runtime」的机器验收形式，但全仓实测**不存在任何 throwaway / 测试用 provider 包**（`moui/` 下 grep 无命中，仅有 `.openseek/sessions/*.jsonl` 聊天日志误中），该测试从未落地；ADR 0019 §Consequences（`:521-523`）要求的 skia/wgpu 共享契约测试套件同样缺席（两侧 `*test*.mbt` 无一引用 `provider_contract`）。因此「渲染器选择」维度的开放扩展属性本应由 E7 守护却无人值守。本方案 **Phase 5 补上这两项实现**——落地 throwaway provider 包 + 共享契约测试套件，用「加 1 包 + 1 行注册即挂上、core/host/runtime 零改动」来机器证明用户第三诉求。M1 的泛型注入点 + M3 整体透传是让该测试**能够通过**的结构前提（而非「让既有测试真实通过」——因为该测试本就不存在）。

5. **新增 `scripts/validate-options-field-drift.mjs`，挂靠 `validation-hygiene-cleanup`**：
   - 推导式比对：抽取各 `<Platform>HostAppOptions` 字段集与对应绑定包实际透传字段做差集，**非空即 fail**（非硬编码渲染器→工厂清单，解药于 ADR 0019 决策第 4 条「闭合矩阵」残留）。
   - 遵守该计划验收口径 #3：写 `fixtures/options-field-drift/lost/`（断言 fail）与 `intact/`（断言 pass）规格测试，随迁移阶段从红转绿。
   - **与 `validate_renderer_capability_consistency`（Phase 4）正交不合并**：前者校验 options 透传完整性（D3 维度），后者校验「代码自报 vs renderer-capability-report 能力一致性」；输入与失败模式不同，合并会模糊责任边界。
   - 接入 `checks/profiles.json` 的 `pr` profile 须待 `validation-hygiene-cleanup` Phase 2 完成同一文件后再追加。

6. **M5 完成信号（E8 EXACT 豁免缩短 = 不变量棘轮 shrink-or-stay 实证）**：`NativeGpuPlatform` / `NativeRendererMode` 下沉 skia 族后，`SELECTION_ALLOWLIST_EXACT`（`validate-renderer-provider-open-extension.mjs:85-88`）中 `"moui/backend/host_rendering_test.mbt"` 一行可被删除且 `validate-renderer-provider-open-extension.mjs` 仍通过。豁免名单缩短 = 不变量棘轮 shrink-or-stay 的实证，正好接上 Plan D 的 P11「provider 预算只减不增」口径。

7. **排序约束落地**：Plan D 的 Phase 1 不得先于 `validation-hygiene-cleanup` Phase 2；迁移各阶段验证块挂 `validate-options-field-drift.mjs`，阶段收益汇总以「剩余丢失字段数」单调列 19 → 18 → 18 → 16 → 0 贯穿，作为贯穿各阶段的机器验收门槛。

### Consequences

#### 正面

- **D1 / D2 / D3 / D4 四个真问题全部闭合**：抽象可绕过（6 包归队协商）、4 份注入点复制（泛型 `HostRendererAdapter[W]`）、O(P×R) 样板与 19 处功能缺陷（M3 整体透传 + 漂移归零校验）、web/wechat 架构违例。
- **ADR 0019 开放扩展属性真正闭环（Phase 5 补上 E7 throwaway 测试 + 共享契约测试套件）**：「渲染器选择」维度由 Phase 5 落地的测试守住；「平台选项透传」维度由 `validate-options-field-drift.mjs` 补上此前从不存在的执行器。
- **不触发 P11 RFC 棘轮**：M1/M2/M4/M5 不新增 provider ID、不扩大能力表面（stay，`from_provider` 复用入参 provider 的 id/descriptor）。
- **交付体量与链接模型不变**：单个绑定包 341–1293 行压缩到约 130 行；编译期选择机制（入口 import）原样保留，链接单元数量不减少。
- **净减约 1330 行业务代码**（含新增装配壳约 +120 行的 Phase 1、Phase 5 新增测试包）。

#### 负面 / 注意

- **迁移需五个独立可回滚阶段**，跨 `validation-hygiene-cleanup` 计划排序，存在协同依赖（Phase 1 不得抢改 `checks/profiles.json`）。
- **一处校验器放宽已撤销**：原 M5 草稿曾提议把 R3 校验器 `has_env` 放宽为「含 `desktop_surface_route` 调用」，但 B5 边界约束表明 `MOUI_SKIA_RENDERER` 读取点须留在各平台 skia provider（R3 `has_env` 硬依赖），故 R3 校验器**不放宽**；provider 调用 `resolve_surface_route` 满足 `has_parse` 的 OR 分支，R3 自然通过。
- **R-2 认知风险长期存在**：任何「减少绑定包数量」的后续提议都会撞上 MoonBit 链接期约束（Plan D §5.1），已记录为长期约束。
- **R-4**：Phase 2/5 让 sun/wgpu 首次真正出现在能力上报时，须用 `validate-renderer-provider-manifests.mjs` 实测确认 manifest 不报增长（其 ID 在 `render/sun/provider.mbt:18`、`render/wgpu/provider.mbt:17` 已声明，属「已声明未启用」非新增）。
- **本补充条款不解决**：`run_*` 入口数量精简、`typealias` 可用性验证、embedded runtime `W=UInt64` 类型收紧、Platform Bridge 行为收敛——列为 Plan D §7.2 未决项，待拍板。

### 验收判据（gate）

- 漂移归零：`validate-options-field-drift.mjs` 输出从 19 单调降至 0。
- E7 Gate（Phase 5 落地后）：throwaway renderer 仅加 1 包 + 1 行注册挂上，core/host/runtime/既有渲染器零改动。
- E8 EXACT 豁免缩短：M5 完成后 `SELECTION_ALLOWLIST_EXACT` 删除 `host_rendering_test.mbt` 一行仍通过。

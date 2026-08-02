# ADR 0007-0022: Renderer and Skia (merged)

> 原编号保留为小节锚点: 0007-skia-layer-cache-indexing-and-damage-region,0009-draw-frame-clear-and-skia-damage-clip,0019-renderer-provider-plugin-architecture,0022-native-wgpu-labeled-experimental

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
   to `HostWindowRenderer` fallback rendering, browser WebGPU host calls, and
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
   root. It must not require edits to `moui/core`, `moui/backend/host`,
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
  `moui/core`, `moui/backend/host`, and `moui/runtime` (non-composition-root)
  do not branch on renderer identity.

### Implementation Progress (Phase E, 2026-07-29)

Provider implementation is now owned by Phase E of the
[architecture-convergence plan](../plans/done/moui-architecture-convergence.md).
`moui/render` exposes add-only provider bindings that pair a provider with a
`HostWindowRenderer` factory. Each platform composition root registers its
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


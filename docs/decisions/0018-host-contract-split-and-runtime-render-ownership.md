# 0018: Host contract split — runtime/render ownership leaves `backend/host`

- **Date**: 2026-07-28
- **Status**: Accepted
- **Deciders**: Agent-assisted (AtomCode GLM-5.2)
- **Related**: ADR 0005 (mobile host channel ownership), ADR 0006 (mobile GPU
  surface and render thread ownership), ADR 0011 (platform product class),
  invariants P4/P5/P6

## Context

`moui/backend/host` is currently a thick package. Its `moon.pkg` directly
imports `wzzc-dev/moui/runtime` and `wzzc-dev/moui/render`, and the package
contains implementation that is not host-contract work:

- `host_runtime_driver.mbt` — runtime orchestration / lifecycle driver
- `renderer.mbt` — renderer completion wiring
- `host_surface.mbt` + `image_repaint.mbt` — surface attach/detach, GPU
  recovery, image snapshot repaint tracking
- `wall_clock.mbt` + `redraw_scheduler.mbt` — frame/wall-clock scheduling
- async image loader, completion source, layer cache glue

This bundles three distinct ownerships into one package: (a) platform-neutral
**host contracts** (`HostEvent`, `HostCmd`, services facade,
`EmbedderHostChannel`, capability summary), (b) **runtime lifecycle
orchestration**, (c) **render completion / GPU recovery / image snapshot /
layer cache**. Invariants P4 (runtime lifecycle → `moui/runtime`) and P6
(renderer implementation → `moui/render/*`) are violated by the import edges
`host → runtime` and `host → render`.

Forces:

- Mobile sessions (`android`/`ios`/`harmonyos`) share `EmbedderHostChannel`;
  that contract must stay in `backend/host` and remain platform-neutral.
- Platform adapters translate native callbacks into `HostCmd`/`HostEvent`
  only (invariant M6); they must not need to import runtime or render impl.
- Native Skia mainline and Native WGPU diagnostic both render through host;
  the host surface glue is render-result plumbing, not host contract.

## Decision

Split `backend/host` into three ownerships.

1. **`backend/host` = platform-neutral host contracts only.** Keep
   `HostEvent`, `HostCmd`, `HostService` facade, `EmbedderHostChannel`,
   `HostPlatformChannel`, capability summary, text-input session contract,
   window lifecycle **contracts**, window request **contracts**. The package
   imports only `moui/core` (neutral value types) and `wzzc-dev/window/core`
   (window handle contract). **Remove** direct imports of `moui/runtime` and
   `moui/render`.
2. **`moui/runtime` owns `HostRuntimeDriver` and runtime orchestration.**
   `host_runtime_driver.mbt`, `wall_clock.mbt`, `redraw_scheduler.mbt`, and
   the runtime-side subscription source adapters move to `moui/runtime`
   (or a `moui/runtime/host_driver` sub-package). Runtime owns lifecycle,
   frame pacing, redraw scheduling, subscription routing.
3. **`moui/render/*` owns renderer completion, GPU recovery, image snapshot,
   layer cache.** `host_surface.mbt`'s render-completion half,
   `image_repaint.mbt`, `renderer.mbt` completion glue, async image loader
   completion, and layer-cache indexing move to `moui/render` (render
   surface contract) or the specific renderer provider package that owns the
   resource. Window event **translation** (native → `HostEvent`) stays in
   platform adapters or a dedicated adapter helper, not host.

Allowed `backend/host` import set after the split:

```text
wzzc-dev/moui/core
wzzc-dev/window/core        # window handle contract only
wzzc-dev/window/dpi          # scale normalization contract
Milky2018/moon_accesskit     # accessibility bridge contract (neutral)
moonbitlang/core/encoding/utf8
# for "test" only: wzzc-dev/moui/views
```

Forbidden after the split:

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/render` (any)
- concrete platform backends (`backend/<platform>`)
- concrete renderer providers (`moui_skia`, `render/skia`, `render/wgpu`, …)

## Options Considered

### Option A: three-way ownership split (chosen)

- Pros: each ownership lands in the package named for it; import edges match
  invariants P4/P5/P6; platform adapters import only host contracts; new
  renderers/runtimes do not require editing host.
- Cons: one-time migration of ~10 files; need a render-surface contract type
  to bridge host surface attach/detach → render completion without host
  importing render.

### Option B: keep host thick, document the leak as "necessary"

- Pros: zero migration.
- Cons: invariant P4/P6 stay violated; platform adapters keep transitive
  runtime/render deps; blocks the renderer provider model (ADR 0019) because
  host would need to know each renderer.

### Option C: split runtime out, leave render glue in host

- Pros: smaller migration; runtime ownership clarified.
- Cons: render completion/GPU recovery/image snapshot still leak host; host
  still imports `moui/render`; does not satisfy the invariant or the
  requested "renderer completion, GPU recovery, image snapshot, layer cache
  均位于职责匹配的包".

## Rationale

Option A is the only choice that makes the import graph match the
ownership cheat sheet in `docs/architecture-map.md`. The render-surface
bridge is a small neutral contract (`RenderSurfaceRequest` /
`RenderCompletion` value types) that can live in `moui/render` and be
referenced by runtime + providers without host owning it. Mobile
`EmbedderHostChannel` is unaffected — it is a host contract, not runtime
orchestration.

## Consequences

- `backend/host/moon.pkg` no longer imports `moui/runtime` or
  `moui/render`. `moon info moui/backend/host` surface shrinks.
- New `moui/runtime/host_driver` (or files in `moui/runtime`) owns
  `HostRuntimeDriver`, wall clock, redraw scheduler.
- New render-surface contract in `moui/render` owns completion, recovery,
  image snapshot, layer cache glue; providers implement the surface.
- Platform adapters import only `backend/host` (+ their renderer provider);
  no transitive runtime/render deps.
- Invariants P5 tightened to "host contracts only"; P4/P6 reinforced.
- New validator: `scripts/validate-host-import-baseline.mjs` enforces that
  `backend/host/moon.pkg` imports neither `moui/runtime` nor `moui/render`.

## Agent Notes

- **Session context**: MoUI core/views/host/renderer/platform architecture
  convergence task; sub-task 3 (host 拆分).
- **Agent model**: AtomCode (GLM-5.2).
- **Key prompt or instruction**: "收缩 `moui/backend/host` 为平台中立的
  host contracts…拆出 `HostRuntimeDriver` 与 runtime orchestration…目标
  依赖图中 `backend/host` 不再直接依赖 `moui/runtime`、`moui/render/*` 或
  window 实现包。"
- **Validation**: `moon info moui/backend/host` shows no runtime/render
  symbols; `moon test moui/backend/host moui/runtime moui/render --target
  native`; new validator green; daily profile green.

## References

- `docs/invariants.md` P4/P5/P6/M6
- `docs/architecture-map.md` ownership cheat sheet
- `moui/backend/host/host_runtime_driver.mbt`, `renderer.mbt`,
  `host_surface.mbt`, `image_repaint.mbt`, `wall_clock.mbt`,
  `redraw_scheduler.mbt`
- ADR 0005, ADR 0006, ADR 0011

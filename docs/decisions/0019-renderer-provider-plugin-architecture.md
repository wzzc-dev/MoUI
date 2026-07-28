# 0019: Renderer provider plugin architecture

- **Date**: 2026-07-28
- **Status**: Accepted
- **Deciders**: Agent-assisted (AtomCode GLM-5.2)
- **Related**: ADR 0006 (mobile GPU surface and render thread ownership),
  ADR 0007 (Skia layer cache indexing), ADR 0009 (DrawFrame clear),
  ADR 0018 (host contract split), invariants P6/R1/R2

## Context

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

## Decision

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
   mobile window-hosted entrypoints register their `*/skia` provider; web
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

## Options Considered

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

## Rationale

Option A is the only choice that delivers open extension within MoonBit's
compile-time link model. The composition root is the single edit point, and
it is a registration list (additive), not a central switch (branching). Host
and runtime consume `RendererProvider`/`RendererInstance` contracts and never
branch on renderer identity, so ADR 0018's host-import baseline holds.

## Consequences

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

## Implementation Progress (Phase E, 2026-07-28)

The closed matrix is being replaced incrementally. Current state:

- **`NativePlatformSurface` trait** (`moui/render/native_platform_surface.mbt`):
  platform surface knowledge is decentralized. Each `NativeGpuPlatform` variant
  owns its `surface_route` / `gpu_promoted` / `platform_label` via
  `pub impl NativePlatformSurface for NativeGpuPlatform`. The
  `resolve_surface_route` generic function replaces the central
  `select_native_renderer` branching for surface routing.
- **`native_gpu_selection.mbt`** kept as a **deprecated bridge**:
  `select_native_renderer` still exists for backwards compatibility but
  internally delegates to `resolve_surface_route`. Platform skia providers
  (`moui/backend/{macos,windows,linux}/skia/*_skia_provider.mbt`) now call
  `resolve_surface_route` directly instead of `select_native_renderer`.
- **`capabilities_backend_matrix.mbt` deleted**: `renderer_capability_backends`,
  `renderer_feature_capability_entry`, and the Sun feature mirror
  (`sun_feature_status` / `sun_feature_note`) merged into
  `moui/render/capabilities_report.mbt`. The Sun mirror stays local to
  `moui/render` because the package cannot depend on its `moui/render/sun`
  subpackage; provider-driven aggregation will replace the mirror once each
  provider's `capabilities()` field is wired into a registry.
- **Sun feature capabilities** (`moui/render/sun/capabilities.mbt`): the Sun
  provider owns its live `sun_feature_status` / `sun_feature_note` /
  `sun_feature_capabilities` data. The central matrix mirror is a static
  duplicate kept only until provider-driven aggregation lands.
- **Validator enforce mode**: `scripts/validate-renderer-provider-open-extension.mjs`
  now exits 1 on violations. Check 4 enforces that platform skia providers
  call `resolve_surface_route` (not `select_native_renderer`). The
  `CAPABILITY_ALLOWLIST_EXACT` permits `renderer_capability_backends` only in
  `capabilities_report.mbt`, `capabilities_test.mbt`, and showcase diagnostics.

Remaining migration work (tracked in
`docs/plans/active/renderer-provider-trait-refactor.md`):

- Provider-driven `renderer_feature_capability_report(providers)` signature
  that aggregates from each provider's `capabilities()` field, removing the
  static Sun mirror.
- Runtime composition root that registers providers and replaces the
  host-driver renderer switch.

## Agent Notes

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

## References

- `docs/invariants.md` P6/R1/R2
- `moui/render/native_gpu_selection.mbt`,
  `moui/render/capabilities_backend_matrix.mbt`,
  `moui/render/renderer.mbt`
- `moui/render/skia`, `moui/render/wgpu`, `moui/render/webgpu_adapter`,
  `moui/render/canvas2d`, `moui/render/sun`
- ADR 0006, ADR 0007, ADR 0009, ADR 0018

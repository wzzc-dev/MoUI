# Plan: Renderer provider trait refactor (Phase E)

- **Status**: active
- **Goal**: 用 MoonBit `pub(open) trait` 机制消灭 `native_gpu_selection.mbt` 和
  `capabilities_backend_matrix.mbt` 两个中央 match 矩阵,把"平台知识"归还给各
  renderer provider,完成 ADR 0019 的 Phase E。`RendererProvider` 本身保持
  struct + 函数字段(动态注册需求),不强行 trait 化。
- **Decisions**: ADR 0019 (renderer provider),保留 `NativeGpuPlatform` enum +
  trait impl(不拆 6 个 struct),保留 `select_native_renderer` 作 deprecated
  桥接,`NativePlatformSurface` trait 放在 `moui/render` 包。
- **Non-goals**: `RendererProvider` trait 化(明确不做);完全删除
  `select_native_renderer`(留待所有消费者迁移后);`PlatformCapabilities`
  trait 化(struct + capability booleans 已是正确设计)。

## 当前状态评估(2026-07-28)

| Step | 状态 | 说明 |
|---|---|---|
| Step 1 | ✅ 已完成 | trait 声明去重,仅保留 `native_platform_surface.mbt` |
| Step 2 | ✅ 已完成 | `pub impl NativePlatformSurface for NativeGpuPlatform` 可见性修正 |
| Step 3 | ✅ 已完成 | macos/windows/linux skia provider 改用 `resolve_surface_route` |
| Step 4 | ✅ 已完成 | `resolve_surface_route` 泛型版本 |
| Step 5 | ✅ 已完成 | `hybrid_renderer.mbt` 改用 `surface_route` 字段,不依赖 `NativeRendererSelection` |
| Step 6 | ✅ 已完成 | sun provider capabilities 迁移到 `moui/render/sun/capabilities.mbt` |
| Step 7 | ✅ 已完成 | `capabilities_backend_matrix.mbt` 已删除,内容合并到 `capabilities_report.mbt` |
| Step 8 | ✅ 已完成 | validator 转 enforce,Check 4 验证 platform skia provider 迁移 |
| Step 9 | ✅ 已完成 | 测试更新:`native_gpu_selection_test.mbt` 覆盖 `resolve_surface_route` + trait dispatch |

**剩余工作**:
- Provider-driven `renderer_feature_capability_report(providers)` 签名(从每个
  provider 的 `capabilities()` 字段聚合,移除 `moui/render` 中的 Sun 静态镜像)
- Runtime composition root 注册 providers,替换 host-driver 的 renderer switch

---

## File Structure

| 文件 | 角色 | 操作 |
|---|---|---|
| `moui/render/native_platform_surface.mbt` | trait 声明 + `resolve_surface_route` | 保留(权威位置) |
| `moui/render/provider_contract.mbt:246-258` | 重复的 trait 声明 | 删除 |
| `moui/render/native_gpu_selection.mbt` | enum + impl + deprecated `select_native_renderer` | 修改:内部改用 `resolve_surface_route` |
| `moui/backend/macos/skia/macos_skia_provider.mbt:82-104` | `macos_surface_route_from_environment` | 修改:改用 `resolve_surface_route` |
| `moui/backend/windows/skia/windows_skia_provider.mbt:44-58` | `windows_surface_route_from_environment` | 修改:同上 |
| `moui/backend/linux/skia/linux_skia_provider.mbt:33-47` | `linux_surface_route_from_environment` | 修改:同上 |
| `moui/render/skia/hybrid_renderer.mbt` | `SkiaHybridRenderer` | 修改:去掉 `NativeRendererSelection` 依赖 |
| `moui/render/sun/capabilities.mbt` | sun feature capabilities(新建) | 创建:从 `capabilities_backend_matrix.mbt` 迁入 |
| `moui/render/capabilities_backend_matrix.mbt` | 中央 capability 矩阵 | 删除 |
| `moui/render/capabilities_report.mbt` | 调用 `renderer_feature_capability_entry` | 修改:改为遍历 provider capabilities |
| `examples/showcase/app/diagnostics/components.mbt:582` | 调用 `renderer_capability_backends` | 修改:改为从 registry 获取 |
| `scripts/validate-renderer-provider-open-extension.mjs` | report-only validator | 修改:转 enforce + 检查 trait 化 |
| `tools/moui/validate_maintenance_baseline/line_budget_catalog.mbt` | baseline | 修改:删除 `capabilities_backend_matrix.mbt` 条目 |
| `moui/render/native_gpu_selection_test.mbt` | 测试 | 修改:测试 `resolve_surface_route` + trait 方法 |
| `moui/render/skia/hybrid_renderer_wbtest.mbt` | 测试 | 修改:去掉 `select_native_renderer` 调用 |
| `moui/render/capabilities_test.mbt` | 测试 | 修改:改为遍历 provider capabilities |

---

## Task 1: 修复 trait 重复声明 + extend 警告(立即修复编译错误)

**Files**:
- Modify: `moui/render/provider_contract.mbt`(删除 line 246-258 的重复 trait 声明)
- Modify: `moui/render/native_gpu_selection.mbt`(在 impl 块前加 extend 声明)

### Step 1.1: 删除 provider_contract.mbt 中的重复 trait 声明

删除 `moui/render/provider_contract.mbt` line 246-258(从 `///|` 注释到 trait
闭合 `}`),保留 `native_platform_surface.mbt` 作为权威位置。

```moonbit
// 删除这段(line 246-258):
///|
/// Native platform surface knowledge that each platform backend declares
/// locally. ...
pub(open) trait NativePlatformSurface {
  fn surface_route(Self) -> SkiaSurfaceRoute
  fn gpu_promoted(Self) -> Bool
  fn platform_label(Self) -> String
}
```

### Step 1.2: 在 native_gpu_selection.mbt 添加 extend 声明

在 `moui/render/native_gpu_selection.mbt` 的 impl 块前添加 `extend` 声明,消除
trait 方法调用警告。

在 line 116(第一个 impl 之前)插入:

```moonbit
///|
/// Promote `NativePlatformSurface` methods onto `NativeGpuPlatform` so
/// call sites can use `platform.surface_route()` directly without the
/// `NativePlatformSurface::surface_route(platform)` qualifier.
extend NativeGpuPlatform with NativePlatformSurface
```

### Step 1.3: 验证编译

```sh
moon check moui/render --target native 2>&1 | tail -10
```

Expected: 无错误,无 deprecated 警告。

### Step 1.4: Commit

```sh
git add moui/render/provider_contract.mbt moui/render/native_gpu_selection.mbt
git commit -m "fix(render): deduplicate NativePlatformSurface trait and add extend declaration

Remove the duplicate trait declaration from provider_contract.mbt (kept
in native_platform_surface.mbt). Add `extend NativeGpuPlatform with
NativePlatformSurface` to promote trait methods onto the enum and clear
the deprecated implicit-promotion warning."
```

---

## Task 2: 迁移 macos skia provider 调用点

**Files**:
- Modify: `moui/backend/macos/skia/macos_skia_provider.mbt:82-104`

### Step 2.1: 重写 `macos_surface_route_from_environment`

替换 `moui/backend/macos/skia/macos_skia_provider.mbt` line 82-104:

```moonbit
///|
fn macos_surface_route_from_environment() -> @render.SkiaSurfaceRoute {
  // Smoke/scripts may force a concrete route. Unset falls through to
  // MOUI_SKIA_RENDERER (default auto -> GPU when Metal is available).
  match @env.get_env_var("MOUI_MACOS_SKIA_SURFACE_ROUTE") {
    Some("metal-gpu") => @render.SkiaSurfaceRoute::MetalGpuSurfaceRoute
    Some("raster") => @render.SkiaSurfaceRoute::RasterSurfaceRoute
    _ => {
      let requested = match @env.get_env_var("MOUI_SKIA_RENDERER") {
        Some(value) =>
          @render.NativeRendererMode::parse(value).unwrap_or(
            @render.NativeRendererMode::Auto,
          )
        None => @render.NativeRendererMode::Auto
      }
      let platform = @render.NativeGpuPlatform::Macos
      @render.resolve_surface_route(
        platform,
        requested,
        gpu_available=@skia_native.Surface::metal_gpu_context_runtime_available(),
        gpu_promoted=platform.gpu_promoted(),
      )
    }
  }
}
```

### Step 2.2: 验证编译

```sh
moon check moui/backend/macos/skia --target native 2>&1 | tail -10
```

Expected: 无错误。

### Step 2.3: Commit

```sh
git add moui/backend/macos/skia/macos_skia_provider.mbt
git commit -m "refactor(macos/skia): use resolve_surface_route instead of select_native_renderer

The macOS Skia provider only consumed `.surface_route` from
`select_native_renderer`; switch to `resolve_surface_route` + trait
method `platform.gpu_promoted()`. This removes one caller of the
central selection matrix (ADR 0019 Phase E)."
```

---

## Task 3: 迁移 windows skia provider 调用点

**Files**:
- Modify: `moui/backend/windows/skia/windows_skia_provider.mbt:44-58`

### Step 3.1: 重写 `windows_surface_route_from_environment`

替换 line 44-58:

```moonbit
///|
fn windows_surface_route_from_environment() -> @render.SkiaSurfaceRoute {
  let requested = match @env.get_env_var("MOUI_SKIA_RENDERER") {
    Some(value) =>
      @render.NativeRendererMode::parse(value).unwrap_or(
        @render.NativeRendererMode::Auto,
      )
    None => @render.NativeRendererMode::Auto
  }
  let platform = @render.NativeGpuPlatform::Windows
  @render.resolve_surface_route(
    platform,
    requested,
    gpu_available=@skia_native.Surface::direct3d_gpu_context_runtime_available(),
    gpu_promoted=platform.gpu_promoted(),
  )
}
```

### Step 3.2: 验证编译

```sh
moon check moui/backend/windows/skia --target native 2>&1 | tail -10
```

Expected: 无错误。

### Step 3.3: Commit

```sh
git add moui/backend/windows/skia/windows_skia_provider.mbt
git commit -m "refactor(windows/skia): use resolve_surface_route instead of select_native_renderer

Switch to `resolve_surface_route` + trait method `platform.gpu_promoted()`.
Removes one caller of the central selection matrix (ADR 0019 Phase E)."
```

---

## Task 4: 迁移 linux skia provider 调用点

**Files**:
- Modify: `moui/backend/linux/skia/linux_skia_provider.mbt:33-47`

### Step 4.1: 重写 `linux_surface_route_from_environment`

替换 line 33-47:

```moonbit
///|
fn linux_surface_route_from_environment() -> @render.SkiaSurfaceRoute {
  let requested = match @env.get_env_var("MOUI_SKIA_RENDERER") {
    Some(value) =>
      @render.NativeRendererMode::parse(value).unwrap_or(
        @render.NativeRendererMode::Auto,
      )
    None => @render.NativeRendererMode::Auto
  }
  let platform = @render.NativeGpuPlatform::Linux
  @render.resolve_surface_route(
    platform,
    requested,
    gpu_available=@skia_native.Surface::vulkan_gpu_context_runtime_available(),
    gpu_promoted=platform.gpu_promoted(),
  )
}
```

### Step 4.2: 验证编译

```sh
moon check moui/backend/linux/skia --target native 2>&1 | tail -10
```

Expected: 无错误。

### Step 4.3: Commit

```sh
git add moui/backend/linux/skia/linux_skia_provider.mbt
git commit -m "refactor(linux/skia): use resolve_surface_route instead of select_native_renderer

Switch to `resolve_surface_route` + trait method `platform.gpu_promoted()`.
Removes one caller of the central selection matrix (ADR 0019 Phase E)."
```

---

## Task 5: 重构 select_native_renderer 内部使用 resolve_surface_route

**Files**:
- Modify: `moui/render/native_gpu_selection.mbt:191-259`

### Step 5.1: 重写 `select_native_renderer` 内部

`select_native_renderer` 保留作 deprecated 桥接,但内部改用
`resolve_surface_route` + trait 方法,消除内部 route 计算 match。同时
`selected` 字段计算改为基于 `surface_route.is_gpu()` 判断,而非独立 match。

替换 line 191-259:

```moonbit
///|
/// [DEPRECATED] Resolve native renderer selection using the central matrix.
///
/// **Migration**: Use `resolve_surface_route` for route-only consumers, or
/// `RendererProviderRegistry::select_native` for provider-based selection.
/// This function is preserved for incremental migration and will be removed
/// after all consumers migrate.
pub fn select_native_renderer(
  platform : NativeGpuPlatform,
  requested : NativeRendererMode,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
) -> NativeRendererSelection {
  let surface_route = resolve_surface_route(
    platform,
    requested,
    gpu_available~,
    gpu_promoted~,
  )
  let selected = if surface_route.is_gpu() {
    RendererBackendKind::SkiaGpuNative
  } else {
    RendererBackendKind::SkiaRasterNative
  }
  let fallback_reason : String? = if surface_route.is_gpu() {
    None
  } else {
    match requested {
      NativeRendererMode::SkiaRaster => None
      NativeRendererMode::SkiaGpu =>
        Some("requested Skia GPU host surface is unavailable")
      NativeRendererMode::Auto =>
        if !gpu_available {
          Some("Skia GPU host surface is unavailable")
        } else {
          Some("Skia GPU route has not passed platform promotion gates")
        }
    }
  }
  NativeRendererSelection::new(
    platform~,
    requested~,
    selected~,
    gpu_available~,
    gpu_promoted~,
    surface_route~,
    fallback_reason~,
  )
}
```

### Step 5.2: 验证编译 + 测试

```sh
moon check moui/render --target native 2>&1 | tail -10
moon test moui/render --target native -f native_gpu_selection_test.mbt 2>&1 | tail -20
```

Expected: 现有测试通过(行为不变)。

### Step 5.3: Commit

```sh
git add moui/render/native_gpu_selection.mbt
git commit -m "refactor(render): select_native_renderer delegates to resolve_surface_route

Internal route calculation now reuses `resolve_surface_route` + trait
method, removing the duplicated match. The `selected` field is derived
from `surface_route.is_gpu()`. Function signature and behavior are
unchanged for existing callers."
```

---

## Task 6: 迁移 hybrid_renderer 去掉 NativeRendererSelection 依赖

**Files**:
- Modify: `moui/render/skia/hybrid_renderer.mbt`

### Step 6.1: 重写 `SkiaHybridRenderer` struct + `create_hybrid_renderer`

替换 line 1-52:

```moonbit
///|
/// A renderer owner that keeps the raster factory and GPU queue model under one
/// lifecycle. `Recorded` queue completions are internal handoff signals; only
/// the window-backed presenter can produce a public `Presented` completion.
pub struct SkiaHybridRenderer {
  priv renderer : SkiaRasterRenderer
  priv worker : @render.GpuRenderWorker
  priv surface_route : @render.SkiaSurfaceRoute
  priv requested : @render.NativeRendererMode
  priv mut fallback_to_raster : Bool
  priv pending_completions : Array[@render.RenderPresentCompletion]
}

///|
pub fn create_hybrid_renderer(
  platform : @render.NativeGpuPlatform,
  requested : @render.NativeRendererMode,
  metrics : @render.RendererSurfaceMetrics,
  target : SkiaPresentTarget,
  gpu_available~ : Bool,
  gpu_promoted~ : Bool,
  gpu_target? : HostGpuPresentTarget? = None,
  font_resolution? : SkiaFontResolution = SkiaFontResolution::SystemFontMgr,
  async_image_loading? : Bool = false,
) -> SkiaHybridRenderer raise SkiaRendererError {
  let surface_route = @render.resolve_surface_route(
    platform,
    requested,
    gpu_available~,
    gpu_promoted~,
  )
  let gpu_target = if surface_route.is_gpu() {
    gpu_target
  } else {
    None
  }
  let renderer = create_with_present_target_and_route(
    metrics,
    target,
    surface_route~,
    gpu_target~,
    font_resolution~,
    async_image_loading~,
  )
  {
    renderer,
    worker: @render.GpuRenderWorker::new(),
    surface_route,
    requested,
    fallback_to_raster: false,
    pending_completions: [],
  }
}

///|
pub fn SkiaHybridRenderer::surface_route(
  self : SkiaHybridRenderer,
) -> @render.SkiaSurfaceRoute {
  self.surface_route
}

///|
pub fn SkiaHybridRenderer::requested_mode(
  self : SkiaHybridRenderer,
) -> @render.NativeRendererMode {
  self.requested
}
```

### Step 6.2: 更新 `render_frame` 中的 `selection.selected` 引用

替换 line 62-69 中的 `self.selection.selected is
@render.RendererBackendKind::SkiaRasterNative`:

```moonbit
///|
pub fn SkiaHybridRenderer::render_frame(
  self : SkiaHybridRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  if self.fallback_to_raster || !self.surface_route.is_gpu() {
    return self.renderer.render_frame(frame)
  }
  // ... 余下逻辑不变
```

### Step 6.3: 验证编译 + 测试

```sh
moon check moui/render/skia --target native 2>&1 | tail -10
```

Expected: `hybrid_renderer_wbtest.mbt` 会因字段名变化报错,Task 10 中修复。

### Step 6.4: Commit

```sh
git add moui/render/skia/hybrid_renderer.mbt
git commit -m "refactor(render/skia): hybrid_renderer uses surface_route directly

Replace `NativeRendererSelection` dependency with `surface_route` +
`requested` fields. The `selected` backend kind is derived from
`surface_route.is_gpu()`. Removes one consumer of `select_native_renderer`
(ADR 0019 Phase E)."
```

---

## Task 7: 迁移 sun provider feature capabilities

**Files**:
- Create: `moui/render/sun/capabilities.mbt`
- Modify: `moui/render/capabilities_backend_matrix.mbt`(删除 sun 相关函数)

### Step 7.1: 创建 `moui/render/sun/capabilities.mbt`

```moonbit
///|
/// Sun raster feature capability status. Migrated from the central
/// `capabilities_backend_matrix.mbt` (ADR 0019 Phase E) so the Sun
/// provider owns its own feature knowledge.
pub fn sun_feature_status(
  feature : @render.RendererFeature,
) -> @render.RendererFeatureStatus {
  match feature {
    @render.RendererFeature::Rect
    | @render.RendererFeature::RoundedRect
    | @render.RendererFeature::Clip
    | @render.RendererFeature::Transform
    | @render.RendererFeature::Opacity
    | @render.RendererFeature::PathVector
    | @render.RendererFeature::Gradient
    | @render.RendererFeature::BlendMode
    | @render.RendererFeature::Text
    | @render.RendererFeature::Image
    | @render.RendererFeature::Shadow
    | @render.RendererFeature::LayerCompositing
    | @render.RendererFeature::FilterEffect
    | @render.RendererFeature::ShaderEffect
    | @render.RendererFeature::TextShaping
    | @render.RendererFeature::EmojiText
    | @render.RendererFeature::AsyncImage => @render.RendererFeatureStatus::Supported
  }
}

///|
pub fn sun_feature_note(
  feature : @render.RendererFeature,
) -> String {
  // 复制 capabilities_backend_matrix.mbt:99-136 的完整 match 内容
  // (保持原有文案不变)
  match feature {
    @render.RendererFeature::Rect =>
      "Sun raster renders clear, rect fill, and rect stroke commands through moui_sun/graphics Canvas."
    // ... 完整 17 分支,从原文件复制
    @render.RendererFeature::AsyncImage =>
      "Sun raster decodes PNG/JPEG/BMP data URI plus local-file image sources through moui_sun Pixmap codecs and a mizchi/image JPEG-to-RGBA adapter, records renderer-local loading/ready/failed/disposed image lifecycle snapshots, clears cached image pixmaps on dispose while preserving disposed records, exposes sun_image_load_completion and sun_image_load_completion_from_bytes for provider-owned decode completions, forwards revisioned image-resource snapshots plus callback/apply ports through native Sun providers, keeps cached repeat draws revision-stable, retries async local-file failures once the file appears, routes macOS/Linux/Windows Sun local-file loads through HostNativeAsyncImageSource with off-main file I/O, and package tests cover deferred native-source completion through the host repaint tracker into the second presented frame."
  }
}
```

**注意**:实施时需从 `capabilities_backend_matrix.mbt:84-136` 完整复制 17 个分支
的 note 文案,保持原文不变。

### Step 7.2: 删除 `capabilities_backend_matrix.mbt` 中的 sun 函数

删除 `moui/render/capabilities_backend_matrix.mbt` line 84-136
(`sun_feature_status` + `sun_feature_note`)。

### Step 7.3: 更新 `renderer_feature_capability_entry`

`renderer_feature_capability_entry`(line 31-81)中的 sun 分支改为调用
`@sun.sun_feature_status(feature)` 和 `@sun.sun_feature_note(feature)`:

```moonbit
renderer_backend_feature(
  feature,
  RendererBackendKind::SunRasterNative,
  @sun.sun_feature_status(feature),  // 改为跨包调用
  @sun.sun_feature_note(feature),    // 改为跨包调用
),
```

**注意**:`moui/render/sun/moon.pkg` 需确认已 import `moui/render`,且
`moui/render` 的 `moon.pkg` 不能反向依赖 `moui/render/sun`(避免循环)。如果
`capabilities_backend_matrix.mbt` 调用 `@sun.sun_feature_status`,则 `moui/render`
需依赖 `moui/render/sun`。这会引入循环依赖。

**替代方案**:`renderer_feature_capability_entry` 也迁移到
`moui/render/sun/capabilities.mbt` 或新建 `moui/render/capabilities_report.mbt`
中,由 sun 包之外的位置组装。具体做法见 Task 8。

### Step 7.4: 验证编译

```sh
moon check moui/render/sun --target native 2>&1 | tail -10
moon check moui/render --target native 2>&1 | tail -10
```

### Step 7.5: Commit

```sh
git add moui/render/sun/capabilities.mbt moui/render/capabilities_backend_matrix.mbt
git commit -m "refactor(render/sun): migrate sun feature capabilities to sun package

Move `sun_feature_status` and `sun_feature_note` from the central
`capabilities_backend_matrix.mbt` to `moui/render/sun/capabilities.mbt`.
The Sun provider now owns its feature knowledge (ADR 0019 Phase E)."
```

---

## Task 8: 删除 capabilities_backend_matrix + 更新 capabilities_report

**Files**:
- Delete: `moui/render/capabilities_backend_matrix.mbt`
- Modify: `moui/render/capabilities_report.mbt`
- Modify: `examples/showcase/app/diagnostics/components.mbt`

### Step 8.1: 重写 `capabilities_report.mbt`

`renderer_feature_capability_report()` 当前调用 `renderer_feature_capability_entry`
(在 `capabilities_backend_matrix.mbt` 中)。需把 `renderer_feature_capability_entry`
逻辑迁入 `capabilities_report.mbt` 或改为遍历 provider capabilities。

**推荐做法**:保留 `renderer_feature_capability_entry` 但迁移到
`capabilities_report.mbt`(同包,不引入循环依赖),sun 分支改为本地 match
(因为 `moui/render` 不能依赖 `moui/render/sun`)。

实际上,由于 `moui/render` 包内不能调用 `moui/render/sun`(子包),sun 的
capabilities 应通过 `RendererProvider.capabilities()` 动态获取。这要求重构
`renderer_feature_capability_report`:

```moonbit
///|
pub fn renderer_feature_capability_report(
  providers : Array[@render.RendererProvider],
) -> Array[RendererFeatureCapability] {
  // 遍历每个 feature,聚合各 provider 的 capability
  let all_features = [
    RendererFeature::Rect,
    RendererFeature::RoundedRect,
    // ... 17 个 feature
  ]
  all_features.map(feature => {
    let backends : Array[RendererBackendFeatureCapability] = []
    for provider in providers {
      for cap in provider.capabilities() {
        if cap.feature == feature {
          backends.push(cap)
        }
      }
    }
    RendererFeatureCapability::new(feature~, backends~)
  })
}
```

**注意**:这要求每个 provider 的 `capabilities()` 返回完整 feature 列表。需确认
各 provider 工厂(`create_skia_raster_provider` 等)已正确填充。如果未填充,本
Task 需先补全各 provider 的 capabilities。

### Step 8.2: 删除 `capabilities_backend_matrix.mbt`

```sh
rm moui/render/capabilities_backend_matrix.mbt
```

### Step 8.3: 更新 `examples/showcase/app/diagnostics/components.mbt:582`

`renderer_capability_backends()` 已删除,改为从 registry 或硬编码列表获取
(因为 showcase 不一定有 runtime registry):

```moonbit
let backends = [
  @render.RendererBackendKind::SkiaRasterNative,
  @render.RendererBackendKind::SkiaGpuNative,
  @render.RendererBackendKind::WebGpuWasm,
  @render.RendererBackendKind::NativeWgpu,
  @render.RendererBackendKind::SunRasterNative,
  @render.RendererBackendKind::Canvas2DWasm,
]
```

**注意**:这把硬编码移到调用点。更好的做法是 showcase 持有一个
`RendererProviderRegistry` 并遍历 `providers.map(p => p.descriptor.backend)`。
但 showcase 是否有 registry 取决于其架构,实施时确认。

### Step 8.4: 验证编译

```sh
moon check moui/render --target native 2>&1 | tail -10
moon check examples/showcase --target native 2>&1 | tail -10
```

### Step 8.5: Commit

```sh
git add moui/render/capabilities_report.mbt examples/showcase/app/diagnostics/components.mbt
git rm moui/render/capabilities_backend_matrix.mbt
git commit -m "refactor(render): remove central capabilities_backend_matrix

Delete `capabilities_backend_matrix.mbt`. `renderer_feature_capability_report`
now aggregates from provider `capabilities()` fields. Showcase diagnostics
uses a local backend list (or registry-derived list). Completes ADR 0019
Phase E central matrix removal."
```

---

## Task 9: 更新测试

**Files**:
- Modify: `moui/render/native_gpu_selection_test.mbt`
- Modify: `moui/render/skia/hybrid_renderer_wbtest.mbt`
- Modify: `moui/render/capabilities_test.mbt`

### Step 9.1: 更新 `native_gpu_selection_test.mbt`

现有测试调用 `select_native_renderer` 并检查 `.selected` / `.surface_route`。
由于 `select_native_renderer` 保留为 deprecated 桥接且行为不变,**现有测试可
保持不变**。但应新增测试覆盖 `resolve_surface_route` + trait 方法:

在文件末尾追加:

```moonbit
///|
test "resolve_surface_route returns gpu route when available and promoted" {
  let route = resolve_surface_route(
    NativeGpuPlatform::Macos,
    NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=true,
  )
  assert_true(route == SkiaSurfaceRoute::MetalGpuSurfaceRoute)
}

///|
test "resolve_surface_route falls back to raster when gpu unavailable" {
  let route = resolve_surface_route(
    NativeGpuPlatform::Windows,
    NativeRendererMode::Auto,
    gpu_available=false,
    gpu_promoted=true,
  )
  assert_true(route == SkiaSurfaceRoute::RasterSurfaceRoute)
}

///|
test "NativePlatformSurface trait dispatches platform_label" {
  assert_true(NativeGpuPlatform::Macos.platform_label() == "macos")
  assert_true(NativeGpuPlatform::HarmonyOs.platform_label() == "harmonyos")
}
```

### Step 9.2: 更新 `hybrid_renderer_wbtest.mbt`

line 19-24 的 `selection:` 字段改为 `surface_route:` + `requested:`:

```moonbit
let hybrid = SkiaHybridRenderer::{
  renderer,
  worker: @render.GpuRenderWorker::new(),
  surface_route: @render.SkiaSurfaceRoute::MetalGpuSurfaceRoute,
  requested: @render.NativeRendererMode::SkiaGpu,
  fallback_to_raster: false,
  pending_completions: [],
}
```

### Step 9.3: 更新 `capabilities_test.mbt`

line 910 和 962 调用 `renderer_capability_backends()`。改为遍历 provider
capabilities 或使用本地列表:

```moonbit
// 替换 renderer_capability_backends() 调用
let backends = [
  @render.RendererBackendKind::SkiaRasterNative,
  @render.RendererBackendKind::SkiaGpuNative,
  @render.RendererBackendKind::WebGpuWasm,
  @render.RendererBackendKind::NativeWgpu,
  @render.RendererBackendKind::SunRasterNative,
  @render.RendererBackendKind::Canvas2DWasm,
]
```

或者如果 Task 8 引入了 `renderer_feature_capability_report(providers)` 签名,
需更新测试调用。

### Step 9.4: 验证测试

```sh
moon test moui/render --target native 2>&1 | tail -20
moon test moui/render/skia --target native 2>&1 | tail -20
```

Expected: 全部通过。

### Step 9.5: Commit

```sh
git add moui/render/native_gpu_selection_test.mbt moui/render/skia/hybrid_renderer_wbtest.mbt moui/render/capabilities_test.mbt
git commit -m "test(render): update tests for trait-based surface route and removed matrix

Add tests for `resolve_surface_route` and `NativePlatformSurface` trait
dispatch. Update `hybrid_renderer_wbtest` to use new `surface_route` field.
Update `capabilities_test` to use local backend list instead of removed
`renderer_capability_backends`."
```

---

## Task 10: 更新 validator 转 enforce + baseline

**Files**:
- Modify: `scripts/validate-renderer-provider-open-extension.mjs`
- Modify: `tools/moui/validate_maintenance_baseline/line_budget_catalog.mbt`

### Step 10.1: validator 转 enforce

修改 `scripts/validate-renderer-provider-open-extension.mjs`:

1. line 198 注释改为 `enforce mode`
2. line 237-243 的 `hasViolations` 分支改为 `process.exit(1)`
3. 新增 Check 4:验证 `moui/render/native_gpu_selection.mbt` 中
   `select_native_renderer` 不被 macos/windows/linux skia provider 调用
   (允许 `resolve_surface_route` + trait 方法)
4. 新增 Check 5:验证 `capabilities_backend_matrix.mbt` 已删除

```javascript
// line 237-243 改为:
if (hasViolations) {
  console.log("❌ Violations found (enforce mode).");
  process.exit(1);
} else {
  console.log("✅ All checks passed.");
  process.exit(0);
}
```

新增 Check 4(在 `checkCentralMatrixCallers` 之后):

```javascript
// ---------------------------------------------------------------------------
// Check 4: No select_native_renderer callers in platform skia providers
// ---------------------------------------------------------------------------
function checkPlatformSkiaProviderMigration() {
  const violations = [];
  const platformSkiaProviders = [
    "moui/backend/macos/skia/macos_skia_provider.mbt",
    "moui/backend/windows/skia/windows_skia_provider.mbt",
    "moui/backend/linux/skia/linux_skia_provider.mbt",
  ];

  for (const relPath of platformSkiaProviders) {
    const fullPath = join(REPO_ROOT, relPath);
    if (!existsSync(fullPath)) continue;
    const content = readFileSync(fullPath, "utf-8");
    if (content.includes("select_native_renderer")) {
      violations.push(
        `  ${relPath}: still calls select_native_renderer (use resolve_surface_route)`
      );
    }
  }

  return violations;
}
```

### Step 10.2: 更新 baseline

修改 `tools/moui/validate_maintenance_baseline/line_budget_catalog.mbt`:

删除 `capabilities_backend_matrix.mbt` 的 line budget 条目(搜索
`capabilities_backend_matrix` 关键字,删除整条)。

### Step 10.3: 验证 validator + baseline

```sh
node scripts/validate-renderer-provider-open-extension.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-guidance-consistency.mjs
```

Expected: 全部通过,exit 0。

### Step 10.4: Commit

```sh
git add scripts/validate-renderer-provider-open-extension.mjs tools/moui/validate_maintenance_baseline/line_budget_catalog.mbt
git commit -m "chore(validate): enforce renderer provider open-extension + update baseline

Switch `validate-renderer-provider-open-extension.mjs` from report-only
to enforce mode. Add Check 4 to verify platform skia providers migrated
to `resolve_surface_route`. Remove `capabilities_backend_matrix.mbt`
from line budget catalog."
```

---

## Task 11: 最终验证 + 文档更新

### Step 11.1: 运行完整测试

```sh
moon test moui/render moui/render/skia --target native
moon test moui/backend/macos/skia moui/backend/windows/skia moui/backend/linux/skia --target native
moon test moui/backend/host --target native
moon test tools/moui/validate_maintenance_baseline --target native
```

### Step 11.2: 运行静态 trio

```sh
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-guidance-consistency.mjs
node scripts/validate-renderer-provider-open-extension.mjs
node scripts/validate-core-theme-no-control-surface.mjs
```

### Step 11.3: 行为不变性验证

确认:
- macOS Skia 在 GPU 可用时仍走 `MetalGpuSurfaceRoute`
- Windows Skia 在 GPU 可用时仍走 `Direct3DGpuSurfaceRoute`
- Linux Skia 在 GPU 可用时仍走 `VulkanGpuSurfaceRoute`
- GPU 不可用时所有平台回退 `RasterSurfaceRoute`
- `hybrid_renderer` 的 sticky 降级行为不变

### Step 11.4: 更新 ADR + 文档

更新 `docs/decisions/` 中 ADR 0019,标记 Phase E 完成。更新
`docs/architecture-map.md` 中 renderer provider 部分,说明
`NativePlatformSurface` trait 取代了中央矩阵。

### Step 11.5: 最终 commit

```sh
git add docs/decisions/ docs/architecture-map.md
git commit -m "docs(adr-0019): mark Phase E complete — central matrices removed

Update ADR 0019 to record that `NativePlatformSurface` trait +
`resolve_surface_route` replaced the central `surface_route` match,
and provider `capabilities()` replaced `capabilities_backend_matrix`."
```

---

## 假设与风险

### 假设
- MoonBit `extend Type with Trait` 语法可消除 implicit-promotion 警告(需
  `moon ide doc` 确认)
- `SkiaSurfaceRoute::is_gpu()` 方法已存在(`hybrid_renderer` 已调用)
- `resolve_surface_route`(泛型版本)能覆盖所有 route 计算场景
- 各 provider 的 `capabilities()` 字段已正确填充(若未填充,Task 8 需补全)

### 风险
1. **循环依赖**:`moui/render` 不能依赖 `moui/render/sun`(子包)。Task 7/8 需
   确保 sun capabilities 通过 provider `capabilities()` 字段动态获取,而非跨包
   调用。
2. **provider capabilities 未填充**:如果各 provider 工厂的 `capabilities` 字段
   返回空数组,Task 8 的 `renderer_feature_capability_report(providers)` 会返回空。
   需先确认/补全。
3. **showcase registry 可用性**:Task 8.3 的 showcase 改造取决于其是否有
   `RendererProviderRegistry`。若无,使用本地列表(已写在方案中)。
4. **测试覆盖**:Task 9 新增的 `resolve_surface_route` 测试需覆盖所有 6 平台 ×
   3 mode 组合(当前只测 2 个 case,可扩展)。

---

## 验证总结

### 编译验证
```sh
moon check moui/render moui/render/skia moui/render/sun --target native
moon check moui/backend/macos/skia moui/backend/windows/skia moui/backend/linux/skia --target native
```

### 测试验证
```sh
moon test moui/render moui/render/skia --target native
moon test moui/backend/host --target native
moon test tools/moui/validate_maintenance_baseline --target native
```

### Validator 验证
```sh
node scripts/validate-renderer-provider-open-extension.mjs  # enforce
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-api-surface.mjs
node scripts/validate-guidance-consistency.mjs
```

### 开放扩展验证
确认新增 renderer provider 只需:
1. 在新包内 `impl @render.NativePlatformSurface for ...`(如需平台 surface 知识)
2. 调用 `create_xxx_provider` 工厂返回 `RendererProvider`
3. 在 composition root `registry.register(provider)`
4. **不需要**编辑 `native_gpu_selection.mbt` 或 `capabilities_backend_matrix.mbt`
   (因为已删除)

---

## Out of Scope

- **Phase A**(平台 backend 接入 shared_adapter):独立工作
- **Phase B**(ControlThemeSet 接入 examples):独立工作
- **完全删除 `select_native_renderer`**:本方案保留为 deprecated 桥接,完整删除
  留待所有消费者迁移后
- **`RendererProvider` trait 化**:明确不做(决策 1)
- **`PlatformCapabilities` trait 化**:struct + capability booleans 已是正确设计

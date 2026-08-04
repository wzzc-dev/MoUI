# MoUI 后端渲染器彻底外提方案（backend-renderer-extraction）

> 目标：`moui/backend/**` 下不存在任何渲染器实现、渲染器 import、渲染器命名的符号；渲染器与后端的装配全部上移到应用入口（composition root），入口以 `run_app().render(skia).backend(linux)` 形态表达。
>
> 状态：实施完成并归档（2026-08-04；跨平台实机 presentation 证据继续由平台证据矩阵跟踪）
> 前置文书：`docs/plans/active/renderer-backend-decoupling.md`（下称「方案 D」）
> 证据基线日期：以本仓库当前工作树为准，所有 `文件:行号` 均取自非 `_build/` 的源文件。

## 执行结果

本计划已按一次性迁移口径落地：`moui/backend/**` 不再包含具体 renderer
实现、native binding 或 provider 装配；各 application composition root 通过
`@moui.run_app(...).render/render_all(...).backend(...).run()` 完成组装。
`AppBuilder`、`PlatformEntry`、`HostSurfaceKit` 与 resolver 已进入生产代码，
并新增 backend boundary、renderer manifest、入口和根门面依赖校验。

本机已完成静态边界、API、文档、能力一致性、focused native/wasm-gc 编译与
renderer/backend package tests。Canvas2D wasm-gc 运行测试需要浏览器 host import，
window-hosted smoke 需要对应本地 window workspace 和目标设备，不能在本机据此宣称
真实 presentation 或移动设备运行时通过。

---

## 0. 与 `renderer-backend-decoupling.md`（方案 D）的关系

方案 D 与本方案针对同一组事实、同一批证据，差别只在**处置力度**。

方案 D 的定位是「ADR 0019 / Phase E 的 close-out 补完，不引入新架构范式」（`renderer-backend-decoupling.md:24`），它在方案对比矩阵里明确选择了「**13 绑定包保留**」（`renderer-backend-decoupling.md:854`），把单包体量从 341-1293 行压到约 130 行，代价是 `moui/backend/<platform>/<renderer>/` 这一层继续存在，`moui/backend` 因此**永远无法做到零渲染器依赖**。

本方案是同一诊断下的激进版本：**不压缩绑定子包，直接删除绑定子包这一层**。

### 0.1 作废与继承矩阵

| 方案 D 章节 | 内容 | 本方案处置 |
|---|---|---|
| `:850-868` §5 方案对比矩阵「D 列：13 绑定包保留」 | 保留 `moui/backend/<platform>/<renderer>/` 13 个包 | **作废**。本方案第 4 章 P2/P3 全量删除这 13 个包 |
| `:893-1032` §6 Phase 1-5 | 迁移路径以「绑定包瘦身」为主线 | **作废**，由本方案 §4 的 P0-P5 取代 |
| `:324-332` §2.3 诉求三「新增 (P,R) 组合 = 新增约 130 行绑定包」 | 边际成本 130 行绑定包 | **作废**。本方案的边际成本是入口 main 包里约 8 行链式调用 + 0 个新包 |
| `:326` §2.3「唯一的 O(P×R) 剩余项是合成根本身——不可消除的本质复杂度」 | 承认 (P,R) 交叉不可消除 | **部分修正**。本方案 §1.3 给出实测：当前被当作 (P,R) 交叉的 1047 行 native presenter stub **实际是纯平台代码，只是命名带 `skia`**，交叉面积远小于方案 D 的估计 |
| `:691-712` §3.5.1 `native_gpu_selection.mbt` 混装根因与拆分边界 | `GpuHostSurfaceDescriptor` 留中立层、策略矩阵下沉 skia 族 | **完整继承**，作为本方案 P0 |
| `:717-723` §3.5.3 M5 与 R3 校验器的硬边界（B5） | `MOUI_SKIA_RENDERER` 字面量必须留在 provider 文件 | **继承前提，但结论反转**。删除绑定包后「provider 文件」不复存在，R3 必须改判定口径而不是改路径；口径已由 §5.1.1 U1 裁决（字面量迁往 `moui/render/skia` 的 `from_env`） |
| `:868-881` §5.1 否决方案 B 的链接期论证 | `moon.pkg` 不支持按特性开关门控 import，一个 (P,R) 组合 = 一个链接单元 | **完整继承**，是本方案全部设计的硬约束 |
| `:51-236` §1 现状诊断 D1-D4 | 四条真问题 | **继承并加强**，见本文 §1 |
| `:1046-1072` §7 风险与未决项 | R-1 至 R-6 | **继承**，本文 §5 只列新增/变更项 |
| `:724-744` §3.6 不新建 `moui/render/composition` 包 | 装配复用件放已有 `moui/render` | **继承**。本方案新增的中立契约同样落在 `moui/render`，不新建包 |

### 0.2 为什么现在敢做激进版

方案 D 保留绑定包的核心理由是「(P,R) 交叉是本质复杂度」。本方案在写作期间做了方案 D 未做的一项勘察：**逐个打开 13 个绑定包的 native stub，看它们到底依赖了什么**。结论见 §1.3——这些 stub 里 1047 行 presenter/surface-host 代码**一行 Skia/Sun/WGPU API 都没调用**，它们做的是「把 CPU 像素缓冲贴到 NSView/HWND/ANativeWindow」和「在 NSView 上装一个 CAMetalLayer 并返回句柄」。这是平台能力，不是渲染器能力，命名里的 `skia` 是历史遗留。

这项事实把「(P,R) 交叉」的实际面积从 8303 行 MoonBit + 2412 行 native 压缩到**每个 (P,R) 组合约 8 行入口链式调用**，激进版因此从「理想」变成「可执行」。

---

## 1. 现状诊断

### 1.1 平台基座本体已经中立（好消息，且比方案 D 描述的更好）

六个原生平台基座的 `moon.pkg` **没有任何一行 import 具体渲染器**：

| 包 | `moon.pkg` import 中的渲染器 | 证据 |
|---|---|---|
| `moui/backend/linux` | 无（只有 `wzzc-dev/moui/render`） | `moui/backend/linux/moon.pkg:1-11` |
| `moui/backend/macos` | 无 | `moui/backend/macos/moon.pkg:1-13` |
| `moui/backend/windows` | 无 | `moui/backend/windows/moon.pkg:1-12` |
| `moui/backend/android` | 无 | `moui/backend/android/moon.pkg:1-8` |
| `moui/backend/ios` | 无 | `moui/backend/ios/moon.pkg:1-10` |
| `moui/backend/harmonyos` | 无 | `moui/backend/harmonyos/moon.pkg:1-8` |
| `moui/backend/host` | 无 | `moui/backend/host/moon.pkg:1-6` |
| `moui/backend/platform_bridge` | 无 | `moui/backend/platform_bridge/moon.pkg:1-8` |
| `moui/backend/web` | **有：`"wzzc-dev/moui/render/webgpu_adapter" @webgpu`** | `moui/backend/web/moon.pkg:7` |
| `moui/backend/wechat` | **有：`"wzzc-dev/moui/render/canvas2d"`** | `moui/backend/wechat/moon.pkg:6` |

即：`moui/backend` 的渲染器依赖只有两个来源——**13 个绑定子包**，和 **web / wechat 两个平台基座本体**。前者是 §1.2，后者是 §1.4。

### 1.2 13 个绑定子包：体量实测

统计口径：`wc -l`，按文件类别分列，`*_test.mbt` / `*_wbtest.mbt` 归入测试列。

| 包 | 生产 `.mbt` | 测试 `.mbt` | `.mbti` | native stub | 是否走 `select_renderer_provider_binding` |
|---|---:|---:|---:|---:|---|
| `moui/render/skia` | 940 | 328 | 42 | 485 | 是（`macos_skia_provider.mbt:518`） |
| `moui/render/skia` | 697 | 409 | 38 | 253 | 是（`linux_skia_provider.mbt:344`） |
| `moui/render/skia` | 663 | 322 | 38 | 432 | 是（`windows_skia_provider.mbt:350`） |
| `moui/render/skia` | 593 | 27 | 36 | 372 | 是（`ios_skia_provider.mbt:171`） |
| `moui/render/skia` | 535 | 38 | 32 | 64 | 是（`android_skia_provider.mbt:152`） |
| `moui/render/skia` | 472 | 35 | 32 | 143 | 是（`harmonyos_skia_provider.mbt:151`） |
| `moui/backend/macos/sun` | 390 | 332 | 41 | 160 | **否** |
| `moui/render/wgpu` | 333 | 134 | 38 | 58 | **否** |
| `moui/backend/windows/sun` | 327 | 319 | 37 | 239 | **否** |
| `moui/backend/linux/sun` | 305 | 251 | 37 | 167 | **否** |
| `moui/render/wgpu` | 202 | 130 | 31 | 34 | **否** |
| `moui/render/wgpu` | 200 | 130 | 31 | 5 | **否** |
| `moui/render/canvas2d` | 110 | 81 | 0 | 0 | 是（`wechat_canvas_provider.mbt:75`） |
| **合计** | **5767** | **2536** | **433** | **2412** | 7 是 / 6 否 |

加上 13 个 `moon.pkg`（321 行），这一层总计 **11469 行**。

> 口径说明：方案 D `:108` 记该层为 8537 行，其分项表（`:110-123`）把生产与测试 `.mbt` 合并并计入包描述文件。两个数字口径不同，不构成事实冲突；本方案后续所有收益计算以本表为准。

每个绑定包的 `moon.pkg` 都同时 import 平台基座与具体渲染器，这是 `moui/backend` 渲染器依赖的直接来源：

```
moui/render/skia/moon.pkg:7   "wzzc-dev/moui/backend/linux" @linux_host
moui/render/skia/moon.pkg:9   "wzzc-dev/moui/render/skia" @skia_renderer
moui/render/skia/moon.pkg:10  "wzzc-dev/moui_skia"
moui/render/skia/moon.pkg:11  "wzzc-dev/moui_skia/native" @skia_native
```

```
moui/backend/linux/sun/moon.pkg:6    "wzzc-dev/moui/backend/linux" @linux_host
moui/backend/linux/sun/moon.pkg:8    "wzzc-dev/moui/render/sun" @sun_renderer
```

```
moui/render/canvas2d/moon.pkg:3  "wzzc-dev/moui/backend/host"
moui/render/canvas2d/moon.pkg:5  "wzzc-dev/moui/render/canvas2d"
```

### 1.3 关键新发现：2412 行 native stub 里有 1047 行是**误命名的平台代码**

逐个打开 13 个包的 `.c/.cpp/.m/.mm`，导出符号如下：

**（A）CPU 像素呈现器 —— 零渲染器 API 调用，纯平台**

| 符号 | 文件:行 | 实际语义 |
|---|---|---|
| `moui_macos_present_skia_pixels_to_view(handle, pixels, w, h, row_bytes, scale)` | `moui/render/skia/macos_skia_presenter.mm:42` | 把 CPU 像素缓冲包成 `CGImage` 装进 `NSImageView` |
| `moui_windows_present_skia_pixels_to_hwnd(...)` | `moui/render/skia/win32_skia_presenter.cpp:21` | 把 CPU 像素缓冲 blit 到 HWND |
| `moui_android_present_skia_pixels_to_surface(...)` | `moui/render/skia/android_skia_presenter.cpp:9` | 把 CPU 像素缓冲写入 `ANativeWindow` |

三个符号的入参都是 `(句柄, 像素指针, 宽, 高, row_bytes, scale)`，与 Skia 无关；名字里的 `skia` 是历史遗留。`moui/render/sun` 走同样的 CPU 像素路径，却因为这三个符号「叫 skia」而各自复制了一份 —— 这正是 `macos/sun`、`linux/sun`、`windows/sun` 三个包存在的主要理由之一。

**（B）GPU layer 安装器 —— 零渲染器 API 调用，纯平台**

| 符号 | 文件:行 | 实际语义 |
|---|---|---|
| `moui_macos_skia_metal_layer_for_view(view)` | `moui/render/skia/macos_skia_presenter.mm:152` | 取 NSView 上的 `CAMetalLayer` |
| `moui_macos_skia_install_metal_layer(view)` | `moui/render/skia/macos_skia_presenter.mm:174` | 在 NSView 上装 `CAMetalLayer`，返回 `UInt64` 句柄 |
| `moui_macos_skia_configure_metal_layer(view, ...)` | `moui/render/skia/macos_skia_presenter.mm:216` | 配置 drawable size / pixel format |
| `moui_macos_surface_host_layer_from_view(view, w, h)` | `moui/render/wgpu/macos_wgpu_surface_host.m:9` | **与上面三个语义重复**，只因为在 wgpu 包里就重写了一遍 |
| `moui_ios_skia_create_metal_view / release / configure` | `moui/render/skia/ios_skia_view_glue.mm:62,81,89` | 创建带 `CAMetalLayer` 的 UIView |
| `moui_linux_surface_host_ptr_from_u64(handle)` | `moui/render/wgpu/linux_wgpu_surface_host.c:3` | 5 行指针转换 |

这些函数的产物恰好就是已有的中立载荷 `GpuHostSurfaceDescriptor::MetalLayer(UInt64)`（`moui/render/native_gpu_selection.mbt:34-40`）。**`macos/skia` 与 `macos/wgpu` 各写一份 CAMetalLayer 安装代码，是「按渲染器切包」导致平台代码重复的铁证。**

**（C）异步图片 stub —— 平台 I/O + 可选 Skia 解码，可一分为二**

| 文件 | 行数 | Skia 耦合 |
|---|---:|---|
| `moui/render/skia/linux_async_image.cpp` | 253 | 有：`#if defined(MOUI_SKIA_HAS_SKIA)` 下 include `SkCodec/SkBitmap/SkData`（`:24-30`） |
| `moui/render/skia/macos_async_image.mm` | 236 | 有 |
| `moui/render/skia/windows_async_image.cpp` | 310 | 有 |
| `moui/backend/linux/sun/linux_sun_async_image.c` | 167 | **无**：纯 pthread + `fread`（`:1-10`） |
| `moui/backend/macos/sun/macos_sun_async_image.m` | 160 | 无 |
| `moui/backend/windows/sun/windows_sun_async_image.c` | 239 | 无 |

skia 版与 sun 版的结果结构体字段完全一致（`window_id / source / bytes / status / background_io / next`，对比 `linux_async_image.cpp:32-40` 与 `linux_sun_async_image.c:12-21`）。差别只有一处：skia 版在 worker 线程里多做一次 `SkCodec` 解码。**同一平台的两份 I/O 实现可以合并为一份中立实现**，解码阶段归 `moui/render/skia`（已由 §5.1.1 U2 裁决）。

**结论**：2412 行 native stub 中，1047 行（A+B）是可以原样搬进 `moui/backend/<platform>` 的平台代码，1365 行（C）可合并去重约 40%，真正必须留在渲染器侧的只有 Skia 解码分支。

### 1.4 web / wechat：唯二在平台基座本体里直连渲染器

`moui/backend/wechat/host_runtime.mbt` 是全仓最严重的一处 —— 平台基座**直接持有渲染器实例**：

```
moui/backend/wechat/host_runtime.mbt:12   mut renderer : @canvas2d.Canvas2DRenderer?
moui/backend/wechat/host_runtime.mbt:37   let r = @canvas2d.Canvas2DRenderer::new(canvas_id~)
moui/backend/wechat/host_runtime.mbt:38   r.resize(renderer_metrics)
moui/backend/wechat/host_runtime.mbt:39   d.set_text_system(r.text_system())
moui/backend/wechat/host_runtime.mbt:43   state.renderer = Some(r)
```

注意 `moui/render/canvas2d/` 这个绑定包同时存在且实现了正确的协商路径（`wechat_canvas_provider.mbt:75` 调用 `select_renderer_provider_binding`），但 `moui/backend/wechat` 的 `run_app` 完全绕过它 —— `examples/showcase/wechat_canvas/main.mbt:16` 调的是 `@wechat.run_app`，不是绑定包。**绑定包在这条线上是死代码。**

`moui/backend/web` 稍好，它至少走了协商，但注册表写死在平台基座里：

```
moui/backend/web/webgpu_renderer.mbt:2    type WebRendererError = @webgpu.WebGpuHostError
moui/backend/web/webgpu_renderer.mbt:38   @render.select_renderer_provider_binding(
moui/backend/web/webgpu_renderer.mbt:57   fn web_renderer_provider_bindings(...)  // 内部构造 @webgpu.create_webgpu_provider
```

### 1.5 `platform_bridge` 里的 Skia 字面量

`moui/backend/platform_bridge/skia_preflight_fragments.mbt` 共 15 行，两个函数返回的字符串里硬编码了 `SkiaRasterRenderer.*` 与 `skia_async_image_loader`：

```
moui/backend/platform_bridge/skia_preflight_fragments.mbt:6   "...renderer_frame=SkiaRasterRenderer.render_frame; ..."
moui/backend/platform_bridge/skia_preflight_fragments.mbt:14  "...renderer_image_loader=skia_async_image_loader; ..."
```

`platform_bridge` 的 `moon.pkg` 不 import 任何渲染器（`moui/backend/platform_bridge/moon.pkg:1-8`），所以这是**字符串层面的违例**，不是依赖违例，但同样违背「backend 不包含渲染器命名」的目标。

### 1.6 反向依赖已达标，但中立层残留渲染器命名

`moui/render/moon.pkg:1-6` 只 import `moon_zeno / moui/core / mizchi/svg / core/env` —— **`moui/render` 及其子包对 `moui/backend` 的依赖为 0**，这一半的隔离早已完成，本方案不需要动它。

但中立层的**命名**仍有 Skia 残迹（`moui/render/pkg.generated.mbti`）：

```
:56   pub fn negotiate_gpu_surface(..., route_for~ : (GpuHostSurfaceDescriptor) -> SurfaceRoute)
:96   pub fn[P : NativePlatformSurface] resolve_surface_route(P, NativeRendererMode, ...) -> SurfaceRoute
:121  BoundSurface.route : SurfaceRoute
:861  pub(all) enum SurfaceRoute
:907  trait method surface_route(Self) -> SurfaceRoute
```

以及 `NativeGpuPlatform`（`moui/render/native_gpu_selection.mbt:10-17`）、`NativeRendererMode`（`:24-28`）这两个 skia 族策略枚举。这正是方案 D §3.5.1 已经定位的问题，本方案 P0 继承其拆分边界。

### 1.7 抽象可被绕过：6 个包从不协商

`select_renderer_provider_binding` 全仓生产调用点共 8 处（`moui/render/provider_contract.mbt:128` 定义）：

```
moui/render/skia/macos_skia_provider.mbt:518
moui/render/skia/linux_skia_provider.mbt:344
moui/render/skia/windows_skia_provider.mbt:350
moui/render/skia/android_skia_provider.mbt:152
moui/render/skia/ios_skia_provider.mbt:171
moui/render/skia/harmonyos_skia_provider.mbt:151
moui/backend/web/webgpu_renderer.mbt:38
moui/render/canvas2d/wechat_canvas_provider.mbt:75
```

`{linux,macos,windows}/{sun,wgpu}` 六个包一次都没调用过，它们直接构造 `<Platform>RendererProvider` 塞给中立入口：

```
moui/backend/linux/sun/linux_sun_provider.mbt:44    @linux_host.run_app_with_renderer_provider(
moui/backend/macos/sun/macos_sun_provider.mbt:59    @macos_host.run_app_with_renderer_provider(
moui/backend/windows/sun/windows_sun_provider.mbt:44 @windows_host.run_app_with_renderer_provider(
moui/render/wgpu/linux_wgpu_provider.mbt:37  @linux_host.run_app_with_renderer_provider(
moui/render/wgpu/macos_wgpu_provider.mbt:52  @macos_host.run_app_with_renderer_provider(
moui/render/wgpu/windows_wgpu_provider.mbt:40 @windows_host.run_app_with_renderer_provider(
```

**原因不是这六个包偷懒**：`RendererProviderBinding::create_host_renderer` 的签名是 `(RendererSurfaceMetrics, BoundSurface) -> HostWindowRenderer`（`moui/render/provider_contract.mbt:104-107`），构造它需要先拿到平台 `PresentTarget`。而 `SkiaPresentTarget`（`moui/render/skia/renderer_surface.mbt:11-14`）与 `SunPresentTarget`（`moui/render/sun/renderer_surface_model.mbt:12-15`）是两个不同类型，**中立层没有共同的 present 抽象**，所以 sun/wgpu 侧没有零成本路径去构造 binding。这是抽象被绕过的机制性原因，也是本方案 §3.1 必须先补 `HostPresentTarget` 的理由。

### 1.8 应用入口现状：装配已经在入口，只是通过绑定包间接完成

```
examples/showcase/linux_skia/moon.pkg:4-5
  "wzzc-dev/moui/backend/linux" @linux_backend,
  "wzzc-dev/moui/render/skia" @linux_skia_backend,
examples/showcase/linux_skia/main.mbt:18
  @linux_skia_backend.run_app_with_options("MoUI Showcase", runtime, options=...)
```

入口已经同时 import 平台基座和绑定包，只是把装配委托给了绑定包。`examples/showcase/web_wasm/main.mbt:11-13` 更进一步，已经在入口手工组装 provider 列表：

```
let renderer_providers = @render.renderer_provider_binding_providers(
  @web.web_renderer_provider_bindings(canvas_id="moonbit-window-web-showcase"),
)
```

这是合成根的雏形。本方案要做的是把它变成**所有入口的统一形态**。

嵌入式入口的形态不同，`provider_factory` 已经是闭包注入：

```
examples/showcase/android_window_hosted/main.mbt:14
  provider_factory=() => @android_skia_backend.renderer_provider(),
```

### 1.9 校验器与文档写死绑定包路径

| 位置 | 硬编码内容 |
|---|---|
| `tools/moui/validate_harness_invariants/main.mbt:67-72` | `desktop_skia_providers()` 写死三条 `moui/backend/{macos,windows,linux}/skia/*_skia_provider.mbt` |
| `tools/moui/validate_harness_invariants/main.mbt:433-458` | `check_r3_provider_text` 要求文件体含 `MOUI_SKIA_RENDERER` 且含 `NativeRendererMode::parse` 或 `resolve_surface_route` |
| `tools/moui/validate_skia_entrypoints/main.mbt:71-157` | 7 个入口包，每个写死 `backend_alias` / `options_type` / `run_function` |
| `tools/moui/validate_skia_entrypoints/main.mbt:169-180` | `skia_provider_contracts()` 写死三条 `moui/backend/*/skia/moon.pkg` |
| `tools/moui/validate_skia_entrypoints/main.mbt:186-190` | `platform_backend_import()` 断言入口必须 import `"wzzc-dev/moui/backend/<p>/skia"` |
| `scripts/validate-renderer-provider-open-extension.mjs:65-83` | `SELECTION_ALLOWLIST_PREFIXES` 12 条 backend 绑定包路径 |
| `scripts/validate-renderer-provider-open-extension.mjs:85-88` | `SELECTION_ALLOWLIST_EXACT` 2 条 |
| `docs/architecture.md` / `docs/zh-Hans/architecture.md:105,111,116,188-201` | 目录说明表列出 13 个绑定包 |
| `docs/zh-Hans/platform-notes-macos.md:3,10,13,25,37` | 大量 `backend/macos/skia` / `backend/macos/wgpu` 引用 |
| `docs/zh-Hans/wechat-support.md:18` | `moui/render/canvas2d` 引用 |
| `docs/zh-Hans/examples.md:558,637,684` | 三处入口说明 |

`MOUI_SKIA_RENDERER` 的三个读取点：`linux_skia_provider.mbt:34`、`macos_skia_provider.mbt:89`、`windows_skia_provider.mbt:45`。删包后这三个文件不存在，R3 判定必须重设计（口径见 §5.1.1 U1）。

---

## 2. 目标架构与目录布局

### 2.1 职责边界

```
┌──────────────────────────────────────────────────────────────────────────┐
│  composition root  =  examples/<app>/<platform>_<renderer>/               │
│  ─────────────────────────────────────────────────────────────────────    │
│  唯一同时 import「平台基座」与「渲染器」的地方。                            │
│  唯一决定渲染器注册顺序（= 协商优先级）的地方。                             │
│  唯一决定链接单元内容的地方（moon.pkg import = 编译期选择）。               │
│                                                                            │
│      import "wzzc-dev/moui/backend/linux"   @backend_linux                 │
│      import "wzzc-dev/moui/render/skia"     @render_skia                   │
│                                                                            │
│      run_app(title).program(rt)                                            │
│        .render(@render_skia.gpu())        // 先试 GPU                      │
│        .render(@render_skia.raster())     // 回落 CPU                      │
│        .backend(@backend_linux.entry())                                    │
│        .run()                                                              │
└────────────┬─────────────────────────────────────────┬───────────────────┘
             │ 提供 PlatformEntry                       │ 提供 RendererBindingFactory
             │ （不认识渲染器）                          │ （不认识平台）
             ▼                                          ▼
┌───────────────────────────────┐        ┌────────────────────────────────────┐
│ moui/backend/<platform>/      │        │ moui/render/<renderer>/            │
│ ───────────────────────────── │        │ ────────────────────────────────── │
│ 窗口 / 生命周期 / 输入 / 服务  │        │ 渲染器实现                          │
│ HostSurfaceKit 生产：          │        │ RendererProvider 工厂               │
│   · SurfaceDescriptor          │        │ RendererBindingFactory 工厂         │
│   · HostPresentTarget（CPU）   │        │ 消费 HostSurfaceKit                 │
│   · GpuHostSurfaceDescriptor   │        │                                     │
│   · HostAsyncImageLoader       │        │ import moui/render ✓                │
│ <Platform>RendererProvider     │        │ import moui/backend ✗（现已为 0）    │
│ run_app_with_renderer_provider │        │                                     │
│ entry() -> PlatformEntry       │        │                                     │
│                                │        │                                     │
│ import moui/render ✓（中立契约）│        │                                     │
│ import moui/render/<r> ✗       │        │                                     │
│ 符号名含 skia/sun/wgpu ✗       │        │                                     │
└───────────────┬───────────────┘        └────────────────┬───────────────────┘
                │                                          │
                └──────────────┬───────────────────────────┘
                               ▼
        ┌──────────────────────────────────────────────────┐
        │ moui/render （中立契约层，不含任何渲染器实现）     │
        │ ──────────────────────────────────────────────── │
        │ SurfaceDescriptor            provider_contract:5  │
        │ GpuHostSurfaceDescriptor     native_gpu_selection:34 │
        │ RendererProvider             provider_contract:80 │
        │ RendererProviderBinding      provider_contract:104│
        │ select_renderer_provider_binding  :128            │
        │ HostWindowRenderer           host_window_renderer:34 │
        │ HostAsyncImageLoader         image_repaint:425     │
        │ ── P0 新增 ──                                      │
        │ HostPixelFrame / HostPresentTarget                │
        │ HostSurfaceKit / RendererBindingFactory           │
        └──────────────────────────────────────────────────┘
                               ▲
                               │
        ┌──────────────────────┴───────────────────────────┐
        │ moui/runtime （AppBuilder / PlatformEntry 宿主）  │
        │ 已 import core + render + backend/host           │
        │ moui/runtime/moon.pkg:1-6                         │
        └──────────────────────────────────────────────────┘
```

### 2.2 目录布局对照

```
迁移前                                          迁移后
──────────────────────────────────────────────────────────────────────────
moui/backend/linux/                            moui/backend/linux/
  linux_backend.mbt                              linux_backend.mbt
  linux_app_runtime.mbt                          linux_app_runtime.mbt
  ...                                            linux_surface_kit.mbt      ← 新增
                                                 linux_entry.mbt            ← 新增
                                                 linux_present.c            ← 从 skia 包迁入并改名
                                                 linux_async_image_io.c     ← skia/sun 两版合并
moui/render/skia/          ← 删除
  linux_skia_provider.mbt   697
  linux_skia_provider_wbtest 409
  linux_async_image.cpp     253
  moon.pkg / pkg.generated.mbti
moui/backend/linux/sun/           ← 删除
  linux_sun_provider.mbt    305
  linux_sun_provider_wbtest 251
  linux_sun_async_image.c   167
  moon.pkg / pkg.generated.mbti
moui/render/wgpu/          ← 删除
  linux_wgpu_provider.mbt   200
  linux_wgpu_provider_wbtest 130
  linux_wgpu_surface_host.c   5
  moon.pkg / pkg.generated.mbti

moui/render/skia/                              moui/render/skia/
  provider.mbt                                   provider.mbt
  renderer_surface.mbt                           renderer_surface.mbt
  hybrid_renderer.mbt                            hybrid_renderer.mbt
                                                 binding_factory.mbt        ← 新增
                                                 gpu_surface_bridge.mbt     ← 新增（吃 GpuHostSurfaceDescriptor）
                                                 skia_native_policy.mbt     ← P0 从 render 下沉
                                                 skia_async_decode.cpp      ← 从 backend 迁入（可选，见 U2）

examples/showcase/linux_skia/                  examples/showcase/linux_skia/
  moon.pkg  (import backend/linux/skia)          moon.pkg  (import backend/linux + render/skia)
  main.mbt  (23 行)                              main.mbt  (约 26 行)
```

删除清单（13 个目录）：

```
moui/render/skia      moui/backend/linux/sun      moui/render/wgpu
moui/render/skia      moui/backend/macos/sun      moui/render/wgpu
moui/render/skia    moui/backend/windows/sun    moui/render/wgpu
moui/render/skia    moui/render/skia       moui/render/skia
moui/render/canvas2d
```

### 2.3 依赖方向硬规则（迁移完成后必须成立）

| 编号 | 规则 | 机器验证 |
|---|---|---|
| E1 | `moui/backend/**/moon.pkg` 不得出现 `wzzc-dev/moui/render/` 后跟子路径的 import；`wzzc-dev/moui/render`（根包）允许 | grep `moui/backend/**/moon.pkg` |
| E2 | `moui/backend/**/moon.pkg` 不得 import `wzzc-dev/moui_skia*`、`wzzc-dev/moui_sun*`、`Milky2018/wgpu_mbt` | grep |
| E3 | `moui/backend/**` 的 `.mbt` 源码中不得出现标识符 `Skia`/`Sun`/`Wgpu`/`Canvas2D` 前缀的类型名与 `skia_`/`sun_`/`wgpu_`/`canvas2d_` 前缀的函数名 | 正则扫描 |
| E4 | `moui/backend/**` 下不得存在名为 `skia`/`sun`/`wgpu`/`canvas` 的子目录 | 目录扫描 |
| E5 | `moui/render/**` 不得 import `wzzc-dev/moui/backend`（现已成立，需保持） | grep |
| E6 | 每个 `examples/*/<platform>_<renderer>/moon.pkg` 恰好 import 一个 `moui/backend/<platform>` 与至少一个 `moui/render/<renderer>` | 入口校验器 |

E1-E4 已由 `scripts/validate-backend-renderer-boundary.mjs` 实现并纳入 PR 校验。

---

## 3. 核心机制

### 3.1 机制①：`SurfaceDescriptor` —— 后端与渲染器唯一的中立契约

现有 `SurfaceDescriptor`（`moui/render/provider_contract.mbt:5-10`）已经是正确的契约：

```moonbit
pub(all) enum SurfaceDescriptor {
  CpuRaster(Double, Double, Double)
  GpuSurface(GpuHostSurfaceDescriptor, Double, Double, Double)
}
```

`GpuHostSurfaceDescriptor`（`moui/render/native_gpu_selection.mbt:34-40`）承载原始句柄：

```moonbit
pub enum GpuHostSurfaceDescriptor {
  MetalLayer(UInt64)
  D3D12Hwnd(UInt64)
  AndroidVulkanWindow(UInt64)
  WaylandVulkanSurface(UInt64, UInt64)
  EglNativeWindow(UInt64)
}
```

问题在于**契约只覆盖了「输入」，没覆盖「输出」**。渲染器画完之后怎么上屏，中立层没有说法，于是 skia 与 sun 各自定义了 `SkiaPresentTarget`（`moui/render/skia/renderer_surface.mbt:11-14`）和 `SunPresentTarget`（`moui/render/sun/renderer_surface_model.mbt:12-15`）。两者结构近乎同构：

```moonbit
// moui/render/skia/renderer_surface.mbt:2-8
pub struct SkiaPixelFrame {
  priv width : Int; priv height : Int; priv row_bytes : Int
  priv scale_factor : Double; priv pixels : Bytes
}

// moui/render/sun/renderer_surface_model.mbt:2-9
pub struct SunPixelFrame {
  priv width : Int; priv height : Int; priv row_bytes : Int
  priv scale_factor : Double
  priv pixels : FixedArray[Byte]   // 与 bytes 重复
  priv bytes : Bytes
}
```

**P0 新增中立输出契约**，补齐这一半：

```moonbit
// moui/render/host_surface_kit.mbt（新增）

///|
/// 中立 CPU 像素帧。渲染器产出，平台呈现器消费。
/// 取代 `SkiaPixelFrame` / `SunPixelFrame` 的重复定义。
pub struct HostPixelFrame {
  priv width : Int
  priv height : Int
  priv row_bytes : Int
  priv scale_factor : Double
  priv pixels : Bytes
} derive(Eq, Debug)

///|
pub fn HostPixelFrame::new(
  width~ : Int,
  height~ : Int,
  row_bytes~ : Int,
  scale_factor~ : Double,
  pixels~ : Bytes,
) -> HostPixelFrame {
  { width, height, row_bytes, scale_factor, pixels }
}

///|
/// 平台把 CPU 像素帧送上屏的中立能力。由 `moui/backend/<platform>` 产出。
pub struct HostPresentTarget {
  priv description : String
  priv present : (HostPixelFrame) -> Bool
}

///|
pub fn HostPresentTarget::new(
  description~ : String,
  present~ : (HostPixelFrame) -> Bool,
) -> HostPresentTarget {
  { description, present }
}

///|
pub fn HostPresentTarget::present(
  self : HostPresentTarget,
  frame : HostPixelFrame,
) -> Bool {
  (self.present)(frame)
}

///|
pub fn HostPresentTarget::description(self : HostPresentTarget) -> String {
  self.description
}
```

有了 `HostPresentTarget`，`SkiaPresentTarget` 与 `SunPresentTarget` 都退化为对它的薄封装，`moui/backend/<platform>` 只需产出一个中立值即可同时喂给 skia 和 sun —— §1.3(A) 里那三份重复的 CPU 呈现器 stub 从此只需要一份。

再补一个「平台交给渲染器的全部东西」的聚合体：

```moonbit
///|
/// 平台在不知道渲染器是谁的前提下能提供的全部能力。
/// 由 `moui/backend/<platform>` 在每次创建渲染器时构造。
pub struct HostSurfaceKit {
  priv surface : SurfaceDescriptor
  priv metrics : RendererSurfaceMetrics
  priv present : HostPresentTarget
  priv image_loader : HostAsyncImageLoader?
}

///|
pub fn HostSurfaceKit::new(
  surface~ : SurfaceDescriptor,
  metrics~ : RendererSurfaceMetrics,
  present~ : HostPresentTarget,
  image_loader? : HostAsyncImageLoader? = None,
) -> HostSurfaceKit {
  { surface, metrics, present, image_loader }
}

///|
pub fn HostSurfaceKit::surface(self : HostSurfaceKit) -> SurfaceDescriptor {
  self.surface
}

///|
pub fn HostSurfaceKit::metrics(
  self : HostSurfaceKit,
) -> RendererSurfaceMetrics {
  self.metrics
}

///|
pub fn HostSurfaceKit::present(self : HostSurfaceKit) -> HostPresentTarget {
  self.present
}

///|
pub fn HostSurfaceKit::image_loader(
  self : HostSurfaceKit,
) -> HostAsyncImageLoader? {
  self.image_loader
}
```

`HostAsyncImageLoader` 已存在（`moui/render/image_repaint.mbt:425`），平台侧通过 `HostNativeAsyncImageSource::loader_with_drain`（`:519`）构造，这条路径**本来就不需要渲染器**。

### 3.2 机制②：`<Platform>RendererProvider` —— 已存在的中立注入点

平台基座已经暴露了正确形状的注入点。以 Linux 为例（`moui/backend/linux/linux_backend.mbt:59-63`）：

```moonbit
pub struct LinuxRendererProvider {
  priv create_renderer : (@window_linux.Window, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
  priv sync_surface : (@window_linux.Window, @host.HostSurfaceMetrics) -> Unit
  priv image_loader : @render.HostAsyncImageLoader?
}
```

它是纯闭包结构体，**不含任何渲染器类型**。中立入口同样已就位（`moui/backend/linux/linux_app_runtime.mbt:2-17`）：

```moonbit
pub fn run_app_with_renderer_provider(
  title : String,
  runtime : @runtime.AppRuntime,
  provider~ : LinuxRendererProvider,
  options? : LinuxHostAppOptions = LinuxHostAppOptions::new(),
  window_requests? : @host.HostWindowRequestQueue = @host.HostWindowRequestQueue::new(),
) -> Unit
```

macOS / Windows 同构（`macos_backend.mbt:53`、`windows_backend.mbt:53`），嵌入式三平台用 `RendererProviderAdapter`（`moui/backend/internal/embedded_runtime_backend/hosted_window_backend.mbt:33-37`）把 `Window` 换成 `UInt64`：

```moonbit
pub struct RendererProviderAdapter {
  create_renderer : (UInt64, @host.HostSurfaceMetrics) -> @render.HostWindowRenderer?
  sync : (UInt64, @host.HostSurfaceMetrics) -> Unit
  image_loader : @render.HostAsyncImageLoader?
}
```

**这一层不需要改造，只需要补齐它的上游**：平台基座要新增一个「把自己的 `Window` 翻译成 `HostSurfaceKit`」的中立函数。仍以 Linux 为例：

```moonbit
// moui/backend/linux/linux_surface_kit.mbt（新增）

///|
/// 中立 CPU 呈现：把像素缓冲贴到 X11/Wayland surface。
/// 从 `backend/linux/skia/linux_async_image.cpp` 同级的呈现路径迁入并去 skia 命名。
extern "c" fn linux_present_pixels(
  window_handle : UInt64,
  pixels : Bytes,
  width : Int,
  height : Int,
  row_bytes : Int,
  scale : Double,
) -> Int = "moui_linux_present_pixels"

///|
/// 平台产出的中立呈现目标。渲染器无关。
pub fn linux_present_target(
  window : @window_linux.Window,
) -> @render.HostPresentTarget {
  let handle = window.raw_handle()
  @render.HostPresentTarget::new(
    description="linux-cpu-pixels",
    present=frame => linux_present_pixels(
        handle,
        frame.pixels(),
        frame.width(),
        frame.height(),
        frame.row_bytes(),
        frame.scale_factor(),
      ) ==
      0,
  )
}

///|
/// 平台产出的中立 surface 描述。GPU 句柄来自平台自己的 layer/surface 安装。
pub fn linux_surface_descriptor(
  window : @window_linux.Window,
  metrics : @host.HostSurfaceMetrics,
  prefer_gpu~ : Bool,
) -> @render.SurfaceDescriptor {
  let w = metrics.logical_size().width
  let h = metrics.logical_size().height
  let scale = metrics.scale_factor()
  if prefer_gpu {
    match linux_gpu_host_surface(window) {
      Some(gpu) => @render.SurfaceDescriptor::GpuSurface(gpu, w, h, scale)
      None => @render.SurfaceDescriptor::CpuRaster(w, h, scale)
    }
  } else {
    @render.SurfaceDescriptor::CpuRaster(w, h, scale)
  }
}

///|
/// 把平台窗口打包成渲染器需要的全部中立材料。
pub fn linux_surface_kit(
  window : @window_linux.Window,
  metrics : @host.HostSurfaceMetrics,
  prefer_gpu~ : Bool,
) -> @render.HostSurfaceKit {
  @render.HostSurfaceKit::new(
    surface=linux_surface_descriptor(window, metrics, prefer_gpu~),
    metrics=renderer_metrics_from_host(metrics),
    present=linux_present_target(window),
    image_loader=Some(linux_async_image_loader()),
  )
}
```

其中 `renderer_metrics_from_host` 正是方案 D `:130` 指出的「12 份复制」，本方案里它每个平台只剩一份，位于平台基座内。

### 3.3 机制③：`AppBuilder` 流式装配

#### 3.3.1 MoonBit 没有一等模块，`skia` 与 `linux` 必须是**值**

`run_app().render(skia).backend(linux)` 里的 `skia` / `linux` 不可能是包名（MoonBit 的 `@pkg` 前缀不是值）。落地方式是让两侧各自导出一个**工厂函数返回中立值**：

```moonbit
@render_skia.raster()      -> @render.RendererBindingFactory
@render_skia.gpu()         -> @render.RendererBindingFactory
@backend_linux.entry()     -> @runtime.PlatformEntry
```

入口可以先绑定到局部名字，得到与目标写法字面一致的形态：

```moonbit
let skia = @render_skia.raster()
let linux = @backend_linux.entry()
@runtime.run_app("MoUI Showcase").program(runtime).render(skia).backend(linux).run()
```

#### 3.3.2 `RendererBindingFactory`：延迟绑定是必需的

不能让 `.render()` 直接收 `RendererProviderBinding`，因为构造 binding 需要平台的 `PresentTarget`（§1.7 已论证）。所以 `.render()` 收的是一个**待应用的函数**：

```moonbit
// moui/render/host_surface_kit.mbt（续）

///|
/// 延迟绑定：合成根注册它，平台入口在拿到窗口后用自己的
/// `HostSurfaceKit` 把它兑现成 `RendererProviderBinding`。
/// 这是「合成根决定顺序、平台负责兑现」的载体。
pub struct RendererBindingFactory {
  priv id : String
  priv bind : (HostSurfaceKit) -> RendererProviderBinding
}

///|
pub fn RendererBindingFactory::new(
  id~ : String,
  bind~ : (HostSurfaceKit) -> RendererProviderBinding,
) -> RendererBindingFactory {
  { id, bind }
}

///|
pub fn RendererBindingFactory::id(self : RendererBindingFactory) -> String {
  self.id
}

///|
pub fn RendererBindingFactory::bind(
  self : RendererBindingFactory,
  kit : HostSurfaceKit,
) -> RendererProviderBinding {
  (self.bind)(kit)
}

///|
/// 把合成根注册的工厂列表在给定 kit 上兑现并协商，返回宿主渲染器。
/// 所有平台入口共用这一条路径 —— 协商从此没有旁路。
pub fn resolve_host_renderer(
  factories : Array[RendererBindingFactory],
  kit : HostSurfaceKit,
) -> HostWindowRenderer? {
  let bindings = factories.map(factory => factory.bind(kit))
  match select_renderer_provider_binding(bindings, kit.surface()) {
    Some((binding, bound)) =>
      Some((binding.create_host_renderer)(kit.metrics(), bound))
    None => None
  }
}
```

渲染器包侧的工厂（Skia 为例，基于已有的 `moui/render/skia/provider.mbt:53` `create_skia_raster_host_binding`）：

```moonbit
// moui/render/skia/binding_factory.mbt（新增）

///|
/// Skia CPU raster 绑定工厂。合成根用 `.render(@render_skia.raster())` 注册。
pub fn raster(
  font_resolution? : SkiaFontResolution = SkiaFontResolution::system(),
) -> @render.RendererBindingFactory {
  @render.RendererBindingFactory::new(
    id="skia-raster",
    bind=kit => create_skia_raster_host_binding(
      create_renderer=metrics => SkiaRasterRenderer::create_with_present_target(
        metrics,
        present_target=skia_present_target_from_host(kit.present()),
        font_resolution~,
        image_loader=kit.image_loader(),
      ),
    ),
  )
}

///|
/// Skia GPU 绑定工厂。只在 kit 的 surface 是 `GpuSurface` 时协商通过；
/// 否则 `select_renderer_provider_binding` 会自动跳到下一个注册项。
pub fn gpu(
  font_resolution? : SkiaFontResolution = SkiaFontResolution::system(),
) -> @render.RendererBindingFactory {
  @render.RendererBindingFactory::new(
    id="skia-gpu",
    bind=kit => create_skia_hybrid_host_binding(
      create_renderer=(metrics, bound) => SkiaRasterRenderer::create_with_present_target_and_route(
        metrics,
        route=bound.route(),
        gpu_target=skia_gpu_target_from_descriptor(kit.surface()),
        present_target=skia_present_target_from_host(kit.present()),
        font_resolution~,
        image_loader=kit.image_loader(),
      ),
    ),
  )
}

///|
/// 中立呈现目标 -> Skia 呈现目标的薄适配。
fn skia_present_target_from_host(
  host : @render.HostPresentTarget,
) -> SkiaPresentTarget {
  SkiaPresentTarget::new(
    description=host.description(),
    present=frame => host.present(
      @render.HostPixelFrame::new(
        width=frame.width(),
        height=frame.height(),
        row_bytes=frame.row_bytes(),
        scale_factor=frame.scale_factor(),
        pixels=frame.pixels(),
      ),
    ),
  )
}
```

`moui/render/sun/binding_factory.mbt`、`moui/render/wgpu/binding_factory.mbt`、`moui/render/canvas2d/binding_factory.mbt`、`moui/render/webgpu_adapter/binding_factory.mbt` 同构，各约 25-40 行。

#### 3.3.3 `PlatformEntry`：把窗口类型 `W` 从公开 API 里消掉

`AppBuilder` 不能对 `@window_linux.Window` 泛型化 —— 它在 `moui/runtime`，不认识任何平台。解决办法是让平台入口把 `W` **闭包捕获在内部**：

```moonbit
// moui/runtime/app_builder.mbt（新增）

///|
/// 平台入口的中立形状。每个 `moui/backend/<platform>` 导出一个 `entry()`
/// 返回它。平台窗口类型被闭包吃掉，不出现在签名里。
pub struct PlatformEntry {
  priv id : String
  priv run : (AppLaunchRequest) -> Unit
}

///|
pub fn PlatformEntry::new(
  id~ : String,
  run~ : (AppLaunchRequest) -> Unit,
) -> PlatformEntry {
  { id, run }
}

///|
pub fn PlatformEntry::id(self : PlatformEntry) -> String {
  self.id
}

///|
/// 合成根交给平台入口的全部内容。
pub struct AppLaunchRequest {
  priv title : String
  priv runtime : AppRuntime
  priv factories : Array[@render.RendererBindingFactory]
  priv window_requests : @backend_host.HostWindowRequestQueue
  priv scene_resolver : HostWindowSceneResolver
  priv event_sources : HostPlatformEventSources?
  priv platform_view_plugins : Array[@backend_host.PlatformViewPlugin]
  priv exit_after_first_present : Bool
}

///|
pub fn AppLaunchRequest::title(self : AppLaunchRequest) -> String {
  self.title
}

///|
pub fn AppLaunchRequest::runtime(self : AppLaunchRequest) -> AppRuntime {
  self.runtime
}

///|
pub fn AppLaunchRequest::factories(
  self : AppLaunchRequest,
) -> Array[@render.RendererBindingFactory] {
  self.factories
}
```

`AppLaunchRequest` 的字段集合是**当前 12 个 `<Platform><Renderer>AppOptions` 的并集**，这直接兑现方案 D §3.3（`:483`）「消灭逐字段拷贝」与 §1.3.1「19 处字段漂移归零」—— 因为不再有转发层，就不可能漏字段。

Linux 侧的 `entry()`：

```moonbit
// moui/backend/linux/linux_entry.mbt（新增，全文约 40 行）

///|
/// Linux 平台入口。渲染器无关：它只知道如何把自己的窗口打包成
/// `HostSurfaceKit`，然后让合成根注册的工厂列表去协商。
pub fn entry(
  prefer_gpu? : Bool = true,
  transparent_titlebar? : Bool = false,
  platform_attributes? : @window_core.PlatformWindowAttributes = @window_core.PlatformWindowAttributes::default(),
) -> @runtime.PlatformEntry {
  @runtime.PlatformEntry::new(
    id="linux",
    run=request => {
      let factories = request.factories()
      let provider = LinuxRendererProvider::new(
        create_renderer=(window, metrics) => @render.resolve_host_renderer(
          factories,
          linux_surface_kit(window, metrics, prefer_gpu~),
        ),
        sync_surface=(window, metrics) => linux_sync_surface(window, metrics),
        image_loader=Some(linux_async_image_loader()),
      )
      run_app_with_renderer_provider_smoke(
        request.title(),
        request.runtime(),
        provider~,
        options=LinuxHostAppOptions::new(
          scene_resolver=request.scene_resolver(),
          event_sources=request.event_sources(),
          platform_view_plugins=request.platform_view_plugins(),
          transparent_titlebar~,
          platform_attributes~,
        ),
        smoke_options=LinuxHostSmokeOptions::new(
          first_frame_smoke_auto_exit=request.exit_after_first_present(),
        ),
        window_requests=request.window_requests(),
      )
    },
  )
}
```

**这段代码里没有 `skia`/`sun`/`wgpu` 任何字样**，满足 E2/E3。协商发生在 `@render.resolve_host_renderer`，顺序由合成根的 `.render()` 调用顺序决定。

#### 3.3.4 `AppBuilder` 本体

```moonbit
// moui/runtime/app_builder.mbt（续）

///|
/// 流式装配壳。`render` 可多次调用，调用顺序即协商优先级。
pub struct AppBuilder {
  priv title : String
  priv runtime : AppRuntime?
  priv factories : Array[@render.RendererBindingFactory]
  priv entry : PlatformEntry?
  priv window_requests : @backend_host.HostWindowRequestQueue
  priv scene_resolver : HostWindowSceneResolver
  priv event_sources : HostPlatformEventSources?
  priv platform_view_plugins : Array[@backend_host.PlatformViewPlugin]
  priv exit_after_first_present : Bool
}

///|
/// 装配入口。`run_app("MoUI Showcase").program(rt).render(...).backend(...).run()`
pub fn run_app(title : String) -> AppBuilder {
  {
    title,
    runtime: None,
    factories: [],
    entry: None,
    window_requests: @backend_host.HostWindowRequestQueue::new(),
    scene_resolver: HostWindowSceneResolver::unavailable(),
    event_sources: None,
    platform_view_plugins: [],
    exit_after_first_present: false,
  }
}

///|
pub fn AppBuilder::program(
  self : AppBuilder,
  runtime : AppRuntime,
) -> AppBuilder {
  { ..self, runtime: Some(runtime) }
}

///|
/// 注册一个渲染器。多次调用建立回落链：先注册的先协商。
pub fn AppBuilder::render(
  self : AppBuilder,
  factory : @render.RendererBindingFactory,
) -> AppBuilder {
  { ..self, factories: self.factories + [factory] }
}

///|
/// 批量注册渲染器，保持传入顺序即回落顺序。
/// 供 `@render_skia.from_env()` 这类「由环境变量决定顺序」的场景使用（见 §5.1.1 U1）。
pub fn AppBuilder::render_all(
  self : AppBuilder,
  factories : Array[@render.RendererBindingFactory],
) -> AppBuilder {
  { ..self, factories: self.factories + factories }
}

///|
/// 绑定平台入口。一个链接单元只能有一个。
pub fn AppBuilder::backend(
  self : AppBuilder,
  entry : PlatformEntry,
) -> AppBuilder {
  { ..self, entry: Some(entry) }
}

///|
pub fn AppBuilder::exit_after_first_present(
  self : AppBuilder,
  value : Bool,
) -> AppBuilder {
  { ..self, exit_after_first_present: value }
}

///|
pub fn AppBuilder::platform_views(
  self : AppBuilder,
  plugins : Array[@backend_host.PlatformViewPlugin],
) -> AppBuilder {
  { ..self, platform_view_plugins: plugins }
}

///|
/// 终结操作：把渲染器工厂列表与平台入口合成一次
/// `run_app_with_renderer_provider` 调用。
pub fn AppBuilder::run(self : AppBuilder) -> Unit {
  guard self.runtime is Some(runtime) else {
    abort("AppBuilder::run requires .program(runtime)")
  }
  guard self.entry is Some(entry) else {
    abort("AppBuilder::run requires .backend(entry)")
  }
  guard self.factories.length() > 0 else {
    abort("AppBuilder::run requires at least one .render(factory)")
  }
  (entry.run)({
    title: self.title,
    runtime,
    factories: self.factories,
    window_requests: self.window_requests,
    scene_resolver: self.scene_resolver,
    event_sources: self.event_sources,
    platform_view_plugins: self.platform_view_plugins,
    exit_after_first_present: self.exit_after_first_present,
  })
}

///|
/// 嵌入式终结操作：不启动事件循环，返回工厂供
/// `EventLoop::run_app` 使用（android/ios/harmonyos 用）。
pub fn AppBuilder::renderer_factories(
  self : AppBuilder,
) -> Array[@render.RendererBindingFactory] {
  self.factories
}
```

`AppBuilder` 落在 `moui/runtime`：它已经 import `core` + `render` + `backend/host`（`moui/runtime/moon.pkg:1-6`），零新增依赖，符合方案 D §3.6（`:724`）「不新建包」的判断。根门面 `moui` 的 re-export 按 §5.1.1 U3 裁决另走 RFC，且以根门面依赖校验器落地为前置。

#### 3.3.5 合成根迁移前后对照

**迁移前**（`examples/showcase/linux_skia/main.mbt:1-23` + `moon.pkg:1-16`）：

```
moon.pkg:
  "wzzc-dev/moui/backend/linux" @linux_backend,
  "wzzc-dev/moui/render/skia" @linux_skia_backend,   ← 绑定包

main.mbt:18-22
  @linux_skia_backend.run_app_with_options(
    "MoUI Showcase", runtime,
    options=@linux_skia_backend.LinuxHostAppOptions::new(),
  )
```

**迁移后**：

```moonbit
// examples/showcase/linux_skia/moon.pkg
import {
  "wzzc-dev/moui/runtime",
  "wzzc-dev/moui/backend/host" @host,
  "wzzc-dev/moui/backend/linux" @backend_linux,
  "wzzc-dev/moui/render/skia" @render_skia,
  "examples/showcase/app" @showcase_app,
}

supported_targets = "native"
pkgtype(kind: "executable")
options(
  link: { "native": { "cc-link-flags": "${build.MOUI_SKIA_STUB_CC_FLAGS}" } },
  targets: { "main.mbt": [ "native" ] },
)
```

```moonbit
// examples/showcase/linux_skia/main.mbt
///|
fn main {
  let services = @host.HostAppServices::new(
    bridge=@backend_linux.linux_service_bridge(),
  )
  let app = @showcase_app.ShowcaseApp::new()
  let runtime = @runtime.new_program_with_dimensions(
    program=app.program_with_host(
      @backend_linux.linux_capability_summary(),
      services~,
      timer_source=Some(@backend_linux.linux_timer_source()),
    ),
    width=1100.0,
    height=680.0,
  )
  runtime.set_action_commands(@showcase_app.action_command_map())
  @runtime
  .run_app("MoUI Showcase")
  .program(runtime)
  .render(@render_skia.gpu())
  .render(@render_skia.raster())
  .backend(@backend_linux.entry())
  .run()
}
```

入口从 23 行变成 26 行，但 `moui/render/skia/` 整个 1106 行 MoonBit + 253 行 C++ 消失。

**新增一个 (P,R) 组合的边际成本**：新建一个 `examples/<app>/<platform>_<renderer>/` 目录，写 1 个 `moon.pkg`（约 15 行）+ 1 个 `main.mbt`（约 25 行），**不新建任何库包**。对比方案 D 的「约 130 行绑定包 + 1 个新包」，再对比现状的「341-1293 行 + 1 个新包」。

### 3.4 机制④：6 个绕过协商的包如何统一到 `RendererProviderBinding`

§1.7 已论证绕过的机制性原因：中立层缺少共同的 present 抽象，导致 sun/wgpu 没有零成本构造 binding 的路径。`HostPresentTarget`（§3.1）补上这个缺口后，收敛是自动发生的：

| 现状 | 迁移后 |
|---|---|
| `linux/sun/linux_sun_provider.mbt:44` 直接构造 `LinuxRendererProvider` 调 `run_app_with_renderer_provider` | 包删除。`@render_sun.raster()` 返回 `RendererBindingFactory`；`@backend_linux.entry()` 内部走 `@render.resolve_host_renderer`，**必然**经过 `select_renderer_provider_binding` |
| `macos/sun:59`、`windows/sun:44` | 同上 |
| `linux/wgpu:37`、`macos/wgpu:52`、`windows/wgpu:40` | 同上 |

关键点：**协商不是「要求这六条线去调用」，而是「平台入口只有这一条路径」**。`LinuxRendererProvider::create_renderer` 的闭包体在迁移后由 `moui/backend/linux` 自己写死为 `@render.resolve_host_renderer(factories, kit)`，合成根无法绕过 —— 它只能提供工厂列表，不能替换协商逻辑。

`sun` 的 binding 工厂（`moui/render/sun/provider.mbt:13` `create_sun_provider` 已存在，只需补外壳）：

```moonbit
// moui/render/sun/binding_factory.mbt（新增，约 28 行）

///|
pub fn raster() -> @render.RendererBindingFactory {
  @render.RendererBindingFactory::new(
    id="sun-raster",
    bind=kit => @render.RendererProviderBinding::new(
      provider=create_sun_provider(),
      create_host_renderer=(metrics, _bound) => SunRasterRenderer::create_with_present_target(
        metrics,
        present_target=sun_present_target_from_host(kit.present()),
        image_loader=kit.image_loader(),
      ).to_host_window_renderer(),
    ),
  )
}
```

`wgpu`（`moui/render/wgpu/provider.mbt:9` `create_wgpu_provider`）、`canvas2d`（`moui/render/canvas2d/provider.mbt:9`）、`webgpu_adapter`（`moui/render/webgpu_adapter/adapter.mbt:65,86`）同构。

**收敛后的不变量**：renderer negotiation 从 8 个分散的绑定装配点收敛为
`moui/render/host_surface_kit.mbt` 的一个 `resolve_host_renderer` 循环，覆盖的
(P,R) 组合从 7 条变成 13 条全覆盖。`select_renderer_provider_binding` 仍保留为
公开的直接 provider 选择辅助 API，但平台生产路径不再绕过 factory plan。这可以
直接作为 P3 的机器验收信号。

---

## 4. 迁移路径

每个阶段独立可验证、独立可回滚。P0-P1 为纯新增，P2 为单点试点，P3 为主体删除，P4-P5 为收尾。

### P0：中立契约补齐 + `native_gpu_selection.mbt` 拆分（纯新增，零删除）

**动作**

1. 新建 `moui/render/host_surface_kit.mbt`：`HostPixelFrame` / `HostPresentTarget` / `HostSurfaceKit` / `RendererBindingFactory` / `resolve_host_renderer`（§3.1、§3.3.2）。
2. 按方案 D §3.5.1（`:691-712`）拆分 `moui/render/native_gpu_selection.mbt`：
   - `GpuHostSurfaceDescriptor`（`:34-40`）留在 `moui/render`，文件更名为 `gpu_surface_descriptor.mbt`。
   - `NativeGpuPlatform`（`:10-17`）、`NativeRendererMode`（`:24-28`）、`NativeRendererMode::parse`（`:140-147`）、`NativePlatformSurface for NativeGpuPlatform` impl（`:108-137`）下沉 `moui/render/skia/skia_native_policy.mbt`。
   - 旧 `SkiaSurfaceRoute`（`moui/render/skia_surface_route.mbt`）随之下沉；`BoundSurface.route`（`provider_contract.mbt:24-27`）字段类型改为中立 `SurfaceRoute`（保留 `is_gpu` / `label`，去掉 `Skia` 前缀）。
3. `moui/render/skia`、`moui/render/sun` 内 `SkiaPresentTarget` / `SunPresentTarget` 增加 `from_host` 构造与 `HostPixelFrame` 互转（不删旧类型，保持二进制兼容不是要求，但 P0 阶段不动调用方）。
4. `moui/render/sun/renderer_surface_model.mbt:2-9` 的 `SunPixelFrame` 去掉冗余的 `pixels : FixedArray[Byte]`（与 `bytes : Bytes` 重复）。

**机器验证信号**

- `moon check --target native` 与 `--target wasm-gc` 全绿；13 个绑定包**零改动**编译通过。
- `moui/render/pkg.generated.mbti` 中旧 `SkiaSurfaceRoute` 消失，新增中立
  `SurfaceRoute` / `HostPixelFrame` / `HostPresentTarget` / `HostSurfaceKit` /
  `RendererBindingFactory`。
- `scripts/validate-renderer-provider-open-extension.mjs` 的 `SELECTION_ALLOWLIST_EXACT`（`:85-88`）中 `"moui/backend/host/host_rendering_test.mbt"` 一行可删且脚本仍通过（方案 D §3.5.2 `:713-716` 预言的豁免收缩）。
- `grep -c "Skia" moui/render/pkg.generated.mbti` 从 12 降到 0。

### P1：平台基座中立化（native stub 归位 + `entry()` 落地，绑定包仍在）

**动作**（六个原生平台 + web + wechat，每平台独立提交）

1. native stub 迁入平台基座并去 skia 命名：
   - `macos_skia_presenter.mm:42` → `moui/backend/macos/macos_present.mm` 的 `moui_macos_present_pixels_to_view`
   - `macos_skia_presenter.mm:152,174,216` + `macos_wgpu_surface_host.m:9`（重复实现）合并为 `moui/backend/macos/macos_metal_layer.mm`
   - `win32_skia_presenter.cpp:21` → `moui/backend/windows/win32_present.cpp`
   - `android_skia_presenter.cpp:9` → `moui/backend/android/android_present.cpp`
   - `ios_skia_view_glue.mm:62,81,89` → `moui/backend/ios/ios_metal_view.mm`
   - `linux_wgpu_surface_host.c:3`（5 行）→ `moui/backend/linux/linux_surface_host.c`
   - 六份 `*_async_image.*` 中的 I/O 部分合并为每平台一份 `moui/backend/<platform>/<platform>_async_image_io.*`；Skia 解码分支按 §5.1.1 U2 裁决下沉到 `moui/render/skia/skia_async_decode.cpp`。
2. 每平台新增 `<platform>_surface_kit.mbt`（§3.2）与 `<platform>_entry.mbt`（§3.3.3）。
3. 嵌入式三平台：新增 `<platform>_embedded_entry.mbt`，把 `RendererProviderAdapter`（`hosted_window_backend.mbt:33-40`）的 `create_renderer` 闭包体改为 `@render.resolve_host_renderer`。
4. `moui/runtime` 新增 `app_builder.mbt`（§3.3.3、§3.3.4）。
5. 13 个绑定包改为**转发到新入口**（内部实现替换，公开 API 不变），验证行为等价。

**机器验证信号**

- 每个 `moui/backend/<platform>/moon.pkg` 的 import 集合不变（本来就没有渲染器）。
- 新增文件中 `grep -iE "skia|sun|wgpu|canvas2d"` 结果为空。
- 13 个绑定包的 `pkg.generated.mbti` 逐字不变（公开 API 未变），`git diff --stat` 只覆盖实现文件。
- 全平台 smoke：`MOUI_LINUX_SUN_EXIT_AFTER_FIRST_PRESENT=1` 等首帧退出路径全部通过。
- `moui/backend/**` 下 native stub 总行数从 2412 降至约 1750（重复的 CAMetalLayer 实现与 sun/skia 双份 I/O 合并）。

### P2：试点删除 `linux/sun` + `linux/wgpu`

选这两个包的理由：native stub 面积最小（167 行 / 5 行），且都是当前**不走协商**的那 6 个之一，能同时验证「删包」与「收敛协商」两件事。

**动作**

1. 改写 `examples/showcase/linux_sun/main.mbt`、`examples/showcase/linux_wgpu/main.mbt`、`examples/showcase/linux_wgpu_cosmic/` 为 `AppBuilder` 形态。
2. 新增 `moui/render/sun/binding_factory.mbt`、`moui/render/wgpu/binding_factory.mbt`。
3. 删除 `moui/backend/linux/sun/`、`moui/render/wgpu/`。
4. `scripts/validate-renderer-provider-open-extension.mjs:65-83` 删除对应两条 allowlist 前缀。

**机器验证信号**

- `moui/backend/linux/{sun,wgpu}` 目录不存在。
- `SELECTION_ALLOWLIST_PREFIXES` 长度从 17 降到 15，脚本通过（棘轮 shrink 实证）。
- `moon build examples/showcase/linux_sun --target native` 成功且首帧 smoke 通过。
- `grep -rn "select_renderer_provider_binding" moui/backend/` 结果中不再包含 linux/sun、linux/wgpu 相关行；`examples/showcase/linux_sun` 的渲染器创建路径经 `@render.resolve_host_renderer` —— 用一条 wbtest 断言 `resolve_host_renderer` 在 sun 路径被调用。

### P3：全量删除剩余 11 个绑定子包

**动作**（按 native stub 面积从小到大分 4 批提交）

| 批次 | 删除包 | 需改写入口 |
|---|---|---|
| B1 | `wechat/canvas`、`macos/wgpu`、`windows/wgpu` | `examples/showcase/{wechat_canvas,macos_wgpu,macos_wgpu_cosmic,windows_wgpu,windows_wgpu_cosmic}` |
| B2 | `macos/sun`、`windows/sun` | `examples/showcase/{macos_sun,windows_sun}` |
| B3 | `android/skia`、`harmonyos/skia`、`ios/skia` | `examples/showcase/{android,harmonyos,ios}_window_hosted`、`examples/harmonyos_demo` |
| B4 | `linux/skia`、`macos/skia`、`windows/skia` | `examples/showcase/{linux,macos,windows}_skia`、`examples/markdown_editor/*`、`examples/mo_workbench/macos_skia`、`examples/mo_desktop/*` |

B4 之前必须完成 R3 校验器口径重设计（口径见 §5.1.1 U1），否则 `validate_harness_invariants` 会因 `desktop_skia_providers()`（`:67-72`）指向不存在的文件而 fail。

**机器验证信号**

- `find moui/backend -type d \( -name skia -o -name sun -o -name wgpu -o -name canvas \)` 无输出（E4）。
- `grep -rn "wzzc-dev/moui/render/" moui/backend --include=moon.pkg` 只剩 `wzzc-dev/moui/render`（根包），无子路径（E1）。
- `grep -rniE "\b(Skia|Sun|Wgpu|Canvas2D)[A-Z]" moui/backend --include=*.mbt` 无输出（E3）。
- renderer negotiation 生产路径只剩 `moui/render/host_surface_kit.mbt` 的
  `resolve_host_renderer`，从 8 个分散装配点收敛为一个中央循环，覆盖组合从
  7 条升到 13 条；`select_renderer_provider_binding` 保留为公开辅助 API，未被
  平台入口直接调用。
- 全部 `examples/*/moon.pkg` 中 `wzzc-dev/moui/backend/*/[a-z]*` 形式 import 归零。
- `sh scripts/check.sh --profile platform` 在 Darwin 通过。

### P4：web / wechat 去直连 + `AppBuilder` 门面收口

**动作**

1. `moui/backend/wechat/host_runtime.mbt`：
   - `:12` `mut renderer : @canvas2d.Canvas2DRenderer?` → `mut renderer : @render.HostWindowRenderer?`
   - `:37-39` 的 `Canvas2DRenderer::new` → `@render.resolve_host_renderer(factories, kit)`
   - `run_app` 增加 `factories~` 参数，由入口传入；旧签名删除（无兼容要求）
   - `:110-127` `wechat_render_frame` 改为通过 `HostWindowRenderer` 接口调用
   - `moui/backend/wechat/moon.pkg:6` 删除 `"wzzc-dev/moui/render/canvas2d"`
2. `moui/backend/web/webgpu_renderer.mbt`：
   - `:2` `type WebRendererError = @webgpu.WebGpuHostError` 改为中立错误类型
   - `:57` `web_renderer_provider_bindings` 删除（其内容迁到 `examples/showcase/web_wasm/main.mbt`，那里已经有雏形，见 `main.mbt:11-13`）
   - `:38` 的协商调用改为 `@render.resolve_host_renderer`
   - `moui/backend/web/moon.pkg:7` 删除 `"wzzc-dev/moui/render/webgpu_adapter" @webgpu`
3. `moui/backend/platform_bridge/skia_preflight_fragments.mbt` 删除，两个函数的字符串改为由渲染器侧提供：`moui/render/skia` 导出 `skia_host_renderer_bridge_preflight_{mobile,desktop}()`，preflight 汇总在合成根拼装。
4. `moui/runtime` 落地 `AppBuilder` 与 `run_app`（§3.3.4），`@runtime.run_app()` 成为**规范装配入口**；全部合成根迁移到该入口。根门面 `moui` 的 `run_app` re-export 不在本阶段做，按 §5.1.1 U3 裁决另走 RFC，且以 P5 的根门面依赖校验器落地为前置条件。
5. `moui/render/skia` 落地 `from_env()`（§5.1.1 U1），三个桌面合成根改写为 `.render_all(@render_skia.from_env())`；`MOUI_SKIA_RENDERER` 字面量在全仓收敛到该文件一处。

**机器验证信号**

- `grep -rn "wzzc-dev/moui/render/" moui/backend --include=moon.pkg` 完全无子路径命中（E1 对 web/wechat 也成立）。
- `grep -rn "MOUI_SKIA_RENDERER" --include=*.mbt moui/ examples/` 只在 `moui/render/skia/binding_factory.mbt` 命中一次。
- `grep -rn "run_app_with_options\|SkiaAppOptions" examples/` 无输出（合成根全部走 `@runtime.run_app()`）。
- `moui/backend` 全目录 `grep -riE "skia|sun|wgpu|canvas2d"` 命中数 = 0（含注释与字符串，E3 加强版）。
- `moui/backend/platform_bridge/` 下文件数 -1。
- 微信小程序 wasm 产物体积对比：`wechat/canvas` 包删除后 `.wasm` 不增大。

### P5：校验器口径重设计 + 文档批量更新 + 预算重置

**动作**

1. `tools/moui/validate_harness_invariants/main.mbt`：
   - `desktop_skia_providers()`（`:67-72`）改为 `desktop_composition_roots()`，指向 `examples/showcase/{macos,linux,windows}_skia/main.mbt`
   - `check_r3_provider_text`（`:433-458`）判定口径改为：合成根 `main.mbt` 引用 `@render_skia.from_env()`，**或**存在等价的 env 驱动装配（合成根自行含 `MOUI_SKIA_RENDERER` 字面量并据此排序注册）。口径以 §5.1.1 U1 裁决为准
2. `tools/moui/validate_skia_entrypoints/main.mbt`：
   - `skia_entries()`（`:71-157`）的 `backend_alias` 从 `@<p>_skia_backend` 改为 `@render_skia` + `@backend_<p>`
   - `options_type` / `run_function` 字段删除（不再有 `<Platform>SkiaAppOptions`），改为断言 `.render(@render_skia.` 与 `.backend(@backend_<p>.entry()`
   - `skia_provider_contracts()`（`:169-180`）改指 `moui/render/skia/binding_factory.mbt`
   - `platform_backend_import()`（`:186-190`）改为断言两条 import
3. `scripts/validate-renderer-provider-open-extension.mjs`：
   - `SELECTION_ALLOWLIST_PREFIXES`（`:65-83`）删除全部 12 条 backend 条目，只保留 `moui/render*` 5 条
   - `restrictedDirs`（`:103`）新增 `moui/backend`（此前因绑定包在里面而无法加）
4. `scripts/validate-backend-renderer-boundary.mjs` 实现 §2.3 的 E1-E4，并纳入 PR 校验。
5. 文档更新：
   - `docs/architecture.md` / `docs/zh-Hans/architecture.md:105,111,116,188-201`
   - `docs/zh-Hans/platform-notes-macos.md:3,10,13,25,37`（及 linux/windows 对应文件）
   - `docs/zh-Hans/wechat-support.md:18`
   - `docs/zh-Hans/examples.md:558,637,684`
   - `docs/invariants.md:20`（P6 表述改为「渲染器实现与 binding 工厂在 `moui/render/*`；`moui/backend/**` 对渲染器零依赖；合成根在应用入口」）
   - `docs/invariants.md:35`（R3）：按 §5.1.1 U1 裁决，措辞从「desktop skia provider 文件必须存在且含 `MOUI_SKIA_RENDERER` 字面量」改为「desktop 合成根须尊重 `--renderer`（经由 `moui/render/skia` 的 `from_env` 驱动选择）」
6. 架构决策沿用 ADR 0019-A 补充条款；根门面 re-export 约束另记录于 `docs/rfcs/0001-root-facade-run-app.md`。旧方案 D 已在顶部标记为被本计划取代，保留在 active 目录以供迁移审计追溯。
7. 重复度预算重置：`checks/platform-adapter-duplication-baseline.json` 中「Texture native surface creation」等条目的豁免范围收窄（CAMetalLayer 安装从两份变一份后，该条目的实际重复面积下降）。
8. 根门面最小依赖校验器（§5.1.1 U3 裁决的前置条件）：新增 `scripts/validate-root-facade-deps.mjs`，解析 `moui/moon.pkg` 的传递依赖闭包，允许中立 `moui/backend/host` 合同但拒绝平台 backend；`moui/render` 是否准入由 RFC 决定，校验器以显式 allowlist 表达。同时在 `docs/rfcs/` 建立「根门面 re-export `run_app`」RFC 条目，其合入门槛写明「本校验器已在 `scripts/check.sh` 中生效」。

**机器验证信号**

- `sh scripts/check.sh` 全绿。
- `scripts/validate-renderer-provider-open-extension.mjs` 的 allowlist 从 17+2 条降到 5+1 条。
- `grep -rn "backend/[a-z]*/\(skia\|sun\|wgpu\|canvas\)" docs/ --include=*.md | grep -v plans/done` 无输出。
- `checks/platform-adapter-duplication-baseline.json` 的总重复行数单调下降（P12 shrink-or-stay）。
- `scripts/validate-root-facade-deps.mjs` 在 `moui/moon.pkg` 未改动时通过；中立 `wzzc-dev/moui/backend/host` 允许，向闭包加入 `wzzc-dev/moui/backend/linux` 后必须失败（负例自测）。
- `grep -n "renderer-backend-decoupling" docs/plans/active/*.md` 与 `docs/plans/active/renderer-backend-decoupling.md` 首行的作废声明互相对应。

---

## 5. 风险与未决项

### 5.1 未决项（已于 2026-08-03 全部裁决，结论见 §5.1.1）

> 本节保留提案时的原始论证与备选项对比，供追溯决策依据。**执行口径以 §5.1.1 为准。**

**U1（必须先决）：R3 校验口径重设计**

现状：`check_r3_provider_text`（`tools/moui/validate_harness_invariants/main.mbt:433-458`）硬要求三个 `moui/backend/*/skia/*_skia_provider.mbt` 文件存在且体内含 `MOUI_SKIA_RENDERER`。方案 D §3.5.3（`:717-723`）明确指出 `has_env` 是硬条件，`MOUI_SKIA_RENDERER` 字面量必须留在 provider 文件里。**本方案删除了这三个文件，该约束必然被打破。**

关键区分：R3 的**语义目标**是「桌面入口尊重 `--renderer auto|skia-gpu|skia-raster`」，不是「某个特定路径的文件存在」。删包不改变语义目标，只改变实现位置。

推荐做法（推荐项 A）：把判定对象从「backend provider 文件」改为「桌面合成根 `main.mbt`」，判定内容改为二选一：
- 合成根含 `MOUI_SKIA_RENDERER` 字面量（应用自行读环境变量并据此决定注册顺序）；**或**
- 合成根同时含 `@render_skia.gpu()` 与 `@render_skia.raster()`（存在 GPU→CPU 回落链，等价于 `auto` 语义）

同时在 `moui/render/skia` 提供 `pub fn from_env() -> Array[@render.RendererBindingFactory]`，读 `MOUI_SKIA_RENDERER` 并返回相应顺序的工厂列表，让合成根写成 `.render_all(@render_skia.from_env())` —— 这样 `MOUI_SKIA_RENDERER` 字面量落在 `moui/render/skia`，合成根用 `from_env()` 表达意图，R3 判定 `from_env()` 出现即可。

备选项 B：保留 `MOUI_SKIA_RENDERER` 读取在合成根 `main.mbt` 里显式写。语义更透明但每个入口重复约 8 行。

**推荐 A**：字面量集中在渲染器包一处，合成根一行表达，R3 判定简单且不退化。

**U2：Skia 后台解码线程的归属**

现状：`linux_async_image.cpp:24-30`（及 macos/windows 对应文件）在 worker 线程里用 `SkCodec` 解码，`*_sun_async_image.*` 只读文件字节、在主线程解码。删包后必须二选一：

- 选项 A（推荐）：`moui/backend/<platform>` 只保留中立文件 I/O（合并 skia/sun 两版为一版，约 -40% 行数）；`moui/render/skia` 新增自己的 `native-stub`（`skia_async_decode.cpp`），保持后台解码。`moui/render/skia/moon.pkg:18-20` 已有 `link` 段，加 `"native-stub"` 是标准操作。
- 选项 B：解码统一上主线程，backend 只出字节。实现最简，但大图首帧延迟回归，且 `skia_preflight_fragments.mbt:14` 声明的 `renderer_async_image_loading=off-main-io` 不再成立。

**推荐 A**：保持已交付的性能特性，代价是 `moui/render/skia` 多一个 native-stub 文件。

**U3：`AppBuilder` 是否在根门面 `moui` re-export**

`moui/moon.pkg:1-3` 目前只 import `moui/core`，`moui/moui.mbt` 只有 `pub using @core`。要让用户写 `@moui.run_app(...)`，需给根门面加 `wzzc-dev/moui/runtime` import，根门面的依赖足迹会扩大到 `render` + `backend/host`。

**推荐**：P4 阶段先只在 `moui/runtime` 提供（`@runtime.run_app(...)`），根门面 re-export 单独提 RFC。理由：根门面的最小依赖属性目前没有校验器保护，一旦扩大很难缩回，不应该顺带做掉。

### 5.1.1 总监裁决（2026-08-03）

项目总监已对 §5.1 三项未决项作出裁决，以下为最终口径。**§5.1 中的「推荐 / 备选」表述自本节起仅作背景保留，执行以本节为准。**

#### 裁决 U1：采纳推荐项 A —— R3 判定对象上移到桌面合成根

裁决内容：

1. R3 的判定对象从「三个 `moui/backend/*/skia/*_skia_provider.mbt`」改为「桌面合成根 `examples/showcase/{macos,linux,windows}_skia/main.mbt`」。
2. 判定内容：合成根须引用 `@render_skia.from_env()`，或存在等价的 env 驱动装配（合成根内自行读取 `MOUI_SKIA_RENDERER` 并据此决定注册顺序）。
3. `moui/render/skia` 新增 `from_env()`，读 `MOUI_SKIA_RENDERER` 返回按优先级排序的工厂列表；合成根写 `.render_all(@render_skia.from_env())`（`render_all` 定义见 §3.3.4）。
4. `MOUI_SKIA_RENDERER` 字面量在全仓收敛到 `moui/render/skia` 一处。
5. `docs/invariants.md:35`（R3）措辞同步改写：从「desktop skia provider 文件必须存在且含 `MOUI_SKIA_RENDERER` 字面量」改为「desktop 合成根须尊重 `--renderer`（经由 `moui/render/skia` 的 `from_env` 驱动选择）」。该改写列入 P5 清单。

签名口径校正（执行时按此为准）：裁决文中写作 `from_env() -> Array[RendererProvider]`，但按 §3.1 与 §3.3.2 的类型分层，`RendererProvider` 必须由 `HostSurfaceKit` 兑付后才能构造，合成根阶段拿不到平台 kit。因此实际签名为：

> **总监补证（2026-08-03，机械核验）**：该校正成立，但原表述的论据不够精确，按以下证据为准。
>
> `moui/render/provider_contract.mbt:80-96` 的 `RendererProvider` 结构体字段**不直接出现** `HostSurfaceKit`（本方案中该类型尚不存在，全仓 grep `HostSurfaceKit` 在 `moui/render` 下零命中），因此不能从字段类型推出「需 kit 兑付」。真正的约束在 `create` 字段的**闭包捕获**上：
>
> - `moui/render/skia/provider.mbt:9-23` `create_skia_raster_provider(create_raster~ : (RendererSurfaceMetrics) -> SkiaRasterRenderer) -> RendererProvider` —— 构造 provider 的前提是先有 `create_raster` 闭包。
> - 该闭包必须返回 `SkiaRasterRenderer`，而它持有 `SkiaPresentTarget`（`moui/render/skia/renderer_surface.mbt:11-14`，`{description, present : (SkiaPixelFrame) -> Bool}`）。
> - `present` 回调是**宿主在窗口创建之后**才能提供的（`provider.mbt:5-8` 注释原文：让平台入口 "capture its own `SkiaPresentTarget` without the provider needing to know the platform"）。
>
> 结论：合成根运行在窗口创建之前，拿不到 `present` 回调 ⇒ 造不出 `create_raster` ⇒ **造不出 `RendererProvider`**。故 `from_env()` 只能返回延迟工厂，原签名 `Array[RendererProvider]` 类型上不可实现。
>
> 附带的低风险信号：`provider.mbt:53-72` `create_skia_raster_host_binding(create_host_renderer~) -> RendererProviderBinding` 与 `:77-96` 的 hybrid 版本，**已经**是「收宿主闭包 → 还 binding」的形状。`RendererBindingFactory` 不是发明新机制，而是把这两个已有函数升格为一等值并延后调用，实现风险相应下调（见 §5.2 风险表可据此复核 X-5 的迁移比例假设）。

```moonbit
// moui/render/skia/binding_factory.mbt
///|
/// 读 MOUI_SKIA_RENDERER，返回按协商优先级排序的绑定工厂列表。
/// - "skia-gpu"    -> [gpu()]
/// - "skia-raster" -> [raster()]
/// - "auto" / 未设置 -> [gpu(), raster()]（GPU 优先，失败回落 CPU）
pub fn from_env() -> Array[@render.RendererBindingFactory]
```

这是**类型层的表述校正，不是语义变更**：返回的仍是「按环境变量排序的工厂列表」，与裁决括注中的「工厂列表」一致。

#### 裁决 U2：采纳推荐项 A —— 后台解码下沉到 `moui/render/skia`

裁决内容：

1. `moui/backend/<platform>` 的异步图片路径只保留中立文件 I/O，skia 版与 sun 版两套 native stub 合并为一套（`linux_async_image.cpp` 与 `linux_sun_async_image.c` 合一，macos / windows 同理，预计减少约 40% 行数，依据见 §1.3）。
2. `moui/render/skia` 新增自有 native stub `skia_async_decode.cpp`，`SkCodec` 解码留在 worker 线程；其 `moon.pkg:18-20` 已有 `link` 段，追加 `"native-stub"` 即可。
3. 选项 B（解码统一上主线程）**否决**，理由：会使 `moui/platform_bridge/skia_preflight_fragments.mbt:14` 声明的 `renderer_async_image_loading=off-main-io` 不再成立，属于已交付能力的回归。

#### 裁决 U3：采纳混合方案 —— builder 落在 `runtime`，根门面 re-export 走 RFC + 校验器

裁决内容：

1. `AppBuilder` 的定义与实现落在 `moui/runtime`，P4 阶段实现并暴露 `@runtime.run_app()` 作为**规范入口**（`moui/runtime/moon.pkg:1-6` 已具备 `core` + `render` + `backend/host`，零新增依赖）。
2. 同时在根门面 `moui` re-export `run_app`，对齐用户原始诉求的 `@moui.run_app()` 拼写；但该 re-export **作为独立 RFC 跟踪**，不与 P0-P5 主线捆绑合入。
3. 新增（或扩展现有）校验器保护「根门面最小依赖」不变量，防止 `render` / `backend` / `host` 被无约束地拖进根门面的依赖闭包。该校验器是 re-export RFC 的**前置条件**：校验器先落地，re-export 才允许合入。

由此产生的两项新增动作已并入迁移路径：

| 动作 | 归属阶段 | 说明 |
|---|---|---|
| `@runtime.run_app()` 落地并成为规范入口 | P4 | 已在 P4 动作 4 中细化 |
| `scripts/validate-root-facade-deps.mjs` + `docs/rfcs/` 下的 re-export RFC | P5 | 见 P5 动作 8 |

裁决的直接后果：§5.1 U3 中「根门面依赖足迹会扩大且无校验器保护」这一顾虑由「先建校验器、再谈扩大」的顺序约束解决，风险从「不可逆扩散」降级为「受校验器约束的可控扩散」。

### 5.2 风险

| 编号 | 风险 | 影响 | 缓解 |
|---|---|---|---|
| X-1 | native stub 迁移改变符号名，链接期错误只在对应平台机器上暴露 | 高：Windows/HarmonyOS/iOS 无本地机器，只能靠 CI | P1 分平台提交，每个平台单独一条 CI；`moui/render/skia` 的 C stub 需要 `windows.h`（`docs/zh-Hans/release-readiness.md:80` 已记录 Darwin 上必然失败），改名后必须在 Windows runner 验证 |
| X-2 | `moon.pkg` 无特性开关，合成根数量随 (P,R) 线性增长 | 中：`examples/` 下目录数不变（现在就是一个组合一个目录），但每个目录的 `main.mbt` 有约 20 行 app 装配重复 | 提供 `examples/showcase/composition/` 共享 helper 包，导出 `fn build_showcase_runtime(host_summary, services, timer_source) -> AppRuntime`，各入口只剩 6-8 行；这是**入口层**的共享，不是 backend 层，不违反本方案目标 |
| X-3 | 嵌入式三平台（android/ios/harmonyos）的 `EventLoop::run_app` 生命周期与 `AppBuilder::run()` 不兼容 | 中 | `AppBuilder` 提供 `renderer_factories()` 终结（§3.3.4），嵌入式入口用 `provider_factory=() => @backend_android.provider_adapter(builder.renderer_factories())`；R3 对嵌入式的判定（`docs/invariants.md:35` 的 `*_window_hosted` + `EventLoop.run_app` 部分）不受影响 |
| X-4 | `BoundSurface.route` 类型从旧 `SkiaSurfaceRoute` 改为中立 `SurfaceRoute`，波及 `moui/render` 全部 5 处公开签名 | 中：`pkg.generated.mbti:56,96,121,126,127,907` | P0 一次性完成，纯改名无语义变化；`moon info` 重新生成 `.mbti` 后 diff 可逐行核对 |
| X-5 | 删除 13 个包会同时删掉 2536 行测试；其中覆盖的行为若无处安放会造成覆盖率回退 | 高 | 逐包审计：provider 构造类测试迁到 `moui/render/<renderer>` 的 binding_factory 测试；平台 surface kit 类测试迁到 `moui/backend/<platform>`；端到端 smoke 迁到合成根。P2 试点时先在 `linux/sun` 上验证迁移比例，若可迁移率低于 70% 需重新评估 |
| X-6 | `MOUI_SKIA_STUB_CC_FLAGS`（`moui/render/skia/moon.pkg:25`）等构建变量随包删除后需在合成根 `moon.pkg` 重新声明 | 中 | P3 每批提交同时更新对应入口的 `options(link:)`；`prebuild` / `link_configs` 的注入点也需同步（`docs/zh-Hans/platform-notes-macos.md:37` 记录过缺失症状） |
| X-7 | 方案 D 与本方案同为 active，可能被并行执行造成冲突 | 高 | 本方案获批后立即在 `renderer-backend-decoupling.md` 顶部加作废说明并标注被取代章节（§0.1），Phase 1-5 停止执行 |

---

## 6. 收益汇总

### 6.1 代码量

| 项目 | 迁移前 | 迁移后 | 净变化 |
|---|---:|---:|---:|
| `moui/backend/**` 绑定子包生产 `.mbt` | 5767 | 0 | **-5767** |
| `moui/backend/**` 绑定子包测试 `.mbt` | 2536 | 约 700（迁移后保留） | 约 -1836 |
| `moui/backend/**` 绑定子包 `.mbti` | 433 | 0 | **-433** |
| `moui/backend/**` 绑定子包 `moon.pkg` | 321 | 0 | **-321** |
| native stub（13 包内） | 2412 | 约 1750（迁入平台基座，去重后） | 约 -662 |
| `moui/render` 新增中立契约 | 0 | 约 180 | +180 |
| `moui/render/<renderer>` binding 工厂（5 个） | 0 | 约 160 | +160 |
| `moui/backend/<platform>` surface kit + entry（8 个） | 0 | 约 640 | +640 |
| `moui/runtime/app_builder.mbt` | 0 | 约 190 | +190 |
| `examples/**` 入口净增 | — | — | 约 +80（22 个入口各 +3~4 行） |
| **合计** | | | **约 -7729 行** |

### 6.2 结构指标

| 指标 | 迁移前 | 迁移后 |
|---|---|---|
| `moui/backend` → `moui/render/<renderer>` 依赖数 | 15（13 绑定包 + web + wechat） | **0** |
| `moui/render` → `moui/backend` 依赖数 | 0 | 0（保持） |
| `moui/backend` 下包总数（含中立 host、platform bridge 和 internal 支撑包） | 24 | **13** |
| 中央 renderer negotiation 路径 | 8 个绑定包各自装配，覆盖 7/13 组合 | **1 个 `resolve_host_renderer` 循环，覆盖 13/13 组合** |
| 绕过协商的 (P,R) 组合 | 6 | **0** |
| `<Platform><Renderer>AppOptions` 转发层 | 12 份，19 处字段漂移 | **0 份，0 处漂移** |
| `renderer_metrics_from_host` 复制份数 | 12 | **8**（每平台 1 份，在基座内） |
| CAMetalLayer 安装实现份数（macOS） | 2（skia + wgpu 各一份） | **1** |
| CPU 像素呈现 stub 份数（每桌面平台） | 2（skia + sun 各一份） | **1** |
| 每平台异步图片 I/O stub 份数 | 2 | **1** |
| `MOUI_SKIA_RENDERER` 读取点 | 3（三个 backend provider 文件） | **1**（`moui/render/skia` 的 `from_env`，见 §5.1.1 U1） |
| 新增一个 (P,R) 组合的成本 | 1 个新包 + 341~1293 行 | **0 个新包 + 约 40 行入口** |
| `validate-renderer-provider-open-extension.mjs` allowlist 条目 | 17 前缀 + 2 精确 | **5 前缀 + 1 精确** |

### 6.3 与方案 D 的量化对比

| 维度 | 方案 D | 本方案 |
|---|---|---|
| 净减少行数 | 约 830-900 | **约 7729** |
| `moui/backend` 渲染器依赖 | 13（保留绑定包） | **0** |
| 渲染器绑定层包数量变化 | +1 | **-13** |
| 新增 (P,R) 边际成本 | 约 130 行 + 1 个新包 | **约 40 行 + 0 个新包** |
| 绕过协商的组合数 | 0（通过 `from_provider` 让协商成为默认路径） | **0**（通过平台入口只有一条路径，更强） |
| 校验器改动量 | 小（1 处简化，R3 无需改动） | **大**（R3 口径重设计 + 3 个工具 + 1 个新脚本） |
| 主要风险 | 低 | X-1（跨平台链接期）、X-5（测试迁移） |

方案 D 用小改动换 10% 的收益，本方案用大改动换 93% 的收益。两者不是渐进关系——方案 D 的 Phase 1-5 做完之后再做本方案，绑定包瘦身的那部分工作会被完整丢弃。**因此本方案获批即应停止方案 D 的执行**（X-7）。

---

## 附录 A：证据索引

> 本附录保留迁移前诊断所用的路径和行号，便于追溯决策依据；其中标记为
> 删除/作废的路径不代表当前生产代码。当前结构和校验结果以本文顶部的
> 「执行结果」、`docs/invariants.md` 及各 validator 输出为准。

### A.1 中立契约（`moui/render`）

```
provider_contract.mbt:5-10      SurfaceDescriptor
provider_contract.mbt:24-27     BoundSurface
provider_contract.mbt:42-50     RendererInstance
provider_contract.mbt:80-96     RendererProvider
provider_contract.mbt:104-107   RendererProviderBinding
provider_contract.mbt:128-140   select_renderer_provider_binding
provider_contract.mbt:144       renderer_provider_binding_providers
provider_contract.mbt:153       RendererProviderRegistry
native_gpu_selection.mbt:10-17  NativeGpuPlatform（P0 下沉）
native_gpu_selection.mbt:24-28  NativeRendererMode（P0 下沉）
native_gpu_selection.mbt:34-40  GpuHostSurfaceDescriptor（P0 保留）
host_window_renderer.mbt:34     HostWindowRenderer
image_repaint.mbt:425           HostAsyncImageLoader
image_repaint.mbt:440           HostNativeAsyncImageSource
image_repaint.mbt:519           HostNativeAsyncImageSource::loader_with_drain
moon.pkg:1-6                    render 层依赖（无 backend）
pkg.generated.mbti:56,96,121,126,127,861,907   SurfaceRoute 残迹
```

### A.2 平台注入点

```
moui/backend/linux/linux_backend.mbt:59-63       LinuxRendererProvider
moui/backend/linux/linux_backend.mbt:120-129     LinuxRendererProvider::new
moui/backend/linux/linux_app_runtime.mbt:2-17    run_app_with_renderer_provider
moui/backend/linux/linux_app_runtime.mbt:20-35   run_app_with_renderer_provider_smoke
moui/backend/macos/macos_backend.mbt:53          MacosRendererProvider
moui/backend/macos/macos_app_runtime.mbt:5,24,51 三个入口变体
moui/backend/windows/windows_backend.mbt:53      WindowsRendererProvider
moui/backend/windows/windows_backend.mbt:107,125 两个入口变体
moui/backend/android/android_backend.mbt:71      AndroidRendererProvider::new
moui/backend/android/android_backend.mbt:123     renderer_provider_adapter_from_android
moui/backend/ios/ios_backend.mbt:73,125          同构
moui/backend/harmonyos/harmonyos_backend.mbt:73,125  同构
moui/backend/internal/embedded_runtime_backend/hosted_window_backend.mbt:33-46
                                                 RendererProviderAdapter
```

### A.3 违例点

```
moui/backend/web/moon.pkg:7                      import @webgpu
moui/backend/web/webgpu_renderer.mbt:2,38,57     直连 webgpu
moui/backend/wechat/moon.pkg:6                   import render/canvas2d
moui/backend/wechat/host_runtime.mbt:12,37,38,39,43   基座持有 Canvas2DRenderer
moui/backend/platform_bridge/skia_preflight_fragments.mbt:6,14   Skia 字符串
```

### A.4 绕过协商的 6 个包

```
moui/backend/linux/sun/linux_sun_provider.mbt:44,64
moui/backend/macos/sun/macos_sun_provider.mbt:59,83,110
moui/backend/windows/sun/windows_sun_provider.mbt:44,64
moui/render/wgpu/linux_wgpu_provider.mbt:37
moui/render/wgpu/macos_wgpu_provider.mbt:52,71
moui/render/wgpu/windows_wgpu_provider.mbt:40
```

### A.5 native stub 清单

```
moui/render/skia/macos_skia_presenter.mm:42,152,174,216   249 行
moui/render/skia/macos_async_image.mm                     236 行
moui/backend/macos/sun/macos_sun_async_image.m                   160 行
moui/render/wgpu/macos_wgpu_surface_host.m:9               58 行
moui/render/skia/win32_skia_presenter.cpp:21            122 行
moui/render/skia/windows_async_image.cpp                310 行
moui/backend/windows/sun/windows_sun_async_image.c               239 行
moui/render/wgpu/win32_wgpu_surface_host.c               34 行
moui/render/skia/linux_async_image.cpp:24-30              253 行
moui/backend/linux/sun/linux_sun_async_image.c                   167 行
moui/render/wgpu/linux_wgpu_surface_host.c:3                5 行
moui/render/skia/android_skia_presenter.cpp:9            64 行
moui/render/skia/ios_skia_presenter.mm                      221 行
moui/render/skia/ios_skia_view_glue.mm:62,81,89             151 行
moui/render/skia/harmonyos_skia_presenter.cpp         143 行
```

### A.6 渲染器工厂现状

```
moui/render/skia/provider.mbt:9    create_skia_raster_provider
moui/render/skia/provider.mbt:31   create_skia_hybrid_provider
moui/render/skia/provider.mbt:53   create_skia_raster_host_binding
moui/render/skia/provider.mbt:77   create_skia_hybrid_host_binding
moui/render/skia/renderer_surface.mbt:2-8,11-14   SkiaPixelFrame / SkiaPresentTarget
moui/render/sun/provider.mbt:13    create_sun_provider
moui/render/sun/renderer_surface_model.mbt:2-9,12-15  SunPixelFrame / SunPresentTarget
moui/render/wgpu/provider.mbt:9    create_wgpu_provider
moui/render/canvas2d/provider.mbt:9  create_canvas2d_provider
moui/render/webgpu_adapter/adapter.mbt:65,86  create_webgpu_provider / fallback
```

### A.7 校验器与文档

```
tools/moui/validate_harness_invariants/main.mbt:67-72,433-458
tools/moui/validate_skia_entrypoints/main.mbt:71-157,169-180,186-190
scripts/validate-renderer-provider-open-extension.mjs:65-83,85-88,103
docs/invariants.md:19,20,35
docs/architecture.md / docs/zh-Hans/architecture.md:105,111,116,188-201
docs/zh-Hans/platform-notes-macos.md:3,10,13,25,37
docs/zh-Hans/wechat-support.md:18
docs/zh-Hans/examples.md:558,637,684
docs/plans/active/renderer-backend-decoupling.md:24,108,324-326,691-723,850-868
```

### A.8 入口现状

```
examples/showcase/linux_skia/moon.pkg:4-5, main.mbt:18-22
examples/showcase/linux_sun/moon.pkg:5-6, main.mbt:22-29
examples/showcase/linux_wgpu/moon.pkg:4-5, main.mbt:18
examples/showcase/web_wasm/moon.pkg:3-4, main.mbt:11-13,32-36
examples/showcase/wechat_canvas/moon.pkg:2, main.mbt:16-26
examples/showcase/android_window_hosted/moon.pkg:3-4, main.mbt:4-19
examples/showcase/app/moon.pkg                （已同时 import backend/host 与 render）
```

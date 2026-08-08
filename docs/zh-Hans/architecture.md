# 架构

一页地图（定位时优先使用）：[`architecture-map.md`](architecture-map.md)。
文档目录：[`INDEX.md`](../INDEX.md)。约束：[`invariants.md`](../invariants.md)。

MoUI 是一个多平台 MoonBit GUI 框架。仓库围绕一条规则组织：应用逻辑保持平台无关，host backends 拥有窗口、生命周期和平台服务，应用 composition root 负责选择 renderer 并完成装配。

当前主线是 native Skia raster 加 Web
`wasm-gc + backend/web + browser WebGPU host imports` 路径。Native WGPU 仍是实验性诊断路线。除非变更有意更新架构，否则新工作应与这个形态保持一致。

运行时流水线是显式的：

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

## 代码地图

| 路径 | 所有者职责 |
| --- | --- |
| `moui/` | 面向 app-loop 类型的根 public facade：`View`、`Program`、`Effect`、`Subscription`、`Theme`、`Environment` 和 `ViewEnvironment`。 |
| `moui/{geometry,graphics,animation,text,state}/` | 面向应用的 geometry、paint/drawing、motion、text 和 state/focus value types 的 `moui/core` 领域门面。它们依赖 `core`；`core` 不依赖它们。 |
| `moui/core/` | 平台无关的基础契约：不透明 `View`、typed events、`Program`、`Effect`、`Subscription`、geometry、draw commands、semantics、text editing、theme token surface 和公开、与消息无关的 `ViewNode` 扩展协议。 |
| `moui/views/` | Public view constructors、面向应用的 control APIs、default themes、form/navigation/data helpers，以及通过 `@core.View::from_node` 构造的具体 `ViewNode` behavior。 |
| `moui/runtime/` | AppRuntime construction、runtime state、element/layout/render tree generation、event dispatch、program queue drain、effects、subscriptions、diagnostics 和 inspector snapshots。 |
| `moui/backend/` | 面向 windows、routes、timers、host services、WebView、async image loading、accessibility、input、redraw scheduling 和 renderer handoff 的共享 host contracts。 |
| `moui/backend/common/` | 无状态 DTO 转换与跨 owner window-host workflow；不持有宿主生命周期状态。 |
| `moui/backend/common/lifecycle/` | Window registry/request queue、runtime slots、平台窗口映射、逻辑 phase、surface generation、exit intent 与 exactly-once close。 |
| `moui/backend/common/frame/` | 逐窗口 `RendererSession`、pending/present completion、redraw、resize 与 IME frame hook。 |
| `moui/backend/common/image/` | 只拥有可取消的 image I/O task、opaque-token completion、callback detach 与 cancellation；`image/native` 提供 filesystem image-byte source。 |
| `moui/backend/common/input/` | 中立事件转换与 pointer/text/IME session state。平台原始 decode 留在具体 backend。 |
| `moui/backend/common/services/` | Service facade、async completion 与 bridge 生命周期；`services/{desktop,embedded,native}` 拥有具体 router、callback transport 与 filesystem services。 |
| `moui/backend/common/embedded/` | Android、iOS 和 HarmonyOS 的 embedded session 组合层：transport/session generation、renderer attach、IME、semantics、platform views 与 services；组合其他 owner，不复制 lifecycle/frame/image state。 |
| `moui/backend/{macos,windows,linux,android,ios,harmonyos,web}/` | 具体平台 backend implementations。macOS、Windows 和 Linux 是原生宿主后端；Android、iOS 和 HarmonyOS 是由 `wzzc-dev/window` 驱动的嵌入运行时后端；web 是 canonical browser host。 |
| `moui/backend/{macos,windows,linux,android,ios,harmonyos}/` | 只拥有平台窗口、surface、presenter、生命周期和中立 host I/O；renderer provider 不在 backend 内实现。 |
| `moui/render/` | Renderer-neutral frame/image/descriptor DTO、不透明 `HostSurface`/`NativeSurface` capability，以及 `RendererProvider`/`RendererSession` 两层生命周期契约；不包含平台或图形 API surface tag。 |
| `moui_skia_renderer/` | 基于 `moui_skia` 的 Native Skia renderer facade。 |
| `moui_web_renderer/` | `wasm-gc` 的 Browser WebGPU host-import adapter。 |
| `moui_wgpu_renderer/` | 实验性 native WGPU renderer 和 native text providers。 |
| `moui_sun_renderer/` | 实验性 Sun CPU raster renderer，基于仓库内 `moui_sun` workspace（ADR 0023：默认能力冻结，不在默认组合根）。 |
| `moui_sun/` | 实验性 MoonBit 原生 CPU raster graphics/text/softbuffer workspace（ADR 0023）。 |
| `moui_richtext/` | 富编辑应用使用的 Markdown/rich-text document、editor、command、input、paste、table 和 source-mapping 逻辑。 |
| `moui_skia/` | 可编辑的 Skia binding 以及 native/fallback capability contract workspace。 |
| `moui_theme/` | 可选设计系统 addon workspace，涵盖 Material、Carbon、Primer、Fluent、通用 source-mapped token diagnostics，以及 Sickle 等第一方 visual theme addons。 |
| `moui_tests/` | 不发布的测试模块，`tester/` 承接 harness 与 fixtures，并包含集成测试、benchmark、文本一致性套件及 renderer smoke。 |
| `moui_devtools/` | Devtools 和 overlay/debug helpers。 |
| `moui_agent/`, `moui_agent_mcp/` | Agent protocol、schema、host runtime 和 MCP router support packages。 |
| `examples/*/app/` | 共享应用逻辑包。除非刻意拆出 app-specific service package，否则这些包应保持平台无关。 |
| `examples/*/{web_wasm,macos_skia,windows_skia,linux_skia,...}/` | 为某个 app package 创建 runtime/backend/renderer 接线的薄平台入口。 |
| `tools/` | 由 `scripts/` 下 JS shell entrypoints 使用的 MoonBit-backed repository validators。 |
| `scripts/` | Local/CI command entrypoints、smoke runners、package validators 和 platform setup helpers。 |

## 后端宿主模型

这两种 native backend 模型按宿主所有权分类，而不是按设备形态分类。Android 和
HarmonyOS 可以运行在桌面硬件上；这不改变它们当前 MoUI 集成所采用的模型。

| 模型 | 当前平台 | 所有权边界 |
| --- | --- | --- |
| 原生宿主后端 | macOS、Windows、Linux | MoUI backend 拥有 host runtime、原生窗口生命周期、event-loop 集成和窗口注册表。 |
| 嵌入运行时后端 | Android、iOS、HarmonyOS | `wzzc-dev/window` embedder 拥有 lifecycle、surface、input 和 event loop；MoUI backend 拥有所附着的 runtime session 与 renderer composition。 |

## 应用边界

共享应用包默认应依赖：

- `wzzc-dev/moui`
- 按需使用 `wzzc-dev/moui/geometry`、`wzzc-dev/moui/graphics`、
  `wzzc-dev/moui/animation`、`wzzc-dev/moui/text` 和
  `wzzc-dev/moui/state` 等领域门面
- `wzzc-dev/moui/views`

仅当应用需要领域门面或 `moui/views` 未暴露的高级 kernel/diagnostic 类型时，才使用 `wzzc-dev/moui/core`。仅为 file import、WebView commands、route events 或 async image service integration 等 host service protocols 使用 `wzzc-dev/moui/backend`。

普通应用包应避免直接依赖：

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/render/*`
- 具体平台 backend packages
- renderer provider packages
- `moui_theme/*`，除非该 app 是 design-system preview 或 addon diagnostic

只有 `examples/showcase/app/diagnostics` 允许更宽，因为它展示 runtime 和 renderer capabilities。Components 和 Patterns 遵循普通应用依赖；Platform 可以额外导入 `backend`。把 Diagnostics 当作框架检查包，而不是默认 app dependency model。详细策略见 `docs/moui-app-package-boundary.md`。

## 框架边界

把新 API 加到最窄的归属包：

- 跨运行时协议和中立 value types 属于 `moui/core`。
- 基于 `core`、面向应用的领域门面属于
  `moui/{geometry,graphics,animation,text,state}`。它们可以依赖 `core`，但 `core` 不得依赖它们。
- 面向应用的 controls、control styles、form/navigation helpers、WebView facade、default themes 和具体 custom view implementations 属于 `moui/views`。
- Runtime lifecycle、inspector snapshots、effect/subscription diagnostics 和 runtime construction 属于 `moui/runtime`。
- Host service 和 platform service protocols 属于 `moui/backend`。
- 平台窗口、中立 presenter、native handle 与 host I/O 属于
  `moui/backend/<platform>`；这些包不得导入具体 renderer。
- Renderer implementation 和 capability reporting 属于 `moui/render/*`。
- Native Skia binding ownership、fallback parity、FFI borrow rules 和 native capability manifests 属于 `moui_skia`。

不要为每个功能新增顶层 public package。优先使用既有归属包，除非该能力可独立复用，并且无法由 `views`、`runtime`、`backend`、`render` 或 addon workspace 清晰拥有。

## 目标路线

- Web app route：shared app package -> `examples/<app>/web_wasm` composition ->
  `moui/backend/web` + `moui_web_renderer`。
- Native Skia route：shared app package -> platform `*_skia` entrypoint ->
  `@runtime.run_app(...).render_all(@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::<Platform>)).backend(@platform.entry())`
  -> 中立 platform surface + `moui_skia_renderer` -> `moui_skia`。
- Android 嵌入运行时路线（`experimental`）：shared app package ->
  `examples/<app>/android_window_hosted` composition，通过
  `@runtime.run_app(...).render_all(@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Android)).backend(@android.entry())`
  -> `wzzc-dev/window/android` `HostCmd` -> 共享
  `wzzc-dev/window/internal/embedded_dispatch` callback dispatch -> `EventLoop` -> 中立 Android
  surface binding -> `moui_skia_renderer` -> `moui_skia`。
  window template 拥有 Android lifecycle、surface acquisition 和 input；嵌入运行时
  backend 负责 runtime/session 与中立 surface 装配。
- iOS 嵌入运行时路线（`experimental`）：shared app package ->
  `examples/<app>/ios_window_hosted` composition，通过
  `@runtime.run_app(...).render_all(@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::IOS)).backend(@ios.entry())`
  -> `wzzc-dev/window/ios` `HostCmd` -> 共享 embedded-host kernel ->
  `EventLoop` -> 中立 iOS surface
  binding -> `moui_skia_renderer` -> `moui_skia`。UIKit lifecycle、
  surface 和 touch callbacks 只能经由 window event loop 进入。
- HarmonyOS 嵌入运行时路线（`experimental`）：shared app package ->
  `examples/<app>/harmonyos_window_hosted` composition，通过
  `@runtime.run_app(...).render_all(@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::HarmonyOS)).backend(@harmonyos.entry())`
  -> `wzzc-dev/window/harmonyos` `HostCmd` -> 共享 embedded-host kernel ->
  `EventLoop` -> 中立 HarmonyOS
  surface binding -> `moui_skia_renderer` -> `moui_skia`。
  Native XComponent callbacks 是 surface、pointer、resize 和 detach events 的唯一来源。
- Native WGPU route：shared app package -> platform `*_wgpu` entrypoint ->
  `@runtime.run_app(...).render(@render_wgpu.native(...)).backend(@platform.entry())`
  -> `moui_wgpu_renderer`。这是实验性且诊断性的路线，不是默认主线。

平台入口应保持很薄：创建 program/runtime，通过 AppBuilder 组合 backend 与 renderer provider，并传入 app-owned service adapters。业务 model/update/view 逻辑应留在 shared app package。

嵌入运行时 session 共享 `EmbedderHostChannel`，用于有序 IME 更新、带 generation 前置条件的已提交语义，以及异步 clipboard/accessibility responses。见
[Window-hosted MoUI](../window-hosted-moui.md)、ADR 0005 和 ADR 0006。现在的产品默认值是在每个 native Skia platform 上，只要 host GPU surface 可用（macOS、Windows、Linux、Android、iOS 和 HarmonyOS 的 `NativeGpuPlatform::gpu_promoted` 均为 `true`），就使用 `SkiaGpuNative`。Window-surface 路径是 Metal（macOS/iOS）、带 EGL/GLES fallback 的 Vulkan（Android）、EGL/GLES（HarmonyOS）、D3D12（Windows）和 Wayland Vulkan（Linux）。`SkiaRasterNative` 仍是显式 `skia-raster` 模式，并且是 terminal GPU failure 后的 sticky recovery fallback。Matching-device seven-gate manifests 仍是有用证据，并且在非 macOS hosts 上可能仍不完整，但它们不再阻挡产品 `auto` 默认值。Native `SkPicture`/POD handoff 运行在独立 `std::thread` 上，带 latest-wins frame slot、ordered controls、detach acknowledgement 和 polling diagnostics。Platform branches 在该 worker 上拥有 Metal、D3D12、Vulkan WSI 或 EGL context/surface/swapchain/synchronization resources，并且只有在 platform present call 后才发出 `Presented`。Android 动态加载 Vulkan，因此 API 23 仍可加载并 fallback 到 EGL/GLES。Native hosts 独立于 frame submission 轮询 worker completions，只计数 `Presented`，并在 terminal GPU recovery 切换到 raster 时保留当前 `AppRuntime`。

## 扩展规则

- 新控件：在 `moui/views` 中添加面向应用的 constructors 和具体行为；用 `@core.ViewNode` 实现与消息无关的 layout/paint/focus/semantics behavior，并用 `@core.View::from_node` 连接类型化 children/event/text command；不要为普通控件添加新的 core primitive enum variants。
- 新 app examples：先创建 `examples/<name>/app`，再添加一个或多个薄平台入口。
- 新 renderer capability：更新 implementation、tests、capability model、`docs/renderer-capability-report.md`，并在 text behavior 变化时更新文本 docs。
- 新 public API：更新或重新生成 `pkg.generated.mbti`，运行 API surface checks，并在 review 中说明归属包。
- 影响 workflow 的新 docs：更新根 `docs/`、`AGENTS.md` 和相关 `skills/` guidance。Website docs 由 `node scripts/sync-website-docs.mjs` 从 root docs 同步。

## 验证钩子

架构敏感的变更通常应运行：

```sh
sh scripts/check.sh --profile daily
moon info
node scripts/validate-api-surface.mjs
```

编辑时使用聚焦 package tests，然后在可行时于交付前运行 daily validation script。Platform 和 real-renderer behavior 需要 `docs/testing.md` 与 `docs/release-readiness.md` 中描述的 opt-in manual smoke gates。

## 范围

- 平台无关的 `core` contracts、不透明 views、environment/event/geometry、
  draw models，以及由类型化 `View[Msg]` adapter 包装的公开、与消息无关的 `ViewNode` protocol。
  `core` 只应增长跨运行时协议和共享 value types；具体 control behavior 属于 `moui/views`，并与 public view facade 放在一起。新控件不得添加 core enum variants、primitive constructors 或 lowering arms。持久 runtime state、element/render trees、layout、paint、event dispatch 和 program execution 由 runtime 拥有，不从 `core` 暴露。
- `moui/runtime` 是 app/host runtime entrypoint package。它暴露不透明
  `@runtime.AppRuntime` construction/query/dispatch methods，并拥有 program message drain、effect task、subscription lifecycle 和 runtime diagnostics。
- Public root package 只为 `@wzzc-dev/moui` consumers 别名化经过筛选的 app-loop types：`View`、`Program`、`Effect`、`Subscription`、`Theme`、`Environment` 和
  `ViewEnvironment`。Geometry、graphics、animation、text 和 state/focus aliases 位于各自领域门面。中立的 default/light/dark/custom theme builders 位于 `moui/views`，并返回普通 `@moui.Theme` 值。
- `moui_theme/common` 是可选 design-system addon 的面向应用构造公开面：
  `DesignPreset`、`DesignSystemTokens`、各系统 token structs 及其
  `core_*` projection methods，以及 `DesignPreset` 上的 construction-surface methods（`theme`/`tokens`/`label`...）。它只暴露应用用 branded system 构建 `@core.Theme` 所需的内容，不暴露 audit/diagnostics machinery。
- `moui_theme/audit` 是 design-system diagnostics package：source-mapped
  manifests、golden mappings、official-token/source-lock coverage、
  source-package inventories、source-imported token records（带 pinned file shas）、runtime token alignment、adaptation-difference、token taxonomy、
  semantic palette / typography role、token-group resolver、component-token
  matrix、density/variant resolver 和 customization capability reports。
  Audit methods 是 top-level `pub fn`（MoonBit 禁止给另一个包的类型定义 methods），由 `@common.DesignPreset` keyed。Apps 通过
  `@audit.xxx(@material.preset())` 使用它；variant packages 不再 re-export audit entrypoints。
- `moui_theme` 是 repo-local addon workspace member。它可以导入
  `wzzc-dev/moui/core`，但 `moui/core`、`moui/views` 和根
  `wzzc-dev/moui` package 不依赖 `moui_theme`。具体 Material、Carbon、Primer、Fluent 和第一方 addon theme names 通过
  `moui_theme/material`、`moui_theme/carbon`、`moui_theme/primer` 和
  `moui_theme/fluent` package entrypoints 加上 `moui_theme/sickle` 等聚焦包留在此 addon 中；`core` 保持为中立 token runtime。
- `views` 中 spec-first views，包括 `text`、`button`、`text_field`、`container`、row/column layout 和 spacer primitives。
- `backend` 中统一的 host boundaries，带共享 window-event mapping，平台 hosts 将 events 归一化为 `Event`。
- Native mainline rendering 通过基于 `moui_skia_renderer` 的 provider packages 完成，并在 `moui_wgpu_renderer` 下保留实验性 native WGPU diagnostics。
- Web rendering 只通过 `wasm-gc` 上的 `moui_web_renderer` 完成，并使用 browser WebGPU host imports 进行可见绘制。旧 JS-target WebGPU path 已有意移除。

## 包

```text
moui/                         root public facade workspace member
moui/core/                    platform-neutral contracts, opaque View, and custom view callback contracts
moui/runtime/                 opaque app/host AppRuntime entrypoint, runtime state, tree/layout/paint, and program execution
moui/views/                   public view constructors and concrete custom view control behavior
moui_theme/common/            addon construction surface: DesignPreset, DesignSystemTokens, per-system token structs + core_* projections, and the construction-surface DesignPreset methods
moui_theme/audit/             addon diagnostics: manifests, golden mappings, official-token/source-lock coverage, source-import records, runtime alignment, taxonomy/role/resolver/matrix reports (top-level pub fn, not DesignPreset methods)
moui_theme/{material,carbon,primer,fluent}/ package-local official-system entrypoints: light/dark/high-contrast/system Theme helpers, tokens, and theme_for_variant over common
moui_theme/sickle/            first-party hybrid skeuomorphic/flat Theme addon with light/dark and style-mode helpers
moui/backend/                 neutral Event/window/service/input/IME/accessibility protocols and DTOs
moui/backend/common/          stateless DTO conversion and cross-owner workflows
moui/backend/common/lifecycle/ registry, request, runtime slot, platform map, phase/generation and close
moui/backend/common/frame/    per-window RendererSession, redraw/resize/present completion and IME frame hooks
moui/backend/common/image/    image scheduling, repaint revision, completion, callback detach/cancellation
moui/backend/common/input/    neutral conversion and pointer/text/IME session state
moui/backend/common/services/ service facade, async completion, bridge lifetime and concrete service subpackages
moui/backend/windows/         Windows 原生宿主后端（仅中立 host surface/presenter）
moui/backend/macos/           macOS 原生宿主后端（仅中立 host surface/presenter）
moui/backend/linux/           Linux Wayland 原生宿主后端（仅中立 host surface/presenter）
moui/backend/android/         Android 嵌入运行时后端，基于共享 host/runtime contracts
moui/backend/ios/             iOS 嵌入运行时后端，基于共享 host/runtime contracts
moui/backend/harmonyos/       HarmonyOS 嵌入运行时后端，基于共享 host/runtime contracts
moui/backend/web/             canonical Web host on wasm-gc plus browser JS assets
moui/render/                  renderer facade and shared draw helpers
moui_skia_renderer/             native Skia raster renderer facade over moui_skia
moui_web_renderer/   browser WebGPU host-import renderer for wasm-gc
moui_wgpu_renderer/             experimental native wgpu renderer
moui_wgpu_renderer/cosmic_text/ Moon Cosmic provider for native wgpu text
moui_wgpu_renderer/coretext/    macOS CoreText provider for native wgpu text
moui_wgpu_renderer/text_protocol/ shared native measure/run/raster/register bytes protocol
moui_wgpu_renderer/directwrite/ Windows DirectWrite provider scaffold
moui_wgpu_renderer/fontconfig/  Linux fontconfig/HarfBuzz/FreeType provider scaffold
moui_tests/tooling/           quickcheck and pixelmatch integration tests
moui_tests/text_conformance/  opt-in native/Web text diagnostic matrix
moui_tests/skia_renderer_smoke/native/ opt-in real Skia renderer pixel smoke
moui_tests/skia_cached_layer_benchmark/ opt-in real Skia cached-layer benchmark harness
moui_tests/skia_text_emoji_smoke/ opt-in real Skia text/emoji renderer smoke
moui_tests/wgpu_renderer_smoke/ opt-in native WGPU renderer smoke
examples/counter/app/         smallest shared app shape
examples/counter/{macos_skia,web_wasm}/ retained Counter platform entrypoints
examples/harmonyos_demo/app/  standalone HarmonyOS demo app with viewport/tap feedback
examples/showcase/harmonyos_window_hosted/ Showcase HarmonyOS window-hosted entrypoint
examples/agent_counter/       minimal agent-controllable runtime example (shared app at example root plus main/ and macos_skia/ entrypoints)
examples/button_freeze_probe/app/ minimal native Skia button-freeze repro app
examples/button_freeze_probe/macos_skia/ retained Button Freeze Probe entrypoint
examples/showcase/            模块根 Showcase integration package
examples/showcase/app/components/ focused reusable component catalog with app-safe dependencies
examples/showcase/app/patterns/ Counter/Todo, forms, data, navigation, and workflow patterns
examples/showcase/app/platform/ host Effect/Subscription, canvas, routes, and mobile service probe
examples/showcase/app/diagnostics/ pure diagnostic DTO/view package
examples/showcase/diagnostics.mbt runtime/renderer DTO adapter
examples/design_systems/app/  dedicated addon diagnostic source-mapped design-system preview/parity example using moui_theme
examples/design_systems/{web_wasm,macos_skia}/ retained Design Systems addon diagnostic host entrypoints
examples/showcase/macos_skia/ macOS showcase selecting native Skia raster
examples/showcase/macos_wgpu/      macOS native WGPU diagnostic showcase
examples/showcase/web_wasm/   Web showcase on wasm-gc
examples/showcase/windows_skia/ Windows showcase selecting native Skia raster
examples/showcase/windows_wgpu/    Windows native WGPU diagnostic showcase
examples/showcase/linux_skia/ Linux showcase selecting native Skia raster
examples/showcase/linux_wgpu/      Linux Wayland native WGPU diagnostic showcase
examples/markdown_editor/app/  shared WYSIWYG Markdown editor app
examples/markdown_editor/macos_skia/ macOS Markdown editor selecting native Skia raster
examples/markdown_editor/web_wasm/ Web Markdown editor on wasm-gc
examples/code_editor/app/ shared native code editor and language-provider demo app
examples/code_editor/macos_skia/ retained Code Editor Skia entrypoint
examples/webview_demo/app/ shared native WebView demo app
examples/webview_demo/{macos_skia,web_wasm}/ retained WebView demo entrypoints
examples/pdf_workbench/app/  shared PDF reader/light editor app
examples/pdf_workbench/macos_skia/ retained PDF Workbench Skia entrypoint
examples/pdf_workbench/{pdflite_adapter,pdflite_service_protocol,pdflite_service_native_transport,pdflite_service_cli,pdfium_adapter}/ app-private PDF parse/writeback/raster adapter and service subpackages
examples/mo_workbench/app/   shared multi-backend agent desktop dogfood app
examples/mo_workbench/openseek_native_transport/ app-private OpenSeek in-process agent backend (native)
examples/mo_workbench/acp_native_transport/ app-private generic ACP stdio agent backend (native)
examples/mo_workbench/macos_skia/ macOS Mo Workbench native Skia entrypoint
examples/{settings,data_table,file_importer,command_palette}/app/ shared app-pattern packages without platform entrypoints
```

## 公共 View API

MoUI app code 使用不透明 `@moui.View[Msg]` 值和 typed TEA loop 构建 UI：`view : Model -> View[Msg]`、typed messages、`update` handlers，以及用于后续工作的显式 `Effect[Msg]`。`Subscription[Msg]` 声明持续的 event sources。完整细节见：[TEA 程序模型](../tea-program-model.md)。

关键公开面：`Program::simple` / `Program::new` / `*_with_environment`、
`Effect::send` / `Effect::run` / `Effect::task` / `Effect::service_task`、
`Subscription::timer` / `Subscription::host_event` / `Subscription::route_event`、
`View::map`、`Effect::map`、`Subscription::map`。Message drains 是有界 runtime turns；`AppRuntime::destroy()` 之后的 stale dispatchers 会被忽略。

## 运行时心智模型

MoUI 保持运行时流水线显式：

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

- `View[Msg]` 是应用代码生成的不可变、不透明 public description；它包装一个内部 view protocol，包含 identity、children、layout、paint、event、semantics、text-control 和 focus behavior。
- `ElementTree` 是已挂载 runtime tree。其 `ElementNode` entries 拥有 view identity、keys、child elements、dirty flags、runtime-owned control slots、layout memoization 和 damage state；renderer resource/cache residency 不在此镜像。
- `LayoutTree` 是最新 placement result。其 `PlacedNode` entries 携带 measurement 和 parent placement 产生的最终 frames。
- `RenderTree` 是 paint-stage tree。其 `RenderNode` entries 将 hit testing 和 draw command payloads 附加到来自 `LayoutTree` 的 frames。
- App code 通过 `Program`、`Effect`、`Subscription` 和 `ViewEnvironment` 使用 `AppRuntime`。`RuntimeState`、`ElementTree`、`LayoutTree`、`RenderTree` 及其 node types 是 engine implementation details。
- `ViewEnvironment` 是面向 TEA 的只读 environment snapshot。它暴露当前 viewport size 和 `Environment`，但不会把 backend/lifecycle ownership 或 renderer resources 暴露给 app-level views。
- hover、pressed、drag、caret、selection、IME composition 与非受控普通滚动属于按 element identity 和 runtime lifetime 作用域化的 `ViewStateSlot`。slot 不得持有 service、runtime、renderer、task handle 或 cleanup closure；需要被应用读取/恢复的滚动和 focus 才进入 Model，并通过不可变 request id 驱动。
- `AppRuntime` 拥有 app-level `Program` diagnostics，包括 message queue、effect/subscription lifecycle、stale dispatch rejection、pipeline pass counters 和 structured damage summary。Inspector 读取稳定的 layout/render/semantics snapshot，不会 drain pending work。它保留 effect、scheduled effect 与 subscription plan summary，供 tooling 在不检查 `Msg` 值的情况下识别 host-service/task runner。这是唯一的应用 state/effect 模型；不存在第二套 component lifecycle state machine。
- Layout 使用 constraints down、measured size up，然后 parent placement，并将结果写入 `LayoutTree`。
- Paint 消费 `LayoutTree` frames 来构建 `RenderTree`，并发出 platform-neutral `DrawCommand` 值。普通 host path 会向 `AppRuntime::draw_frame()` 请求 commands 和 `DamageRegion`；每个 retained layer 每帧都携带完整 payload，renderer session 自己决定命中、更新与淘汰。runtime 不保存 cache epoch/residency，backend 不提供 command-cache fallback。`DrawFrame.clear_color` 拥有 frame initialization，而其 command array 包含 view content，不包含前置 `Clear`；`DrawFrame.platform_views` 携带 native platform-view placements，而不把它们加入 `DrawCommand`。
- Backends 将 platform events 归一化为 `Event`；它们不拥有 UI state，也不直接修改 element/render trees。
- `HostRuntimeDriver` 在 host boundary 拥有 redraw scheduling，将归一化 events 分派到 `AppRuntime`，并为 renderers 暴露带 `FrameToken` 的 platform-neutral draw frame。`RendererSession::render_frame()` 接收完整 retained-layer 声明；Skia、Sun、WGPU 和 Web 的资源/缓存诊断留在各自 session。backend 只管理 pending frame、I/O task 与取消，applied image completion 才请求下一次 redraw。
- `AppRuntime::focus_next` 和 `AppRuntime::focus_previous` 在共享 tab-order model 之上暴露显式 focus traversal entry points。

## 状态与绑定

应用状态只有一条闭环：`Program<Model, Msg>`、`Effect<Msg>`、`Subscription<Msg>`
与只读 `ViewEnvironment`。业务数据、导航 route stack、表单值、文档和异步结果
必须在 `Model` 中，由 typed `Msg` 经 `update` 修改；副作用只能通过 `Effect` 与
`Subscription`。不再提供 `State`、`Binding`、`DerivedState`、`ComponentContext`、
component watch/effect/saveable 或任意 Model setter。

控件瞬态通过 `ViewStateSlot`/`ViewStateContext` 绑定到稳定 element identity 和
runtime lifetime。hover、pressed、drag、caret、selection、IME composition 和非受控
滚动不进入 Model；受控滚动/focus 使用 value + typed callback，程序化变化使用递增
`ScrollRequest`/`FocusRequest`。slot 是低层 custom-control API，不从 app facade 重导出。

## 布局

```text
Constraints down -> Size up -> parent places children
```

`Constraints::tight`、`Constraints::loose`、`Constraints::deflate`、
`Constraints::tighten` 和 `Constraints::unbounded` 可在 `core` 中使用。
`Padding` 会 deflate child constraints 并 inflate 自身 measured size。`Frame` 会 tighten child constraints。`Flex`、`Grid`、`List`、`Stack`、`Scroll` 和有序 layout modifiers 在 `moui/views` 中实现为具体 custom view behavior；runtime 测量 children，将 child sizes 传入 owning virtual node，并把返回的 child frames 存入 `PlacedNode`。Paint 会复用这些 placed child frames，而不会再次运行 layout。

高级 layout authors 可以使用 `@views.custom_children_layout` 定义 child layout delegate，同时仍返回 `View[Msg]`。该 delegate 接收 measured child sizes，返回自身 size，并用显式 frames 放置 children。它的 context 也暴露 child baselines 和 layout priorities，使 custom layouts 能对齐文本并做出 priority-aware placement decisions；paint 和 semantics metadata 保留在同一个 concrete `ViewNode` behavior surface 上。

## 修饰器与环境

Modifiers 表示为内部 view wrappers，而不是递归重写每个 child view。这让 modifier order 可观察，并使 disabled、focusable、semantics 和 shortcuts 等 stateful wrappers 可预测地组合：

```moonbit
@views.text("A").padding(8.0).background(@core.Color::gray())
@views.text("A").background(@core.Color::gray()).padding(8.0)
```

第一个在 padding 外绘制 background；第二个在 padding 内绘制。`font`、`foreground`、`corner_radius` 和 runtime text system 通过 render environment 流动，而 layout 与 paint modifiers 保持为有序 wrappers。
除 padding 和 frame 外，MoUI 当前支持 background brushes、opacity、shadow、border、offset、clip、scale、disabled、accessibility labels、semantics roles、focusability、tap actions、keyboard shortcuts，以及简单的 flexible/alignment wrappers。

## 视觉

MoUI 的视觉系统是一条 `ThemeSpec -> resolve_theme -> Theme` 流水线。`core` 拥有中立 schema 和 resolver；controls 在 paint time 从 ambient resolve styles。完整细节见：[视觉主题系统](../visual-theme-system.md)。

要点：`@views.light_theme()` / `@views.dark_theme()` resolve Minimal preset，`ButtonVariant::style(control_set)` 从 `control_set.button`（views 拥有的 `ControlThemeSet`，ADR 0017）resolve，`ControlStateStyle` 位于 `views` 并由 token resolver 和 view-layer style structs 共享，`DesignSemanticPalette` 携带 Fluent 2 neutral ramp。每控件 style resolution 另见 [按钮样式指南](../button-styling-guide.md)。

## 内置与自定义视图

public `views` 包包括 text、button、text field、checkbox、image、container、row/column、stack、scroll_view、grid、list、frame、padding、spacer、navigation stack、tab view、dialog host、lazy list、toggle、radio、slider、progress、menu button、tooltip 和 layout helper functions。

当前 public constructor matrix、test coverage 和 example coverage 见 [View catalog](../view-catalog.md)。
更大的 WYSIWYG editing workflow 记录在 [Markdown Editor](../markdown-editor.md)。

高级用户可以使用 `@views.custom_layout` 提供 measurement、paint 和 semantics callbacks，而无需暴露内部 runtime tree。其 concrete node 与普通 `moui/views` 控件一样实现 `ViewNode`，并通过 `View::from_node` 构造：

```moonbit
let swatch = @views.custom_layout(
  measure=constraints => constraints.constrain(@moui.Size::new(width=32.0, height=20.0)),
  paint=frame => [
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(rect=frame, radius=4.0),
      @core.Brush::solid(@core.Color::blue()),
    ),
  ],
  semantics_label="Color swatch",
)
```

对于带 children 的 custom layouts，使用 `@views.custom_children_layout` helper：

```moonbit
let pair = @views.custom_children_layout(
  children=[@views.text("A"), @views.text("B")],
  measure=ctx => ctx.constraints.constrain(@moui.Size::new(width=160.0, height=24.0)),
  place=ctx => [
    @core.Rect::new(x=ctx.frame.origin.x, y=ctx.frame.origin.y, width=80.0, height=24.0),
    @core.Rect::new(x=ctx.frame.origin.x + 80.0, y=ctx.frame.origin.y, width=80.0, height=24.0),
  ],
  semantics_label="Custom pair",
)
```

添加可复用控件时，将其具体 custom view behavior 放入 `moui/views`，从 `moui/views` 暴露面向应用的 constructor，并围绕 custom view runtime behavior 添加 tests。不要从 app-facing facade 重导出 `ViewNode`，不要添加 `@core.View::primitive_*_view` constructor、`ViewLoweringSink` 或新控件的 runtime lowering arm。

## 平台 Host 契约

`backend` 定义平台包与平台无关 runtime 之间的共享边界。它覆盖 window lifecycle、multi-window bookkeeping、host-event subscriptions、timer/route sources、WebView contracts、async image loading、typed host services、keyboard shortcuts、menus、file drop 和 renderer handoff。完整细节见：[平台 Host 契约](../platform-host-contract.md)。

setup、backend-specific constraints 和 validation commands 见 [平台说明](../platform-notes.md)。

## 可访问性

`core/semantics.mbt` 生成平台无关 semantics tree，包含 roles、labels、hints、values、focus order、checked state 和 live-region metadata。`backend/web` 包含用于 wasm-gc Web path 的 semantics-to-ARIA adapter。Native accessibility snapshots 从 `backend` 导出为 `Milky2018/moon_accesskit` tree updates。Platform bridges 留在 backend boundaries 后面，并消费 AccessKit-shaped snapshot，而 `@core.SemanticsNode` 仍是 source of truth。

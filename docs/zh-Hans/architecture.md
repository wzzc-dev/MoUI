# 架构

一页地图（定位时优先使用）：[`architecture-map.md`](architecture-map.md)。
文档目录：[`INDEX.md`](../INDEX.md)。约束：[`invariants.md`](../invariants.md)。

MoUI 是一个多平台 MoonBit GUI 框架。仓库围绕一条规则组织：应用逻辑保持平台无关，而 host backends 拥有窗口、生命周期、平台服务和 renderer 选择。

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
| `moui/backend/host/` | 面向 windows、routes、timers、host services、WebView、async image loading、accessibility、input、redraw scheduling 和 renderer handoff 的共享 host contracts。 |
| `moui/backend/internal/embedded_runtime_session/` | Android、iOS 和 HarmonyOS window-hosted adapter 的私有 MoUI runtime 装配层；在 `ApplicationHandler` callbacks 之后组合 `AppRuntime`、host contracts 和 renderers。 |
| `moui/backend/{macos,windows,linux,android,ios,harmonyos,web}/` | 具体平台 host implementations。Native platform packages 将 events 归一化为 host contracts；Android、iOS 和 HarmonyOS 是由 `wzzc-dev/window` 驱动的 window-hosted adapters；web 是 canonical browser host。 |
| `moui/backend/{macos,windows,linux,android,ios,harmonyos}/skia/` | 主 native 路线的 Native Skia renderer provider packages。Android 将 CPU pixel frames 呈现到 `ANativeWindow`；iOS 将 CPU pixel frames 呈现到 UIKit `UIImageView` 子视图；HarmonyOS 将 CPU pixel frames 呈现到提供的 XComponent native-window handle。 |
| `moui/backend/{macos,windows,linux}/wgpu/` | Native WGPU diagnostic provider packages。 |
| `moui/render/` | Renderer facade、共享 render capability models、fallback planning、shader/image helpers 和 renderer-neutral command handling。 |
| `moui/render/skia/` | 基于 `moui_skia` 的 Native Skia renderer facade。 |
| `moui/render/webgpu_adapter/` | `wasm-gc` 的 Browser WebGPU host-import adapter。 |
| `moui/render/wgpu/` | 实验性 native WGPU renderer 和 native text providers。 |
| `moui_richtext/` | 富编辑应用使用的 Markdown/rich-text document、editor、command、input、paste、table 和 source-mapping 逻辑。 |
| `moui_skia/` | 可编辑的 Skia binding 以及 native/fallback capability contract workspace。 |
| `moui_theme/` | 可选设计系统 addon workspace，涵盖 Material、Carbon、Primer、Fluent、通用 source-mapped token diagnostics，以及 Sickle 等第一方 visual theme addons。 |
| `moui_tester/` | Harnesses、fixtures 和 first-frame/native smoke helpers。 |
| `moui_devtools/` | Devtools 和 overlay/debug helpers。 |
| `moui_agent/`, `moui_agent_mcp/` | Agent protocol、schema、host runtime 和 MCP router support packages。 |
| `examples/*/app/` | 共享应用逻辑包。除非刻意拆出 app-specific service package，否则这些包应保持平台无关。 |
| `examples/*/{web_wasm,macos_skia,windows_skia,linux_skia,...}/` | 为某个 app package 创建 runtime/backend/renderer 接线的薄平台入口。 |
| `tools/` | 由 `scripts/` 下 JS shell entrypoints 使用的 MoonBit-backed repository validators。 |
| `scripts/` | Local/CI command entrypoints、smoke runners、package validators 和 platform setup helpers。 |

## 应用边界

共享应用包默认应依赖：

- `wzzc-dev/moui`
- 按需使用 `wzzc-dev/moui/geometry`、`wzzc-dev/moui/graphics`、
  `wzzc-dev/moui/animation`、`wzzc-dev/moui/text` 和
  `wzzc-dev/moui/state` 等领域门面
- `wzzc-dev/moui/views`

仅当应用需要领域门面或 `moui/views` 未暴露的高级 kernel/diagnostic 类型时，才使用 `wzzc-dev/moui/core`。仅为 file import、WebView commands、route events 或 async image service integration 等 host service protocols 使用 `wzzc-dev/moui/backend/host`。

普通应用包应避免直接依赖：

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/render/*`
- 具体平台 backend packages
- renderer provider packages
- `moui_theme/*`，除非该 app 是 design-system preview 或 addon diagnostic

只有 `examples/showcase/app/diagnostics` 允许更宽，因为它展示 runtime 和 renderer capabilities。Components 和 Patterns 遵循普通应用依赖；Platform 可以额外导入 `backend/host`。把 Diagnostics 当作框架检查包，而不是默认 app dependency model。详细策略见 `docs/moui-app-package-boundary.md`。

## 框架边界

把新 API 加到最窄的归属包：

- 跨运行时协议和中立 value types 属于 `moui/core`。
- 基于 `core`、面向应用的领域门面属于
  `moui/{geometry,graphics,animation,text,state}`。它们可以依赖 `core`，但 `core` 不得依赖它们。
- 面向应用的 controls、control styles、form/navigation helpers、WebView facade、default themes 和具体 custom view implementations 属于 `moui/views`。
- Runtime lifecycle、inspector snapshots、effect/subscription diagnostics 和 runtime construction 属于 `moui/runtime`。
- Host service 和 platform service protocols 属于 `moui/backend/host`。
- Renderer implementation 和 capability reporting 属于 `moui/render/*`。
- Native Skia binding ownership、fallback parity、FFI borrow rules 和 native capability manifests 属于 `moui_skia`。

不要为每个功能新增顶层 public package。优先使用既有归属包，除非该能力可独立复用，并且无法由 `views`、`runtime`、`backend/host`、`render` 或 addon workspace 清晰拥有。

## 目标路线

- Web app route：shared app package -> `examples/<app>/web_wasm` ->
  `moui/backend/web` -> `moui/render/webgpu_adapter`。
- Native Skia route：shared app package -> platform `*_skia` entrypoint ->
  platform backend -> platform Skia provider -> `moui/render/skia` ->
  `moui_skia`。
- Android window-hosted route（`runtime_partial`）：shared app package ->
  `examples/<app>/android_window_hosted` -> `wzzc-dev/window/android`
  `HostCmd` / `EventLoop` -> `AndroidWindowHostedApp` ->
  `moui/backend/android/skia` -> `moui/render/skia` -> `moui_skia`。
  window template 拥有 Android lifecycle、surface acquisition 和 input；MoUI
  adapter 负责 runtime/session 装配与渲染。
- iOS window-hosted route（`runtime_partial`）：shared app package ->
  `examples/<app>/ios_window_hosted` -> `wzzc-dev/window/ios`
  `HostCmd` / `EventLoop` -> `IosWindowHostedApp` ->
  `moui/backend/ios/skia` -> `moui/render/skia` -> `moui_skia`。UIKit lifecycle、
  surface 和 touch callbacks 只能经由 window event loop 进入。
- HarmonyOS window-hosted route（`runtime_partial`）：shared app package ->
  `examples/<app>/harmonyos_window_hosted` -> `wzzc-dev/window/harmonyos`
  `HostCmd` / `EventLoop` -> `HarmonyOsWindowHostedApp` ->
  `moui/backend/harmonyos/skia` -> `moui/render/skia` -> `moui_skia`。
  Native XComponent callbacks 是 surface、pointer、resize 和 detach events 的唯一来源。
- Native WGPU route：shared app package -> platform `*_wgpu` entrypoint ->
  platform WGPU provider -> `moui/render/wgpu`。这是诊断路线，不是默认主线。

平台入口应保持很薄：创建 program/runtime，选择 backend 和 renderer provider，并传入 app-owned service adapters。业务 model/update/view 逻辑应留在 shared app package。

Window-hosted mobile runtime sessions 共享 `EmbedderHostChannel`，用于带 revision 的 IME 和 semantics updates，以及异步 clipboard/accessibility responses。见
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
- `backend/host` 中统一的 host boundaries，带共享 window-event mapping，平台 hosts 将 events 归一化为 `HostEvent`。
- Native mainline rendering 通过基于 `render/skia` 的 provider packages 完成，并在 `render/wgpu` 下保留实验性 native WGPU diagnostics。
- Web rendering 只通过 `wasm-gc` 上的 `render/webgpu_adapter` 完成，并使用 browser WebGPU host imports 进行可见绘制。旧 JS-target WebGPU path 已有意移除。

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
moui/backend/host/            shared HostEvent, HostWindowEventSource, HostTimerSource, HostRouteSource, metrics, HostWindowRenderer, native async image completion source, input, redraw driver, window/core + dpi event conversion
moui/backend/windows/         Windows native host core
moui/backend/windows/skia/    Windows Skia renderer provider mainline
moui/backend/windows/wgpu/    Windows WGPU renderer provider diagnostic
moui/backend/macos/           macOS native host core
moui/backend/macos/skia/      macOS Skia renderer provider mainline
moui/backend/macos/wgpu/      macOS WGPU renderer provider diagnostic
moui/backend/linux/           Linux Wayland native host core
moui/backend/linux/skia/      Linux Skia renderer provider mainline
moui/backend/linux/wgpu/      Linux WGPU renderer provider diagnostic
moui/backend/android/         Android window-hosted adapter over shared host/runtime contracts
moui/backend/android/skia/    Android Skia renderer provider over ANativeWindow pixel presentation
moui/backend/ios/             iOS window-hosted adapter over shared host/runtime contracts
moui/backend/ios/skia/        iOS Skia renderer provider over UIKit UIImageView pixel presentation
moui/backend/harmonyos/       HarmonyOS window-hosted adapter over shared host/runtime contracts
moui/backend/harmonyos/skia/  HarmonyOS Skia renderer provider over XComponent native-window pixel presentation
moui/backend/web/             canonical Web host on wasm-gc plus browser JS assets
moui/render/                  renderer facade and shared draw helpers
moui/render/skia/             native Skia raster renderer facade over moui_skia
moui/render/webgpu_adapter/   browser WebGPU host-import renderer for wasm-gc
moui/render/wgpu/             experimental native wgpu renderer
moui/render/wgpu/cosmic_text/ Moon Cosmic provider for native wgpu text
moui/render/wgpu/coretext/    macOS CoreText provider for native wgpu text
moui/render/wgpu/text_protocol/ shared native measure/run/raster/register bytes protocol
moui/render/wgpu/directwrite/ Windows DirectWrite provider scaffold
moui/render/wgpu/fontconfig/  Linux fontconfig/HarfBuzz/FreeType provider scaffold
moui/tests/tooling/           quickcheck and pixelmatch integration tests
moui/tests/text_conformance/  opt-in native/Web text diagnostic matrix
moui/tests/skia_renderer_smoke/native/ opt-in real Skia renderer pixel smoke
moui/tests/skia_cached_layer_benchmark/ opt-in real Skia cached-layer benchmark harness
moui/tests/skia_text_emoji_smoke/ opt-in real Skia text/emoji renderer smoke
moui/tests/wgpu_renderer_smoke/ opt-in native WGPU renderer smoke
examples/counter/app/         smallest shared app shape
examples/counter/{macos_skia,web_wasm,android_window_hosted,ios_window_hosted,harmonyos_window_hosted,macos_wgpu,windows_wgpu,linux_wgpu}/ platform counter entrypoints
examples/counter/windows_wgpu_cosmic/ Windows counter selecting Moon Cosmic text
examples/harmonyos_demo/app/  standalone HarmonyOS demo app with viewport/tap feedback
examples/harmonyos_demo/harmonyos_window_hosted/ HarmonyOS demo window-hosted entrypoint
examples/showcase/harmonyos_window_hosted/ Showcase HarmonyOS window-hosted entrypoint
examples/agent_counter/       minimal agent-controllable runtime example (shared app at example root plus main/ and macos_skia/ entrypoints)
examples/button_freeze_probe/app/ minimal native Skia button-freeze repro app
examples/button_freeze_probe/{macos_skia,windows_skia,linux_skia}/ platform Button Freeze Probe entrypoints
examples/showcase/app/        root Showcase router/composition package
examples/showcase/app/components/ focused reusable component catalog with app-safe dependencies
examples/showcase/app/patterns/ Counter/Todo, forms, data, navigation, and workflow patterns
examples/showcase/app/platform/ host Effect/Subscription, canvas, routes, and mobile service probe
examples/showcase/app/diagnostics/ explicit runtime/renderer diagnostic exception
examples/design_systems/app/  dedicated addon diagnostic source-mapped design-system preview/parity example using moui_theme
examples/design_systems/{web_wasm,macos_skia,windows_skia,linux_skia}/ Design Systems addon diagnostic host entrypoints
examples/showcase/macos_skia/ macOS showcase selecting native Skia raster
examples/showcase/macos_wgpu/      macOS native WGPU diagnostic showcase
examples/showcase/macos_wgpu_cosmic/ macOS showcase selecting Moon Cosmic text
examples/showcase/web_wasm/   Web showcase on wasm-gc
examples/showcase/windows_skia/ Windows showcase selecting native Skia raster
examples/showcase/windows_wgpu/    Windows native WGPU diagnostic showcase
examples/showcase/windows_wgpu_cosmic/ Windows showcase selecting Moon Cosmic text
examples/showcase/linux_skia/ Linux showcase selecting native Skia raster
examples/showcase/linux_wgpu/      Linux Wayland native WGPU diagnostic showcase
examples/showcase/linux_wgpu_cosmic/ Linux showcase selecting Moon Cosmic text
examples/markdown_editor/app/  shared WYSIWYG Markdown editor app
examples/markdown_editor/macos_skia/ macOS Markdown editor selecting native Skia raster
examples/markdown_editor/macos_wgpu/ macOS native WGPU diagnostic Markdown editor
examples/markdown_editor/web_wasm/ Web Markdown editor on wasm-gc
examples/markdown_editor/windows_skia/ Windows Markdown editor selecting native Skia raster
examples/markdown_editor/windows_wgpu/ Windows native WGPU diagnostic Markdown editor
examples/markdown_editor/windows_wgpu_cosmic/ Windows Markdown Editor selecting Moon Cosmic text
examples/markdown_editor/linux_skia/ Linux Markdown editor selecting native Skia raster
examples/code_editor/app/ shared native code editor and language-provider demo app
examples/code_editor/{macos_skia,windows_skia,linux_skia}/ platform Code Editor Skia entrypoints
examples/webview_demo/app/ shared native WebView demo app
examples/webview_demo/{macos_skia,windows_skia,linux_skia,web_wasm}/ platform WebView demo entrypoints
examples/pdf_workbench/app/  shared PDF reader/light editor app
examples/pdf_workbench/{macos_skia,windows_skia,linux_skia}/ platform PDF Workbench Skia entrypoints
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
- `ElementTree` 是已挂载 runtime tree。其 `ElementNode` entries 拥有 view identity、keys、child elements、dirty flags、control state、component state、layout cache 和 render cache。
- `LayoutTree` 是最新 placement result。其 `PlacedNode` entries 携带 measurement 和 parent placement 产生的最终 frames。
- `RenderTree` 是 paint-stage tree。其 `RenderNode` entries 将 hit testing 和 draw command payloads 附加到来自 `LayoutTree` 的 frames。
- App code 通常应通过 `AppRuntime`、`Component` 和 `ComponentContext`。`RuntimeState`、`ElementTree`、`LayoutTree`、`RenderTree` 及其 node types 是 engine implementation details，尽管部分 core tests 仍会直接使用它们。
- `ViewEnvironment` 是面向 TEA 的只读 environment snapshot。它暴露当前 viewport size 和 `Environment`，但不会让 app-level views 访问 `ComponentContext` subscriptions、bindings 或 component effects。
- `ScrollState`、`FocusState` 和 `NavigationState` 是 reusable app structure 的首选 state holders，而不是临时 view-local fields。
- `ComponentContext::run_effect` 注册带 key 的 component-scoped effects 和 cleanup callbacks。带稳定 key 的 effects 会在 rebuilds 之间复用，keys 消失或 component 离开 tree 时运行 cleanup。`ComponentContext` 也为小型可保存 string、bool 和 int state 暴露 scoped save/restore helpers。
- `AppRuntime` 拥有 app-level `Program` diagnostics，包括 dispatch、
  update、message queue、effect plan、scheduled effect、区分 send、anonymous dispatch、structured run 和 cancellable task effects 的 effect-kind counters、active/completed/cancelled effect-task lifecycle counters、active subscription counts/kind summaries、subscription plan、start/reuse/cancel、duplicate effect descriptor-key counters/names、duplicate subscription-key counters/names，以及来自 completed、canceled 或 destroyed lifetimes 的 stale callbacks 的 ignored effect-task 和 subscription dispatch counters，还有 runtime destruction 后触发的 anonymous 或 structured effect dispatchers 的 ignored program-dispatch counters。Program message drains 是有界 runtime turns，因此同步 self-queued work 可以留下 pending messages，而不是独占当前 host callback。Program runtime 和 runtime inspector snapshots 暴露 active effect-task descriptors、effect-task lifecycle entries、active subscription descriptors、active subscription kind-count summaries 和 subscription lifecycle entries，使 tooling 能识别哪些 tasks 和 sources 已完成、被复用或被取消，而无需检查 app messages。Runtime inspector snapshots 还暴露 pending rebuild/layout/paint/redraw work 的 structured dirty-state summary，包括 dirty element ids 和 legacy reason strings。Inspector snapshots 读取 cached layout/render/semantics state，不会 drain pending dirty work，因此 devtools 可消费稳定字段而不是解析 captions。来自 `Effect::run`、`Effect::host_service`、`Effect::task` 和 `Effect::service_task` 的 structured effect descriptors 会通过 effect summaries 传递，使 tooling 能识别 planned host-service 或 service/task runners，而无需检查 `Msg` 值；duplicate descriptor-key counts/names 让 planned key conflicts 在执行前可见。Runtime inspector snapshots 还暴露 rebuild、layout、paint 和 draw-command building 的 platform-neutral pipeline pass counters。Dirty summaries 也携带 latest damage kind、dirty-rect count、full-surface reason、cache epoch 和 cached-layer count，使工具能区分 retained boundary updates 与 full redraws，而无需解析 command streams。它保留 latest effect summary、latest scheduled effect summary 和 latest subscription plan summary（包括 planned subscription descriptors）供 inspector tooling 使用。这不同于 component-local `ComponentContext::watch` 和 `ComponentContext::run_effect`；program subscriptions 建模持续的 app event sources，而 build-context subscriptions 建模 component-local state invalidation 和 lifecycle effects。
- Layout 使用 constraints down、measured size up，然后 parent placement，并将结果写入 `LayoutTree`。
- Paint 消费 `LayoutTree` frames 来构建 `RenderTree`，并发出 platform-neutral `DrawCommand` 值。`RenderNode` entries 保留 paint bounds、content revisions 和 repaint-boundary cache keys。普通 host path 会向 `AppRuntime::draw_frame()` 请求 commands、`DamageRegion` 和 cache epoch。`DrawFrame.clear_color` 拥有 frame initialization，而其 command array 包含 view content，不包含前置 `Clear`；legacy command-only renderer adapters 在 lowering frame 时物化该 clear。Rect-damage renderers 必须在跳过 retained cached layers 前，将完整 command stream 约束到 effective damage clip。`DrawFrame.platform_views` 携带 `web_view` 等 native platform-view placements，而不把它们加入 `DrawCommand`。Legacy tests 仍可调用 `draw_commands()` 获取完整 command stream。Renderers 可以基于 capability degrade，但 view constructors 保留 brush、border、shadow、clip、image 和 text intent。
- Backends 将 platform events 归一化为 `HostEvent`；它们不拥有 UI state，也不直接修改 element/render trees。
- `HostRuntimeDriver` 在 host boundary 拥有 redraw scheduling，将归一化 events 分派到 `AppRuntime`，并为 renderers 暴露 platform-neutral draw frames。redraw scheduler 跟踪 `idle`、`scheduled`、`in-frame` 和 `follow-up` 状态，使重复 host callbacks 合并，并让 presentation 期间产生的 redraw requests 成为下一帧。`HostWindowRenderer::render_frame()` 将 retained cached-layer commands 转发给实现 frame rendering 的 renderers，而它的 renderer-neutral command cache 仍是更简单 backends 的 fallback。Native Skia 现在拥有 renderer-local offscreen surface/image cache 用于 repaint boundaries，并报告 cache hit/miss/update/evict diagnostics。real-app cached-layer benchmark 使用 Showcase hover/scroll 和 Markdown Editor text input、scroll、caret-overlay interactions 来验证 sibling-boundary reuse、state-backed scroll redraw、rich-text block boundaries、editing overlays、command-count changes，以及剩余 rebuild、layout 和 damage bottlenecks；OS-level partial present 仍是独立的平台能力。
- `AppRuntime::focus_next` 和 `AppRuntime::focus_previous` 在共享 tab-order model 之上暴露显式 focus traversal entry points。

## 状态与绑定

在 component builds 内，显示 state 应通过 `ComponentContext` 读取：

```moonbit
@core.Component::new(ctx => {
  let count = ctx.watch(self.count)
  @views.text("Count: \{count}")
})
```

普通应用状态使用 TEA-first controlled constructors，例如
`@views.text_field(model.draft, on_input=DraftChanged)`。Component-local state 在跨越 `views` public API boundary 前，仍应投影为显式值和 typed messages；event handlers 和 model methods 可以在 component 内使用 `state.get()`、`state.set()` 和 `state.update()`。runtime 会在 rebuild 时取消并替换 build subscriptions，因此重复 builds 不会累积 listeners。

Component-scoped side effects 应使用 `ctx.run_effect` 注册。当该 effect key 不再为该 component 注册，以及 component 离开 element tree 时，会调用返回的 cleanup callback：

```moonbit
@core.Component::new(ctx => {
  ctx.run_effect(key="subscription", () => {
    connect()
    Some(() => disconnect())
  })
  @views.text("Connected")
})
```

对于简单生命周期工作，`ctx.on_mount(key=..., ...)` 和
`ctx.on_dispose(key=..., ...)` 是同一 keyed effect model 的具名包装。

需要跨 rebuilds、resize 和 same-root remount 存活的 state 可以使用 scoped `save`、`restore` 或 `saveable` helpers，并配合 `SaveableCodec[T]`。string、bool 和 int helpers 仍作为同一 codec path 的 convenience wrappers。`saveable_*` helpers 返回 `State` 值，变化时写回 runtime store 并请求 component rebuilds。它们的 write-back subscriptions 与 `ctx.watch` 一样受 component lifecycle 作用域约束，因此旧 builds 的 stale handles 不会在 rebuild 或 unmount 后继续 invalidating component 或覆盖 saveable store。该 store 可通过 `SaveableStateSnapshot` snapshot/restore，用于更高层 state restoration flows。

Environment values 通过 `ComponentContext` 流动，使 components 能响应 color scheme、locale、layout direction、accessibility contrast、reduced motion、content size category、text scale 和 scale factor 等 platform 与 accessibility signals。只需要读取这些值的 TEA apps 应使用 `ViewEnvironment`，并让 `ComponentContext` 只作用于 components 和高级 state holders。

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

要点：`@views.light_theme()` / `@views.dark_theme()` resolve Minimal preset，`ButtonVariant::style(theme)` 从 `theme.components.button` resolve，`ControlStateStyle` 位于 `core` 并由 token resolver 和 view-layer style structs 共享，`DesignSemanticPalette` 携带 Fluent 2 neutral ramp。每控件 style resolution 另见 [按钮样式指南](../button-styling-guide.md)。

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

`backend/host` 定义平台包与平台无关 runtime 之间的共享边界。它覆盖 window lifecycle、multi-window bookkeeping、host-event subscriptions、timer/route sources、WebView contracts、async image loading、typed host services、keyboard shortcuts、menus、file drop 和 renderer handoff。完整细节见：[平台 Host 契约](../platform-host-contract.md)。

setup、backend-specific constraints 和 validation commands 见 [平台说明](../platform-notes.md)。

## 可访问性

`core/semantics.mbt` 生成平台无关 semantics tree，包含 roles、labels、hints、values、focus order、checked state 和 live-region metadata。`backend/web` 包含用于 wasm-gc Web path 的 semantics-to-ARIA adapter。Native accessibility snapshots 从 `backend/host` 导出为 `Milky2018/moon_accesskit` tree updates。Platform bridges 留在 backend boundaries 后面，并消费 AccessKit-shaped snapshot，而 `@core.SemanticsNode` 仍是 source of truth。

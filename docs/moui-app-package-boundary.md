# MoUI 应用包边界规范

本文档规定 MoUI 应用开发时可以依赖哪些包、`wzzc-dev/moui/core`
作为基础协议层 / 抽象 UI kernel 的边界、root facade 应该暴露哪些类型，
以及 `wzzc-dev/moui/views` 如何同时承接普通 view constructor 和低层控件实现。

## Core 定位

`wzzc-dev/moui/core` 的定位是**基础协议层 / 抽象 UI kernel**。
它定义跨 runtime、跨 backend、跨 renderer 都稳定成立的 UI 协议和值类型，
让 app、views、runtime、backend、renderer 可以在同一套抽象上协作。

`core` 应该包含：

- 基础值类型：geometry、color、brush、font、event、keyboard、text range 等。
- 抽象 UI 协议：`View`、layout/paint/event/semantics/focus/text input contract。
- App loop contract：`Program`、`Effect`、`Subscription` 这类平台中立执行协议。
- Renderer-neutral draw/text/accessibility contract：绘制命令、文本测量协议、语义树协议。
- Theme 的中立 token surface：不绑定具体设计系统品牌、不含平台或 renderer 实现。

`core` 不应该成为：

- 控件 catalog：按钮、表单、选择器、富文本编辑器等具体控件 API 应属于
  `moui/views`，而不是塞进 kernel。
- Runtime implementation：element tree、dirty state、runtime lifecycle、component
  storage、任务/订阅实际调度应属于 `moui/runtime`。
- Platform service layer：WebView、文件对话框、剪贴板、窗口服务、平台 channel
  应属于 `moui/backend/host` 或具体 backend。
- Renderer implementation：Skia/WGPU/browser WebGPU 细节应属于 `moui/render/*`。
- Design-system addon：Material、Fluent、Carbon、Primer 及其 component token
  应属于 `moui_theme/*` 或 `moui/views` 的 app-facing style facade。

## 少包策略

MoUI 的包边界优先保持少而清晰，不按每个功能名拆出一组顶层 public package。
除非现有层无法自然承接，否则不要新增 `moui/style`、`moui/forms`、
`moui/rich_text`、`moui/routing`、`moui/platform`、`moui/diagnostics`
这类细碎包。

当前目标落点是：

- app-facing 能力和具体控件行为进入 `moui/views`：控件样式、form helper、
  routing/history、picker item、WebView constructor、普通 app 需要看到的 rich text
  facade，以及 button/text field/picker 等低层 custom view 实现。
- runtime/diagnostics 进入 `moui/runtime`：runtime inspector、program lifecycle
  snapshot、view/render diagnostics snapshot、`ComponentContext` runtime 构造细节。
- 平台服务进入 `moui/backend/host`：WebView command/event/policy/spec、host
  capability、host service contract。
- renderer/backend 实现仍在 `moui/render/*` 和 `moui/backend/*`。

只有当一个能力无法由上述层自然承接，且会被多个包稳定复用时，才考虑新增 addon
或更专门的 package。新增 package 必须先说明它为什么不是 `views`、
`runtime` 或 `backend/host` 的职责。

## 当前 Core 收敛状态

按“基础协议层 / 抽象 UI kernel”来衡量，`moui/core` 已经完成以下厚能力迁出。
这些迁移是后续新增 API 的默认边界，不应被回填到 `core`。

- **控件样式和 picker model ownership 已迁出**：`ButtonStyle`、
  `TextFieldStyle`、`ChoiceControlStyle`、`ProgressStyle`、`SliderStyle`、
  `PickerStyle`、`FeedbackStyle`、`BadgeStyle`、`FormValidationStyle`、
  `PickerItem` 已由 `moui/views` 拥有。`core` 只保留 `Color`、`Brush`、
  `BorderStyle`、`ShadowStyle`、`Theme` token 这类基础值。picker 的低层
  option representation 是 `views` 包内私有实现细节；普通 app 使用
  `@views.PickerItem` / `@views.picker`。
- **WebView ownership 已迁出**：`WebViewSpec`、`WebViewCommand`、
  `WebViewEvent`、`WebViewNavigationPolicy` 已归 `moui/backend/host` 拥有。
  `core` 只保留 renderer-neutral 的 `PlatformViewPlacement`、
  `PlatformViewProperty`、`PlatformViewEvent` 和 `AppEvent::PlatformView`。
  普通 app 使用 `moui/views.web_view` 以及 `@views.WebViewEvent` /
  `@views.WebViewNavigationPolicy` facade；平台入口和 backend 使用
  `@host.WebView*`。
- **表单模型 ownership 已迁出**：`FormFieldState`、`FormValidationRule`、
  `FormController`、`validate_form`、`required_field` 已由 `moui/views` 的 form
  支持层拥有。`core` 不再承载具体表单工作流。
- **Rich text ownership 已迁出**：`RichTextDocument`、table/image/source range、
  rich text geometry/paint/selection helper 已由 `moui/views` 拥有，并通过
  `@views.RichTextDocument`、`@views.RichTextInputTransform`、
  `@views.rich_text_document_height` 等 facade 给普通 app 使用。`core` 只保留
  `TextRange`、grapheme boundary、`TextSystem`、paragraph layout contract、基础
  text input state。
- **`ComponentContext` runtime 构造入口已收口**：`ComponentContext` 仍作为
  component-facing kernel 类型保留在 `core`，因为 `View::node` /
  `views.component` 的签名需要它且 `core` 不能反向依赖 `runtime`。runtime 使用
  `ComponentContext::from_runtime(ComponentRuntimeContextInput)` 构造执行上下文；
  普通 component API 不暴露散落的 runtime storage 参数，root facade 也不暴露该
  构造入口。
- **Date picker 控件语义已迁出**：`DateValue` 是中立数据模型，继续属于
  `core`；`DatePickerMode` 是具体控件语义，属于 `moui/views`。低层 display
  mode representation 是 `views` 包内私有实现细节，转换由普通 constructor 完成。
- **Theme schema 和默认审美已拆分**：`core.Theme` / `core.Environment` 保留
  token schema 和 `neutral()` fallback/testing 值；`default_theme()`、
  `light_theme()`、`dark_theme()` 等 app-facing 默认审美属于 `moui/views`。
- **诊断/Inspector 结构偏 runtime/devtools**：`RuntimeInspectorSnapshot`、
  `ProgramRuntimeSnapshot`、`ViewTreeInspectorSnapshot`、`RenderInspectorSnapshot`
  等是很有价值的诊断 API，但不是 UI kernel 的基础协议。`EffectPlanSummary`、
  `SubscriptionPlanSummary` 和 runtime snapshots 由 `moui/runtime` 拥有；`core`
  不再导出 diagnostics summary 或 runtime op 列表，也不能作为新增 diagnostics
  API 的 owning package。它们应避免进入 root facade，devtools/overlay 应基于
  `@runtime.*` diagnostics 类型构建视图。
- **Routing/history ownership 已迁出**：`RouteLocation`、`RouteDescriptor`、
  `RouterSnapshot`、`RouteHistoryState`、`RouteFocusStore`、`RouterState` 和
  `resolve_route` 已归 `moui/views` navigation 支持层拥有。`core` 只保留
  `NavigationState` 这类基础 state holder。Host route 事件使用
  `@host.HostRouteLocation`，普通 app 在接入 navigation history 时转换为
  `@views.RouteLocation`。

新增 API 默认放在更具体的 owning package；只有确认它是跨 runtime 的抽象协议或
基础值类型时，才进入 `core`。

## 目标边界声明

本规范描述的是当前 API 的目标边界。新增依赖或公开 API 时，按 owning package
直接落位，不保留兼容别名或 deprecated 过渡入口。

- app-facing 控件、控件语义、默认主题、form/routing/WebView/rich text facade、
  以及具体 custom view 控件行为进入 `moui/views`。
- runtime lifecycle、component runtime input、effect/subscription diagnostics
  summary、inspector snapshot 进入 `moui/runtime`。
- host/platform service 协议进入 `moui/backend/host` 或具体 backend。
- `core` 只保留跨 runtime/backend/renderer/views 稳定成立的协议和值类型。

`showcase/app` 可以作为 diagnostics 示例直接依赖 `@runtime`，也可以为了 renderer
capability 展示依赖 `@render`；普通 app 不应把这两个示例用途当作默认依赖模式。
测试目标下的 `for "test"` / `for "wbtest"` 额外 import 不计入运行时边界。

## 普通共享 App 包

普通共享 app 包指 `examples/*/app` 这类平台无关的业务逻辑包，以及同形态的
`website/app` 和把共享 app 放在示例根目录的 `examples/agent_counter`。它们应该默认只依赖：

- `wzzc-dev/moui`
- `wzzc-dev/moui/views`

`wzzc-dev/moui` 是应用 facade。它应该 re-export app-safe 的平台中立常用类型，让普通 app 不必频繁直接 import `wzzc-dev/moui/core`。

`wzzc-dev/moui/views` 是 app-facing UI 构造器入口。应用层组合按钮、文本、布局、表单、列表、弹窗、WebView wrapper、主题 helper 等，应该优先使用这里的函数。

普通 app 可以按需直接依赖：

- `wzzc-dev/moui/core`：仅当 root facade 尚未覆盖，或确实需要高级平台中立协议类型时使用。
- `wzzc-dev/moui/backend/host`：仅当 app 需要 host service / 平台服务协议时使用，例如文件对话框、异步图片、剪贴板、WebView command queue 或 host service 交互。普通 app 处理 WebView 事件时优先使用 `@views.WebViewEvent`。

普通 app 不应该直接依赖：

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/render/*`
- `wzzc-dev/moui/backend/{web,macos,windows,linux}`
- `wzzc-dev/moui/backend/{macos,windows,linux}/skia`
- `wzzc-dev/moui/backend/{macos,windows,linux}/wgpu`
- `moui_theme/*`，除非该 app 本身是设计系统 addon 或 preview app。

已知例外见上方“目标边界声明”：`showcase/app` 暂时依赖 `@render` 用于 capability 报告，
并依赖 `@runtime` 用于 diagnostics snapshot 示例。前者应在 capability 报告收敛为
app-facing API 后移除；后者仅限 diagnostics 示例，不代表普通 app 默认可依赖 runtime。

## App 私有子包

某些 app 在共享 app 包之外，还会带有自己的私有支持包，例如
`examples/pdf_workbench` 的 `pdfium_adapter`、`pdflite_adapter`、
`pdflite_service_*` 等。这类包既不是普通共享 app 包，也不是平台入口包，
而是某个 app 专用的适配层 / 服务实现 / 进程间协议。

定位规则：

- 它们只服务于宿主 app，不应被其他 app 或框架层依赖。
- 它们可以依赖 `@core`、`@backend/host`、`@views` 以及 app 自身的共享 app 包，
  视具体职责而定，但不应该被普通共享 app 包反向依赖。
- 它们不进入 root facade，也不向 `@core` / `@views` 注入 app 特定类型。
- 评审时把它们视作 app 的实现细节，而不是框架 API 表面的一部分。

如果某个 app 私有子包的抽象逐渐被多个 app 复用，应考虑上提到
`moui/views`、`moui/core` 或独立的 addon 包，而不是继续作为某个 app 的私有子包存在。

## Root Facade 暴露规则

`wzzc-dev/moui/core` 的平台中立基础类型可以、也应该由
`wzzc-dev/moui` 做 curated re-export，方便普通 app 少 import `core`。
root facade 暴露的是 app-safe 的 kernel 类型别名，不是把整个 `core` 公共面完整转发。

允许进入 root facade 的类型必须同时满足：

- 平台中立，不绑定 Web、macOS、Windows、Linux、Skia、WGPU 或 host service 实现。
- app-safe，普通应用作者可以理解并稳定使用。
- 不暴露 runtime tree、renderer、backend、inspector、debug payload 或 private view implementation details。
- 是普通 app 高频需要的类型。

推荐由 `wzzc-dev/moui` 暴露的类型包括：

- app shape：`View`、`Program`、`Effect`、`Subscription`、`Theme`
- 几何与布局：`Point`、`Size`、`Rect`、`Insets`、`Constraints`、`Axis`、`Alignment`
- 绘制基础值：`Color`、`Brush`、`BorderStyle`、`ShadowStyle`
- 文本基础值：`FontSpec`、`FontFamily`、`TextRange`、`TextAlign`
- 状态：`State`、`Binding`、`DerivedState`
- 环境：`Environment`、`ViewEnvironment`、`ColorScheme`、`LayoutDirection`
- app 状态 holder：`ScrollState`、`FocusState`、`NavigationState`
- 交互：`ActionCommand`、`ActionCommandMap`、`CommandBinding`、`CommandIntent`、`KeyboardShortcut`、`KeyModifiers`
- 常用数据模型：`DateValue`

不应该进入 root facade 的类型包括：

- `ViewLayoutContext`、`ViewPaintContext`、`ViewEventContext`
- `ViewPaintPlan`、`ViewPaintLayer`、`ViewEventResult`
- `DrawCommand`、`DrawFrame`、`DamageRegion`
- `ComponentContext::from_runtime` 这类 runtime-only 构造入口
- runtime snapshot、inspector snapshot、diagnostic payload
- renderer resource、renderer capability、platform-view placement
- backend host/runtime driver 相关类型
- 具体控件 mode/style/default theme、表单 workflow helper、WebView command/event、
  routing/history controller、rich text document/editor transform 等非 kernel 能力

扩展 root facade 时必须同步更新 `pkg.generated.mbti` 和 API surface guard，
并用 review 确认新增 alias 是 app-safe neutral type。

Diagnostics 类型的 owning package 是 `wzzc-dev/moui/runtime`。`core` 不再导出
`EffectPlanSummary`、`SubscriptionPlanSummary`、`EffectRuntimeOp`、
`InspectorSnapshot`、`ProgramRuntimeSnapshot` 或 `RenderInspectorSnapshot` 这类
diagnostics/runtime 类型。

WebView 类型的 owning package 是 `wzzc-dev/moui/backend/host`。`core` 不再导出
`WebViewSpec`、`WebViewCommand`、`WebViewEvent` 或
`WebViewNavigationPolicy`，也不提供 `PlatformViewPlacement::web_view` 这类
WebView 专有 helper。

## `moui/views` 低层 custom view 规则

`wzzc-dev/moui/views` 同时面向普通 app 和 MoUI 内置控件实现者。普通 app 使用
`button`、`text_field`、`picker` 这类 app-facing constructor；框架和控件实现可以在
`views` 包内使用私有 `*_control` / `*_layout` / `*_surface` helper 对接
`@core.View::node`。

只有在需要实现新的 reusable control，并且必须自定义以下行为时，才新增低层
helper：

- layout
- paint
- event handling
- text input state / text command
- semantics
- focus

如果只是组合已有控件，例如按钮、表单、列表、布局、弹窗、菜单、
WebView wrapper，应用层应使用 `wzzc-dev/moui/views` 的 app-facing constructor。

新增控件时遵循这个落点：

- 公共 app-facing constructor 放在 `moui/views`。
- 具体 custom view behavior 实现也放在 `moui/views`，helper 名应描述行为，
  例如 `button_control`、`text_field_control`、`scroll_container`。
- 底层协议通过 `@core.View::node` 以及 `ViewLayoutContext`、`ViewPaintContext`、
  `ViewEventContext` 等回调类型对接。
- 普通 app 只看到 `@views.some_control(...) -> View[Msg]`。

换句话说，Iced 的控件层同时是内置控件和自定义控件入口；
MoUI 当前把两类入口统一在 `moui/views`：普通 app 使用高层 constructor，
控件作者复用同包内私有 control/layout helper。这不改变普通 app 默认只依赖
`moui` 和 `moui/views` 的规则；低层 public 入口只有 `@core.View::node(...)`。

## 平台入口包

平台入口包指 `examples/*/{web_wasm,macos_skia,windows_skia,linux_skia}`
这类 `is-main` package。它们负责创建 runtime、连接平台 backend、选择 renderer。

平台入口包可以依赖：

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/backend/web`
- `wzzc-dev/moui/backend/host`
- `wzzc-dev/moui/backend/{macos,windows,linux}`
- `wzzc-dev/moui/backend/{macos,windows,linux}/skia`
- `wzzc-dev/moui/render/skia`
- 对应的 shared app package，例如 `examples/showcase/app`

WGPU 相关 backend/render 包只作为实验或诊断入口使用，不是普通 app 或默认平台入口的推荐依赖。

平台入口包不应该承载业务 UI。业务 view/model/update 应留在共享 app 包，平台入口只负责 runtime + backend + renderer wiring。

## 框架和控件实现包

框架内部、控件实现、renderer/backend 集成可以使用更低层的包。

- `moui/core`：基础协议层 / 抽象 UI kernel，包含平台中立协议和值类型，
  例如 `View`、event、layout、paint、semantics、text contract 等。
- `moui/views`：app-facing constructor 与具体 custom view 控件行为实现。
- `moui/runtime`：runtime state、element tree、layout/paint/event dispatch、program execution。
- `moui/backend/host`：host service、window/event/service 协议。
- `moui/backend/*`：平台 backend。
- `moui/render/*`：renderer facade 和具体 renderer 实现。
- `moui_richtext`：富文本/Markdown 文档、编辑、命令、输入、粘贴、表格与源码映射逻辑
  addon，供 rich editing app（如 `examples/markdown_editor`、`examples/mo_workbench`、
  `examples/showcase`）按需直接依赖；不进入 `core`、`views` 或 root facade 默认依赖。
- `moui_agent` / `moui_agent_mcp`：agent 协议、schema、host runtime 与 MCP router
  support addon，供 agent-controllable app（如 `examples/agent_counter`）按需直接依赖；
  不进入 `core`、`views` 或 root facade 默认依赖。
- `moui_theme/*`：设计系统 addon，不进入 `core`、`views` 或 root facade 的默认依赖。

普通 app 默认只依赖 `moui` 与 `moui/views`；直接依赖 `moui_richtext`、
`moui_agent*`、`moui_theme/*` 等 addon 仅在 app 明确需要该能力时才允许。直接依赖
`moui/core`、`moui/backend/host` 的普通 app 由 API surface guard 的 advanced-app
白名单约束（当前覆盖 `examples/markdown_editor/app`、`examples/mo_workbench/app`、
`examples/pdf_workbench/app`、`examples/showcase/app`、`website/app` 中的 core 导入，
以及 `examples/showcase/app` 的 runtime 导入）。

## Review Checklist

新增依赖或公开 API 前，先回答这些问题：

- 这个 package 是普通共享 app、平台入口、测试，还是框架/控件实现？
- 普通共享 app 是否只依赖 `wzzc-dev/moui` 和 `wzzc-dev/moui/views`？
- 如果普通 app 直接 import `wzzc-dev/moui/core`，是否只是为了 root facade 尚未覆盖的 app-safe neutral type？
- 如果普通 app import `wzzc-dev/moui/backend/host`，是否确实需要 host service 协议？
- 普通 app 是否错误依赖了 `runtime`、`render/*` 或平台 backend？
- 新增 root alias 是否是平台中立、app-safe、高频使用的类型？
- 新增低层 custom view helper 是否同时提供了 `moui/views` app-facing constructor？
- 新增控件是否避免向 `core` 添加具体控件 enum variant、primitive constructor 或 runtime lowering 分支？
- 新增 `core` API 是否真的是跨 runtime 的基础协议 / 抽象 UI kernel 能力？
- 新增 style、form、webview、routing、rich text editor、diagnostics API 是否更适合
  放在 `views`、`runtime`、`backend/host`、`moui_devtools` 或 addon？
- `moui_theme/*` 是否仍然只是 addon/preview 依赖，没有进入普通 app 默认依赖？

如果一个改动需要突破上述规则，必须在同一个变更中写明理由，并说明为什么它不是更适合放在 `views`、`runtime`、`backend` 或 `render` 的职责。

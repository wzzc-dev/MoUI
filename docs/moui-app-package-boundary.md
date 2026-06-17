# MoUI 应用包边界规范

本文档规定 MoUI 应用开发时可以依赖哪些包、`wzzc-dev/moui/core`
作为基础协议层 / 抽象 UI kernel 的边界、root facade 应该暴露哪些类型，
以及 `wzzc-dev/moui/widget` 什么时候可以使用。

## Core 定位

`wzzc-dev/moui/core` 的定位是**基础协议层 / 抽象 UI kernel**。
它定义跨 runtime、跨 backend、跨 renderer 都稳定成立的 UI 协议和值类型，
让 app、widget、runtime、backend、renderer 可以在同一套抽象上协作。

`core` 应该包含：

- 基础值类型：geometry、color、brush、font、event、keyboard、text range 等。
- 抽象 UI 协议：`View`、`WidgetOps`、layout/paint/event/semantics/focus/text input contract。
- App loop contract：`Program`、`Effect`、`Subscription` 这类平台中立执行协议。
- Renderer-neutral draw/text/accessibility contract：绘制命令、文本测量协议、语义树协议。
- Theme 的中立 token surface：不绑定具体设计系统品牌、不含平台或 renderer 实现。

`core` 不应该成为：

- 控件 catalog：按钮、表单、选择器、富文本编辑器等具体控件 API 应属于
  `moui/views` / `moui/widget`，而不是塞进 kernel。
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

- app-facing 能力进入 `moui/views`：控件样式、form helper、routing/history、
  picker item、WebView constructor，以及普通 app 需要看到的 rich text facade。
- 控件实现进入 `moui/widget`：rich text editor、picker、text field、button 等低层
  widget implementation。
- runtime/diagnostics 进入 `moui/runtime`：runtime inspector、program lifecycle
  snapshot、view/render diagnostics snapshot、`BuildContext` runtime 构造细节。
- 平台服务进入 `moui/backend/host`：WebView command/event/policy/spec、host
  capability、host service contract。
- renderer/backend 实现仍在 `moui/render/*` 和 `moui/backend/*`。

只有当一个能力无法由上述层自然承接，且会被多个包稳定复用时，才考虑新增 addon
或更专门的 package。新增 package 必须先说明它为什么不是 `views`、`widget`、
`runtime` 或 `backend/host` 的职责。

## 当前 Core 收敛状态

按“基础协议层 / 抽象 UI kernel”来衡量，`moui/core` 已经完成以下厚能力迁出。
这些迁移是后续新增 API 的默认边界，不应被回填到 `core`。

- **控件样式和 picker model ownership 已迁出**：`ButtonStyle`、
  `TextFieldStyle`、`ChoiceControlStyle`、`ProgressStyle`、`SliderStyle`、
  `PickerStyle`、`FeedbackStyle`、`BadgeStyle`、`FormValidationStyle`、
  `PickerItem` 已由 `moui/views` 拥有。`core` 只保留 `Color`、`Brush`、
  `BorderStyle`、`ShadowStyle`、`Theme` token 这类基础值。低层 picker widget
  使用 `moui/widget.PickerOption` 作为实现输入，普通 app 仍使用
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
  rich text geometry/paint/selection helper 已由 `moui/widget` 拥有，`moui/views`
  通过 `@views.RichTextDocument`、`@views.RichTextInputTransform`、
  `@views.rich_text_document_height` 等 facade 给普通 app 使用。`core` 只保留
  `TextRange`、grapheme boundary、`TextSystem`、paragraph layout contract、基础
  text input state。
- **`BuildContext` runtime 构造命名已收口**：旧的
  `BuildContext::new_for_runtime` 已移除。`BuildContext` 仍作为 component-facing
  kernel 类型保留在 `core`，因为 `core.WidgetOps` / `views.component` 的签名需要
  它且 `core` 不能反向依赖 `runtime`。当前只保留中性的 `BuildContext::new` 供
  runtime 构造执行上下文，root facade 不暴露该构造器；新增代码不得恢复
  `new_for_runtime` 或暴露 runtime storage 形状。
- **诊断/Inspector 结构偏 runtime/devtools**：`RuntimeInspectorSnapshot`、
  `ProgramRuntimeSnapshot`、`ViewTreeInspectorSnapshot`、`RenderInspectorSnapshot`
  等是很有价值的诊断 API，但不是 UI kernel 的基础协议。第二阶段已经由
  `moui/runtime` 拥有 runtime-owned diagnostics/snapshot 类型；`core` 不再导出
  这些 diagnostics 类型，也不能作为新增 diagnostics API 的 owning package。
  它们应避免进入 root facade，devtools/overlay 应基于
  `@runtime.InspectorSnapshot` 构建视图。
- **Routing/history ownership 已迁出**：`RouteLocation`、`RouteDescriptor`、
  `RouterSnapshot`、`RouteHistoryState`、`RouteFocusStore`、`RouterState` 和
  `resolve_route` 已归 `moui/views` navigation 支持层拥有。`core` 只保留
  `NavigationState` 这类基础 state holder。Host route 事件使用
  `@host.HostRouteLocation`，普通 app 在接入 navigation history 时转换为
  `@views.RouteLocation`。

新增 API 默认放在更具体的 owning package；只有确认它是跨 runtime 的抽象协议或
基础值类型时，才进入 `core`。

## 现状声明（过渡期）

本规范描述的是 MoUI 包边界的**目标态**。截至当前版本，仓库内存在以下已知的、
计划随 root facade 扩展逐步收敛的偏差，不应被视为鼓励扩大的先例：

- **第一阶段 facade 已落地**：`moui/views` 已承接 app-facing 厚类型，
  包括控件样式、form validation、rich text document / input transform、
  routing/history、WebView event/policy 等。普通 app 新增代码应
  优先使用 `@views.RichTextDocument`、`@views.FormValidationSummary`、
  `@views.RouteHistoryState`、`@views.TextFieldStyle`、`@views.WebViewEvent`
  等入口，而不是新增 `@core.*` 厚类型引用。
- **第二阶段 diagnostics ownership 已落地**：`moui/runtime` 已拥有
  `ProgramRuntimeSnapshot`、`RuntimeInspectorSnapshot`、`InspectorSnapshot`、
  `ViewTreeInspectorSnapshot`、`LayoutInspectorSnapshot`、`RenderInspectorSnapshot`
  和 `SemanticsInspectorSnapshot` 等诊断类型。`AppRuntime::inspector_snapshot`
  和 `AppRuntime::program_runtime_snapshot` 返回 runtime-owned 类型。`core` 中的
  历史 diagnostics 类型和兼容桥已经删除；新增 devtools、tester、diagnostics 示例
  必须使用 `@runtime.*`。
- **第三阶段 WebView ownership 已落地**：`moui/backend/host` 已拥有
  WebView command/event/policy/spec 以及 host queue/event source。`moui/views`
  继续提供普通 app 入口 `web_view`，并 re-export `@views.WebViewEvent` /
  `@views.WebViewNavigationPolicy`。`core` 的 WebView 专有 public surface 已删除，
  API guard 将 `core` WebView legacy family 锁定为
  `occurrences=0 max=0 target=0`；新增 WebView API 必须进入 `backend/host` 或
  `views`。
- **第四阶段 routing/history ownership 已落地**：`moui/views` 已拥有 routing /
  history / route focus store / router state API，`moui/core` 的 routing owning
  surface 已删除，API guard 将 `core` routing legacy family 锁定为
  `occurrences=0 max=0 target=0`。新增 navigation/router/history API 必须进入
  `views`；`core.NavigationState` 只作为基础 state holder 保留。
- **第五阶段 form/style ownership 已落地**：控件 style、form validation 和
  picker item 已由 `moui/views` 拥有，`moui/core` 的相关 owning surface 已删除，
  API guard 将 `core` control style 和 form workflow legacy family 锁定为
  `occurrences=0 max=0 target=0`。
- **第六阶段 rich text ownership 已落地**：rich text document / input transform /
  geometry / paint / selection helper 已由 `moui/widget` 拥有，`moui/views` 提供
  app-facing facade。`moui/core` 的 rich text owning surface 已删除，API guard
  将 `core` rich text legacy family 锁定为 `occurrences=0 max=0 target=0`。
- **第七阶段 BuildContext 构造命名已收口**：`BuildContext::new_for_runtime`
  已删除并由中性的 `BuildContext::new` 替代。由于 `BuildContext` 是
  component-facing kernel 类型，仍保留在 `core`；构造入口只由 runtime 使用，
  不进入 root facade。
- **`@core` 当前仍包含部分 advanced kernel surface**：例如 `WidgetOps`、
  `DrawCommand`、`TextInputState` 等，这些是框架/控件/renderer 协作协议，不是
  普通 app 默认入口。新增 app-facing 能力应优先放到 `views`、`widget`、
  `runtime`、`backend/host`、`render` 或 `moui_theme`。
- **`@core` 仍被部分 app 直接依赖**：root facade（`moui/moui.mbt`）已经开始按
  “Root Facade 暴露规则”re-export app-safe neutral aliases，例如 `Color`、
  `Size`、`Rect`、`State`、`Environment` 等。部分业务 app 仍直接 import `@core`
  使用几何、event、draw command、text range、program contract 等 kernel /
  advanced 能力，这是过渡期事实。checklist 中“普通共享 app 是否只依赖
  `wzzc-dev/moui` 和 `wzzc-dev/moui/views`”应以**目标态**理解，不作为阻断当前
  example 合规的硬性条件；但新增 form、rich text、routing、控件 style
  app-facing 引用应走 `@views`，新增 WebView host 协议应走 `@host`。
- **`showcase/app` 直接依赖 `@render`**：用于 renderer capability 报告
  （`renderer_feature_capability_report()` 等）。这属于已知偏差，正确做法是把
  capability 报告收敛为 app-facing API（经 `moui/views` 或 root facade 暴露），
  而不是让普通 app 直接依赖 `@render/*`。在收敛前，`showcase/app` 是该规则的唯一
  已知例外。
- **`showcase/app` 直接依赖 `@runtime`**：用于展示 runtime diagnostics snapshot
  示例卡片。普通 app 不应以此为先例默认依赖 runtime；只有平台入口、测试、devtools
  或明确的 diagnostics 示例可以使用 `@runtime.*` diagnostics 类型。
- **测试目标下的额外 import 不计入运行时边界**：各 app 在 `for "test"` /
  `for "wbtest"` 下 import `@runtime`、`@core` 等仅用于测试，不构成运行时依赖，
  不违反本规范。

新增依赖或公开 API 时，应朝目标态靠拢，而不是以现存偏差为先例扩大偏差。

## 普通共享 App 包

普通共享 app 包指 `examples/*/app` 这类平台无关的业务逻辑包。它们应该默认只依赖：

- `wzzc-dev/moui`
- `wzzc-dev/moui/views`

`wzzc-dev/moui` 是应用 facade。它应该 re-export app-safe 的平台中立常用类型，让普通 app 不必频繁直接 import `wzzc-dev/moui/core`。

`wzzc-dev/moui/views` 是 app-facing UI 构造器入口。应用层组合按钮、文本、布局、表单、列表、弹窗、WebView wrapper、主题 helper 等，应该优先使用这里的函数。

普通 app 可以按需直接依赖：

- `wzzc-dev/moui/core`：仅当 root facade 尚未覆盖，或确实需要高级平台中立协议类型时使用。
- `wzzc-dev/moui/backend/host`：仅当 app 需要 host service / 平台服务协议时使用，例如文件对话框、异步图片、剪贴板、WebView command queue 或 host service 交互。普通 app 处理 WebView 事件时优先使用 `@views.WebViewEvent`。

普通 app 不应该直接依赖：

- `wzzc-dev/moui/widget`
- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/render/*`
- `wzzc-dev/moui/backend/{web,macos,windows,linux}`
- `wzzc-dev/moui/backend/{macos,windows,linux}/skia`
- `wzzc-dev/moui/backend/{macos,windows,linux}/wgpu`
- `moui_theme/*`，除非该 app 本身是设计系统 addon 或 preview app。

已知例外见上方“现状声明”：`showcase/app` 暂时依赖 `@render` 用于 capability 报告，
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
- 不暴露 runtime tree、renderer、backend、inspector、debug payload 或 widget implementation details。
- 是普通 app 高频需要的类型。

推荐由 `wzzc-dev/moui` 暴露的类型包括：

- app shape：`View`、`Program`、`Effect`、`Subscription`、`Theme`
- 几何：`Point`、`Size`、`Rect`、`Insets`、`Constraints`、`Axis`
- 绘制基础值：`Color`、`Brush`、`BorderStyle`、`ShadowStyle`
- 文本基础值：`FontSpec`、`FontFamily`、`TextRange`、`TextAlign`
- 状态：`State`、`Binding`、`DerivedState`
- 环境：`Environment`、`ViewEnvironment`、`ColorScheme`、`LayoutDirection`
- app 状态 holder：`ScrollState`、`FocusState`、`NavigationState`
- 交互：`CommandIntent`、`KeyboardShortcut`、`KeyModifiers`
- 常用数据模型：`DateValue`

不应该进入 root facade 的类型包括：

- `WidgetOps`、`WidgetLayoutContext`、`WidgetPaintContext`、`WidgetEventContext`
- `WidgetPaintPlan`、`WidgetPaintLayer`、`WidgetEventResult`
- `DrawCommand`、`DrawFrame`、`DamageRegion`
- `BuildContext::new` 这类 runtime-only 构造入口
- runtime snapshot、inspector snapshot、diagnostic payload
- renderer resource、renderer capability、platform-view placement
- backend host/runtime driver 相关类型
- 具体控件 style 默认值、表单 workflow helper、WebView command/event、routing/history
  controller、rich text document/editor transform 等非 kernel 能力

扩展 root facade 时必须同步更新 `pkg.generated.mbti` 和 API surface guard，
并用 review 确认新增 alias 是 app-safe neutral type。

Diagnostics 类型的 owning package 是 `wzzc-dev/moui/runtime`。`core` 不再导出
`InspectorSnapshot`、`ProgramRuntimeSnapshot` 或 `RenderInspectorSnapshot` 这类
diagnostics 类型。

WebView 类型的 owning package 是 `wzzc-dev/moui/backend/host`。`core` 不再导出
`WebViewSpec`、`WebViewCommand`、`WebViewEvent` 或
`WebViewNavigationPolicy`，也不提供 `PlatformViewPlacement::web_view` 这类
WebView 专有 helper。

## `moui/widget` 使用规则

`wzzc-dev/moui/widget` 面向框架作者、控件库作者、以及 MoUI 内置控件实现者。

只有在需要实现新的 reusable widget，并且必须自定义以下行为时，才使用 `moui/widget`：

- layout
- paint
- event handling
- text input state / text command
- semantics
- focus

如果只是组合已有控件，例如按钮、表单、列表、布局、弹窗、菜单、
WebView wrapper，应用层应使用 `wzzc-dev/moui/views`，不应该绕过
`views` 直接使用 `widget`。

新增 widget 时遵循这个落点：

- 公共 app-facing constructor 放在 `moui/views`。
- 具体 widget ops 实现放在 `moui/widget`。
- 底层协议通过 `@core.View::widget` 和 `@core.WidgetOps` 对接。
- 普通 app 只看到 `@views.some_control(...) -> View[Msg]`。

换句话说，Iced 的 `iced::widget` 同时是内置控件和自定义控件入口；
MoUI 当前更保守：`moui/views` 是普通 app 的控件入口，
`moui/widget` 更接近 widget implementation layer。未来如果 MoUI
希望提供公开的 custom widget API，可以在 `moui/widget` 中稳定一层
专门面向控件作者的 API，但这不改变普通 app 默认不依赖 `widget` 的规则。

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
  例如 `View`、`WidgetOps`、event、layout、paint、semantics、text contract 等。
- `moui/widget`：具体 widget ops 实现。
- `moui/runtime`：runtime state、element tree、layout/paint/event dispatch、program execution。
- `moui/backend/host`：host service、window/event/service 协议。
- `moui/backend/*`：平台 backend。
- `moui/render/*`：renderer facade 和具体 renderer 实现。
- `moui_theme/*`：设计系统 addon，不进入 `core`、`views` 或 root facade 的默认依赖。

## Review Checklist

新增依赖或公开 API 前，先回答这些问题：

- 这个 package 是普通共享 app、平台入口、测试，还是框架/控件实现？
- 普通共享 app 是否只依赖 `wzzc-dev/moui` 和 `wzzc-dev/moui/views`？
- 如果普通 app 直接 import `wzzc-dev/moui/core`，是否只是为了 root facade 尚未覆盖的 app-safe neutral type？
- 如果普通 app import `wzzc-dev/moui/backend/host`，是否确实需要 host service 协议？
- 普通 app 是否错误依赖了 `runtime`、`widget`、`render/*` 或平台 backend？
- 新增 root alias 是否是平台中立、app-safe、高频使用的类型？
- 新增 widget 是否同时提供了 `moui/views` app-facing constructor？
- 新增控件是否避免向 `core` 添加具体控件 enum variant、primitive constructor 或 runtime lowering 分支？
- 新增 `core` API 是否真的是跨 runtime 的基础协议 / 抽象 UI kernel 能力？
- 新增 style、form、webview、routing、rich text editor、diagnostics API 是否更适合
  放在 `views`、`widget`、`runtime`、`backend/host`、`moui_devtools` 或 addon？
- `moui_theme/*` 是否仍然只是 addon/preview 依赖，没有进入普通 app 默认依赖？

如果一个改动需要突破上述规则，必须在同一个变更中写明理由，并说明为什么它不是更适合放在 `views`、`widget`、`runtime`、`backend` 或 `render` 的职责。

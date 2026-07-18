# MoUI 应用包边界规范

本文档规定 MoUI 应用开发时可以依赖哪些包、`wzzc-dev/moui/core`
作为基础协议层 / 抽象 UI kernel 的边界、根 facade `wzzc-dev/moui`（app-loop 糖）
与领域 facade（`moui/geometry`、`moui/graphics`、`moui/animation`、
`moui/text`、`moui/state`）如何按领域承接 app-facing kernel 类型，以及
`wzzc-dev/moui/views` 如何承接普通 view constructor、控件语义和低层控件实现。

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

依赖方向采用 Iced 风格的单向分层：`core` 是 foundation，领域 facade、`views`、
`runtime`、`backend`、`render` 可以依赖并扩展它；`core` 永远不依赖
`geometry`、`graphics`、`animation`、`text`、`state`、`views`、`runtime`、
`backend`、`render` 或 addon 包。

## 少包策略

MoUI 的包边界优先保持少而清晰，不按每个功能名拆出一组顶层 public package。
除非现有层无法自然承接，否则不要新增 `moui/style`、`moui/forms`、
`moui/rich_text`、`moui/routing`、`moui/platform`、`moui/diagnostics`
这类细碎包。

**根 `wzzc-dev/moui`** 只转发 app-loop 高频类型（`View`、`Program`、`Effect` 等），
写作 `@moui.*`，避免与 `examples/*/app` 包默认别名 `@app` 冲突。

**领域 facade**（见下方“领域 facade 暴露规则”）：`moui/geometry`、
`moui/graphics`、`moui/animation`、`moui/text`、`moui/state`。它们是
app-facing facade/extension over `core`，第一阶段主要通过
`pub using @core {type X}` 暴露高频类型；后续可以承接不适合放进 `core`
的轻量领域 helper，但不能反向依赖 `views`、`runtime`、`backend`、`render`
或其它领域 facade，也不能让 `core` 依赖它们。新增领域 facade 须说明转发集合、
扩展职责及为何根 facade 与其它领域 facade 无法承接。

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
- **组件 theme schema 仍在 core（S1）**：`ComponentThemes` / `ButtonTheme` /
  `ControlStateTokens` / `ControlStateStyle` 等挂在 `@core.Theme.components` 上，
  供 resolver 与 `moui_theme` 投影使用。因 `core` 不能依赖 `views`，在拆分
  `Theme`（去掉 `components` 字段）的 RFC 之前，这些类型的**定义**留在
  `core`；app 侧控件外观仍优先 `@views.*Style` 与 `light_theme`/`theme`。
  详见 `docs/plans/active/core-component-theme-to-views.md`。
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
  rich text geometry/paint/selection helper 由 `moui_richtext` addon 拥有，普通
  app 通过 `@moui_richtext.RichTextDocument`、`@moui_richtext.RichTextInputTransform`、
  `@moui_richtext.rich_text_document_height`、`@moui_richtext.markdown_editor`、
  `@moui_richtext.controlled_markdown_session_editor` 等 facade 使用。`core` 只保留
  `TextRange`、grapheme boundary、`TextSystem`、paragraph layout contract、基础
  text input state。`moui/views` 只保留 `text`/`text_field`/`text_area` 纯文本控件。
- **`ComponentContext` runtime 构造入口已收口**：`ComponentContext` 仍作为
  component-facing kernel 类型保留在 `core`，因为 `View::node` /
  `views.component` 的签名需要它且 `core` 不能反向依赖 `runtime`。runtime 使用
  `ComponentContext::from_runtime(ComponentRuntimeContextInput)` 构造执行上下文；
  普通 component API 不暴露散落的 runtime storage 参数，领域 facade 也不转发该
  构造入口。
- **Date picker 控件语义已迁出**：`DateValue` 是中立数据模型，继续属于
  `core`；`DatePickerMode` 是具体控件语义，属于 `moui/views`。低层 display
  mode representation 是 `views` 包内私有实现细节，转换由普通 constructor 完成。
- **Sheet 控件语义已迁出**：`SheetPresentationMode` 是 sheet 控件语义，属于
  `moui/views`。`core` 不导出它，sheet / sheet_host constructor 直接使用
  `@views.SheetPresentationMode`。
- **Theme schema 和默认审美已拆分**：`core.Theme` / `core.Environment` 保留
  token schema 和 `neutral()` fallback/testing 值；`default_theme()`、
  `light_theme()`、`dark_theme()` 等 app-facing 默认审美属于 `moui/views`。
- **诊断/Inspector 结构偏 runtime/devtools**：`RuntimeInspectorSnapshot`、
  `ProgramRuntimeSnapshot`、`ViewTreeInspectorSnapshot`、`RenderInspectorSnapshot`
  等是很有价值的诊断 API，但不是 UI kernel 的基础协议。`EffectPlanSummary`、
  `SubscriptionPlanSummary` 和 runtime snapshots 由 `moui/runtime` 拥有；`core`
  不再导出 diagnostics summary 或 runtime op 列表，也不能作为新增 diagnostics
  API 的 owning package。领域 facade 不转发它们，devtools/overlay 应基于
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
`website/app` 和把共享 app 放在示例根目录的 `examples/agent_counter`。它们应该默认依赖:

- `wzzc-dev/moui` —— app-loop 糖（`@moui.View`、`@moui.Program`、`@moui.Effect`、
  `Subscription`、`Theme`、`Environment`、`ViewEnvironment`）。与共享 app 包别名
  `@app`（业务模块）分离。

- `wzzc-dev/moui/<领域>` —— 其余高频领域 facade，按需 import:

  - `wzzc-dev/moui/geometry`:`Point`、`Size`、`Rect`、`Insets`、`Constraints`、`Axis`、`Alignment`。
  - `wzzc-dev/moui/graphics`:`Color`、`Brush`、`BorderStyle`、`ShadowStyle`、
    `RoundedRect`、`PathSpec`、`PathVerb`、`ImageRun`、`ImageFit`、`BlendMode`、
    `LayerSpec`、`LayerMask`、`FilterEffect`、`ShadowSpec`、`Transform2D`、
    `ShaderEffectSpec`。
  - `wzzc-dev/moui/animation`:`Easing`、`TransitionSpec`、`TransitionStyle`。
  - `wzzc-dev/moui/text`:`FontSpec`、`FontFamily`、`TextRange`、`TextAlign`、
    `FontFamilyStack`、`TextRun`（后两者为示例/绘制辅助高频项）。
  - `wzzc-dev/moui/state`:`State`、`Binding`、`DerivedState`、`ScrollState`、
    `FocusState`、`NavigationState`、`ColorScheme`、`LayoutDirection`、
    `FocusScope`、`FocusScopeItem`。

  领域 facade 当前只依赖 `core`，主要以 `pub using @core {type X}` 转发；
  领域前缀与 `@core.X` 为同一类型。app 在单文件内应统一一种前缀，避免同文件
  同类型双前缀（参见 showcase 早期的 `@moui.View` + `@core.Point` 并存问题）。
  跨示例包引用业务 API 仍用 `@app.ShowcaseModel` 等。

- `wzzc-dev/moui/views` —— app-facing UI 构造器入口。应用层组合按钮、文本、布局、表单、列表、弹窗、WebView wrapper、主题 helper 等，应该优先使用这里的函数。
  另通过 facade 转发命令/菜单类型（`ActionCommand`、`CommandIntent`、
  `KeyboardShortcut` 等）、默认主题 helper、控件 style、form/navigation/data helper。
  `DateValue` 因 datepicker 公共 API 已暴露而暂留 `@views.DateValue` facade；
  绘制、动画、focus scope 和低层 runtime/semantics id 不再经 `@views` 兜底。

- `wzzc-dev/moui_i18n` —— **可选本地化 addon**。它提供 locale 规范化、静态 catalog
  lookup、fallback、命名插值和有限 count message 规则；产品 catalog 和 locale 选择仍归
  app。它不被根 facade / `views` 重导出，也不向 `core` 注入 JSON、资源加载或平台 locale
  探测。完整工作流见 `docs/internationalization.md`。

- `wzzc-dev/moui/core` —— **类型真源**。共享 app **运行时**宜优先 `@moui` / 领域糖 /
  `@views`，使 `moon.pkg` 默认 **不** import `core`（`validate_api_surface` 对 shared
  app 有 core import budget）。低频 kernel、自定义 `View::node`、或 **测试** 模拟
  `AppEvent` / `DrawCommand` 时，在 `for "test"` / `for "wbtest"` 中 import
  `wzzc-dev/moui/core`（及按需 `runtime`），测试目标不计入默认运行时边界。

`wzzc-dev/moui` 根包**只**转发 app-loop 糖；geometry/graphics/animation/text/state
仍走对应领域 facade。其余低频 kernel 类型直连 `@core`。

普通 app 可以按需直接依赖:

- `wzzc-dev/moui/backend/host`:仅当 app 需要 host service / 平台服务协议时使用,例如文件对话框、异步图片、剪贴板、WebView command queue 或 host service 交互。普通 app 处理 WebView 事件时优先使用 `@views.WebViewEvent`。

普通 app 不应该直接依赖:

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/render/*`
- `wzzc-dev/moui/backend/{web,macos,windows,linux}`
- `wzzc-dev/moui/backend/{macos,windows,linux,android}/skia`
- `wzzc-dev/moui/backend/{macos,windows,linux}/wgpu`
- `moui_theme/*`,除非该 app 本身是设计系统 addon 或 preview app。

已知例外见上方“目标边界声明”:`showcase/app` 暂时依赖 `@render` 用于 capability 报告,
并依赖 `@runtime` 用于 diagnostics snapshot 示例。前者应在 capability 报告收敛为
app-facing API 后移除;后者仅限 diagnostics 示例,不代表普通 app 默认可依赖 runtime。

## App 私有子包

某些 app 在共享 app 包之外，还会带有自己的私有支持包，例如
`examples/pdf_workbench` 的 `pdfium_adapter`、`pdflite_adapter`、
`pdflite_service_*` 等。这类包既不是普通共享 app 包，也不是平台入口包，
而是某个 app 专用的适配层 / 服务实现 / 进程间协议。

定位规则：

- 它们只服务于宿主 app，不应被其他 app 或框架层依赖。
- 它们可以依赖 `@core`、`@backend/host`、`@views` 以及 app 自身的共享 app 包，
  视具体职责而定，但不应该被普通共享 app 包反向依赖。
- 它们不进入领域 facade，也不向 `@core` / `@views` 注入 app 特定类型。
- 评审时把它们视作 app 的实现细节，而不是框架 API 表面的一部分。

如果某个 app 私有子包的抽象逐渐被多个 app 复用，应考虑上提到
`moui/views`、`moui/core` 或独立的 addon 包，而不是继续作为某个 app 的私有子包存在。

## 领域 facade 暴露规则

`wzzc-dev/moui/core` 的平台中立基础类型，由根 `wzzc-dev/moui`（app-loop）与领域
facade 做 curated re-export，让普通 app 减少 `@core` 前缀的样板。领域 facade
遵循以下原则:

- **`core` 真源，领域 facade 承接 app-facing 前缀**。领域 facade 的第一职责是为
  高频类型省前缀；它**不追求完整覆盖** `core` 公开面。`@core.X` 与
  `@<domain>.X` 是同一类型。后续若新增领域 helper，它必须是轻量 app-facing
  extension over `core`，不能让 `core` 反向依赖领域包。
- **每个类型只属一个领域 facade**。跨越 layout 与 state 等集合边界的归属判断以语义为准
  (例如 `ColorScheme` 用于 theme 解析属 `state`,不归 `graphics`),不按 app 出现频次
  把同一类型塞进多个领域 facade。
- **依赖单向，不互 import**。领域 facade 只 import `wzzc-dev/moui/core`，不互相依赖，
  不 re-export 其他领域 facade 或 `views`/`runtime`/`backend`/`render`/`host` 的类型。
- **只转 app-safe neutral 类型**。不转发 runtime tree、renderer、backend、inspector、
  debug payload、private view implementation details、控件 mode/style/default theme、
  form helper、WebView command/event、routing/history controller、rich text document。

### 领域 facade 清单

**`wzzc-dev/moui`（根 facade，`moui/moui.mbt`）** — `@moui.*`
```
View  Program  Effect  Subscription  Theme  Environment  ViewEnvironment
```

**`moui/geometry`** (import `@core`)
```
Point  Size  Rect  Insets  Constraints  Axis  Alignment
MainAxisAlignment  CrossAxisAlignment
```

**`moui/graphics`** (import `@core`)
```
Color  Brush  BorderStyle  ShadowStyle  RoundedRect  PathSpec  PathVerb
ImageRun  ImageFit  BlendMode  LayerSpec  LayerMask  FilterEffect
ShadowSpec  Transform2D  ShaderEffectSpec
```

**`moui/animation`** (import `@core`)
```
Easing  TransitionSpec  TransitionStyle
```

**`moui/text`** (import `@core`)
```
FontSpec  FontFamily  TextRange  TextAlign  FontFamilyStack  TextRun
```

**`moui/state`** (import `@core`)
```
State  Binding  DerivedState  ScrollState  FocusState  NavigationState
ColorScheme  LayoutDirection  FocusScope  FocusScopeItem
```

### `@views` 转发（constructor / 控件 facade，不兜底 kernel）

**允许**（控件工作流表面）：

- 命令与菜单：`ActionCommand`、`ActionCommandMap`、`CommandBinding`、`CommandIntent`、
  `KeyModifiers`、`KeyboardShortcut`（`menu_commands.mbt`）。
- Date picker 数据：`DateValue` 暂留 `@views.DateValue`（datepicker 公共 API 已暴露；
  无独立 domain facade）。
- 主题构造辅助：`ColorPalette`、`TypographyScale`（`theme.mbt`）。
- 控件样式桥：`ControlStateStyle`（`control_style.mbt`；真源在 `core`）。

**禁止**（领域值类型，走 domain facade，不从 `@views` 再导出）：

- `@graphics.Color` / paint 值类型 — **不要** `@views.Color`
- `@state.ColorScheme` — **不要** `@views.ColorScheme`
- geometry / animation / text / state 其它值类型 — 用对应 domain facade

绘制/动画/focus/低层 runtime id 路径：

- 绘制与低层 paint 类型用 `@graphics.Color`、`@graphics.RoundedRect`、`@graphics.PathSpec`、
  `@graphics.ImageFit`、`@graphics.LayerSpec`、`@graphics.Transform2D` 等。
- 动画类型用 `@animation.TransitionSpec`、`@animation.TransitionStyle`、`@animation.Easing`。
- focus / scheme 用 `@state.FocusScope`、`@state.FocusScopeItem`、`@state.ColorScheme`。
- diagnostics/kernel-only 类型在需要时直连 `@core.ElementId`、`@core.SemanticsRole`、
  `@core.ComponentContext`，并限定在 showcase/diagnostics/custom kernel 或测试场景。

### 不设糖 / 仅测试或框架直连 `@core`

以下仍属 kernel，**不设领域 facade**；共享 app 主代码应避免 `@core` 前缀，测试在
`for "test"` / `for "wbtest"` 中 import `core` 后使用：

`AccessibilityContrast`、`ContentSizeCategory`；
`AppEvent`、`KeyboardEvent`、`PointerEvent`、`DrawCommand`、`CompositionUpdate` 等
事件与绘制协议（runtime 测试、能力展示）。

历史计划曾将 `CommandIntent` 等列为“仅 `@core`”；现以 **`@views` re-export** 为准。

### 别名语法规范

领域 facade 暴露 `core` 类型**统一使用新式 `pub using @core {type X}`**:

```moonbit
pub using @core {type View}
```

**禁用旧式 `pub type X = @core.X`**。MoonBit 工具链两套语法在 `moon info` 重新生成
`pkg.generated.mbti` 时会归一到 `pub using @core {type X}`,所以新式语法由 review 与
API surface guard 的 `required_tokens` 共同维护;旧式手写别名不属于本规范的合法形态。

Diagnostics 类型的 owning package 是 `wzzc-dev/moui/runtime`。`core` 不再导出
`EffectPlanSummary`、`SubscriptionPlanSummary`、`EffectRuntimeOp`、
`InspectorSnapshot`、`ProgramRuntimeSnapshot` 或 `RenderInspectorSnapshot` 这类
diagnostics/runtime 类型，领域 facade 也不转发。

WebView 类型的 owning package 是 `wzzc-dev/moui/backend/host`。`core` 不再导出
`WebViewSpec`、`WebViewCommand`、`WebViewEvent` 或
`WebViewNavigationPolicy`，也不提供 `PlatformViewPlacement::web_view` 这类
WebView 专有 helper；领域 facade 也不转发。

### 扩展领域 facade

扩展领域 facade（新增类型到现有领域 facade，或新增一个领域 facade）必须同步:

- 更新 `pkg.generated.mbti`(运行 `moon info <pkg>`)。
- 更新 `tools/moui/validate_api_surface/main.mbt` 中对应领域 facade 的
  `sugar_<domain>_tokens()` 与 budget。
- 用 review 确认新增类型是平台中立、app-safe、高频的 kernel 类型，
  或是该领域可自然承接的轻量 extension，且不与现有领域 facade 或“不设糖”清单重叠。

`@core` 公开面扩展不需要领域 facade 同步；领域 facade 负责的是“app-facing 高频前缀”
集合，新加的 kernel 类型默认走 `@core` 直连，直到被显式纳入领域 facade 清单。

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
控件作者复用同包内私有 control/layout helper。这不改变普通 app 默认依赖
`moui/<领域>`（按需）与 `moui/views` 的规则；低层 public 入口只有 `@core.View::node(...)`。

## 平台入口包

平台入口包指 `examples/*/{web_wasm,macos_skia,windows_skia,linux_skia}`
这类 `is-main` package。它们负责创建 runtime、连接平台 backend、选择 renderer。
Android 例外地拆成 `examples/*/android_skia` MoonBit embedded-session 入口和
package-owned Kotlin managed shell；构建时从已解析的 MoUI package staging，
`examples/*/android_app` 只保留为 Release N legacy fixture。
iOS 同样走 embedded-session 入口：`examples/*/ios_skia` 暴露 MoonBit C exports，
构建时 staging 的 `moui/mobile/ios` canonical SwiftUI shell 负责单 scene 生命周期、
`CAMetalLayer` surface、`CADisplayLink`、UIKit service adapter 与触摸转发；
Objective-C++ 仅保留 Mobile Runtime ABI v1 翻译和数据所有权；
`examples/*/ios_app` 只保留为 Release N fixture。
HarmonyOS 同样走 embedded-session 入口：`examples/*/harmonyos_skia` 暴露
MoonBit C exports；`moui/mobile/harmonyos` 的 canonical ArkTS
Stage Ability/XComponent shell 由构建器 staging，native XComponent callback
独占 surface/input/resize/detach。`examples/*/harmonyos_app` 仅为 Release N
fixture。

平台入口包可以依赖：

- `wzzc-dev/moui/runtime`
- `wzzc-dev/moui/backend/web`
- `wzzc-dev/moui/backend/host`
- `wzzc-dev/moui/backend/{macos,windows,linux,android,ios,harmonyos}`
- `wzzc-dev/moui/backend/{macos,windows,linux,android,ios,harmonyos}/skia`
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
  `examples/showcase`）按需直接依赖；不进入 `core`、`views` 或领域 facade 默认依赖。
- `moui_agent` / `moui_agent_mcp`：agent 协议、schema、host runtime 与 MCP router
  support addon，供 agent-controllable app（如 `examples/agent_counter`）按需直接依赖；
  不进入 `core`、`views` 或领域 facade 默认依赖。
- `moui_theme/*`：设计系统 addon，不进入 `core`、`views` 或领域 facade 默认依赖。

普通 app 默认依赖 `moui/<领域>`（按需）与 `moui/views`；直接依赖 `moui_richtext`、
`moui_agent*`、`moui_theme/*` 等 addon 仅在 app 明确需要该能力时才允许。直接依赖
`moui/core`、`moui/backend/host` 的普通 app 由 API surface guard 的 advanced-app
白名单约束（当前覆盖 `examples/markdown_editor/app`、`examples/mo_workbench/app`、
`examples/pdf_workbench/app`、`examples/showcase/app`、`website/app` 中的 core 导入，
以及 `examples/showcase/app` 的 runtime 导入）。

## 评审清单

新增依赖或公开 API 前，先回答这些问题：

- 这个 package 是普通共享 app、平台入口、测试，还是框架/控件实现？
- 普通共享 app 是否依赖 `wzzc-dev/moui`、`wzzc-dev/moui/<领域>`（按需）与 `wzzc-dev/moui/views`？
- 如果普通 app 直接 import `wzzc-dev/moui/core`，是否确实需要领域 facade 未覆盖的 kernel 类型（一等用法）？
- 如果普通 app import `wzzc-dev/moui/backend/host`，是否确实需要 host service 协议？
- 普通 app 是否错误依赖了 `runtime`、`render/*` 或平台 backend？
- 新增领域 facade alias 是否是平台中立、app-safe、高频使用的类型，且已更新 API surface guard？
- 新增低层 custom view helper 是否同时提供了 `moui/views` app-facing constructor？
- 新增控件是否避免向 `core` 添加具体控件 enum variant、primitive constructor 或 runtime lowering 分支？
- 新增 `core` API 是否真的是跨 runtime 的基础协议 / 抽象 UI kernel 能力？
- 新增 style、form、webview、routing、rich text editor、diagnostics API 是否更适合
  放在 `views`、`runtime`、`backend/host`、`moui_devtools` 或 addon？
- `moui_theme/*` 是否仍然只是 addon/preview 依赖，没有进入普通 app 默认依赖？

如果一个改动需要突破上述规则，必须在同一个变更中写明理由，并说明为什么它不是更适合放在 `views`、`runtime`、`backend` 或 `render` 的职责。

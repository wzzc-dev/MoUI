# 示例

MoUI 示例是可运行的文档。Showcase 是视觉目录，现在也采用与普通应用相同的
TEA 形态：由 `Program::simple_with_environment` 驱动的
`Model / Msg / update / view`。它仍然包含 Counter 和 Todo 交互模式。WYSIWYG
Markdown 编辑器保持独立，因为它展示的是更大的编辑工作流，并带有自己的模型和
解析器测试。需要 host-service 工作的应用应使用带 `Effect[Msg]` 的
`Program::new`；当 host-service 桥接需要携带稳定诊断键时优先使用
`ServiceTask::effect`，自定义结构化异步桥接使用 `Effect::run`，而类似服务的
一次性异步任务需要 runtime 管理取消、完成和过期 dispatch 诊断时使用
`Effect::service_task`。自定义任务类型使用 `Effect::task`。需要持续类型化回调的
应用可以添加 `subscriptions=model => ...` 和稳定的 `Subscription` 键，同时把具体
timer 或 host 适配器留在 `core` 之外。
Showcase 会优先呈现渲染器能力的后续项，这样可见文档不会把 partial 或 gap
状态藏在 ready 功能后面。专用的 `examples/design_systems/app` 包拥有 Material、
Carbon、Primer、Fluent 的 source-mapped 预览 UI，以及 Sickle 第一方主题附加包
采样器，因此 Showcase 保持为 MoUI framework 目录，不依赖 `moui_theme`。Sickle
位于 `moui_theme/sickle`，它是第一方主题附加包，而不是官方 source-mapped 预设。
Design Systems 是附加包诊断覆盖，提供 Web wasm-gc 以及 macOS、Windows、Linux Skia
入口，用于在 framework Showcase 之外试用附加包采样器。

当你想复制一种模式而不是检查完整示例包时，请使用[非渲染组件 cookbook](non-render-component-cookbook.md)。
它把表单、表格、shell、菜单、宿主服务、timer、剪贴板、窗口事件和虚拟列表映射到
覆盖它们的示例。如果需要一个可运行的单一界面，把这些宿主配方连同 canvas 绘制都
打包进去，请打开 Showcase 的 Platform 工作区。

开始新的共享应用包时，请使用 [App 模板](app-templates.md)。独立应用应使用
`moui new`（参见[入门](getting-started.md)）；文档骨架覆盖计数器、dashboard
和 document-editor 形态，适用于 monorepo 或手写包。根目录的 `website/` 工作区在
`examples/` 之外使用相同的 app-first 形态，因此 MoUI 可以渲染自己的双语主页。

移动端打包元数据位于 `moui.mobile.json`。应用代码仍放在
`examples/<app>/app`；Android、iOS 和 HarmonyOS 使用匹配的
`*_window_hosted` 入口以及 `wzzc-dev/window` templates。template 负责 native
lifecycle、surface creation 和 input，MoUI 入口负责 program 和 renderer provider。
修改移动端 host 路径后，请运行 `sh scripts/window-hosted-hostsim-smoke.sh`。

| 示例 | 用途 | 共享 app 包 | 主要覆盖 |
| --- | --- | --- | --- |
| Website | MoUI 构建的主页工作区 | `website/app/` | 双语产品主页、首屏 MoUI 品牌 hero、紧凑 Counter 代码片段、交互式运行时预览、框架基础、平台矩阵、release-readiness 卡片、Web 快速开始命令、运行时文档门户；该门户会获取打包后的同源 `docs/*.md` Markdown 以及 MoUI 和 `moui_skia` README 副本；还包含仅 Web 的 `website/web_wasm` 入口 |
| Playground | MoonBit 原生浏览器教程和编辑器 | `website/playground/app/`, `website/playground/web_wasm/` | 使用 `moui_richtext` 构建的代码编辑器、受控 `main.mbt`/`moon.pkg` 文件、应用安全 import 验证、固定版本 MoonBit 编译器 Worker 桥接、沙盒预览宿主、本地持久化、分享 URL 协议，以及六份双语课程资产 |
| Agent Counter | 最小 agent 可控制运行时示例 | `examples/agent_counter/`, `examples/agent_counter/main/`, `examples/agent_counter/macos_skia/` | 带有语义和命令意图流的 Counter 应用，用于 agent 观察和控制，另有原生 macOS Skia 入口 |
| Counter | 最小 model/update/view 应用 | `examples/counter/app/` | 简单 `Program::simple` 流程、`center`/`card`、类型化按钮消息，以及保留的 macOS/Web 入口 |
| Multi Window | 宿主管理的 scene 示例 | `examples/multi_window/app/` | 通过 `WindowActions`（`open` / `focus` / `close`）实现独立 main 和 inspector runtime，并配合 `WindowRequestQueue` 与 `WindowSceneResolver`；保留 macOS 和 multi-canvas Web route |
| HarmonyOS Demo | 平台中立 HarmonyOS 交互模型 | `examples/harmonyos_demo/app/` | viewport/tap feedback app model；canonical HarmonyOS composition 与设备证据统一由 Showcase 承担 |
| Button Freeze Probe | 原生 Skia button freeze 复现 | `examples/button_freeze_probe/app/` | 最小 `data_filter_bar` 过滤 chip、重复点击计数器、primary/tonal 按钮对比，以及保留的 macOS Skia 入口 |
| Showcase | 统一的组件、模式、平台和诊断目录 | `examples/showcase/app/` | 根 TEA shell；Components/Patterns/Platform 保持 app-safe，Diagnostics 接收中立 DTO，runtime/render 适配位于模块根集成包。Showcase 是唯一覆盖完整 14 路矩阵的示例。 |
| Design Systems | 附加包诊断用 source-mapped design-system 预览和第一方主题采样器 | `examples/design_systems/app/`, `examples/design_systems/{web_wasm,macos_skia}/` | 覆盖 Material、Carbon、Primer、Fluent、Sickle 主题预览、density/token diagnostics，以及保留的 Web/macOS 入口 |
| Settings | Settings shell 模式 | `examples/settings/app/` | 表单 section、侧边栏导航、分段主题模式、toggle 偏好，以及可保存状态的 snapshot/restore |
| Data Table | 面向操作型数据浏览器的模式 | `examples/data_table/app/` | 搜索/过滤 toolbar 模式、状态 chip、`ColumnVisibilityState`、带 `DataSortState` 的可排序表头、应用拥有的列宽/列顺序状态、带 `SelectionState` 的行选择、选择 toolbar 操作、树过滤器、loading/error/empty 状态、`PaginationState`、公开 `pagination` 和 `detail_panel`、model-level filtering 与 data slicing |
| Excel | Spreadsheet workbook 原型 | `examples/excel/{cell,formula,sheet,xlsx,app}/`, `examples/excel/macos_skia/` | 原生 `.xlsx` load/save、spreadsheet shell、formula/name bars、sheet tabs、编辑与 undo/redo，以及保留的 macOS Skia 入口 |
| File Importer | 文件导入工作流模式 | `examples/file_importer/app/` | Drop zone、typed `ServiceTask`、成功/失败/取消消息和 selected file list，不暴露 host request id |
| WebView Demo | 原生 platform WebView 模式 | `examples/webview_demo/app/` | 受控 `web_view` primitive、native host capability fallback、address bar、navigation commands、JavaScript evaluation command，以及 macOS Skia native entrypoint |
| DSH Desktop | 薄的 DeepSeek Harness WebView 宿主 | `examples/deepseek_harness_desktop/app/` | 为已有本地 Harness Host 提供原生 macOS WKWebView、Windows WebView2 和 Linux WebKitGTK surface，不复制 Web UI 状态；`Settings…`（`Cmd+,`）持久化根地址并用 MoUI 模态层覆盖 WebView；顶部 32 点支持 drag/no-drag |
| PDF Workbench | PDF 阅读和轻量编辑原型 | `examples/pdf_workbench/app/` | 简洁的原生 PDF reader/editor shell、host binary file service open/save flow、PDFium page bitmap preview、fit-width responsive reading canvas、scrollable page/inspector panels、reader fullscreen toggle、page navigation/direct page jump/search/metadata summaries、可 undo/可 discard 的 preview rotate/crop/stamp/title/bookmark/note edit state、用于真实 parsing/writeback checks 的独立 `pdflite_adapter` 包、JSONL pdflite helper protocol 加 native process transport、用于 page rasterization 的 native-only `pdfium_adapter` 包、macOS/Windows/Linux Skia native entrypoints |
| Command Palette | 命令元数据和菜单模式 | `examples/command_palette/app/` | Command palette rows、shortcut labels、enabled/disabled dispatch、command menu、context menu fallback、`program(environment)`，以及 `@services.MenuServices::show_context` native menu preview |
| Markdown Editor | Typora 风格编辑原型 | `examples/markdown_editor/app/` | Editor snapshot core、`mizchi/markdown` parsing、source-range mapping、primary rich text editor、可选 source preview |
| Code Editor | 原生代码编辑器 shell 和 language-provider 原型 | `examples/code_editor/app/` | 带 activity rail、file tab、line-number gutter、status bar、tokenizer-backed highlighting、bracket matching、auto indentation、multi-cursor edits、hidden find/replace overlay、runtime action-command shortcuts、completion overlay、diagnostics、hover、go-to-definition、main-editor Diff mode 的原生 `moui_richtext` editor shell，以及通过应用拥有 callbacks 注册的 custom language/provider |
| Mo Desktop | macOS 风格响应式桌面模拟 | `examples/mo_desktop/app/` | Lock/unlock session、image wallpaper、menu bar、live dock、calendar/weather/task widgets、带 navigation/search/icon-list modes/selection 的 responsive Finder、Safari start page 和 search results、可搜索 Apps/Actions launcher、notifications、Control Center toggles/sliders、全局 light/dark appearance、Web wasm-gc 和 macOS Skia 入口 |
| Mo Workbench | 以 Native-Skia 为优先的桌面 agent dogfood 应用 | `examples/mo_workbench/app/` | 受 DeepSeek-GUI 启发的多工作区 shell，包含 Code chat、starter cards、backend-aware OpenSeek/ACP controls、responsive left rail、optional right inspector、low-noise status bar、grouped Settings form、static Write/Connect Phone/Scheduled Tasks/Plugins surfaces、injected stub backend、OpenSeek native transport、generic ACP stdio native transport、macOS Skia native entrypoint |

聚焦 Website 检查：

```sh
moon test website/app --target native
moon build website/web_wasm --target wasm-gc
```

Website Docs 页面是 homepage 同一 MoUI 应用状态的一部分。它不会把 Markdown
预编译进 wasm；Web 宿主文本文件服务会在运行时从 `docs/` 获取选中的同源
Markdown 文件。进行本地预览时，运行 `node scripts/sync-website-docs.mjs`，让
`website/web_wasm/docs/` 包含根目录 docs，以及 `moui-readme.md` 和
`moui-skia-readme.md`。GitHub Pages workflow 会使用 `scripts/package-web-app.mjs`
打包 `website/web_wasm`，包含 release/strip wasm、本地运行时 JS、预压缩资产
和 `bundle-size.json`，然后运行
`node scripts/sync-website-docs.mjs --out dist/pages/docs`，使发布站点从 `docs/`
获取相同的 Markdown 路径。

`website/web_wasm` 入口附带静态降级视图(`fallback.js`)：不支持
WebAssembly 或缺少 wasm-gc 扩展的浏览器会看到 Canvas2D 品牌 hero、showcase
截图画廊和 docs 目录 / Markdown 阅读视图，而不是空白画布。检测逻辑对"完全
无 WebAssembly"使用同步判定，对"缺少 wasm-gc"使用
`WebAssembly.validate` 校验下载的 wasm；其余 Web 示例保持 fail-clearly 行为。

## Counter

Counter 是最小的推荐应用形态。它把用户代码保留在
`Model / Msg / update / view` 中，然后让 `Program::simple` 将这个纯模型循环连接到
runtime。它拥有 Web、macOS、Windows、Linux、实验性 Android 和 iOS Skia
embedded-session 入口、托管 Kotlin/SwiftUI 打包以及 `windows_wgpu`
入口，因此它也是无需完整 Showcase 界面即可验证薄平台包的
最快方式：

```moonbit
using @views {button, card, center, column, row, text}

pub struct Model {
  count : Int
}

pub(all) enum Msg {
  Increment
  Decrement
  Reset
}

pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    Increment => { count: model.count + 1 }
    Decrement => { count: model.count - 1 }
    Reset => { count: 0 }
  }
}

pub fn view(model : Model) -> @moui.View[Msg] {
  center(
    card(
      column([
        text("MoUI Counter").title(),
        text("Count: \{model.count}").title(),
        row([
          button("-", on_click=Decrement),
          button("Reset", on_click=Reset),
          button("+", on_click=Increment),
        ]),
      ]),
    ),
  )
}

pub fn program() -> @moui.Program[Model, Msg] {
  @moui.Program::simple(init=Model::new(), update~, view~)
}
```

聚焦 Counter 检查：

```sh
moon test examples/counter/app --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/counter/macos_skia --target native
```

fallback APK 和 `.app` 命令只验证打包路径。声明 Android 或 iOS 首帧运行时支持前，
需要匹配的 device 或 simulator smoke。

## HarmonyOS Demo

HarmonyOS Demo 只保留为平台中立的应用模型，提供可见的 tap 和 viewport 反馈。
独立平台 composition root 已退役；Showcase 是唯一 canonical HarmonyOS 路线，并拥有
window-hosted application。`wzzc-dev/window/harmonyos` template 拥有 Stage Ability 和
XComponent bridge。

聚焦 HarmonyOS Demo 检查：

```sh
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test examples/harmonyos_demo/app --target native
MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon check examples/showcase/harmonyos_window_hosted --target native
sh scripts/window-hosted-hostsim-smoke.sh
moui build harmonyos showcase \
  --mobile-config "$PWD/examples/showcase/moui.mobile.json" --fallback-skia
```

真实 HarmonyOS Skia 检查请使用锁定的 HarmonyOS release artifact：

```sh
MOUI_SKIA_PLATFORM=harmonyos MOUI_SKIA_ARCH=arm64 MOUI_SKIA_LINK_MODE=static \
  moon check examples/showcase/harmonyos_window_hosted --target native
```

HarmonyOS `auto` / `skia-gpu` 构建必须使用完整的 static provider。锁定的共享
`libskia.so` 可用于 raster rendering，但会隐藏 `libskia_ganesh_ext.a` 引用的
Ganesh 内部符号；dynamic linking 只能配合显式 `skia-raster` 使用。不设置
`MOUI_SKIA_LINK_MODE` 时，shell builder 会为 GPU 选择 static、为 raster 选择
dynamic。

fallback HAP 命令只验证 MoonBit C/native glue 和 staged package 形态。声明
HarmonyOS 首帧运行时支持前，需要匹配的 device/emulator smoke。

## Button Freeze Probe

Button Freeze Probe 会把原生 Skia click-freeze 调查从完整 Showcase 界面中隔离出来。
它只保留可复用的 `data_filter_bar` 搜索输入、已选过滤 chip、直接的 primary/tonal
按钮对比和一个小型点击/操作读数，因此重复点击会在没有 table、tree、pagination 或
renderer catalog 噪声的情况下覆盖同一个焦点输入、按钮 dispatch 和重绘路径。

聚焦 Button Freeze Probe 检查：

```sh
moon test examples/button_freeze_probe/app --target native
moon build examples/button_freeze_probe/macos_skia --target native
```

## Code Editor

Code Editor 是原生专用 editor shell。它不嵌入 Monaco 或 WebView；可编辑界面是
`moui_richtext.controlled_rich_text_editor`，并带有应用拥有的 editor chrome、代码
格式化和 language-service 状态。共享应用拥有源缓冲区、光标、隐藏的查找/替换 overlay、
补全 overlay、诊断、hover 结果、definition target、括号匹配状态，以及用于 review 和
patch inspection 的 main-editor Diff mode。

Language support 通过 `CodeLanguageRegistry` 和 `CodeLanguageProvider` callbacks
注册。Provider 提供 tokenizer、completion、diagnostics、hover 和 definition
callbacks，因此该示例演示了自定义语言注册，而无需把 app-specific language-service
API 移入 MoUI framework。应用把 shortcut metadata 声明为 typed
`ProgramCommand`；composition root 不安装直接修改应用状态的 callback。

聚焦 Code Editor 检查：

```sh
moon test examples/code_editor/app --target native
moon check examples/code_editor/macos_skia --target native
```

## WebView Demo

WebView Demo 展示原生 platform-view 路径，而不涉及渲染器绘制命令。共享应用拥有受控
导航状态：页面链接发出 `NavigationRequested`，model 更新 `url`，host 将真实 native
WebView commit 到下一个 `DrawFrame.platform_views` rectangle。按钮覆盖 host command
queue，用于 load、reload、stop、back、forward 和 JavaScript evaluation。

保留的 macOS 入口把 `HostWebViewCommandQueue` 传给平台 backend，使 `WKWebView` 可以在
rendering 后 drain commands。Windows WebView2 与 Linux WebKitGTK 继续作为 backend 能力，
由 backend tests 和 matching-host probes 覆盖，不再建立单独 demo composition root。

聚焦 WebView Demo 检查：

```sh
moon test examples/webview_demo/app --target native
moon check examples/webview_demo/macos_skia --target native
```

## DSH Desktop

DSH Desktop 是已有 DeepSeek Harness Web UI 的薄原生宿主，默认加载
`http://127.0.0.1:3080`。系统应用菜单中的 `Settings…`（`Cmd+,`）打开 MoUI
模态层，只编辑要加载的 DSH 根地址，不复制网页内部的 profile、导航或 API 设置。
地址和主题模式在 macOS settings 持久化成功后才应用；保存相同地址不会刷新。
主题模式提供“跟随系统 / 深色 / 浅色”三种选择。解析后的主题背景会随 platform placement
传给原生 WebView，并在导航开始前设置 WebView 承载面的背景色，避免浅色系统配深色 Chat
时出现白色闪屏，或深色系统配浅色页面时出现黑色闪屏。网页内容不会通过注入 JavaScript
强制改主题。
在 macOS 上还会把解析后的模式设置为 WKWebView 原生的 Aqua / Dark Aqua 外观，因此应用
显式选择深色时，即使系统是浅色，WebKit 自己的加载承载面也会使用深色。

共享 app 只提供 WebView surface 和 native-unavailable fallback；macOS、Windows、Linux
composition root 分别接入 WKWebView、WebView2、WebKitGTK plugin，并选择 Skia provider
route。模态层打开时，透明 Skia presenter 位于全窗口 WKWebView 上方，WebView 保持可见
但不接收点击；关闭后恢复 WebView 层级和输入。Skia auto 路由优先使用 GPU surface，
不可用时回退 CPU raster，两种 presenter 都支持该层级切换。该能力只承诺全窗口原生
WebView 上的 MoUI 模态覆盖，不代表任意 native view 与普通 MoUI 内容交错。

```sh
moon test examples/deepseek_harness_desktop/app --target native
moon check examples/deepseek_harness_desktop/macos_skia --target native
moon check examples/deepseek_harness_desktop/windows_skia --target native
moon check examples/deepseek_harness_desktop/linux_skia --target native
```

Showcase 按主目录顺序组织：
`Overview -> Examples -> Text & Media -> Controls -> Forms -> Data -> Layout ->
Navigation Shell -> Feedback -> Runtime/Renderer -> Diagnostics`。前九个 section
覆盖面向用户的组件和布局模式。`Runtime/Renderer` 显示 host capability 和 renderer
status cards。`Diagnostics` 展示紧凑的 inspector snapshot，包含 runtime、TEA program
message/effect task/subscription、duplicate key names、view、layout、semantics、
render command 和 render-scope counters，然后链接到更深的诊断路由，用于 interaction
wiring、text diagnostics 和 advanced rendering，
而不会挤占主 sidebar。

隐藏的 diagnostic routes 仍然可以直接访问，用于聚焦测试和开发工作流：

- `Advanced Rendering`：app-local `custom_layout` demo，用于 layer/blend、
  filter、shader effect、path、transform 和 opacity draw commands。
- `Text Diagnostics`：CJK 混排文本、RTL/bidi 样例、emoji 状态标签、定宽换行、窄
  `TextRun.frame` clipping sample，以及紧凑的 Markdown/rich text diagnostic。
- `Interaction Lab`：tooltip、file-drop modifier wiring、FocusScope traversal、
  first-invalid targeting、Enter/Escape command targets、shortcut affordances、runtime
  `View::focus_trap` containment、公开 `shortcut_button` dispatch、应用拥有的
  `focus_ring` affordances、popover/dropdown expanded semantics、
  pressed/selected/disabled semantic state examples、button/text-field variants，以及
  deterministic image lifecycle states。
- `Forms`：validating/help/error/disabled/read-only field states、带 key 的
  first-invalid focus targets，以及 form workflow bar 的 submit-guard state。
- `Navigation Shell`：route headers、section navigation、breadcrumbs、dialogs、sheets、
  command metadata、应用拥有的 route/deep-link history、受控 fade/slide route transition
  preview、受控 drag-resizable split pane，以及 `RouteFocusStore` state；它显示 route
  switch 后哪个 `runtime.focus_key(...)` 调用应恢复 route focus。`@services.RouteSource` 提供
  host-layer route/deep-link subscription fanout，应用可以把它送入这个共享状态，但可见
  route history 仍然是可序列化的 shadow stack，transition 仍由 app state 采样；browser
  history、automatic route-transition scheduling 和 native deep-link dispatch 仍是 host/app
  follow-up work。
- `Feedback`：toast/banner/callout/progress/inline-error surfaces，以及一个
  `ToastQueue` 示例，它把 queued items 转换为 `toast_stack` rows，同时把 timer 保留在
  app model 中。
- `Examples`：Counter 和 Todo 可复用应用模式，直到专用示例应用覆盖这些工作流。

Markdown 编辑器把 Markdown source 作为保存值，同时把格式化 editor surface 作为主工作流。
source preview 仍可从 toolbar 打开。有关编辑模型、source/visual mapping、上下文命令和
验证指引，请参见 [Markdown Editor](markdown-editor.md)。

## Settings

Settings 示例是没有平台入口的共享应用包。它展示 account preferences 推荐的 non-render
shell：公开 sidebar constructor 驱动受控 section selection，form field 在 app model
中拥有 validation messages，segmented control 选择 light/dark/system theme mode，
`SaveableStateStore` snapshot 可在没有 host service 的情况下恢复当前 settings。

## Data Table

Data Table 示例同样只有共享应用。它建模操作型工具通常在渲染器专属打磨之前需要的数据
工作流：受控搜索/过滤 toolbar、状态 chip、列可见性、应用拥有的列宽和顺序控制、可排序
表头、树过滤器、稳定的 model-level sorting、分页导航、选中行详情，以及由公开
`views` constructor 构建的 empty/loading/error panel。
该应用把 filtering、sorting 和 page slicing 保存在它的 TEA model 中，同时使用公开
`DataSortState`、`PaginationState`、`ColumnVisibilityState`、`ColumnWidthState`、
`ColumnOrderState`、`SelectionState`、`data_filter_bar`、table sort-header、
row-selection、`column_visibility_panel`、`selection_toolbar`、`pagination` 和
`detail_panel` helper 来形成可复用 view structure。Filter predicates、async requests、
pointer-specific header gestures、column width/order persistence 和 bulk action effects 仍由
应用拥有。

## Excel

Excel 示例是原生 spreadsheet-workbook 原型。应用包拥有 MoUI 应用、TEA messages、
host-service file effects 和 command map，而应用私有的 `cell`、`formula`、`sheet`
与 `xlsx` 包拥有 cell coordinates/value formatting、formula evaluation、pure workbook
operations 和 `mbtexcel` import/export。可见界面有意以桌面 spreadsheet 为先：分组的
file/edit/format/number/view 控件、formula 和 cell-reference 输入、可滚动网格、底部
sheet tabs、状态栏、颜色 swatch、数字格式以及 heat-map display。

聚焦 Excel 检查：

```sh
moon test examples/excel/cell --target native
moon test examples/excel/formula --target native
moon test examples/excel/sheet --target native
moon test examples/excel/xlsx --target native
moon test examples/excel/app --target native
moon check examples/excel/macos_skia --target native
```

## File Importer

File Importer 示例展示 non-render 文件工作流界面。view 使用 `drop_zone` 和
`file_import_panel`；pure model 接受 dropped paths，而具备 effect 能力的 runtime 使用
`Program::new` 和 `ServiceTask::effect`，通过 `AppServices` 请求 app-level file dialog，
并把 `Success`、`Failure` 或 `Cancelled` 作为 typed message 送回。同一个 task lifecycle
负责 pending callback 的取消和 stale completion 拒绝，业务 model 不保存 host request id。
它的 app tests 还会把 importer 组合为 child feature，使用 `View::map` 和 `Effect::map`；
parent runtime assertions 让 mapped child effect descriptor 与 task lifecycle diagnostics
保持可见。
Browser hosts 通常暴露文件名，而 native hosts 可以暴露文件系统路径，因此生产应用应把
这些字符串视为 host-provided display 或 import handles，而不是假定某一种 platform shape。

## PDF Workbench

PDF Workbench 是 MoUI example-level PDF reader 和 light editor。它的共享应用包有意作为
轻量 UI shell，使 native Skia 入口不会把完整 PDF parser 拉进一个巨大的 generated C
translation unit。应用通过 TEA effects 保持 host 交互：open 使用 file dialog 后接
`AppServices::files().read_bytes`，save 和 save-as 通过
`AppServices::files().write_bytes` 写入；save-as 默认把 dialog name 设为当前 PDF
file name，并在 source path 没有 `.pdf` suffix 时追加 `.pdf`。Clean documents 会写出
未改变的 original bytes，而 dirty documents 会在写入前向注入的
`PdfWorkbenchDocumentServices` writeback hook 请求新的 PDF bytes。Dirty save 成功后，
应用会通过相同 document service 重新加载已写入 bytes，使 clean snapshot、metadata、
page summaries 和 queued diagnostics 反映实际保存的 PDF，而不是过期 preview state。
Preview edits 会作为应用拥有的 edit log 跟踪，并带有 clean snapshot，因此用户可以
undo 最后一项 queued edit，或在保存前 discard queued changes。右侧 inspector 会把这些
controls 分组为 Page、Queue、Document 和 Diagnostics sections：page operations 保持靠近
undo/discard，queued edits 显示为紧凑 rows，saved/unsaved badge 和 zoom percentage 保持
可见，而 parser/raster/writeback diagnostics 与主要 editing actions 分离。
当前 pdflite adapter 会应用 rotate/crop edits，把 stamp text 作为 standard-font overlay
写回，更新 PDF Info dictionary title，添加 current-page bookmarks，并在保存 dirty
documents 时写入 current-page text annotations。
Reader shell 是响应式的：宽窗口并排显示 thumbnails、page canvas 和 inspector，而较窄
窗口会隐藏 side panels，使 PDF bitmap 保持为主要可读界面。page toolbar 也可以把 reader
切换到 fullscreen window-filling mode，隐藏 app chrome 和 side panels，直到用户退出。
page toolbar 包含 previous/next、direct page jump、zoom in/out，以及返回 fit-width
`100%` baseline 并在可用时复用 raster cache 的 `Fit` action。search field 暴露
previous/next hit controls 和紧凑的 active match-position label，例如 `Find: 2/5`；
打开新 PDF 会清除过期 search state，因此 results 始终指向当前 document。
当 inspector 被隐藏时，page surface 会保留紧凑 edit strip，用于 rotate、crop、stamp、
undo 和 discard，让轻量编辑在 reader-first layout 中仍可使用。

`examples/pdf_workbench/pdflite_adapter` 拥有直接的 `bobzhang/pdflite` 依赖，用于真实
PDF parse/text/outline/annotation summary 和 rotate/crop/stamp/title/bookmark/note
writeback checks。它目前保留在默认 native Skia 入口之外，因为把 pdflite 直接 import 到
app executable 会触发 prototype 正在避免的同一个大型 native compile path。
`examples/pdf_workbench/pdflite_service_protocol` 包把该边界定义为类型化 load/writeback
requests 加 JSONL-safe responses。Request/writeback PDF bytes 使用 base64 payload fields，
document-loaded responses 则携带可重建的 metadata、outline、annotation、page-summary、
diagnostic 和 page-count fields，而不会回显 original PDF bytes。
`examples/pdf_workbench/pdflite_service_native_transport` 包通过为每次 load/writeback request
spawn 一个 helper process，把这个 JSONL protocol 转成 `PdfWorkbenchDocumentServices`，
因此 native Skia 入口可以保持很薄，并避免直接 import pdflite。helper executable 本身仍可能有
较慢的首次 native compile，因为它有意包含 pdflite；这个成本与 PDF Workbench UI binary 隔离。
`examples/pdf_workbench/pdfium_adapter` 拥有 native-only PDFium C FFI，用于 existing-page
rasterization。共享应用只依赖注入的 document/raster service interfaces，因此 Web 和
app-package tests 仍能在没有 pdflite 或 PDFium 的情况下构建，而 native Skia 入口传入
PDFium raster service。它的聚焦 native test 覆盖 fallback-unavailable behavior，并且在
PDFium linked 时覆盖真实 BMP output，包括预期 page dimensions、32-bit pixel metadata、
file-size consistency，以及渲染 generated multi-page PDF 的 page 2。

当 PDFium linked 时，打开 PDF、翻页、直接跳页或缩放都会请求 bitmap raster，preview 会用
带 local BMP source path 的 MoUI `DrawImage` 绘制它。共享应用为 page/zoom combinations
保留一个小型 most-recently-used raster cache，因此回退查看保持快速，而不会无限增长
bitmaps，Pages sidebar 也会复用 cached page bitmaps，为 reader 已访问过的 pages 显示真实
thumbnails。如果 PDFium disabled 或 rendering fails，应用会保留已加载 document，回退到
structural MoUI preview 加 diagnostics，并显示可关闭的 failure banner。Skia PDF backend
保留给未来将 MoUI draw commands 写成 PDF 的 export/generation route；它不用于 rasterize
existing PDF pages。
交互式启动运行时，将 `MOUI_PDF_WORKBENCH_STARTUP_PDF` 设为 PDF path，例如
`examples/pdf_workbench/fixtures/minimum.pdf`；startup path 使用与 Open button 相同的
binary-read、document-load 和 PDFium raster request flow。
`node scripts/pdf-workbench-native-smoke.mjs` 把自动检查限定为 PDFium real-raster tests 加
native entrypoint builds。
当你希望 native Skia runs 使用真实 pdflite document model 时，把
`MOUI_PDF_WORKBENCH_PDFLITE_HELPER` 设为已构建的 `pdflite_service_cli` executable。要从
仓库根目录指向 `_build/native/debug/build/examples/pdf_workbench/pdflite_service_cli/`
下的约定 native debug helper path，请使用
`MOUI_PDF_WORKBENCH_PDFLITE_HELPER=auto`。
`MOUI_PDF_WORKBENCH_PDFLITE_HELPER_ARGS` 可以是 whitespace-separated argument string 或
JSON string array，`MOUI_PDF_WORKBENCH_PDFLITE_HELPER_CWD` 设置 helper working directory，
用于 fixture 或 packaged-app smoke runs。helper variable 不存在时，入口会保持 lightweight
document summary fallback，但仍使用 PDFium 绘制 page bitmaps。

聚焦 PDF Workbench 检查：

```sh
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/app --target native --filter 'pdf workbench lightweight smoke covers startup raster navigation search and cache'
moon test examples/pdf_workbench/app --target wasm-gc
moon test examples/pdf_workbench/pdflite_service_protocol --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target wasm-gc
moon test examples/pdf_workbench/pdflite_service_native_transport --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
MOUI_PDFIUM_ENABLE_PREBUILD_PDFIUM=1 moon test examples/pdf_workbench/pdfium_adapter --target native
moon test moui/backend --target native
moon build examples/pdf_workbench/macos_skia --target native
node scripts/pdf-workbench-native-smoke.mjs
scripts/pdf-workbench-macos-smoke.sh
MOUI_PDF_WORKBENCH_STARTUP_PDF=examples/pdf_workbench/fixtures/minimum.pdf moon run examples/pdf_workbench/macos_skia --target native
```

PDFium provider 是 module-level prebuild hook，但默认不会下载 PDFium。仅在真实 raster
adapter validation 时设置 `MOUI_PDFIUM_ENABLE_PREBUILD_PDFIUM=1`，或提供
`MOUI_PDFIUM_INCLUDE` 加 `MOUI_PDFIUM_LIB_DIR` 来使用本地 PDFium install。
命名的 lightweight smoke 使用 fake document 和 raster services，覆盖 startup open、bitmap
drawing、multi-page navigation、search、zoom 和 raster cache reuse，而无需编译 pdflite
helper executable。
`node scripts/pdf-workbench-native-smoke.mjs` 是 matching-host real-raster smoke。它运行
PDFium adapter tests，构建当前 host 的 native Skia entrypoint，并验证 log 包含 PDFium bitmap
path。
`scripts/pdf-workbench-macos-smoke.sh` 是同一 runner 的 macOS convenience wrapper。

## Command Palette

Command Palette 示例把 command definitions 保存在 `@views.ActionCommand` metadata 中，
通过公开 palette 和 command menu views 渲染它们，并使用 `@views.ActionCommandMap` 进行
shortcut dispatch。Disabled commands 保持可见以便 discoverability，但不会通过 model actions
或 runtime command bindings dispatch。它具备 effect 能力的 `program(environment)` 路径展示了
`@services.MenuServices::show_context`，把选中的 native menu command 通过同一个类型化 message
loop dispatch 回来，同时为没有 native menu support 的 hosts 保留 view-level fallback context
menu。

## Mo Desktop

Mo Desktop 是受 macOS 27 reference 启发的平台中立 desktop simulation。它从 full-screen lock
surface 开始，解锁后进入带持久 menu 和 dock chrome 的 layered desktop。Finder 是主要 workspace；
Safari、app launcher、Control Center 和 Notification Center 共享同一个类型化 model 和 update
path。窄 viewport 会隐藏 decorative widgets，把 Finder sidebar 折叠成 location tabs，并让 dock
和 overlays 保持在可用 canvas 内。

该示例有意实现一组较小但可工作的 apps 和 system surfaces，而不是渲染 inactive dock
placeholders。Finder navigation、search、view modes 和 selection 是受控的；Safari 支持 start
page 和 query results；Control Center 拥有 appearance、connectivity、brightness、volume 和
battery preferences；Notification Center 拥有 read state 和 task completion。

聚焦检查：

```sh
moon test examples/mo_desktop/app --target native
moon test examples/mo_desktop/app --target wasm-gc
moon build examples/mo_desktop/web_wasm --target wasm-gc
moon build examples/mo_desktop/macos_skia --target native
```

## Mo Workbench

Mo Workbench 是以 native-Skia 为优先的桌面 agent dogfood 应用。当前共享应用包是受
DeepSeek-GUI 启发的平台中立 multi-workspace shell：左侧 workspace rail、中央 work surface、
topbar controls、可选 right inspector 和 low-noise status bar。Code 是目前唯一交互式 agent
workspace；它默认使用注入的 `AgentBackendRuntime` stub，而 macOS Skia 入口可以从 settings 中
选择 OpenSeek backend 或 generic ACP stdio subprocess backend。

当前 workspaces 包括：

- **Code**：session history、message timeline、starter cards、model/thinking controls、
  prompt composer、streaming 期间的 steering，以及 plan、todo、changes、context 的固定
  inspector cards。
- **Write**：产品形态的静态 Markdown editor/assistant shell。它还不会保存文件或调用
  completion services。
- **Connect Phone**：用于未来 IM 和 webhook automation 的静态 channel/timeline setup shell。
- **Scheduled Tasks**：用于未来 scheduled prompts 的静态 task cards 和 defaults panel。
- **Plugins**：用于未来 Skills/MCP/Web tool management 的静态 capability summary。
- **Settings**：用于 backend selection、OpenAI-compatible provider settings、ACP
  command/args/cwd、working directory、approval policy、sandbox mode 和 font size 的 runtime
  与 permission preferences。

ACP backend 把 stdio JSON-RPC 实现为 ACP client/control side。它支持 baseline session
creation、prompt turns、cancellation、session updates、mode/config updates 和 permission
requests。它在这个 slice 中有意不宣告任何 client filesystem 或 terminal capability。

当前 slice 的聚焦检查：

```sh
moon test examples/mo_workbench/app --target native
moon test examples/mo_workbench/acp_native_transport --target native
moon test examples/mo_workbench/app --target wasm-gc
moon build examples/mo_workbench/macos_skia --target native
```

有关 app architecture、current slice、connector boundary 和 transport follow-up notes，请参见
[Mo Workbench](mo-workbench.md)。

## Web Wasm-GC

从仓库根目录构建任意 Web 示例，然后用本地 static server 提供仓库内容：

```sh
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/mo_desktop/web_wasm --target wasm-gc
moon build website/web_wasm --target wasm-gc
python3 -m http.server 8080 --bind 127.0.0.1
```

从本地 server 打开对应的 `examples/*/web_wasm/index.html` 页面，或为 homepage/docs
workspace 打开 `website/web_wasm/index.html`。Web 路径使用
`wasm-gc + window/web + browser WebGPU host imports`；没有 JS-target fallback。测试
Website Docs 时请从仓库根目录 serve，这样 browser 可以通过 relative path 获取静态
`docs/*.md` 文件。

对于 release-size checks 和 packaged Web artifacts，使用：

```sh
node scripts/web-bundle-size.mjs examples/counter/web_wasm --json
node scripts/package-web-app.mjs examples/counter/web_wasm --out artifacts/web/counter
```

package helper 会输出 release/strip wasm、MoUI Web runtime JS、预压缩 `.gz`/`.br` siblings、
`bundle-size.json`，以及 Web 入口 `assets/` 目录下的所有文件。请把大型 app resources 放在
MoonBit source 之外：小 constants 可以留在代码中，但大 images、长 Markdown、大 JSON 和
fixtures 应位于 `assets/` 下，并通过 `assets/logo.png` 或 `assets/story/buttons.json` 等
relative URLs 引用。Web text/Markdown/JSON loads 必须保持 same-origin；browser host 会拒绝
cross-origin text-file fetches。

## macOS 原生

macOS 示例使用共享应用包、`backend/macos` 和显式 renderer 包。推荐的 `_skia` 入口导入
`moui_skia_renderer`，并通过 `@runtime.run_app` 与 `@macos.entry()` 组合：

```sh
moon build examples/showcase/macos_skia --target native
moon build examples/markdown_editor/macos_skia --target native
moon build examples/pdf_workbench/macos_skia --target native
moon build examples/mo_desktop/macos_skia --target native
moon build examples/mo_workbench/macos_skia --target native
```

`macos_skia` 入口会显式选择 native Skia raster renderer。它们需要本地 Skia native link setup，
让 `moui_skia/native` 在 runtime 可用。常规 macOS Skia 运行使用 renderer 的 system
`FontMgr` 路径；tester-owned first-frame smoke runs 会显式选择 `EmptyTypeface` fallback
path。唯一 `macos_wgpu` 路线使用 CoreText，并把 Cosmic 作为内部 fallback。

配置真实 Skia link flags 后，运行 opt-in real Skia check，验证 binding smoke 和 MoUI renderer
presenter pixels：

```sh
scripts/macos-skia-renderer-smoke.sh
```

在 macOS 上，下面的 helper 会解析固定的 JetBrains Skia binary provider，临时把得到的
include/library paths 接入 `moui_skia`、MoUI renderer smoke、Showcase、Markdown Editor 和
Mo Workbench `macos_skia` 包，然后运行 renderer pixel smoke 并构建 Showcase 入口：

```sh
scripts/macos-skia-renderer-smoke.sh
```

当选中的 Skia binary 也提供 SkShaper module libraries 时传入 `--enable-skshaper`；helper 随后会
验证 MoUI renderer smoke 在 optional shaped-run path 可用的情况下运行。

直接本地 `moon run` 命令使用 `moui_skia` prebuild hook，因此签入的包不需要 machine-local path
rewrites。在 `moon run` 前设置 `MOUI_SKIA_LINK_MODE=dynamic|static|auto`，以选择 Skia library
mode。Helper smoke runs 仍可以用 `--link-mode dynamic|static|auto` 覆盖该次调用的环境。
HarmonyOS 的约束更严格：`auto` / `skia-gpu` 必须解析为 static，dynamic 只支持显式
`skia-raster`。

如需更完整的本地 smoke，请传入 `--run-showcase-smoke`。helper 会构建 Showcase，然后运行
未发布 `moui_tests` 模块中的 first-frame smoke。添加 `--run-markdown-smoke` 会构建 Markdown Editor，并运行同一个
内部 first-frame marker：

```sh
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
```

已有本地 Skia build 时，使用 `--skia-provider existing`：

```sh
scripts/macos-skia-renderer-smoke.sh \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

运行你构建的示例在 `_build/native/debug/build/...` 下生成的 executable。如果 `moon run` 暴露
linker issues，请使用 `platform-notes.md` 中描述的 build-and-execute flow。

要把示例包装成本地 `.app` bundle：

```sh
sh scripts/package-macos-app.sh \
  --package examples/showcase/macos_skia \
  --name "MoUI Showcase" \
  --bundle-id dev.wzzc.moui.showcase \
  --version 0.1.0
```

bundle 包含并验证 schema version 1 `Contents/Resources/moui-package.json` manifest，因此可以在
不解析 `Info.plist` 的情况下检查本地 packaging output。

## Windows 原生

Windows 原生示例使用 MSVC toolchain 和 vcpkg `zlib:x64-windows`。推荐的 `_skia` 入口导入
`backend/windows` 与 `moui_skia_renderer`，并通过 `@runtime.run_app` 显式组合它们。Showcase
`windows_wgpu` 是唯一 canonical native WGPU diagnostic；build/package helper 只为该
WGPU 路线下载并打包 `wgpu_native.dll`。

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -BuildOnly
```

要直接运行入口，请在同一个 PowerShell process 中 import MSVC environment：

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\scripts\windows\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
```

`windows_skia` 遵循 renderer provider 的 Skia availability rules：如果
`moui_skia/native` 只处于 fallback mode，renderer creation 会报告 diagnostic，而不是打开空
HWND。
Windows Skia 示例入口是 interactive app entrypoints。请把 matching-host first-frame smoke 放在
tester/backend smoke runners 中，并引用实际运行过的 smoke log。

要生成包含已构建 executable 和 runtime DLLs 的可复用 distributable folder：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -AppName MoUIShowcase `
  -Version 0.1.0
```

package 会写入 `dist\windows-msvc\MoUIShowcase`，并包含 schema version 1
`moui-package.json`、`run.cmd` 以及 selected renderer 所需的 runtime DLLs。Skia packages 会省略
`wgpu_native.dll`；WGPU diagnostic packages 会包含 WGPU release metadata，并通过 `run.cmd` 设置
`MBT_WGPU_NATIVE_ROOT`。

## Linux 原生

Linux 示例使用 `wzzc-dev/window@0.5.4-0.1.5` Wayland host core。推荐的原生入口导入
`backend/linux` 与 `moui_skia_renderer`，通过 AppBuilder 组合后由中立 Wayland `wl_shm` presenter
呈现 Skia CPU pixel frames。请在已配置
Wayland compositor 和真实 Skia link flags 的 Linux host 上运行：

```sh
moon run examples/showcase/linux_skia --target native
```

Linux Skia 示例入口是 interactive app entrypoints。请把 matching-host first-frame smoke 放在
tester/backend smoke runners 中，并让这些 logs 与 window package dependency smoke logs 分开。

对于 build-only validation，请使用：

```sh
moon build examples/showcase/linux_skia --target native
```

Showcase `linux_wgpu` 是唯一 canonical native WGPU diagnostic，使用 fontconfig provider，
并把 Cosmic 作为内部 fallback。Showcase `linux_skia` 是唯一 Linux Skia composition root；
在依赖 Skia-rendered pixels 前，请先配置真实 Skia link flags。

## 示例验证

对共享应用逻辑使用 package-level tests，对 browser entry points 使用 Web builds：

```sh
moon test examples/showcase/app --target native
moon test examples/counter/app --target native
moon test examples/settings/app --target native
moon test examples/data_table/app --target native
moon test examples/excel/cell --target native
moon test examples/excel/formula --target native
moon test examples/excel/sheet --target native
moon test examples/excel/xlsx --target native
moon test examples/excel/app --target native
moon test examples/file_importer/app --target native
moon test examples/pdf_workbench/app --target native
moon test examples/pdf_workbench/pdflite_service_protocol --target native
moon test examples/pdf_workbench/pdflite_adapter --target native
moon test examples/pdf_workbench/pdfium_adapter --target native
moon test examples/command_palette/app --target native
moon test examples/markdown_editor/app --target native
moon test examples/mo_desktop/app --target native
moon test website/app --target native
moon build examples/counter/web_wasm --target wasm-gc
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
moon build examples/mo_desktop/web_wasm --target wasm-gc
moon build website/web_wasm --target wasm-gc
node scripts/web-bundle-size.mjs examples/counter/web_wasm --json
```

修改平台入口前，请包含受影响 host package tests 和当前平台示例 builds。

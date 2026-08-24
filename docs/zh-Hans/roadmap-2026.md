# MoUI 2026 路线图

MoUI 正在从 MoonBit 多平台 GUI 原型演进为可用、可维护的跨平台声明式 UI 框架。本路线图让项目聚焦于实际应用构建、显式平台 contract，以及清晰的工程质量门禁。

## 2026 目标

- 为 MoonBit UI 应用提供稳定的平台无关 app/runtime/view model。
- 通过返回不透明 `@moui.View[Msg]`，让公开 view 构造器保持简单且有类型。
- 在受支持平台上，让同一套共享应用逻辑运行于 Web wasm-gc/browser WebGPU，以及 macOS 和 Windows 的 native Skia raster 入口点。
- 让示例作为可运行文档发挥作用，而不只是 smoke test。
- 保持渲染器能力透明、已测试并有文档。
- 用有界检查和聚焦测试维护可预测的开发循环。
- 记录 AI 协作工作流，让生成的变更保持可审查，并与架构一致。

## 架构承诺

MoUI 保持 runtime 管线显式：

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

包边界遵循这条管线：

- `core/` 拥有平台无关 contract、不透明 `View[Msg]`、typed event、effect、subscription、layout/input/semantics/draw contract，以及由类型化 adapter 包裹的公开、与消息无关的 `ViewNode` 扩展协议。
- `runtime/` 拥有不透明 `AppRuntime`、runtime state、tree/layout/paint、event dispatch、program message drain、effect-task lifecycle、subscription lifecycle 和 runtime diagnostics。
- `views/` 暴露返回 `@moui.View[Msg]` 的公开 facade 构造器。
- `backend/` 定义共享 host contract。
- `backend/web/` 是 browser wasm-gc host。
- `backend/macos/`、`backend/windows/` 和 `backend/linux/` 是 native host core，它们把平台 event 规范化为 `Event`，并通过平台 renderer provider 接收具体渲染器。
- `moui_skia_renderer` 拥有 native Skia 主线 providers；`moui_wgpu_renderer` 保留显式 native WGPU diagnostics，应用将其与一个平台 backend 组合。
- `backend/linux/` 是 Wayland host core，runtime-evidence、IME、clipboard、file dialog、directory listing、accessibility 和 async image loading 都通过匹配主机 CI provider 接线。
- `render/` 拥有 renderer facade 和能力报告。
- `moui_skia_renderer/` 实现 native Skia raster renderer facade。
- `moui_wgpu_renderer/` 实现实验性 native wgpu renderer。
- `moui_web_renderer/` 将 wasm-gc 应用桥接到 browser WebGPU host import。
- `examples/*/app/` 包包含共享应用逻辑；平台子包只作为入口点。

## 工作流 1：Runtime 与公开 API

重点领域：

- 稳定用于直接静态 view 的 `AppRuntime::new_view`，以及作为默认 typed app runtime 的 `AppRuntime::new_program`。
- 在 component build 期间保持 `ComponentContext::watch` 和 `ctx.binding` 作为首选状态访问模式。
- 使用 `ComponentContext::run_effect` 处理 component-scoped effect 和 cleanup，并用 scoped save/restore helper 保存少量可保存字符串状态。
- 通过公开 `View[Msg]` modifier 保留有序 modifier 语义。
- 保持 `@views.custom_children_layout` 作为 package-local custom control 和 layout experiment 的高级 child layout delegate。
- 将 input、focus、text editing、layout、paint 和 semantics 行为保留在平台无关包中。
- 用 `moon info` 和生成的 `pkg.generated.mbti` diff 审查公开 API 变更。

component effect、saveable string/bool/int state、custom child layout delegate 和 keyed effect reuse 的首批 P0 基础现在已经存在。后续工作应把 saveable state 扩展成通用 codec model，增加超出当前 `on_mount`/`on_dispose` helper 的更丰富 lifecycle 覆盖，并用 layout cache 和 alignment guide 扩展 custom layout protocol。Custom layout 已经接收 child baseline 和 layout priority signal。

验证：

```sh
moon test moui/core --target native
moon check --warn-list +unnecessary_annotation
moon info
```

## 工作流 2：Views 与应用可用性

重点领域：

- 保持 Text、Button、TextField、Checkbox、Container、Row/Column/Flex、Stack、Scroll、List、Grid、Navigation 和 Markdown Editor 可用于真实应用。
- 公开构造器优先采用 MoonBit 风格的 labeled 和 optional 参数。
- 尽可能为交互控件添加 semantics。
- 维护 view catalog，记录 API 示例、theme support、semantics、tests 和 example coverage。
- 使用 Showcase 作为 controls、layout、theme 和 renderer capability status 的视觉索引。
- 新增用户可见框架功能时，优先提供 Showcase 覆盖。当新的 view、renderer capability、host-service interaction 或可检查的平台行为落地时，除非该功能更适合只通过聚焦测试或平台文档验证，否则应添加可见 Showcase 示例和 app-level assertion。

验证：

```sh
moon test moui/views --target native
moon test examples/showcase/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
```

## 工作流 3：实用示例

示例应展示框架中逐步扩大的切片：

| 示例 | 目的 | 共享应用包 | 主要能力 |
| --- | --- | --- | --- |
| Showcase | 视觉系统索引 | `examples/showcase/app/` | Controls、layout、theme、renderer features、Counter/Todo patterns |
| Markdown Editor | 实用编辑演示 | `examples/markdown_editor/app/` | Rich text editing、styled runs、app-level parsing |

示例工作应把业务逻辑保持在 `examples/*/app/` 中，并让平台包保持为轻薄入口点。

Showcase 是框架新增内容的默认可见验证 surface。影响 app author 可见或可操作内容的新功能，在可行时应在此体现，让发布交接可以将聚焦测试与可检查示例配对。

验证：

```sh
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
moon build examples/showcase/web_wasm --target wasm-gc
moon build examples/markdown_editor/web_wasm --target wasm-gc
```

## 工作流 4：渲染器能力跟踪

渲染器功能状态在代码和文档中跟踪：

- `render/capabilities.mbt`
- `render/capabilities_test.mbt`
- `docs/renderer-capability-report.md`
- `docs/feature-proof-matrix.md`（功能到 CI 证明映射）
- `docs/feature-status-dashboard.md`（证明覆盖看板）

当 image、clip、opacity、transform 或其他 draw command 支持变化时，同时更新所有五个文件。

当前优先事项：

1. 在 native Skia raster 主线和 Web wasm-gc/WebGPU 渲染器之间保持 transform 行为显式且一致，同时让 native WGPU transform diagnostics 在显式实验路径下保持可用。
2. 完成 bidi、line breaking、fallback font run 和 native provider behavior 的 text shaping conformance。
3. 持续改进 deterministic emoji text 覆盖；Cosmic 现在会在可用时加载平台 emoji fallback font candidate，并通过 provider-safe mapped native layout path 为代表性 emoji cluster 保持 caret coverage，而跨所有 provider 的完整 native emoji font fallback 和 ZWJ/color emoji conformance 仍是已知 gap。
4. 将 async image cache 和 load diagnostics 暴露到应用可见的 renderer state。
5. 保持 Showcase capability status 与 `docs/renderer-capability-report.md` 对齐，让视觉行为易于验证。当行为可检查时，为渲染器改进添加 Showcase 覆盖；不可检查时，记录为什么 renderer tests/report 是主要观察依据。

验证：

```sh
moon test moui/render --target native
moon test moui_skia_renderer --target native
moon test moui_web_renderer --target wasm-gc
sh scripts/check.sh --profile full
moon build examples/showcase/web_wasm --target wasm-gc
```

只有在触碰 native WGPU 诊断渲染器时，才运行 `sh scripts/check.sh --profile full` 或 `moon test moui_wgpu_renderer --target native`。

## 工作流 5：平台 Contract

MoUI 将平台后端视为围绕共享 host contract 的 adapter。

重点领域：

- 保持 `backend/` 作为 `Event`、surface、input、text input、file drag/drop、window event、metrics 和 redraw contract 的事实来源。
- 保持 Web 走单一 `wasm-gc + window/web + browser WebGPU host imports` 路径。
- 保持 macOS native host 文档与 AppKit 和 native Skia provider 设置一致；将 CAMetalLayer/wgpu-native 要求限定在 WGPU diagnostics 中。
- 保持 Windows native 设置可用 Visual Studio C++ build tools、vcpkg `zlib:x64-windows` 和 renderer-aware build/package helper 复现。Native Skia 包不应下载或捆绑 `wgpu_native.dll`；显式 WGPU 诊断包保留现有 `wgpu_mbt` 动态路线。
- 保持 Linux 支持 Ubuntu 24.04+ Wayland，并具备匹配主机 runtime evidence 和 font-provider coverage（fonts-noto-core、fonts-dejavu-core）。
- 使用 `HostServiceBridge` 作为 clipboard、menus、file dialogs、URL opening 和 system-theme queries 的 typed host-service boundary。
- 对需要 permission prompt、picker callback 或其他 async completion 后 runtime 才能安全应用结果的浏览器或平台服务，使用 `ServiceAsyncQueue`。
- 保持 Web clipboard 行为诚实：copy/cut 通过浏览器 host import 写入选中文本，聚焦的浏览器文本输入仍可通过 input event 粘贴；backend 内部的 `ServiceAsyncQueue` 负责 permission/picker callback，应用只通过 `ServiceTask::effect` 接收 typed result，不保存 request id 或订阅 completion queue。
- 保持 URL opening 在活跃 host 上诚实：macOS 使用 `NSWorkspace`，Windows 使用 `ShellExecuteW`，Web 使用调用 `window.open` 且可报告 popup-blocked failure 的 browser host import。
- 保持 file drag/drop 走共享 host 路径：macOS 和 Windows 转发 native file path，Web 则转发 canvas drop event 中浏览器暴露的 file name。
- 保持 system theme propagation 走 host-service 路径：native macOS 和 Windows startup 现在会在第一次 layout/redraw pass 前，把查询到的 light/dark scheme 安装进 runtime environment。Web startup 使用浏览器 `prefers-color-scheme` 查询，Web/macOS/Windows theme-change window event 通过 `Event::ThemeChanged` 流动。
- 保持 window lifecycle state 通过 `WindowRegistry` 流动；活跃入口点分配 primary window record，把当前 runtime/driver 注册为 primary runtime slot，将 platform window id 绑定到 host id，通过该映射路由传入的 platform window event，并从共享 lifecycle 路径同步这些 slot。带 options 的 runner 会 drain `WindowRequestQueue` 中的 focus、close、resize、minimize、show 和 set-primary request。已 drain request completion 通过共享 host helper 记录回队列，让 request outcome 保持可观察。`OpenWindow` request 携带 platform-neutral scene id 和 payload。`WindowSceneResolver` 是该解析步骤的共享 scene-to-`AppRuntime` contract，`WindowRegistry::resolve_open_request` 会将成功解析与 window record 配对。`WindowRuntimeSlot` 用每个 window 的 `HostRuntimeDriver` instance 包裹这些 record，`WindowRuntimeSlots` 管理 lookup、focused/primary slot selection，以及 registry-backed insert/sync/request/lifecycle helper 和 closed-slot cleanup。Web 创建另一个 browser canvas 和 `WebRenderer`；native host 创建另一个 platform window，并向其 renderer provider 请求 renderer-neutral `RendererSession`，随后附加 platform-window binding、platform slot 和 per-window driver，再通过 `WindowId` 路由 redraw/event/context-menu/IME/dispose 路径。
- 在匹配主机 runtime evidence 和 native font provider support 可用前，通过 Linux 后端 readiness report 保持 Linux readiness 显式。

验证：

```sh
moon test moui/backend --target native
moon test moui/backend/web --target wasm-gc
sh scripts/check.sh --profile platform
```

## 工作流 6：文档与 AI 协作

文档应帮助用户和维护者从 overview 移动到运行代码，再到扩展框架。

计划文档集：

- `README.md`：短入口、quick start、example commands 和 docs index，也是根目录的唯一源文件。
- `docs/architecture.md`：package model 和 runtime mental model。
- `docs/development.md`：setup、focused checks、platform validation commands。
- `docs/platform-notes.md`：平台特定要求和 troubleshooting。
- `docs/text-system.md`：text measurement、provider composition、embedded fonts 和 shaping gaps。
- `docs/renderer-capability-report.md`：renderer status 和 update rule。
- `docs/roadmap-2026.md`：project direction 和 quality gates。
- `docs/view-catalog.md`：view API 和 support matrix。
- `docs/examples.md`：example purposes、commands 和 validation。
- `docs/markdown-editor.md`：WYSIWYG Markdown Editor model 和 workflows。
- `docs/testing.md`：testing layers 和 release checks。
- `docs/ai-collaboration.md`：AI workflow、prompt templates 和 review checklist。
- `docs/release-readiness.md`：preview-release gates、current observation、known gaps 和 next implementation slices。

项目还在以下位置包含 MoUI-specific skills：

```text
skills/moui-framework-development-skill/SKILL.md
skills/moui-app-development-skill/SKILL.md
```

framework skill 应引导 agent 阅读 `AGENTS.md`、尊重包边界、保留 runtime 管线、使用聚焦验证，并同时更新渲染器能力文件。app skill 应让应用工作聚焦在共享应用包、公开 view API 和轻薄平台入口点上。每当 docs placement、validation commands、platform behavior、example structure、renderer capability status 或 text architecture 变化时，都应审查两个 skill 和 `AGENTS.md`。

## 质量门禁

日常开发检查：

```sh
sh scripts/check.sh --profile daily
```

公开 API 审查：

```sh
moon info
```

按需平台验证：

```sh
sh scripts/check.sh --profile platform
sh scripts/check.sh --profile full
```

发布前，项目应具备：

- 有界开发检查通过。
- 公开 API 编辑后已审查 `pkg.generated.mbti` 变更。
- 可运行的 Web wasm-gc 示例。
- 当前平台的 native 示例验证。
- 渲染器能力报告与测试和代码同步。
- 已为变化的命令、包布局、平台行为或用户可见 API 更新文档。

## 发布就绪快照

将此快照用作当前项目形态的最终交接清单：

- README 解释项目价值、包地图，以及 Web/native 示例入口点。
- Architecture、development、platform、examples、testing、renderer capability、AI collaboration、release-readiness、text-system、Markdown Editor 和 view catalog 文档已从 README 链接。
- Showcase 和 Markdown Editor 将共享应用逻辑保持在 `examples/*/app/` 下，平台包作为轻薄入口点；Counter 和 Todo 作为内置交互模式位于 Showcase 中。
- Showcase 暴露 renderer capability status，供视觉审查。
- 每日验证集中在 `sh scripts/check.sh --profile daily`，并包含 core、views、render facade、native Skia、backend host/Web、example app tests 和 Web wasm-gc example builds。Native WGPU diagnostics 只随 `--wgpu-experimental` 运行。
- 平台验证仍通过 `--profile platform` 和 `--profile full` 选择性运行，因为 native executable builds 依赖当前主机设置。
- Linux 后端已完整接线：clipboard（text + image）、file dialog（portal + zenity fallback）、directory listing、text/binary file I/O、open URL、system theme、native menus（zenity + kdialog）、IME、drag-drop、AT-SPI accessibility、GLib timer host、client-side decorations、multi-window、platform view plugins 和 async image loading（pthread + Skia decode）。请在匹配 Wayland 主机上保持 runtime evidence 最新。
- `AGENTS.md` 和 repo-local skills 已针对当前 docs、examples、validation commands 和 text/rendering architecture 检查。

# MoUI

MoUI 是一个多平台 MoonBit GUI 框架，用于构建声明式 UI 应用，并复用平台中立的应用逻辑。原生宿主核心负责窗口、事件、服务和生命周期，然后通过平台 renderer provider 包接收具体渲染器。

欢迎贡献，请参阅 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

当前主线是原生 Skia 光栅化，加上 Web 的 `wasm-gc + window/web + browser WebGPU host imports` 路径。随着 MoonBit WGPU 生态成熟，原生 WGPU 仍作为实验性诊断路线可用。

### 支持的平台（产品等级）

| 平台 | 等级 | 含义 |
| --- | --- | --- |
| macOS | **committed** | 产品主线（L0-L3 证据） |
| Web | **committed** | 产品主线（wasm-gc + WebGPU） |
| Windows | **committed** | 产品主线（L0-L3 证据） |
| Linux | **committed_with_gaps** | 产品 L0-L2；交互式 L3 仍不完整 |
| Android | **experimental** | window-hosted 路径可编译；尚无可用性/产品承诺 |
| iOS | **experimental** | 同 Android |
| HarmonyOS | **experimental** | 同上；签名设备完整 smoke 仍待完成 |

Mobile **不是**“只有未接线的胶水层”，但也**尚未**做出产品承诺。它是
**实验性**的：代码可编译且 host-sim tests 通过，但在匹配设备证据落地前，
不做任何开发/演示可用性或产品承诺。参见[平台就绪声明](../platform-readiness-declaration.md)。

runtime 管线是显式的：

```text
View[Msg] -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer
```

## 项目结构

- `moui/core/` 拥有平台中立 contract、不透明 `View`、类型化事件、`Program`、`Effect`、`Subscription`、geometry、draw、semantics，以及由 `View[Msg]` 包装的私有 custom view 协议。
- `moui/views/` 拥有公开 view constructor 和具体控件行为；它们实现 `@core.ViewNode` 并通过 `@core.View::from_node` 构造，不向 `core` 添加新的 enum variant。
- `moui/runtime/` 暴露 app/host `AppRuntime` 构造入口，并拥有 runtime state、tree/layout/paint、event dispatch、program message drain、effect task、subscription lifecycle 和 diagnostics。
- `moui/views/` 为 app 代码返回面向应用的 `@moui.View[Msg]` 值。
- `moui/backend/` 定义共享 host contract；平台 backend 将窗口和输入事件规范化为 `Event`。
- `moui/backend/<platform>` 只提供中立宿主 surface/presenter；应用通过 `moui_skia_renderer` 或 `moui_wgpu_renderer` factory 显式组合渲染器。
- `moui/render/` 提供 renderer facade；原生 Skia 光栅化、WebGPU adapter 和实验性原生 WGPU 实现分别位于 `moui_skia_renderer/`、`moui_web_renderer/` 和 `moui_wgpu_renderer/`。
- `moui_theme/` 是可选 addon workspace member，用于带源码映射的 Material、Carbon、Primer、Fluent 主题预览，以及一方 Smartisan-inspired Sickle 拟物/扁平混合主题。
- `examples/*/app/` 包含共享 app 逻辑，而平台子包是很薄的入口。
- `website/` 是 MoUI 主页和 Web 演示表面。

## 截图

<div align="center">

  <img src="../../resource/screenshots/showcase.png" width="48%" alt="Showcase 展示应用"/>
  <img src="../../resource/screenshots/markdown_editor.png" width="48%" alt="Markdown 编辑器"/>

  <br/><br/>

  <img src="../../resource/screenshots/mo_workbench.png" width="48%" alt="Mo 工作台"/>
  <img src="../../resource/screenshots/excel.png" width="48%" alt="Excel"/>

  <br/><br/>

  <img src="../../resource/screenshots/webview.png" width="70%" alt="WebView 演示"/>
  <img src="../../resource/screenshots/ios-componentgallery.png" width="25%" alt="iOS 组件图库"/>

  <br/><br/>

  <img src="../../resource/screenshots/harmonyos-componentgallery.png" width="45%" alt="HarmonyOS 组件图库"/>
  <img src="../../resource/screenshots/android-componentgallery.jpg" width="48%" alt="Android 组件图库"/>

</div>

## 快速开始

选择与你要做的事情匹配的路径。

### Playground

打开[浏览器 Playground](https://wzzc-dev.github.io/MoUI/playground/)，无需安装原生工具链即可编辑并运行带引导的示例。这是学习 view/update 模型和检查 Web 行为的最短路径。

### 独立项目

安装独立 CLI，然后在本仓库之外生成项目：

```sh
moon install wzzc-dev/moui_cli/cmd/moui
moui new my_app
# Optional smaller skeleton: moui new my_app --template hello
cd my_app
moon update
moon check
moon run macos_skia --target native   # or windows_skia / linux_skia on that host
```

`moui new` 会创建共享 app 逻辑、Web 入口以及当前桌面入口。Android、iOS 或 HarmonyOS 需要用 `--platform` 显式添加；mobile 项目使用 `wzzc-dev/window` template 和 `*_window_hosted` 入口，不会把原生项目复制进应用仓库。参见[入门指南](getting-started.md)。

### 本仓库

在修改 MoUI 本身或运行完整功能示例时使用这条路径：

```sh
git clone --recurse-submodules https://github.com/wzzc-dev/MoUI.git
cd MoUI
sh scripts/ci-moon-update.sh
sh scripts/check.sh --profile pr
moon test examples/showcase/app --target native
moon test examples/markdown_editor/app --target native
```

Showcase 和 Markdown Editor 是主要的浏览与交互示例。它们的平台入口列在[运行示例](#running-examples)下。

框架搭建细节，包括可选 submodule 和 `window/` 本地源码工作流，位于[开发指南](../development.md)。

默认 daily baseline 覆盖核心框架、maintenance baseline ratchet、Web wasm-gc、原生 Skia 主线 contract、Showcase 和 Markdown Editor。Design Systems 是 addon 诊断覆盖；修改 `moui_theme` 或 `examples/design_systems` 时运行 `sh scripts/check.sh --profile theme`。

针对当前 host 的 backend/provider 检查，运行：

```sh
sh scripts/check.sh --profile platform
```

面向发布的截图和基准交接，使用：

```sh
node scripts/conformance-capture-scaffold.mjs --mode golden
node scripts/conformance-capture-scaffold.mjs --mode benchmark
```

这些命令会在 `artifacts/` 下生成本地 scaffold manifest 和日志；发布说明应引用相关 CI 运行、上传的 artifact 或 smoke log，而不是提交生成的 artifact。`artifacts/` 已被忽略；这些文件应作为本地或 CI 证据保留。

<a id="running-examples"></a>
## 运行示例

重点示例 `showcase`、`markdown_editor`、`mo_workbench` 和 `excel` 在 `examples/<name>/app` 中共享 app 逻辑，并暴露很薄的平台入口。Showcase 使用 `web_wasm`、桌面 renderer 专用入口，以及 `android_window_hosted`、`ios_window_hosted` 和 `harmonyos_window_hosted` mobile 入口。

要在 mobile 平台试用 Showcase，请按平台专用的设置、构建和运行说明操作：[Android](../android-support.md)、[iOS](../ios-support.md) 或 [HarmonyOS](../harmonyos-support.md)。标准示例使用 `wzzc-dev/window` template 和 `*_window_hosted` 入口；应用代码不需要维护原生项目副本。

> **Windows 前置条件：** 构建或运行任何 Windows 原生 Skia 入口（`windows_skia`）之前，请在 PowerShell 会话中初始化 MSVC 工具链：
>
> ```powershell
> .\scripts\windows\msvc_env.ps1
> ```
>
> 这会设置原生 Skia 链接步骤所需的 MSVC 环境。在 Windows 上执行 `moon run ... --target native` 之前，每个 shell 都需要运行一次。

### Showcase

跨桌面、mobile 和 Web 的统一 Components、Patterns、Platform 与 Diagnostics 工作区。源码位于 `examples/showcase/app`；平台入口很薄。

```sh
# Web (wasm-gc)
moon build examples/showcase/web_wasm --target wasm-gc

# macOS Skia
moon run examples/showcase/macos_skia --target native

# Windows Skia (run msvc_env.ps1 first in PowerShell)
.\scripts\windows\msvc_env.ps1
moon run examples/showcase/windows_skia --target native

# Linux Skia
moon run examples/showcase/linux_skia --target native
```

### Markdown Editor

Typora 风格的所见即所得 Markdown 编辑器。源码位于 `examples/markdown_editor/app`；保留的 macOS/Web 入口很薄。

```sh
# Web (wasm-gc)
moon build examples/markdown_editor/web_wasm --target wasm-gc

# macOS Skia
moon run examples/markdown_editor/macos_skia --target native
```

### Mo Workbench

原生 Skia 优先的桌面 agent dogfood 应用。目前只有 `macos_skia` 已接线；Linux/Windows/Web 入口是预留项。`bobzhang/openseek` 依赖从 mooncakes.io 解析（固定在 `examples/mo_workbench/moon.mod`）；不需要 submodule 或 workspace member override。

```sh
moon run examples/mo_workbench/macos_skia --target native
```

### Excel Viewer

使用 MoUI data table 组件的 MoonBit Excel（`bobzhang/mbtexcel`）文件渲染器。共享 app 逻辑位于 `examples/excel/app`；保留的入口为 `macos_skia`。

```sh
# macOS Skia
moon run examples/excel/macos_skia --target native
```

重点示例的聚焦 app-package 测试：

```sh
moon test examples/markdown_editor/app --target native
moon test examples/mo_workbench/app --target native
moon test examples/showcase/app --target native
moon test examples/excel/app --target native
```

参见 [Showcase](../../examples/showcase/README.mbt.md)、[示例](../examples.md)、[Markdown 编辑器](../markdown-editor.md)、[Mo 工作台](../mo-workbench.md) 和 [Showcases](../showcases.md)，了解 package 形态和平台覆盖。

## 文档

源文档位于 `docs/`。网站预览通过 `node scripts/sync-website-docs.mjs` 将这些 Markdown 文件复制到 `website/web_wasm/docs/`。

- [架构](../architecture.md)
- [开发](../development.md)
- [测试](../testing.md)
- [API 表面](../api-surface.md)
- [API 表面审计](../api-surface-audit.md)
- [维护主线](../maintenance.md)
- [平台说明](../platform-notes.md)
- [Renderer 能力报告](../renderer-capability-report.md)
- [View catalog](view-catalog.md)
- [Views API 指南](views-api-guide.md)
- [非渲染组件 cookbook](../non-render-component-cookbook.md)
- [App 模板](../app-templates.md)
- [示例](../examples.md)
- [Markdown 编辑器](../markdown-editor.md)
- [Mo 工作台](../mo-workbench.md)
- [AI 协作](../ai-collaboration.md)
- [2026 路线图](../roadmap-2026.md)
- [发布就绪](../release-readiness.md)

## 贡献

MoUI 由一位维护者在 AI 协助下维护，并向外部贡献开放。Pull request 是变更的主要入口。

- [贡献指南](../../CONTRIBUTING.md) - 设置、包边界、PR 要求、DCO
- [治理](../../GOVERNANCE.md) - 决策机制、RFC 流程、维护者角色、项目交接
- [安全策略](../../SECURITY.md) - 漏洞报告与支持范围
- [行为准则](../../CODE_OF_CONDUCT.md)

## 许可证

Apache-2.0。参见 [LICENSE](../../LICENSE)。

第三方依赖和署名说明收集在 [THIRD_PARTY.md](../../THIRD_PARTY.md)。

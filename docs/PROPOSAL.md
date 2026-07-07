# MoUI 项目申报书

## 项目名称与仓库
MoUI。GitHub: https://github.com/wzzc-dev/MoUI.git；Gitlink: 待同步后填写；Mooncakes 包名: `wzzc-dev/moui`；许可证: Apache-2.0。

## 项目简介
MoUI 是一个原创的 MoonBit 跨平台声明式 GUI 框架，面向桌面应用、Web 应用、开发工具和复杂交互界面。项目采用 Model / Msg / update / view 架构，让应用层业务逻辑保持平台中立，再通过薄平台入口接入 macOS、Linux、Windows 和浏览器运行环境。

## 项目方向与适用场景
项目属于 MoonBit 应用生态与基础 GUI 框架方向，适用于桌面工具、Web wasm-gc 应用、Markdown 编辑器、代码编辑器、设计系统预览、工作台式 IDE、数据表格与命令面板等场景。目标是为 MoonBit 生态提供可复用、可测试、可维护的 GUI 基础设施。

## 拟实现的核心功能
1. 声明式 UI 核心：提供类型安全的 `View[Msg]`、事件、布局、绘制、Effect、Subscription 和运行时调度。
2. 多渲染后端：支持 native Skia raster 主线、浏览器 WebGPU wasm-gc 路径、native WGPU 诊断路径、Sun CPU raster 自研实验性后端，以及浏览器 canvas 回退路径。
3. 控件与主题系统：提供按钮、文本、输入、菜单、弹窗、导航、表格、富文本、Markdown 等控件能力，并支持 Material、Carbon、Primer、Fluent 和 Sickle 等主题。
4. 跨平台宿主：通过 `moui/backend/host` 抽象窗口、输入、剪贴板、图片、计时器等服务，平台后端只负责薄适配。
5. 工程化验证：提供 CI、API surface 检查、smoke gates、平台 smoke、示例应用和核心路径测试。

## 技术实现计划
项目管线为 `View -> ElementTree -> LayoutTree -> RenderTree -> DrawCommand -> renderer`。核心包 `moui` 负责公共 API、视图、运行时、后端合约和渲染抽象；`moui_skia` 负责 Skia 绑定与原生绘制；`moui_sun` 负责 CPU raster、像素画布和软件渲染验证；WGPU / WebGPU 路径负责 GPU 渲染实验与浏览器运行；示例项目以 `examples/<name>/app` 保存共享逻辑，各平台入口保持轻量。

## 预期交付物
完整 MoonBit 源码、根目录 README 与 Apache-2.0 LICENSE、可运行示例、核心测试、GitHub Actions CI、mooncakes.io 发布包、GitHub 与 Gitlink 同步仓库，以及面向使用者的开发文档和平台 smoke 证据。

## 原创性与合规说明
MoUI 是原创项目，不是对已有 GUI 框架的直接移植。项目会明确记录第三方依赖、FFI 绑定、生成代码、测试数据和示例素材来源，遵守 Apache-2.0 及所有上游许可证要求，不包含未授权的私有、闭源或商业代码。

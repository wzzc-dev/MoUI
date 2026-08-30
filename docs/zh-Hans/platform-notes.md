# 平台说明

## Window 包依赖

MoUI 从 MoonBit registry 解析修改后的窗口宿主为 `wzzc-dev/window@0.5.4-0.1.6`。仓库本地 window checkout 不再属于普通开发流程。该 fork 包目前提供上游包尚未覆盖、但 MoUI 需要的目标支持。主 checkout 现在包含 `moui_skia`，它提供原生 Skia 光栅主线渲染器使用的可编辑 Skia 绑定。

## 共享宿主契约

平台后端通过 `backend` 归一化窗口、输入、表面、焦点、文本输入、重绘和关闭事件。应用代码在 Web、macOS、Windows 和当前 Linux Wayland 脚手架上接收同一套核心事件模型。`WindowRegistry` 还为窗口 id、主窗口、聚焦窗口、关闭请求、已关闭窗口清理和逐窗口表面指标提供共享簿记，因此未来多窗口平台宿主无需重复生命周期状态机。`WindowRequestQueue` 是匹配的平台中立请求通道，用于打开、聚焦、关闭、调整大小、最小化、显示和更改主窗口。`OpenWindow` 请求除标题、指标和主窗口意图外，还包含场景 id 和 payload，为未来多窗口宿主提供稳定的应用层 key，用于在创建新平台窗口时选择内容/运行时。`WindowSceneResolver` 把这些请求解析为新的 `AppRuntime` 实例或显式场景拒绝，而不把平台策略嵌入应用代码。`WindowRegistry::resolve_open_request` 随后把已解析运行时绑定到拥有新窗口 id 的 registry 记录，`WindowRuntimeSlot` 用其 `HostRuntimeDriver` 包装该记录。`WindowRuntimeSlots` 存储这些逐窗口 driver，支持查询和主/聚焦 slot 选择，从 registry 同步更新后的生命周期记录，为活动后端提供共享插入/同步/请求/生命周期事件辅助方法，并移除已关闭 slot。`PlatformWindowMap` 把平台 `WindowId` 值绑定到 `WindowId` 值，使多窗口分派在后端附加多个渲染器/窗口句柄集合之前拥有共享路由原语。
活动平台入口点通过带 options 的 runner 接收共享队列，并在平台边缘 drain 聚焦、关闭、调整大小、最小化、显示和 set-primary 请求。每个已 drain 请求都会在同一队列上记录有序 completion，因此测试和更高层宿主代码可以观察已接受操作和显式拒绝。活动后端使用共享队列 drain 辅助方法执行该 drain-and-record 循环，使请求 completion 跟踪保持由宿主拥有。平台一旦报告窗口已关闭，排队给该窗口的命令会被拒绝，而不是重放到陈旧运行时 slot 上；这些拒绝会作为普通请求 completion 记录。
Web 通过同一 registry/slot 路径创建主窗口，`WebAppOptions` 由 `@web.entry` 捕获并支持 resolver-backed `OpenWindow` 请求。原生宿主核心通过同一路径创建平台窗口，但不自行选择具体渲染器族。应用入口点向 `@runtime.run_app` 提供有序 `RendererProvider` 和一个平台 `PlatformEntry`。已解析窗口创建不透明 `HostSurface`，由首个接受的 provider 绑定 `RendererSession`，随后注册 `HostRuntimeDriver`、平台绑定和平台 slot，并按 `WindowId` 路由重绘、事件、上下文菜单、宿主服务 completion、IME 同步和释放。如果没有 scene resolver，宿主会用共享 unavailable-resolver 响应拒绝 `OpenWindow`。

原生渲染器选择属于应用组合，不是 host-core options 字段。Skia 主线使用显式平台策略的 `@render_skia.from_env(platform=...)`，原生 WGPU 诊断使用 `@render_wgpu.native(...)`。Android、iOS 和 HarmonyOS 使用 `wzzc-dev/window` 作为嵌入运行时后端的 embedder。template 通过 `EventLoop` 将 `HostCmd` 交给匹配的 `*EmbeddedRuntimeBackend`，后者装配 MoUI runtime session 和不透明宿主表面。`wzzc-dev/window/internal/embedded_dispatch` 只做三端物理 callback dispatch；平台 `HostCmd` adapter 只保留原生 payload 解码和 nominal `ApplicationHandler`/`Window` effects。`common/lifecycle::EmbeddedLifecycle` 统一拥有 lifecycle、surface generation、primary-window、detach 与 exit intent；`EmbeddedSession` 组合 frame/image/input/services owner 与 renderer/IME/semantics/platform views/transport 能力，不复制 phase 或 frame loop。lifecycle、surface 和 input 不得绕过该路线。

当前平台 provider 测试包含在 `sh scripts/check.sh --profile platform` 中。只有在你已经位于匹配宿主和工具链上时，才直接运行 provider 包。

边界是：

```text
platform window event -> Event -> AppRuntime -> DrawCommand -> renderer
```

后端应把平台细节保留在边缘：

- 表面指标携带逻辑大小、物理大小和缩放因子。
- 指针坐标在到达 `core` 之前归一化。
- 文件拖放事件在到达 `core` drop targets 之前携带归一化逻辑位置和平台文件路径。
- 键盘修饰键和 IME 事件转换为共享核心输入类型。
- 重绘调度由 `HostRuntimeDriver` 拥有；宿主请求重绘，但不直接改变元素树。
- 渲染器消费 `DrawCommand` 值，并与视图构造器和平台事件转换保持分离。
- 原生 `web_view` 是平台视图契约，而不是渲染器命令。`moui/views` 通过 View paint plan 发出平台视图位置，后端宿主契约拥有 WebView spec/event，`DrawFrame.platform_views` 携带矩形，原生宿主在渲染 MoUI 帧之后把这些矩形同步到真实平台 WebView 对象。导航是受控的：page/user navigation 发出 `WebViewEvent::NavigationRequested`，应用通过更新视图 `url` 或通过宿主命令队列发送 `WebViewCommand::LoadUrl` 来提交。
- Sun provider 会显式报告渲染器侧平台视图像素接线。macOS、Windows 和 Linux Sun 通过 `RendererSession` 把离屏平台视图像素转发进 Sun 帧时报告 `renderer_platform_view_pixels=SunRasterRenderer.draw_platform_view_pixels`。这是应用层 renderer composition 接线；在提出更宽的平台运行时就绪声明前，仍需要匹配宿主运行时 smoke。
- 类型化宿主服务通过 `HostServiceBridge` 路由，并为剪贴板、菜单、文件对话框、文本文件访问、URL 打开和系统主题提供显式 capability 标志。不支持的服务应返回 `Unavailable` 响应，而不是把平台检查泄漏到 `core` 或 `views`。
- 应用拥有的路由历史位于 `views` 中的 `RouteHistoryState`，在那里它可以建模 deep-link 字符串、back/forward 游标和 `RouterSnapshot` 恢复，而不依赖平台宿主。`@services.RouteSource` 通过 `Subscription::route_event` 提供类型化 route/deep-link fanout。`backend/web` 把浏览器 `pushState`/`replaceState`/`popstate` 接线到该 route source，并暴露 Web history 命令供应用拥有的 route effect 使用。原生 URL 栏、OS deep-link 分派和应用 history mutation 仍是独立的平台/应用集成。
- `HostCapabilitySummary` 是面向应用的 diagnostics rollup，覆盖服务、输入、窗口、文本输入、IME、拖放、异步服务、无障碍和原生 WebView 就绪度。Web、macOS、Windows 和 Linux 暴露包本地 summary 辅助方法，Showcase 在其 Runtime 区域展示注入的 summary。
  `HostCapabilitySummary::preflight_fields()` 提供渲染器中立的 ready/gap 字段字符串，使 composition-root 审计可以组合 host 与 renderer 诊断，而无需把具体渲染器策略导入宿主核心。
- 权限或回调驱动的宿主服务可以在 host adapter 内使用 `ServiceAsyncQueue` 并返回 `HostServiceResponse::Pending`，而不是阻塞运行时。应用侧只接收 `ServiceTask[T]`，并通过 `ServiceTask::effect` 把成功、失败或取消转换为 typed `Msg`；request id、bridge 和 completion queue 不离开 `backend`，业务 `Model` 不保存平台请求状态。
- 宿主服务桥可以把报告的 light/dark 系统主题应用到运行时 `Environment`。Web、macOS 和 Windows 在启动时第一轮 layout/redraw 之前执行一次。运行时 `ThemeChanged` 窗口事件被归一化为 `Event::ThemeChanged`，并通过 `HostRuntimeDriver` 更新环境。
- Web、macOS 和 Windows 通过活动 service bridge 路由 copy/cut/paste 键盘快捷键。当该 bridge 暴露剪贴板支持时，聚焦文本控件会读写平台剪贴板；如果没有文本命令处理该意图，应用 action 命令仍会接收它。Pending 剪贴板读取在异步 completion 到达前被视为已处理，因此 paste 命令不会分派两次。
- 次要鼠标按钮按下在宿主边缘被视为上下文菜单请求。Web、macOS、Windows 和 Linux 会跳过这些事件的普通指针分派，因此右键不会激活常规控件；macOS、Windows 和 Linux 随后通过其原生菜单服务路由运行时 action command 菜单。
  当文本输入聚焦时，宿主 driver 会把 MoUI 的默认文本命令前置到该菜单，使原生上下文菜单可以通过与键盘快捷键相同的剪贴板和命令路径复制、剪切、粘贴、撤销、重做和选择文本。

## 平台特定说明

关于详细的平台特定设置、要求和运行时证据：

- [Web Wasm-GC](platform-notes-web.md) — 浏览器 WebGPU、剪贴板、文件系统访问、路由历史和触摸滚动。
- [macOS](platform-notes-macos.md) — AppKit 宿主、Skia/WGPU 诊断、链接标志和服务桥细节。
- [Windows](platform-notes-windows.md) — MSVC 工具链、Skia/WGPU 设置、WebView2 自动检测和宿主架构。
- [Linux](platform-notes-linux.md) — Wayland 宿主、运行时要求、Skia renderer composition、运行时证据和剩余缺口。
- [Android](../android-support.md)（**experimental**）— window-hosted Activity、APK 打包和 matching-device evidence requirements。
- [iOS](../ios-support.md)（**experimental**）— window-hosted UIKit template、Simulator 打包和 matching-device evidence requirements。
- [HarmonyOS](../harmonyos-support.md)（**experimental**）— window-hosted Stage Ability/XComponent template、HAP 打包和 signed-device evidence requirements。

产品类别摘要：[平台就绪声明](../platform-readiness-declaration.md)。

## 平台验证

使用聚焦平台验证，而不是宽泛的全仓库原生检查：

```sh
moon test moui/backend --target native
moon test moui/backend/web --target wasm-gc
sh scripts/check.sh --profile platform
```

在已配置宿主上执行 release 风格验证之前，包含平台示例构建：

```sh
sh scripts/check.sh --profile full
```

更改事件转换时，还要运行受影响的后端包测试。更改渲染器表面创建或 WGPU 设置时，至少为当前平台构建一个原生示例。

# 平台宿主契约

> 本文档描述 `moui/backend` 的共享边界契约。概述见
> [架构](architecture.md)。

`backend` 是平台包与平台中立运行时之间的共享边界。它定义
`SurfaceMetrics`、输入能力、坐标策略、`Event`、文本输入会话同步、
文件拖放归一化，以及用于平台中立窗口生命周期和多窗口簿记的
`WindowRegistry`。按 ADR 0018，`HostRuntimeDriver`、`RedrawScheduler`
和 `HostWallClock` 位于 `moui/runtime`；`backend` 把它们当作契约消费，但不拥有它们。它还暴露 `WindowRequestQueue`，让应用/运行时或更高层宿主代码可以
排队打开、聚焦、关闭、调整大小、最小化、显示和主窗口请求，而无需把这些请求嵌入平台后端。
`OpenWindow` 请求除了标题和指标，还携带平台中立的场景 id 和负载，因此未来多窗口宿主有足够的
应用层身份来为新的平台窗口选择运行时/内容。`WindowSceneResolver` 是匹配的共享契约，用于在
平台后端分配原生窗口之前，把这些场景请求解析为新的 `AppRuntime` 实例，或显式拒绝场景。
`HostEventSource` 是用于应用拥有的宿主事件扇出的宿主层订阅适配器：平台代码可以发布归一化的
`Event` 值，而应用通过 `Subscription::host_event` 把选中的事件映射回类型化的 `Program` 消息；
取消订阅会移除发布者处理器，因此迟到的宿主事件不会重新进入陈旧的应用状态。
`HostWindowEventSource` 是用于窗口作用域平台事件的匹配宿主层订阅适配器：平台代码可以发布
一个 `WindowId` 加上归一化的 `Event`，而应用通过 `Subscription::window_event` 映射这些
`HostWindowEvent` 值；取消订阅会移除发布者处理器，因此迟到的窗口事件不会重新进入陈旧的应用状态。
`HostPlatformEventSources` 为平台运行时打包宿主事件源和窗口事件源。Web、macOS、Windows 和 Linux
的应用选项可以携带该包；原始平台事件被归一化并通过匹配的 `HostRuntimeDriver` 分派后，后端会连同其
`WindowId` 发布同一个 `Event`，使应用拥有的 `Subscription::host_event` 和
`Subscription::window_event` 适配器可以观察真实运行时事件，而无需把平台事件转换移入 `core`。
`@services.TimerSource` 是用于应用拥有的计时器节拍的匹配宿主层订阅适配器：宿主/平台代码提供调度器
回调，而应用通过 `Subscription::timer` 把 `@core.Frame` 节拍映射回类型化的 `Program` 消息；
取消订阅会运行调度器清理，因此迟到的计时器回调会被陈旧分派保护忽略。
`@services.RouteSource` 是用于应用拥有的路由/deep-link 流的匹配宿主层订阅适配器：宿主/平台代码可以发布
携带 `@core.RouteLocation` 和来源标签的 `@services.RouteEvent` 值，而应用通过
`Subscription::route_event` 映射这些事件；取消订阅会移除发布者处理器，因此迟到的路由事件不会
重新进入陈旧的应用状态。该适配器本身不会修改 `RouteHistoryState`，也不会同步浏览器/原生历史。
`WindowRegistry::resolve_open_request` 把成功的场景解析与创建出的注册表记录配对，使宿主可以把
窗口 id、场景元数据和运行时保持在一起。随后 `WindowRuntimeSlot` 用 `HostRuntimeDriver` 包装该记录，
在附加平台特定窗口句柄和渲染器句柄之前，为未来多窗口宿主提供共享的逐窗口运行时/驱动器形态。
`WindowRuntimeSlots` 是用于查询、选择主/聚焦槽位、记录同步和已关闭窗口清理的匹配集合，
包括共享辅助方法，用于从 `WindowRegistry` 插入并同步槽位、应用平台中立窗口请求，以及应用
宿主生命周期事件，同时保持槽位记录对齐。
`PlatformWindowMap` 把来自 `wzzc-dev/window` 的平台窗口 id 绑定到 MoUI `WindowId` 值，使事件分派
可以通过宿主注册表路由，而不是假设只有一个全局窗口。
`HostWebViewCapabilities` 是原生平台 WebView 的能力契约。独立的 `moui_webview` addon 拥有
`WebViewHost` 和 `WebViewController`；宿主把 `DrawFrame.platform_views` 同步到具体 WebView
对象，校验并分派 `WebViewEvent`，并在平台边缘 drain controller task。浏览器 Web wasm 报告
不可用，而不是创建 iframe 覆盖层。
Web、macOS、Windows 和 Linux 应将其原生窗口事件转换为 `Event`，然后让 `AppRuntime` 更新状态、
重建并发出 `DrawCommand` 值。
活动的 Web、macOS、Windows 和 Linux 宿主都会打开一个主 `WindowRecord`，把现有运行时/驱动器注册为
主 `WindowRuntimeSlot`，把平台窗口 id 绑定到宿主 id，通过该映射路由传入的平台窗口事件，通过
注册表应用调整大小/聚焦/关闭 `Event` 值，在生命周期变化后同步槽位记录，并在宿主窗口释放时
移除槽位、平台绑定和记录。这使多窗口生命周期状态成为共享宿主职责，而不是未来某个平台特定重写。
平台入口点通过 `AppBuilder::window_requests` 接收共享 `WindowRequestQueue`，并在平台边缘排空聚焦、关闭、
调整大小、最小化、显示和设为主窗口请求。同一队列会记录有序的请求完成记录，使已接受操作和
显式拒绝可观察。活动后端使用共享队列排空辅助方法，因此完成记录保持为宿主契约，而不是
平台本地循环。
`WindowCommands` 是建立在同一队列之上的更高层命令门面，提供面向应用的打开/聚焦/调整大小/最小化/
显示/关闭辅助方法，并共享排空到注册表或窗口运行时槽位的逻辑。
每个应用入口调用 `@runtime.run_app`，提供有序 `RendererProvider` 与一个平台 `entry`，再调用
`run`。渲染器选项和 native handle 解释策略由 provider 捕获，平台选项由 platform entry 捕获。有解析器时，`OpenWindow` 请求把场景解析为新的
`AppRuntime`，创建另一个平台窗口和不透明 `HostSurface`，由首个接受的 provider 绑定 `RendererSession`，注册逐窗口
`HostRuntimeDriver`，绑定平台 id，然后通过按窗口索引的槽位路由重绘、事件、上下文菜单、服务完成记录、
IME 同步和释放。没有解析器时，宿主用共享的解析器不可用消息拒绝 `OpenWindow`。

`RendererSession` 是原生宿主核心使用的渲染器中立 live handle。其稳定构造器核心包含调整大小、
带 `FrameToken` 的帧提交、事件排空、呈现计数诊断和幂等释放。可选行为由
`RendererPlatformViewCapability` 与 `RendererGpuRecoveryCapability` 等中立协议表达；宿主不按具体
renderer 分支。provider rejection 不得保留资源；Bound session 唯一负责接管 renderer/native-surface
资源的幂等释放。宿主核心只依赖 `core`、`runtime`、`backend`、中立 `render` 契约和平台 `window` 包；
平台 backend 拥有窗口句柄、中立 CPU presenter、不透明 native surface/display handle 和生命周期/I/O 回调，
renderer 模块拥有创建、解码、native binding、平台策略、协商和诊断。

图片工作使用 `RendererEvent::ImageLoadRequested` 的 opaque token。renderer session 发出 request，
`backend/common/image` 只保存可取消的 I/O task，通过 `HostImageSource` 读取字节，并把相同 token 的
completion 交回 `RendererSession::apply_image_load_completion`。session 返回 `Applied(repaint)`、
`Stale` 或 `Disposed`；只有 Applied 才请求匹配窗口重绘。格式检测、解码、资源状态、缓存和失败重试
全部属于 renderer session；backend 不保存 revision、resource snapshot、repaint tracker 或 command cache。
窗口释放时先取消 image task，再 dispose session，因此迟到 completion 无副作用。

`RendererDescriptor` 和 `RendererSelection` 仍然是渲染器门面报告工具：
它们描述静态能力身份和匹配，而不是原生宿主运行时装配。`View` 仍然只描述 UI 声明树，
`ControlledValue[T, Msg]` 是 TEA/control 的不可变 value + typed message bridge，不提供 setter。

## 移动宿主通道

`moui/backend` 是中立 `HostServiceRequest`、`HostServiceResponse`、
`HostServiceCapabilities`、`HostServiceBridge`、request id 和 completion
契约的唯一所有者。内部实现按宿主模型分为两套必要机制：

- `common/services/desktop` 统一同步桌面路由；macOS、Windows、Linux 只提供
  clipboard、URL、dialog、menu、settings 的 native closures，并路由
  `common/services/native` 的共享 text/binary file 与 directory 实现。
- `common/services/native` 统一拥有桌面 backend 与 embedded runtime 共用的
  原生 `@fs` service I/O；原始字节 `HostImageSource` 位于 `common/image/native`。
- `common/services/embedded` 统一异步 callback queue；clipboard 和 platform
  channel 按 FIFO 返回 `Pending(id)`，只允许一次 completion，拒绝重复/迟到
  response，并在 dispose 时取消 outstanding request。桌面专属请求同步返回
  `Unavailable`。

`EmbeddedRuntimeHostBridge` 是私有的 Android/iOS/HarmonyOS 运行时聚合边界，
并组合 `common/services/embedded`。它合并 `EmbeddedImeRequest` 更新，
传输由运行时提交的完整/增量语义数据（使用 `SemanticsNodeId` 与
`SemanticsGeneration`），同步 platform-view placement/event，并将 pending
service request 映射到保持不变的 native wire schema。它的 cursor 只用于抑制
未变化的传输，不构成第二套 revision 权威；已释放的 bridge 会取消 outstanding
service 并拒绝迟到响应。

## Window host owners

平台 backend 直接持有窄 owner：`common/lifecycle` 拥有 registry、request、
runtime slot、平台窗口映射、phase/generation 与 exactly-once close；
`common/frame` 拥有逐窗口 `RendererSession`、`FrameToken` pending/completion、redraw/resize
与 IME frame hook；`common/image` 只拥有可取消 I/O task、opaque-token completion、
callback detach 与 cancellation；`common/input` 拥有 pointer/text/IME session；
`common/services` 拥有 service facade、async completion 与 bridge 生命周期。
root `backend/common` 只提供显式接收这些 owner 的无状态 workflow，不再存在总控
state object。

关闭顺序固定为：阻止 lifecycle 重入；解除 image callback 并取消任务；关闭
embedded/service channel；dispose renderer session；dispose platform views/native
host resources；清除 mapping/runtime/registry；完成 close。

`TextInputEvent::ReplaceText` 和 `SetSelection` 保留任意原生 IME 替换和 UTF-16 选区更新。移动请求包含文本、
选区、组字、插入光标和候选矩形，而不改变桌面 `window_core.ImeRequest` 契约。

无障碍动作通过
`AppRuntime::perform_semantics_action(PerformSemanticsActionRequest)` 进入。请求携带 `SemanticsNodeId`、类型化
`SemanticsAction` 与精确的运行时 generation。stale generation、已移除节点、enabled 状态、动作能力和 handler
校验都由运行时负责；宿主适配器只传输请求与 receipt，不得重复校验或把动作转回屏幕坐标输入。
Web 的纯语义提交独立于 redraw 同步。

类型化宿主服务位于同一边界上。`HostServiceBridge` 暴露经过能力检查的分派，用于剪贴板、文件对话框、菜单、
打开 URL 和系统主题请求。后端可以报告不可用服务，而不假装应用代码可以直接调用平台 API。
`HostCapabilitySummary` 把这些服务标志与输入、窗口生命周期、文本输入、IME、拖放、异步服务和原生无障碍就绪度
折叠在一起。它是面向应用、诊断和 Showcase 的高层报告 API。它的 `preflight_fields()` 辅助方法会发出
渲染器中立的就绪/缺口字段字符串，用于提供方/包审计，例如原生 Skia 预检日志；
`HostServiceBridge`、`HostInputContract` 和平台后端设置仍是实际行为的事实来源。
应用不直接消费这条 bridge。`@backend_common.app_services(...)` 把它适配为
`@services.AppServices`，`@backend_common.app_environment(...)` 再组合可选的
`@services.TimerSource` 和 `@services.RouteSource`。平台后端向 composition root 暴露
`app_environment()`；Program 闭包捕获 environment，不把它放入业务 `Model`。
无法同步完成的服务，尤其是需要权限或选择器回调的浏览器剪贴板读取和文件对话框，可以通过
`ServiceAsyncQueue` 返回 `HostServiceResponse::Pending`。宿主在平台边缘把待处理请求排空到
进行中集合，用附带的原始请求完成它们，并记录完成结果。运行时拥有的效果（例如异步粘贴）会交给
`HostRuntimeDriver`。host adapter 把应用拥有的操作转换为 `ServiceTask[T]`；应用通过类型化消息循环接收
`ServiceTaskResult::Success`、`Failure` 或 `Cancelled`。request id 与 queue handler 只留在
`backend`，runtime 的 task lifecycle 会拒绝 stale dispatch。
Web 后端把该队列接线到浏览器宿主导入项，以及用于剪贴板读取和文件选择器的导出 wasm 完成回调。
Web、macOS 和 Windows 入口点会在启动时查询该桥，并在第一轮宿主驱动器布局/重绘轮次之前把报告的
浅色/深色方案安装到 `AppRuntime` 中，因此初始 Program view 构建可以通过 `ViewEnvironment` 看到平台配色方案。
`ThemeChanged` 窗口事件也会被归一化为 `Event::ThemeChanged`；
`HostRuntimeDriver` 会把它们应用到运行时环境，而不是把平台特定事件泄漏到应用代码中。

键盘快捷键、菜单和宿主命令响应共享 `ActionCommand`/`CommandIntent` 模型。`ActionCommandMap` 是平台中立分派器，
用于匹配快捷键并调用已启用的命令处理器。面向应用的命令元数据别名会与命令面板和菜单构造器一起从 `moui/views`
导出；较低层运行时和宿主集成仍可直接使用 `core` 契约。
`views` 包还在同一元数据之上提供视图层菜单辅助方法：`menu_bar`、`command_menu` 和
`context_menu_region` 会把按钮、行、表面和覆盖层渲染为普通 `View[Msg]` 值。它们是后备或
应用编写的菜单 UI，不是平台菜单服务。
复制、剪切和粘贴快捷键会与活动的 `HostServiceBridge` 一起通过 `HostRuntimeDriver` 路由，因此在该服务可用时，
聚焦文本控件会使用平台剪贴板，而当没有文本命令处理该意图时，应用层命令处理器仍会运行。
次要按钮上下文菜单请求由宿主事件层识别：平台后端会跳过这些事件的普通指针分派，然后有原生菜单能力的宿主会请求
`HostServiceBridge::ShowMenu` 展示当前运行时操作命令，并通过 `HostRuntimeDriver` 分派选中的意图。
应用菜单栏 (L2) 使用 `HostServiceRequest::SetApplicationMenu` /
`@services.MenuServices::install_application` 和 `ApplicationMenu` 描述符。macOS 通过 window 包安装原生主菜单
标题/项目；Windows、Linux 和 Web 当前返回 `Unavailable`。选择交付仍使用入口点安装的平台动作处理器（例如
`@window_macos.set_system_menu_action_handler`）。见
[非渲染组件手册](non-render-component-cookbook.md) 和
Showcase 的 Platform 工作区（`examples/showcase/app/platform`）。
面向应用的多窗口生命周期请求通过共享 `WindowRequestQueue` 上的 `WindowActions`
（`open`、`close`、`focus`、`set_primary`、`resize`、`minimize`、`show`）发出。
每个已解析场景仍是独立的 `AppRuntime`；共享状态由应用拥有。见 `examples/multi_window`。
文件放置目标使用 `View::on_file_drop` 修饰器；宿主会在运行时向命中的视图分派类型化消息之前，归一化原生文件拖放
位置和路径。`views.drop_zone` 和 `views.file_import_panel` 是基于该修饰器的视图层工作流外壳；它们的浏览动作
仍是应用消息，因此具备效果能力的应用代码可以返回一个调用 `AppServices::files().open_file` 的
`ServiceTask::effect` 运行器，为不可用或同步文件对话框响应分派类型化完成消息，并为待处理对话框声明
`ServiceTask::effect`。Web 文件导入可能暴露浏览器选中的文件名或句柄，而不是原生文件系统路径，
而原生宿主可以通过同一选择数组返回平台路径。

关于设置、后端特定约束和验证命令，见 [平台说明](platform-notes.md)。

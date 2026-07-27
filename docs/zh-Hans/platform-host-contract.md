# 平台宿主契约

> 本文档描述 `moui/backend/host` 的共享边界契约。概述见
> [架构](architecture.md)。

`backend/host` 是平台包与平台中立运行时之间的共享边界。它定义
`HostSurfaceMetrics`、输入能力、坐标策略、`HostEvent`、文本输入会话同步、
`HostRuntimeDriver`、文件拖放归一化，以及用于平台中立窗口生命周期和多窗口簿记的
`HostWindowRegistry`。它还暴露 `HostWindowRequestQueue`，让应用/运行时或更高层宿主代码可以
排队打开、聚焦、关闭、调整大小、最小化、显示和主窗口请求，而无需把这些请求嵌入平台后端。
`OpenWindow` 请求除了标题和指标，还携带平台中立的场景 id 和负载，因此未来多窗口宿主有足够的
应用层身份来为新的平台窗口选择运行时/内容。`HostWindowSceneResolver` 是匹配的共享契约，用于在
平台后端分配原生窗口之前，把这些场景请求解析为新的 `AppRuntime` 实例，或显式拒绝场景。
`HostEventSource` 是用于应用拥有的宿主事件扇出的宿主层订阅适配器：平台代码可以发布归一化的
`HostEvent` 值，而应用通过 `Subscription::host_event` 把选中的事件映射回类型化的 `Program` 消息；
取消订阅会移除发布者处理器，因此迟到的宿主事件不会重新进入陈旧的应用状态。
`HostWindowEventSource` 是用于窗口作用域平台事件的匹配宿主层订阅适配器：平台代码可以发布
一个 `HostWindowId` 加上归一化的 `HostEvent`，而应用通过 `Subscription::window_event` 映射这些
`HostWindowEvent` 值；取消订阅会移除发布者处理器，因此迟到的窗口事件不会重新进入陈旧的应用状态。
`HostPlatformEventSources` 为平台运行时打包宿主事件源和窗口事件源。Web、macOS、Windows 和 Linux
的应用选项可以携带该包；原始平台事件被归一化并通过匹配的 `HostRuntimeDriver` 分派后，后端会连同其
`HostWindowId` 发布同一个 `HostEvent`，使应用拥有的 `Subscription::host_event` 和
`Subscription::window_event` 适配器可以观察真实运行时事件，而无需把平台事件转换移入 `core`。
`HostTimerSource` 是用于应用拥有的计时器节拍的匹配宿主层订阅适配器：宿主/平台代码提供调度器
回调，而应用通过 `Subscription::timer` 把 `@core.Frame` 节拍映射回类型化的 `Program` 消息；
取消订阅会运行调度器清理，因此迟到的计时器回调会被陈旧分派保护忽略。
`HostRouteSource` 是用于应用拥有的路由/deep-link 流的匹配宿主层订阅适配器：宿主/平台代码可以发布
携带 `@core.RouteLocation` 和来源标签的 `HostRouteEvent` 值，而应用通过
`Subscription::route_event` 映射这些事件；取消订阅会移除发布者处理器，因此迟到的路由事件不会
重新进入陈旧的应用状态。该适配器本身不会修改 `RouteHistoryState`，也不会同步浏览器/原生历史。
`HostWindowRegistry::resolve_open_request` 把成功的场景解析与创建出的注册表记录配对，使宿主可以把
窗口 id、场景元数据和运行时保持在一起。随后 `HostWindowRuntimeSlot` 用 `HostRuntimeDriver` 包装该记录，
在附加平台特定窗口句柄和渲染器句柄之前，为未来多窗口宿主提供共享的逐窗口运行时/驱动器形态。
`HostWindowRuntimeSlots` 是用于查询、选择主/聚焦槽位、记录同步和已关闭窗口清理的匹配集合，
包括共享辅助方法，用于从 `HostWindowRegistry` 插入并同步槽位、应用平台中立窗口请求，以及应用
宿主生命周期事件，同时保持槽位记录对齐。
`HostPlatformWindowMap` 把来自 `wzzc-dev/window` 的平台窗口 id 绑定到 MoUI `HostWindowId` 值，使事件分派
可以通过宿主注册表路由，而不是假设只有一个全局窗口。
`HostWebViewCapabilities`、`HostWebViewCommandQueue` 和 `HostWebViewEventSource` 是原生平台
WebView 的宿主侧契约。宿主报告原生嵌入是否可用，把 `DrawFrame.platform_views` 同步到具体的 WebView
对象，把 `HostEvent::WebView` 分派回运行时，并在平台边缘排空已排队命令。浏览器 Web wasm 报告
不可用，而不是创建 iframe 覆盖层。
Web、macOS、Windows 和 Linux 应将其原生窗口事件转换为 `HostEvent`，然后让 `AppRuntime` 更新状态、
重建并发出 `DrawCommand` 值。
活动的 Web、macOS、Windows 和 Linux 宿主都会打开一个主 `HostWindowRecord`，把现有运行时/驱动器注册为
主 `HostWindowRuntimeSlot`，把平台窗口 id 绑定到宿主 id，通过该映射路由传入的平台窗口事件，通过
注册表应用调整大小/聚焦/关闭 `HostEvent` 值，在生命周期变化后同步槽位记录，并在宿主窗口释放时
移除槽位、平台绑定和记录。这使多窗口生命周期状态成为共享宿主职责，而不是未来某个平台特定重写。
平台入口点还通过其携带选项的运行器接收共享 `HostWindowRequestQueue`，并在平台边缘排空聚焦、关闭、
调整大小、最小化、显示和设为主窗口请求。同一队列会记录有序的请求完成记录，使已接受操作和
显式拒绝可观察。活动后端使用共享队列排空辅助方法，因此完成记录保持为宿主契约，而不是
平台本地循环。
`HostWindowCommands` 是建立在同一队列之上的更高层命令门面，提供面向应用的打开/聚焦/调整大小/最小化/
显示/关闭辅助方法，并共享排空到注册表或窗口运行时槽位的逻辑。
Web 直接暴露 `run_app_with_options`，因为浏览器渲染器是该宿主的一部分。原生宿主核心则暴露
`run_app_with_renderer_provider`；公共原生入口点位于 `backend/<platform>/wgpu` 和
`backend/<platform>/skia`。这些提供方包携带面向用户的 `run_app`、`run_app_with_options`、
渲染器特定选项，以及 `renderer_provider` 构造器。有解析器时，`OpenWindow` 请求把场景解析为新的
`AppRuntime`，创建另一个平台窗口，向提供方请求 `HostWindowRenderer`，注册逐窗口
`HostRuntimeDriver`，绑定平台 id，然后通过按窗口索引的槽位路由重绘、事件、上下文菜单、服务完成记录、
IME 同步和释放。没有解析器时，宿主用共享的解析器不可用消息拒绝 `OpenWindow`。

`HostWindowRenderer` 是原生宿主核心使用的渲染器中立运行时句柄。其稳定构造器核心包含调整大小、
命令/帧渲染、呈现完成排空、呈现计数诊断和释放。可选行为被分组到
不透明的 `HostRendererImageCapability`、`HostRendererPlatformViewCapability` 和
`HostRendererGpuRecoveryCapability` 记录中。当提供方省略某项能力时，现有实例方法保持空操作/默认
语义，因此宿主不会根据渲染器实现细节分支。共享图片重绘跟踪器消费渲染器中立的图片快照，以便按打开窗口路由
迟到图片重绘，并暴露已跟踪窗口版本号加上加载中/就绪/失败/已释放状态计数诊断，包括重绘结果中的
之前/当前计数。宿主核心只依赖 `core`/`backend/host` 加平台 `window` 包；它们不导入
`render/wgpu`、`render/skia`、`wgpu_mbt` 或 `moui_skia`。Skia 提供方包拥有原生主线渲染器创建、
像素呈现器桥和 Skia 可用性诊断。WGPU 提供方包保留 GPU 表面桥、`wgpu-native` 和
原生 WGPU 文本提供方组合，作为实验诊断。

`HostImageResourceCompletionSource` 是原生异步图片加载器完成结果的宿主层边界。原生提供方/平台加载器通过
`HostWindowRenderer::apply_image_resource_load_completion` 发布 `@render.ImageResourceLoadCompletion`
就绪/失败结果，该方法返回带版本号的 `@render.ImageResourceSnapshot`；宿主通过
`HostImageResourceRepaintTracker` 路由该快照，只为匹配的打开窗口请求重绘，忽略陈旧的较低版本号，
并丢弃已关闭窗口的完成结果。`HostAsyncImageLoader` 是该边界的宿主侧调度器适配器：它扫描渲染器快照中的
加载中记录，启动平台/提供方加载器，对进行中的 `(window, source)` 工作去重，并在迟到或已取消的
完成回调能应用到渲染器之前对其拦截。`HostNativeAsyncImageSource` 是宿主拥有的延迟请求源，用于需要
记录待处理 `(window, source)` 工作并稍后从独立原生回调交付完成结果的平台加载器。它证明宿主边界可以在
调度返回后接收迟到的完成回调，并且平台运行时工件会把宿主层观察与渲染器能力状态分开记录。
原生 macOS、Windows 和 Linux 宿主核心会在已呈现图片资源版本号建立基线后调用可选的提供方拥有的
加载器钩子，然后在释放期间取消进行中的窗口加载。原生 WGPU 提供方包现在提供一个提供方拥有的加载器，
把渲染器拥有的 PNG/JPEG/BMP 来源解码结果转换为 `ImageResourceLoadCompletion` 负载。原生 Skia
提供方包现在围绕已解码图片完成结果安装同一提供方拥有的加载器边界，并且提供方创建的 Skia
渲染器选择加入呈现后异步图片加载，因此第一份已呈现快照可以在宿主把就绪/失败完成结果路由到
重绘之前包含加载中记录。本地文件提供方 worker 在主线程外读取并解码 Skia 图片，然后通过
`ImageResourceLoadCompletion` 交付已解码的 RGBA 像素、尺寸、行字节数、`background_io` 和
`background_decode`。Skia 会把已解码就绪完成结果直接应用到渲染器图片缓存，而 data URI 来源
通过渲染器解码路径完成。这是渲染器/宿主边界上的提供方完成结果和冒烟日志证据。宿主请求源和调度器
不会解码图片、修改渲染器缓存，也不位于 `core` 中；
渲染器/提供方包仍拥有具体加载和生命周期记录。

`RendererDescriptor` 和 `RendererSelection` 仍然是渲染器门面报告工具：
它们描述静态能力身份和匹配，而不是原生宿主运行时装配。`View` 仍然只描述 UI 声明树，
`Binding[T]` 仍然是 TEA/control/state 双向绑定术语。

## 移动宿主通道

`EmbeddingHostBridge` 是私有的 Android/iOS/HarmonyOS 服务边界。它合并 `EmbedderImeRequest` 更新，传输由运行时提交的
完整/增量语义数据（使用 `SemanticsNodeId` 与 `SemanticsGeneration`），并承载异步文本/图片剪贴板请求与响应。
它的 cursor 只用于抑制未变化的传输，不构成第二套 revision 权威；已释放的通道会拒绝迟到响应。

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
`HostAppServices` 是建立在同一桥之上的面向应用门面，带有用于剪贴板、文件对话框、URL 打开、系统主题、
上下文菜单、可选异步队列完成处理，以及应用层 `completion_subscription` 适配器的辅助方法；
该桥仍是能力路由和平台分派的事实来源。
无法同步完成的服务，尤其是需要权限或选择器回调的浏览器剪贴板读取和文件对话框，可以通过
`HostServiceAsyncQueue` 返回 `HostServiceResponse::Pending`。宿主在平台边缘把待处理请求排空到
进行中集合，用附带的原始请求完成它们，并记录完成结果。运行时拥有的效果（例如异步粘贴）会交给
`HostRuntimeDriver`，而应用拥有的服务流程应在模型状态中存储待处理请求 id，并从 `Program` 订阅声明
`HostAppServices::completion_subscription`，使完成结果重新进入类型化消息循环，而不向 `core` 暴露平台 API。
当模型离开待处理状态或运行时被销毁导致该订阅被取消时，宿主队列会释放其完成处理器；后续平台响应会被保留为
普通已完成记录，而不是通过已死亡的应用回调分派。较低层的 `HostAppServices::on_completed` 回调仍可用于自定义适配器。
Web 后端把该队列接线到浏览器宿主导入项，以及用于剪贴板读取和文件选择器的导出 wasm 完成回调。
Web、macOS 和 Windows 入口点会在启动时查询该桥，并在第一轮宿主驱动器布局/重绘轮次之前把报告的
浅色/深色方案安装到 `AppRuntime` 中，因此初始视图构建可以通过 `ComponentContext` 环境读取看到平台配色方案。
`ThemeChanged` 窗口事件也会被归一化为 `HostEvent::ThemeChanged`；
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
`HostAppServices::set_application_menu` 和 `HostApplicationMenu` 描述符。macOS 通过 window 包安装原生主菜单
标题/项目；Windows、Linux 和 Web 当前返回 `Unavailable`。选择交付仍使用入口点安装的平台动作处理器（例如
`@window_macos.set_system_menu_action_handler`）。见
[非渲染组件手册](non-render-component-cookbook.md) 和
Showcase 的 Platform 工作区（`examples/showcase/app/platform`）。
面向应用的多窗口生命周期请求通过共享 `HostWindowRequestQueue` 上的 `HostWindowActions`
（`open`、`close`、`focus`、`set_primary`、`resize`、`minimize`、`show`）发出。
每个已解析场景仍是独立的 `AppRuntime`；共享状态由应用拥有。见 `examples/multi_window`。
文件放置目标使用 `View::on_file_drop` 修饰器；宿主会在运行时向命中的视图分派类型化消息之前，归一化原生文件拖放
位置和路径。`views.drop_zone` 和 `views.file_import_panel` 是基于该修饰器的视图层工作流外壳；它们的浏览动作
仍是应用消息，因此具备效果能力的应用代码可以返回一个调用 `HostAppServices::open_file` 的
`Effect::host_service` 运行器，为不可用或同步文件对话框响应分派类型化完成消息，并为待处理对话框声明
`HostAppServices::completion_subscription`。Web 文件导入可能暴露浏览器选中的文件名或句柄，而不是原生文件系统路径，
而原生宿主可以通过同一选择数组返回平台路径。

关于设置、后端特定约束和验证命令，见 [平台说明](platform-notes.md)。

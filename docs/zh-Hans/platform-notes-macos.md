# macOS 平台说明

macOS 宿主核心使用 `wzzc-dev/window/macos` 处理 AppKit 窗口、生命周期、事件、服务、文本输入会话同步、渲染器 resize 调用和重绘请求。它通过 `MacosRendererProvider` 接收具体渲染；`backend/macos/skia` 是推荐的原生主线，通过 `NSImageView` 呈现 CPU 像素帧，而 `backend/macos/wgpu` 在窗口 `NSView` 上安装 `CAMetalLayer`，用于原生 WGPU 诊断。
macOS 原生 WebView 支持使用 `WKWebView` 作为附加到窗口 content view 的宿主平台视图。当 WebKit-backed stub 已链接时，`backend/macos` 报告原生 WebView 可用，从 `DrawFrame.platform_views` 同步位置，通过 `HostEvent::WebView` 转发 WebView navigation/title/history/script 事件，并在帧渲染后 drain `HostWebViewCommandQueue` 命令。
窗口事件通过共享 `backend/host` 转换辅助方法，原生宿主绝不导入 `render/wgpu`、`render/skia`、`wgpu_mbt` 或 `moui_skia`。
macOS 服务桥通过 `NSPasteboard` 路由文本剪贴板请求，通过 `NSWorkspace` 打开 URL，通过 `NSOpenPanel` 和 `NSSavePanel` 展示打开/保存/目录对话框，通过 `NSMenu` 在当前指针位置展示命令菜单，通过共享文本文件服务契约读写 UTF-8 文本文件，并通过共享 `HostServiceBridge` 契约报告有效的 light/dark 系统外观。
原生应用入口点在创建宿主 driver 之前把报告的外观应用到运行时环境，因此组件在首次构建时就能看到系统配色方案。本地 window 后端发出 AppKit theme-change 事件时，它们使用共享 `HostEvent::ThemeChanged` 运行时路径。
右键上下文菜单请求使用同一 `NSMenu` 路径，并通过 `HostRuntimeDriver` 分派选中的 `ActionCommand`。
本地 `window/macos` 后端发出的文件拖放事件会通过 `HostEvent::DragDrop` 归一化，并分派给 `View::on_file_drop` 目标。
原生 WGPU 诊断可以使用共享 Moon Cosmic provider 或平台 provider。`backend/macos/wgpu` 默认使用 CoreText/CoreGraphics provider 执行运行时测量和字形光栅化，并显式组合 Moon Cosmic provider 作为 fallback；Objective-C CoreText stub 位于 `render/wgpu/coretext`，可选择/组合的 Cosmic provider 位于 `render/wgpu/cosmic_text`。CoreText provider 消费共享原生 `FontSpec` payload，尝试来自结构化 family stack 的具名 family，把 `ui-monospace` 和 `serif` 等泛型 CSS family 映射到合适的 macOS 字体，在 CoreText 接受时以请求的 family alias 注册应用提供的字体字节，并在名称不可用时回退到系统字体，然后渲染器再尝试组合的 Cosmic fallback。
使用 `@macos_wgpu.run_app_with_options(..., options=MacosWgpuAppOptions::new(text_engine=...))` 选择文本引擎。同一个 options 值可以携带用于 resolver-backed 次级窗口的 `HostWindowSceneResolver`，以及用于首帧 smoke 测试的 `first_frame_smoke_auto_exit`。`core` 仍只拥有中立 `FontSpec`、`TextSystem` 契约和确定性 fallback 文本系统；它不命名具体 macOS 字体文件。
`examples/showcase/macos_wgpu` 和 `examples/showcase/macos_wgpu_cosmic` 入口点仍是 WGPU 诊断；`macos_wgpu_cosmic` 显式选择 `MoonCosmic`，用于与 WGPU CoreText 路径比较。
`backend/macos` 还为必须在与 AppKit 事件 pump 相同线程上运行 `moonbitlang/async` side work 的原生应用入口点暴露 async pump 变体。`backend/macos/skia.run_app_with_options_async_pump` 保持默认阻塞 `run_app_with_options` 行为不变，但允许 `examples/mo_workbench/macos_skia` 将 Skia 窗口 pump 与其拥有的 Pi JSONL 传输 worker 交错运行。

通过导入 `wzzc-dev/moui/backend/macos/skia` 并使用 `MacosSkiaAppOptions` 选择原生主线 Skia provider。该 provider 创建 `render/skia.SkiaRasterRenderer`，在物理像素 CPU 光栅表面中绘制，按宿主缩放因子缩放 canvas，在每帧后读回 premultiplied 像素，并发送给 macOS presenter。Objective-C presenter 从像素字节构建 `CGImage`，并把它安装到附加在 content view 上的专用 `NSImageView`。macOS Skia options 默认使用与 Windows 和 Linux Skia provider 相同的系统 `FontMgr` 文本路径；测试者拥有的首帧 smoke 入口点显式选择 `EmptyTypeface`。该路径刻意与实验性 `backend/macos/wgpu` 分离；Skia 是 provider 包，不是 host-core `NativeRenderer` 变体。
对于本地真实 Skia 配置，直接 `moon run`/`moon build` 命令使用 `moui_skia` prebuild hook 和 `MOUI_SKIA_LINK_MODE=dynamic|static|auto` 来选择 Skia 库模式。辅助 smoke 运行可以传入 `--link-mode dynamic|static|auto`，为该次调用覆盖环境。
`macos_skia_provider_preflight_summary()` 暴露包级预检观察，包括所选字体解析、渲染器可用性、`moui_skia/native` 可用性、`NSImageView` presenter 路径、继承的 AppKit 宿主服务/输入/窗口就绪度、针对 Skia 文本系统/image-resource/image-resource change callback/present-count/释放诊断的显式 `HostWindowRenderer` 桥转发、剪贴板/菜单/文件对话框/open URL/system-theme/async-service 就绪度、原生上下文菜单和宿主 modal 文件对话框就绪度、原生无障碍状态，以及运行时观察边界。把该 summary 仅视为 provider/package 观察；MoUI macOS Skia 运行时 smoke 仍来自真实 Skia 渲染器像素 smoke 加测试者拥有的首帧/IME 标记。Markdown 编辑器构建覆盖仍是可选示例覆盖，并不是平台运行时观察门禁。
macOS 宿主循环在每次 present 后记录渲染器 image-resource revision，将稍后观察到的 revision 变化路由到匹配窗口的 `request_redraw`，为诊断暴露 tracked-window revision 快照，在 presented revision 建立基线后调用可选 provider 拥有的 `HostAsyncImageLoader`，并在宿主窗口释放时移除 tracked image revision 和飞行中的 image load。macOS Skia provider 创建带 post-present 异步图片加载的渲染器，因此 local/data URI image source 可以以 loading 状态建立基线，通过 `skia_image_load_completion` 完成，并在第二帧重绘；只有当异步第二帧标记存在时，真实 Skia smoke 才把这记录为匹配宿主 artifact。

## 链接标志

macOS host/Skia framework 与 Skia/Ganesh 库由 `moui/build.js` prebuild `link_configs` 注入，适用于：

- `wzzc-dev/moui/backend/macos`
- `wzzc-dev/moui/backend/macos/skia`（host framework + `MOUI_SKIA_CC_LINK_FLAGS`）

示例 `macos_skia` 入口点不应重复 AppKit/Metal/Skia 路径。它们只需要一个空的 `cc-link-flags` 覆盖，让 Moon 禁用 `tcc -run`，并对最终二进制使用系统 linker：

```moonbit
link: {
  "native": {
    "cc-link-flags": "",
  },
},
```

`backend/macos/wgpu` 包仍为 CoreText/WebKit surface 符号声明自己的 provider `cc-link-flags`。缺少 `_objc_msgSend`、`___CFConstantStringClassReference`、`CAMetalLayer` 或 Skia Ganesh 符号通常意味着 prebuild `link_configs` 没有应用，或 `tcc -run` 没有被禁用。

使用 `moon run <package> --target native --dry-run -v` 检查最终 `cc` 命令，并确认 AppKit/Metal/Skia 标志存在。如果 `moon build` 可用但 `moon run` 失败并出现 `tcc: error: file 'AppKit' not found`，则该入口点缺少空的 `cc-link-flags` 覆盖。

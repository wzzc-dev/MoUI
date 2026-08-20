# macOS 平台说明

macOS 宿主核心使用 `wzzc-dev/window/macos` 处理 AppKit 窗口、生命周期、事件、服务、文本输入会话同步、渲染器 resize 调用和重绘请求。它创建包含 `NSImageView` CPU presenter、不透明 native surface/display handles 和 `HostImageSource` 的 `HostSurface`；应用入口提供来自 `moui_skia_renderer`、`moui_sun_renderer` 或 `moui_wgpu_renderer` 的有序 provider，`backend/macos` 不导入也不构造这些 renderer。
macOS 原生 WebView 支持使用 `WKWebView` 作为附加到窗口 content view 的宿主平台视图。当 WebKit-backed stub 已链接时，`backend/macos` 报告原生 WebView 可用，从 `DrawFrame.platform_views` 同步位置，通过 composition root 转发经过校验的 `WebViewEvent`，并在帧渲染后 drain `WebViewController` task。页面通信使用版本化 JSON Bridge，公共 API 不提供 raw JavaScript evaluation。
窗口事件通过共享 `backend` 转换辅助方法，原生宿主绝不导入 `moui_wgpu_renderer`、`moui_skia_renderer`、`wgpu_mbt` 或 `moui_skia`。
macOS 服务桥通过 `NSPasteboard` 路由文本剪贴板请求，通过 `NSWorkspace` 打开 URL，通过 `NSOpenPanel` 和 `NSSavePanel` 展示打开/保存/目录对话框，通过 `NSMenu` 在当前指针位置展示命令菜单，通过共享文本文件服务契约读写 UTF-8 文本文件，并通过共享 `HostServiceBridge` 契约报告有效的 light/dark 系统外观。
原生应用入口点在创建宿主 driver 之前把报告的外观应用到运行时环境，因此组件在首次构建时就能看到系统配色方案。本地 window 后端发出 AppKit theme-change 事件时，它们使用共享 `Event::ThemeChanged` 运行时路径。
右键上下文菜单请求使用同一 `NSMenu` 路径，并通过 `HostRuntimeDriver` 分派选中的 `ActionCommand`。
本地 `window/macos` 后端发出的文件拖放事件会通过 `Event::DragDrop` 归一化，并分派给 `View::on_file_drop` 目标。
原生 WGPU 诊断的 canonical `examples/showcase/macos_wgpu` 路线使用 CoreText/CoreGraphics provider，并把 Moon Cosmic 作为内部 fallback；Objective-C CoreText stub 位于 `moui_wgpu_renderer/coretext`，fallback provider 位于 `moui_wgpu_renderer/cosmic_text`。`core` 仍只拥有中立 `FontSpec`、`TextSystem` 契约和确定性 fallback 文本系统。
`AppBuilder::run_async_pump` 使用 `backend/macos` 提供的可选异步 launch closure，让 `examples/mo_workbench/macos_skia` 将窗口 pump 与其传输 worker 交错运行。

通过导入 `wzzc-dev/moui_skia_renderer`、向 AppBuilder 添加 `@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS)`，并在 `@macos.entry` 中捕获 `MacosHostAppOptions` 来选择原生主线 Skia renderer。provider 绑定由 `@render_skia.SkiaRasterRenderer` 支撑的逐窗口 `RendererSession`，在物理像素 CPU 光栅表面中绘制，按宿主缩放因子缩放 canvas，在每帧后读回 premultiplied 像素，并发送给 macOS presenter。Objective-C presenter 从像素字节构建 `CGImage`，并把它安装到附加在 content view 上的专用 `NSImageView`。Skia provider 默认使用与 Windows 和 Linux 相同的系统 `FontMgr` 文本路径。该路径与实验性的 `moui_wgpu_renderer` provider 分离；Skia 是 renderer 包，不是 host-core 变体。
对于本地真实 Skia 配置，直接 `moon run`/`moon build` 命令使用 `moui_skia` prebuild hook 和 `MOUI_SKIA_LINK_MODE=dynamic|static|auto` 来选择 Skia 库模式。辅助 smoke 运行可以传入 `--link-mode dynamic|static|auto`，为该次调用覆盖环境。
macOS 宿主循环 drain `RendererEvent` 的 image request，只在 `backend/common/image` 保存可取消的原始字节 I/O task，并把带有相同 opaque token 的 completion 回传给选定 session。renderer session 自己负责格式检测、解码、资源缓存和 completion 诊断；宿主不保存 image revision、cache residency 或 repaint tracker。只有 applied completion 才请求匹配窗口重绘，stale/disposed token 会被忽略。只有 token completion 与第二帧标记都存在时，真实 Skia smoke 才把它记录为匹配宿主 artifact。

## 链接标志

macOS host framework 由 `moui/build.js` 为 `wzzc-dev/moui/backend/macos` 注入。Skia/Ganesh 库及其所需 framework 由 `moui_skia/build.js` 生成，并分成两个用途：`moui_skia/native/moon.pkg` 服务 binding 自测，renderer 的最终应用 `link_configs` 服务 is-main 应用。

`moui_skia_renderer/build.js` 会复用 binding 的构建变量，并只注册一次最终应用条目。binding 的 package flags 不会穿过 renderer 依赖传递到 is-main 应用；重复注册 renderer 条目才会让每个静态 archive 被追加两次。

示例 `macos_skia` 入口点不应重复 AppKit/Metal/Skia 路径。它们只需要一个空的 `cc-link-flags` 覆盖，让 Moon 禁用 `tcc -run`，并对最终二进制使用系统 linker：

```moonbit
link: {
  "native": {
    "cc-link-flags": "",
  },
},
```

宿主与 binding 包分别为 AppKit、CoreText、WebKit 和 Skia 符号声明自己的链接标志。缺少 `_objc_msgSend`、`___CFConstantStringClassReference`、`CAMetalLayer` 或 Skia Ganesh 符号通常意味着 prebuild `link_configs` 没有应用，或 `tcc -run` 没有被禁用。

使用 `moon run <package> --target native --dry-run -v` 检查最终 `cc` 命令，并确认 AppKit/Metal/Skia 标志存在。如果 `moon build` 可用但 `moon run` 失败并出现 `tcc: error: file 'AppKit' not found`，则该入口点缺少空的 `cc-link-flags` 覆盖。

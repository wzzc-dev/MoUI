# Windows 平台说明

Windows 原生示例使用 MSVC 工具链、Visual Studio C++ build tools 和 vcpkg `zlib:x64-windows`。Skia 入口点是推荐的原生主线。WGPU 诊断入口点仍使用 `wgpu_mbt` dynamic 模式和官方 `wgpu-windows-x86_64-msvc-release.zip` release。
Windows 原生 WebView 支持由 `moui_webview` prebuild 从 `.tools/webview2/` 缓存目录自动检测（通过 `scripts/windows/setup_msvc_deps.ps1 -InstallWebView2` 设置），这与 Linux 通过 `pkg-config` 自动检测 WebKitGTK 的方式匹配。fallback 构建在没有 WebView2 SDK 时编译，并报告 `HostWebViewCapabilities.available=false`；带 SDK 的构建使用以应用 HWND 为父级的 WebView2 controller，同步 `DrawFrame.platform_views`，转发受控 navigation 和 title/history/script 事件，并在渲染器呈现后 drain `HostWebViewCommandQueue` 命令。可通过设置环境变量覆盖自动检测，例如 `MOUI_WINDOWS_ENABLE_WEBVIEW2=1`、`MOUI_WINDOWS_WEBVIEW2_INCLUDE=<webview2-sdk-include>` 和 `MOUI_WINDOWS_WEBVIEW2_LINK_FLAGS=\"<WebView2Loader link flags>\"`，或设置显式的 `MOUI_WINDOWS_WEBVIEW2_STUB_CC_FLAGS` / `MOUI_WINDOWS_WEBVIEW2_CC_LINK_FLAGS` 对。当 WebView2 标志解析成功时，prebuild 会添加 `-DMOUI_WINDOWS_ENABLE_WEBVIEW2`。

## MSVC 设置

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools -e
powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\setup_msvc_deps.ps1 -InstallZlib
powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\build_windows_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -BuildOnly
powershell -ExecutionPolicy Bypass -File .\\scripts\\windows\\package_windows_app_msvc.ps1 `
  -Package examples/showcase/windows_skia `
  -AppName MoUIShowcase
```

MSVC 辅助脚本通过 `vswhere` 导入 `vcvarsall.bat`，把 `CC` 和 `CXX` 设置为 `PATH` 上的 `cl.exe`，并为 MoonBit 原生 stub 应用共享 `CL`/`LINK` 标志。它检测所选包是否导入 WGPU provider。Skia 包不会下载或打包 `wgpu_native.dll`；WGPU 诊断包设置 `MBT_WGPU_LINK_MODE=dynamic`，并把 `MBT_WGPU_NATIVE_ROOT` 指向已解压的 MSVC WGPU release。`moui_skia` 通过包 prebuild 为其 Windows Skia C++ 绑定发出 `/std:c++20` stub 标志。打包后的 MSVC 应用使用 vcpkg `zlib:x64-windows` runtime 进行原生图片解码。当 Visual Studio 捆绑的 vcpkg 拒绝直接 classic install 时，运行 `setup_msvc_deps.ps1 -InstallZlib`，使依赖通过 `.tools\\vcpkg-msvc` 下被忽略的仓库本地 manifest workspace 安装。打包应用应通过生成的 `run.cmd` 启动；WGPU 诊断包使用该包装器，使捆绑 WGPU release 元数据对动态加载器可见。

设置后要直接运行入口点：

```powershell
powershell -ExecutionPolicy Bypass -Command "& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/showcase/windows_skia --target native }"
powershell -ExecutionPolicy Bypass -Command "& { . .\\scripts\\windows\\msvc_env.ps1; moon run examples/markdown_editor/windows_skia --target native }"
```

普通 Windows Skia 入口点是交互式应用入口点。匹配宿主的首帧 smoke 应保留在测试者/后端 smoke runner 中，而不是向 Showcase 或 Markdown Editor 包添加自动退出标志。

## 链接标志

Windows Skia/Ganesh 库由 `moui/build.js` prebuild `link_configs` 注入，适用于 `wzzc-dev/moui/backend/windows/skia`（来自 `MOUI_SKIA_CC_LINK_FLAGS`）。窗口宿主的 Win32 系统库来自 `window/windows` prebuild `link_configs`。DirectWrite WGPU 文本使用 `render/wgpu/directwrite` link_configs（`-lz`）。

示例 `windows_skia` / `windows_wgpu` 入口点不应重复 Skia 或 Win32 链接标志。它们只需要一个空的 `cc-link-flags` 覆盖，让 Moon 在需要时禁用 `tcc -run`：

```moonbit
link: { "native": { "cc-link-flags": "" } },
```

检测到 SDK 时，WebView2 标志仍由 `moui_webview/build.js` 的 `backend/windows` `link_configs` 拥有。

## 宿主架构

Windows 宿主遵循与 macOS 相同的 `HostEvent` 和 `HostRuntimeDriver` 路径，平台特定所有权限于 Win32 窗口句柄、服务、生命周期、resize 处理、文本输入会话同步和重绘请求。具体渲染通过 `WindowsRendererProvider` 注入；`backend/windows/wgpu` 拥有用于诊断的 HWND/HINSTANCE WGPU surface 创建，`backend/windows/skia` 拥有原生主线的 GDI 像素 presenter。文本剪贴板请求通过 Win32 `CF_UNICODETEXT` 剪贴板 API 实现，并在宿主服务边界归一化为 UTF-8。Windows 服务桥还通过 `ShellExecuteW` 打开 URL，通过 Win32 common dialog 和 shell API 展示基本打开/保存/目录对话框，通过 `TrackPopupMenu` 在当前光标位置展示命令菜单，通过共享文本文件服务契约读写 UTF-8 文本文件，并从当前用户的 `AppsUseLightTheme` registry 值报告 light/dark 系统主题。
原生应用入口点在创建宿主 driver 之前把报告的主题应用到运行时环境，与 macOS 启动路径匹配。本地 window 后端发出 Windows theme-change 事件时，它们使用共享 `HostEvent::ThemeChanged` 运行时路径。
右键上下文菜单请求使用同一 `TrackPopupMenu` 路径，并通过 `HostRuntimeDriver` 分派选中的 `ActionCommand`。
本地 `window/windows` 后端发出的文件拖放事件会通过 `HostEvent::DragDrop` 归一化，并分派给 `View::on_file_drop` 目标，与 macOS 宿主路径匹配。
`backend/windows/wgpu` 仍是 WGPU 诊断路径，并通过与 macOS CoreText 相同的渲染器/运行时边界安装同级 `render/wgpu/directwrite` provider，并将其与 `render/wgpu/cosmic_text` 组合为 fallback。该 provider 目前是显式脚手架，使用 `render/wgpu/text_protocol` 进行 UTF-32 输入编码、私有版本化测量 payload 解析、版本化注册 payload，以及用于字形位置和 DirectWrite-private 光栅 payload 的通用 shaped-run envelope。它还通过共享单通道光栅 parser 路由光栅字形字节。其原生 stub 声明 DirectWrite 集成点，同时不返回平台 layout/raster 数据，因此在真实 DirectWrite 引擎落地前，由组合的 Cosmic fallback 处理原生文本。使用 `WindowsWgpuAppOptions::new(text_engine=...)` 选择 `MoonCosmic`。
`examples/showcase/windows_wgpu` 和 `examples/showcase/windows_wgpu_cosmic` 入口点仍是 WGPU 诊断；`windows_wgpu_cosmic` 显式选择 `MoonCosmic`，用于与 WGPU DirectWrite 脚手架加 Cosmic fallback 路径比较。`examples/showcase/windows_skia` 入口点为主线 Showcase 选择 Windows Skia provider，`examples/markdown_editor/windows_skia` 为主线编辑工作流选择它。
Markdown 编辑器还提供 `examples/markdown_editor/windows_wgpu_cosmic`，用于在编辑工作流上进行同样的显式文本 provider 比较。

## Skia Provider

通过导入 `wzzc-dev/moui/backend/windows/skia` 并使用 `WindowsSkiaAppOptions` 选择 Skia。该 provider 创建 `render/skia.SkiaRasterRenderer`，并通过 Win32 presenter 呈现 CPU 像素帧。C presenter 把 RGBA premultiplied readback 复制到 top-down 32-bit BGRA DIB buffer，并用 `StretchDIBits` blit 到 client DC。如果 `moui_skia/native` 只处于 fallback 模式，渲染器创建会带诊断被拒绝，而不是打开空 HWND。
`windows_skia_provider_preflight_summary()` 暴露包级预检观察，包括所选字体解析、渲染器可用性、`moui_skia/native` 可用性、GDI presenter 路径、继承的 Win32 宿主服务/输入/窗口就绪度、显式剪贴板/菜单/文件对话框/open URL/system-theme/async-service 就绪度、转发 Skia 文本系统/image-resource/present-count/释放诊断的 `HostWindowRenderer` 桥、原生上下文菜单和宿主 modal 文件对话框就绪度、原生无障碍状态，以及匹配宿主运行时边界，包括首帧 smoke 选项是否启用。把该 summary 及其包测试仅视为 provider/preflight 诊断；Windows 宿主循环在每次 present 后记录渲染器 image-resource revision，将稍后观察到的 revision 变化路由到匹配 HWND 的 `request_redraw`，为诊断暴露 tracked-window revision 快照，在 presented revision 建立基线后调用可选 provider 拥有的 `HostAsyncImageLoader`，并在宿主窗口释放时移除 tracked image revision 和飞行中的 image load。Windows Skia provider 创建带 post-present 异步图片加载的渲染器，但必需的异步第二帧 artifact 仍处于匹配宿主待办，直到 Windows/MSVC 运行从 Skia 入口点或 provider smoke 记录它。
通过的 Windows 运行时观察仍需要 Windows/MSVC 宿主运行 Showcase 或 Markdown Editor Skia 入口点并记录 artifact。在非 Windows 宿主上，Win32 presenter 和 service stub 可能因需要 `windows.h` 而 C 编译失败，因此 Darwin 上 `moui/backend/windows/skia` 的失败是宿主/工具链限制，而不是 Windows 运行时观察。

要使用预置本地 `wgpu-native` release 进行 WGPU 诊断，而不是使用辅助脚本管理的副本，把 `MBT_WGPU_NATIVE_ROOT` 设置为已解压 MSVC release root，或把该路径作为 `-WgpuNativeRoot` 传给 Windows 辅助脚本。MSVC dynamic root 应包含 `lib\\wgpu_native.dll` 和 `wgpu-native-meta\\wgpu-native-git-tag`。

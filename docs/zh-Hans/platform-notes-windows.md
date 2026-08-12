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
```

Showcase Windows Skia 路线是交互式应用入口。匹配宿主的首帧 smoke 应保留在 tester/backend smoke runner 中，而不是向 composition root 添加自动退出逻辑。

## 链接标志

Windows Skia/Ganesh 链接标志由 `moui_skia/build.js` 生成（来自 `MOUI_SKIA_CC_LINK_FLAGS`）：`moui_skia/native/moon.pkg` 用于 binding 自测，`moui_skia_renderer/build.js` 为最终应用只注册一个 `link_configs` 条目。窗口宿主的 Win32 系统库来自 `window/windows` prebuild `link_configs`。DirectWrite WGPU 文本使用 `moui_wgpu_renderer/directwrite` link_configs（`-lz`）。

示例 `windows_skia` / `windows_wgpu` 入口点不应重复 Skia 或 Win32 链接标志。它们只需要一个空的 `cc-link-flags` 覆盖，让 Moon 在需要时禁用 `tcc -run`：

```moonbit
link: { "native": { "cc-link-flags": "" } },
```

检测到 SDK 时，WebView2 标志仍由 `moui_webview/build.js` 的 `backend/windows` `link_configs` 拥有。

## 宿主架构

Windows 宿主遵循与 macOS 相同的 `Event` 和 `HostRuntimeDriver` 路径，平台特定所有权限于 Win32 窗口句柄、服务、生命周期、resize 处理、文本输入会话同步和重绘请求。它为 renderer 提供包含 GDI CPU presenter、不透明 native handles 和 raw-byte image source 的 `HostSurface`；具体 renderer provider 由应用入口通过 AppBuilder 注册。文本剪贴板请求通过 Win32 `CF_UNICODETEXT` 剪贴板 API 实现，并在宿主服务边界归一化为 UTF-8。Windows 服务桥还通过 `ShellExecuteW` 打开 URL，通过 Win32 common dialog 和 shell API 展示基本打开/保存/目录对话框，通过 `TrackPopupMenu` 在当前光标位置展示命令菜单，通过共享文本文件服务契约读写 UTF-8 文本文件，并从当前用户的 `AppsUseLightTheme` registry 值报告 light/dark 系统主题。
原生应用入口点在创建宿主 driver 之前把报告的主题应用到运行时环境，与 macOS 启动路径匹配。本地 window 后端发出 Windows theme-change 事件时，它们使用共享 `Event::ThemeChanged` 运行时路径。
右键上下文菜单请求使用同一 `TrackPopupMenu` 路径，并通过 `HostRuntimeDriver` 分派选中的 `ActionCommand`。
本地 `window/windows` 后端发出的文件拖放事件会通过 `Event::DragDrop` 归一化，并分派给 `View::on_file_drop` 目标，与 macOS 宿主路径匹配。
`@render_wgpu.native(...)` 是 WGPU 诊断路径，并通过与 macOS CoreText 相同的渲染器/运行时边界安装同级 `moui_wgpu_renderer/directwrite` provider，将其与 `moui_wgpu_renderer/cosmic_text` 组合为 fallback。该 provider 目前是显式脚手架；通过 factory 的 `text_engine` 参数选择 `MoonCosmic`。
`examples/showcase/windows_wgpu` 是唯一 Windows WGPU 诊断入口，使用 DirectWrite provider，并把 Cosmic 作为内部 fallback。`examples/showcase/windows_skia` 通过 `@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Windows)` 和 `@windows.entry()` 组合主线 Skia 路线。

## Skia Renderer

通过导入 `wzzc-dev/moui_skia_renderer`、向 AppBuilder 添加 `@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Windows)`，并在 `@windows.entry` 中捕获 `WindowsHostAppOptions` 来选择 Skia。provider 绑定由 `@render_skia.SkiaRasterRenderer` 支撑的逐窗口 `RendererSession`，并通过 Win32 presenter 呈现 CPU 像素帧。C presenter 把 RGBA premultiplied readback 复制到 top-down 32-bit BGRA DIB buffer，并用 `StretchDIBits` blit 到 client DC。如果 `moui_skia/native` 只处于 fallback 模式，renderer provider 会带诊断拒绝绑定，而不是打开空 HWND。
Windows 宿主循环 drain `RendererEvent` 的 image request，只保留可取消的原始字节 I/O task，并把带有相同 opaque token 的 completion 回传给选定 session。Skia 或 WGPU 自己负责解码、资源缓存和 completion 诊断；backend 不保存 image revision、cache residency 或 repaint tracker。只有 applied completion 才请求匹配 HWND 重绘，stale/disposed token 会被忽略。必需的异步第二帧 artifact 仍需要匹配 Windows/MSVC 运行记录。
通过的 Windows 运行时观察仍需要 Windows/MSVC 宿主运行 Showcase Skia 入口并记录 artifact。在非 Windows 宿主上，Win32 presenter 和 service stub 可能因需要 `windows.h` 而 C 编译失败，因此 Darwin 上 `moui_skia_renderer` 的失败是宿主/工具链限制，而不是 Windows 运行时观察。

要使用预置本地 `wgpu-native` release 进行 WGPU 诊断，而不是使用辅助脚本管理的副本，把 `MBT_WGPU_NATIVE_ROOT` 设置为已解压 MSVC release root，或把该路径作为 `-WgpuNativeRoot` 传给 Windows 辅助脚本。MSVC dynamic root 应包含 `lib\\wgpu_native.dll` 和 `wgpu-native-meta\\wgpu-native-git-tag`。

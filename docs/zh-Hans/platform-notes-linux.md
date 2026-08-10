# Linux 平台说明

`backend/linux` 是最小原生 Wayland 宿主核心。它使用 `wzzc-dev/window@0.5.4-0.1.5` Linux 包处理 Wayland 事件循环和窗口句柄，通过共享 `Event` 契约归一化窗口/输入事件，并向应用选择的 renderer provider 提供不透明 `HostSurface`。backend 只拥有 Wayland CPU presenter、raw-byte image I/O 与不透明 native surface/display handles；Skia、Sun 和 WGPU 的构造与平台策略分别留在 `moui_skia_renderer`、`moui_sun_renderer` 与 `moui_wgpu_renderer`。

Wayland 窗口路径在 compositor 暴露 `xdg-decoration` 时请求服务端装饰。如果 compositor 回退到客户端装饰，`backend/linux` 会在 MoUI 内容上方保留一个小标题栏带，把窗口标题和基本控件绘制进渲染器命令流，并转换输入坐标，使应用视图仍接收以内容为原点的坐标空间。
同一适配器消费 window 包的 Wayland key/modifier 映射和当前指针坐标：Linux 后端测试覆盖修饰键传播到共享键盘事件，以及使用窗口事件携带的位置而不是陈旧指针状态的按钮事件。该 fork 还向 MoUI 暴露 Wayland data-device 剪贴板 selection 和文件拖放事件；拖放路径在到达 `View::on_file_drop` 之前继续经过 `Event::DragDrop`。
文本输入焦点状态和 IME 请求通过其他原生宿主使用的共享 `TextInputSession` 路径同步。该会话现在为每个启用/更新请求记录 `TextInputImeRequestDiagnostics`，包括经字素归一化的 cursor/anchor 字符位置、surrounding text 的 UTF-8 偏移、逻辑 candidate-anchor 光标矩形，以及 surrounding-text payload 是否适配 window 包的 IME 契约。

## 运行时要求

Linux 运行时要求有意保持原生：

- Wayland compositor。要执行可重复的 headless 检查，使用 headless backend 运行 Weston，并把 `WAYLAND_DISPLAY` 指向其 socket。
- 只有在运行 WGPU 诊断时才需要可用 Vulkan stack。当硬件 Vulkan 不可用时，headless 软件验证可以通过 `vulkan-swrast`/Lavapipe 使用 Mesa llvmpipe。
- `wzzc-dev/window@0.5.4-0.1.5` 原生 stub 需要 Wayland 开发头文件和生成的 xdg-shell protocol source。
- compositor 提供的 `wl_data_device_manager`，用于原生剪贴板 selection 和文件拖放运行时行为。
- Linux 服务需要 XDG desktop 集成：OpenURI 在可用时通过 xdg-desktop-portal，否则回退到 desktop opener；文件对话框选择使用 xdg-desktop-portal，并以 `zenity` 作为 fallback 对话框 provider。如果 portal 不可用，请安装 `zenity`：
  ```sh
  sudo apt-get install zenity
  ```
  当 portal 和 zenity 都不可用时，文件和文件夹选择会静默返回 cancelled，应用会向 stdout 打印诊断消息。
- 最终原生链接需要 zlib / pthread / fontconfig 系统库。`moui/build.js` 通过 prebuild `link_configs` 为 `backend/linux`、`moui_skia_renderer` 和 `moui_wgpu_renderer/fontconfig` 注入这些库。Linux 示例入口点不应重复 `-lz` 或 fontconfig 栈；它们只需要一个空的 `cc-link-flags` 覆盖，让 Moon 在需要时禁用 `tcc -run`。
- glib-2.0 开发头文件和运行时库。`backend/linux` 无条件通过 GLib main loop（`g_timeout_add` / `g_source_remove`）驱动 `@services.TimerSource` subscription，因此 `moui` prebuild 通过 `pkg-config` 解析 `glib-2.0`，把得到的 `-I` include 标志送入 `stub-cc-flags`，并把 libs 合并进 `backend/linux` `link_configs` 条目。在 `pkg-config` 找不到 `glib-2.0` 的宿主上，两者都会解析为空（C stub 主体由 `#ifdef __linux__` 保护，并且只在 Linux 上有意义）。发行版特定设置可以用 `MOUI_LINUX_GLIB_STUB_CC_FLAGS` 和 `MOUI_LINUX_GLIB_CC_LINK_FLAGS` 覆盖解析出的标志。
- 原生 WebView 支持需要 WebKitGTK 开发包（`libwebkit2gtk-4.1-dev` 或 `4.0`）。`moui_webview` prebuild 通过 `pkg-config` 自动检测带 `webkit2gtk-4.1` 或 `webkit2gtk-4.0` 的 `gtk+-3.0`；如果找到，则启用原生桥。fallback 构建不链接 WebKitGTK，并报告 WebView 不可用。发行版特定设置可以用 `MOUI_LINUX_WEBKITGTK_STUB_CC_FLAGS` 和 `MOUI_LINUX_WEBKITGTK_CC_LINK_FLAGS` 覆盖检测。

## Linux RISC-V64 交叉构建

首版 Linux RISC-V64 支持是 canonical `linux/skia` 路线的实验性架构变体，
目标 ABI 固定为 `riscv64-linux-gnu`（glibc/LP64D）。它只承诺 Skia Raster
static provider 的 L0-L2 证据，不承诺 Vulkan、WGPU、WebView 或 Wayland L3。

Ubuntu Base 24.04.4 RISC-V64 与 Zig 0.16.0 的 URL 和 SHA-256 锁在
`checks/toolchains/linux-riscv64.json`。在安装了 `qemu-user-static` 的 Linux
宿主上运行：

```sh
bash scripts/prepare-linux-riscv64-sysroot.sh \
  --output .cache/moui/riscv64/sysroot/ubuntu-24.04.4-riscv64
bash scripts/linux-riscv64-cross-build.sh \
  --sysroot .cache/moui/riscv64/sysroot/ubuntu-24.04.4-riscv64 \
  --run-qemu
```

helper 使用临时 `MOON_CC`/`MOON_AR` Zig wrapper 和目标 `pkg-config`，以
Release 模式构建现有 Showcase、Skia renderer smoke 与 text/emoji smoke。
它严格检查 ELF64、RISC-V machine、LP64D glibc interpreter、static Skia、
无 Vulkan 动态依赖，并记录目标包版本、sysroot 文件 checksum、ELF 报告和
QEMU 日志。`--run-qemu` 在目标 rootfs 中使用其动态库、fontconfig 与字体；
该结果仍不是 Wayland L3。

无需下载 sysroot 的负向检查为：

```sh
bash scripts/test-linux-riscv64-cross-build.sh
```

架构证据保存在 `checks/architecture-evidence/linux-skia-riscv64.json`，必须
保持 `ready=false` 与 `runtimeL3.status=pending`。真实 RISC-V64 Wayland
设备上的 L3 仍需单独收集首帧、输入、IME、剪贴板和服务日志：

```sh
MOUI_SKIA_RENDERER=skia-raster ./linux_skia.exe
```

## 运行

在已配置 Linux 宿主上有用的聚焦命令：

```sh
moon test moui/backend/linux --target native
moon build examples/showcase/linux_skia --target native
moon run examples/showcase/linux_skia --target native
```

普通 Linux Skia 入口点是交互式应用入口点。匹配宿主的首帧 smoke 应保留在测试者/后端 smoke runner 中，并在 release note 需要时把这些日志存储到被忽略的 `artifacts/` 路径下。

当从与 macOS 或 Windows 宿主挂载同一 checkout 的 Linux VM 验证时，保持原生构建输出隔离。切换宿主前运行 `moon clean`，或把 checkout 复制到不含 `_build` 的 Linux 本地临时目录；原生 archive 和 MoonDB 文件是宿主特定的，跨宿主复用可能破坏它们。

## WGPU 诊断

WGPU 诊断 factory 会把 Linux `moui_wgpu_renderer/fontconfig` provider 与共享 Moon Cosmic fallback 组合。fontconfig provider 包括真实 fontconfig family 解析、FreeType 光栅化、HarfBuzz shaping、嵌入字体注册和 color-emoji 路径；canonical `examples/showcase/linux_wgpu` 使用 fontconfig，并把 Cosmic 作为内部 fallback。

## Skia Renderer

通过导入 `wzzc-dev/moui_skia_renderer`、向 AppBuilder 添加 `@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Linux)`，并在 `@linux.entry` 中捕获 `LinuxHostAppOptions` 来选择原生主线 Skia renderer。provider 绑定由 `@render_skia.SkiaRasterRenderer` 支撑的逐窗口 `RendererSession`，并通过 `wzzc-dev/window/linux` 暴露的狭窄 API 呈现 CPU 像素帧。该 window 包拥有 Wayland 对象并提供 `Window::present_rgba_pixels`，其实现使用可复用 `wl_shm` buffer、buffer-release 跟踪、`wl_surface_attach`、damage、commit 和 display flush。把 `wl_shm` presenter 保留在 window 后端可避免在 MoUI 中重复 Wayland registry 和 buffer 所有权。
Linux 原生 WebView 支持通过 `pkg-config` 自动检测。安装 WebKitGTK 开发包时，宿主使用 Wayland surface 句柄从 `DrawFrame.platform_views` 同步位置，在需要时把位置偏移到客户端装饰下方，从 Linux 事件循环 wait 路径 pump GTK main context，通过 `Event::WebView` 转发 navigation/title/history/JavaScript 事件，并在帧渲染后 drain `HostWebViewCommandQueue` 命令。macOS、Windows 和 Linux 原生桥在提交 navigation 前强制执行共享 `WebViewNavigationPolicy`；被阻止的 URL 会产生 `NavigationFailed` 事件。在把 Linux WebView 运行时观察提升到包级编译覆盖之外之前，仍需要匹配宿主 smoke。
Linux 宿主循环 drain `RendererEvent` 的 image request，只保留可取消的原始字节 I/O task，并把带有相同 opaque token 的 completion 回传给选定 session。`backend/linux` 只通过 `HostImageSource` 读取原始字节；renderer session 自己负责解码、资源缓存和 completion 诊断。只有 applied completion 才请求匹配 Wayland 窗口重绘，stale/disposed token 会被忽略。必需的异步第二帧 artifact 仍需要匹配 Wayland 运行记录；包测试和 capability summary 不能证明真实 compositor 呈现。

## 运行时证据

对于 Linux Skia 运行时证据，在匹配 Wayland 宿主上把这些记录为单独的被忽略 `artifacts/` 日志：

```sh
MOUI_FIRST_FRAME_EXIT=1 \\
  moon run examples/showcase/linux_skia --target native
scripts/run-window-package-smoke.sh linux --run
```

Showcase 日志必须包含宿主循环输出的 `Linux renderer presented first frame; exiting by request; title=...`，才能被引用为应用层运行时证据。window 包 smoke 仍是 Wayland 句柄、`present_rgba_pixels`、resize/redraw、IME request 状态和干净关闭的依赖层证据。

window 包为该依赖表面携带 consumer 风格 Linux smoke。在匹配 Wayland 宿主上，运行 `scripts/run-window-package-smoke.sh linux --run` 来覆盖 surface 创建、公共 Wayland 句柄、`Window::present_rgba_pixels`、resize、redraw、IME request 状态和干净关闭。只有在观察到代表性指针/键盘输入时才添加 `--require-input` 或 `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1`。Linux 剪贴板 selection、文件对话框、文本文件读写、desktop URL 打开、IME composition/cursor 几何和文件拖放都是已实现的宿主服务/输入路径，但它们仍是匹配宿主运行时证据边界：只引用实际覆盖了 desktop/compositor 服务的日志，而不是单独引用包预检 summary。从 `wzzc-dev/window@0.5.4-0.1.5` 包 smoke artifact 记录依赖层事实；把 MoUI Showcase `linux_skia` 运行作为 canonical 主线应用层观察。配置 Vulkan/WGPU stack 时，把唯一 `linux_wgpu` 路线保持为非阻塞 WGPU 诊断观察。

Linux WebView 运行时证据属于 matching-host tester/backend probe。包测试覆盖纯事件/命令映射和 fallback capability 路径，但不能证明真实 WebKitGTK view 已呈现。

`examples/showcase/linux_skia` 选择 canonical Linux Skia provider 路线。依赖原生 Skia 渲染像素前，请配置真实 Skia 链接标志。
默认 JetBrains Linux provider 链接 fontconfig、FreeType 和 HarfBuzz；当这些库可用时，`moui_skia` 会通过 fontconfig 构建系统 `FontMgr`，并在 fontconfig 未报告 family 时回退到 `/usr/share/fonts` 等常见字体目录。缺失 CJK 或 emoji 字形覆盖仍取决于已安装系统字体，完整混合文字 fallback 运行仍是文本系统后续工作，而不是 Linux 后端责任。

Linux 原生上下文菜单使用共享 `HostServiceBridge::ShowMenu` 契约。后端为 desktop menu picker 编码启用的命令行，通过 `HostRuntimeDriver` 分派选中的 `ActionCommand`，并在配置的 desktop menu tool 缺失时报告 unavailable 响应。

Linux AT-SPI 无障碍绑定保留在 `backend/linux` 后方：它从共享 semantics tree 发布 AccessKit-shaped 快照，通过共享 semantics action bridge 分派 action 回调，并在释放时报告清理诊断。匹配宿主 assistive-technology smoke 仍是运行时证据，而不是包级证明。

### 剩余缺口

剩余 Linux 缺口保持显示在 `backend/linux.readiness()` 中：

- Linux 剪贴板、文件对话框、文本文件、open URL、文本输入/IME request 和文件拖放宿主表面已经实现，但通过的平台状态仍要求匹配宿主 Wayland/desktop-service 观察，而不能只依赖包预检。

#### WSL2 验证进展（2026-07-11）

2026-07-11，在 WSL2 + WSLg（Windows 上的 Debian 13）完成了一次端到端运行时证据捕获：

```sh
bash window/scripts/capture_moui_runtime_evidence.sh linux \
  --log artifacts/platform-evidence/linux/moui-linux-runtime.log
```

**已通过：**
- ✅ Wayland surface/handles/present/cursor/resize/redraw — 全部正常工作
- ✅ **IME probe：全部 8 个字段通过**（`enabled`、`hint`、`surrounding`、`cursor`、`updated`、`updated_hint`、`updated_cursor`、`disabled` 全部为 `true`）
- ✅ Clipboard data device：`clipboard=true clipboard_roundtrip=true drag_drop=true`
- ✅ `check_ci.sh` CI 检查通过

**仍需要真实 Wayland 桌面：**
- ❌ 交互式指针/键盘输入（无法在 WSL2 中自动发送）
- ❌ 完整 destroy 序列（需要聚焦窗口交互）

IME protocol 功能已通过 WSL2 验证。完整 L3 运行时通过需要在真实 Wayland 桌面（Ubuntu 24.04+）上以 `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` 模式运行，并执行实际键盘按键和鼠标点击。

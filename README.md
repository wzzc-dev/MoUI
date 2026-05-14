# MoUI

MoUI 是一个 MoonBit GUI 框架原型。当前仓库同时包含 macOS native 原型、Windows native 试验路径，以及 JS target 的 web 示例；底层复用 `Milky2018/window` 的窗口事件循环与 `Milky2018/wgpu_mbt` 的图形能力。

## 首版范围

- 声明式 `ViewNode` 视图树。
- 几何、约束、布局、命中测试与绘制命令。
- 基础视图：`label`、`button`、`row`、`column`、`padding`。
- 后端与渲染 facade，为真实 surface 桥接预留集中接入点。
- `examples/counter`、`examples/counter_windows`、`examples/counter_web` 作为不同目标的示例入口。

## 包结构

```text
core/                     平台无关核心模型
views/                    基础视图构造器
render/                   渲染器 facade 与绘制批处理
backend/                  native / web 后端适配 facade
examples/counter/         macOS native Counter 示例
examples/counter_windows/ Windows native Counter 示例
examples/counter_web/     JS target Counter 示例
```

## 环境准备

- 已安装 MoonBit，并确保 `moon` 在 `PATH` 中。
- 如果要运行 Windows native 示例，推荐使用 MSYS2 `ucrt64` 工具链。

## macOS native 验证

```bash
export MBT_WGPU_NATIVE_ROOT=/Users/zc/Downloads/wgpu-macos-aarch64-release
moon check --target native
moon test --target native
moon fmt
moon info
moon run examples/counter --target native
```

`Milky2018/wgpu_mbt` 按上游 README 使用默认 static 模式；下游包只需要用
`"Milky2018/wgpu_mbt" @wgpu` 导入，不需要手写额外 link flags。如果本机无法访问
GitHub release 下载器，可将 `MBT_WGPU_NATIVE_ROOT` 指向已解压的官方
`wgpu-macos-aarch64-release` 目录。

## Windows native（静态 wgpu，MSYS2 / MinGW）

### 1. 安装依赖

先安装 MSYS2，并确保存在 `C:\msys64\ucrt64\bin`。然后安装 UCRT64 编译链和 Vulkan 依赖：

```powershell
C:\msys64\usr\bin\pacman.exe -S --needed --noconfirm `
  mingw-w64-ucrt-x86_64-gcc `
  mingw-w64-ucrt-x86_64-vulkan-loader `
  mingw-w64-ucrt-x86_64-vulkan-headers
```

说明：

- `mingw-w64-ucrt-x86_64-gcc` 提供 `x86_64-w64-mingw32-gcc` / `g++`
- `mingw-w64-ucrt-x86_64-vulkan-loader` 提供 `vulkan-1.dll` 与链接库
- `mingw-w64-ucrt-x86_64-vulkan-headers` 提供 Vulkan 头文件

### 2. 准备 `wgpu-native` 静态库

按 `Milky2018/wgpu_mbt` 当前 pinned 版本 `v27.0.4.0`，下载 Windows x64 GNU 包：

- 直链：[`wgpu-windows-x86_64-gnu-release.zip`](https://github.com/gfx-rs/wgpu-native/releases/download/v27.0.4.0/wgpu-windows-x86_64-gnu-release.zip)
- release 页面：[`gfx-rs/wgpu-native@v27.0.4.0`](https://github.com/gfx-rs/wgpu-native/releases/tag/v27.0.4.0)

解压后推荐放到仓库内：

```text
.local_deps/wgpu-native/v27.0.4.0/wgpu-windows-x86_64-gnu-release
```

也可以放到别的稳定目录，再通过脚本参数 `-WgpuNativeRoot` 指定。

### 3. 只构建

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1 -BuildOnly
```

### 4. 构建并运行

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1
```

这个脚本会自动：

- 将 `C:\msys64\ucrt64\bin` 追加到当前进程 `PATH`
- 设置 `CC=x86_64-w64-mingw32-gcc`
- 设置 `CXX=x86_64-w64-mingw32-g++`
- 设置 `MBT_WGPU_NATIVE_ROOT` 指向静态库 release 根目录
- 清掉 `MBT_WGPU_LINK_MODE`、`MBT_WGPU_NATIVE_LIB`、`MBT_WGPU_VULKAN_LIB` 等动态模式残留变量

如果 `wgpu-native` 没放在默认目录，可显式传入：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\counter_windows_static.ps1 `
  -BuildOnly `
  -WgpuNativeRoot C:\path\to\wgpu-windows-x86_64-gnu-release
```

等价的手动命令如下：

```powershell
$env:PATH = "C:\msys64\ucrt64\bin;$env:PATH"
$env:CC = "x86_64-w64-mingw32-gcc"
$env:CXX = "x86_64-w64-mingw32-g++"
$env:MBT_WGPU_NATIVE_ROOT = "$PWD\.local_deps\wgpu-native\v27.0.4.0\wgpu-windows-x86_64-gnu-release"
Remove-Item Env:MBT_WGPU_LINK_MODE -ErrorAction SilentlyContinue
Remove-Item Env:MBT_WGPU_NATIVE_LIB -ErrorAction SilentlyContinue
Remove-Item Env:MBT_WGPU_VULKAN_LIB -ErrorAction SilentlyContinue
moon build examples/counter_windows --target native
.\_build\native\debug\build\examples\counter_windows\counter_windows.exe
```

运行时如果提示缺少 `libwinpthread-1.dll` 或 `vulkan-1.dll`，通常是因为当前 shell 没带上 `C:\msys64\ucrt64\bin`；直接通过上面的脚本启动即可。

## web 示例

```bash
moon build examples/counter_web --target js
Copy-Item examples/counter_web/bootstrap.js _build\js\debug\build\examples\counter_web\bootstrap.js -Force
Copy-Item examples/counter_web/index.html _build\js\debug\build\examples\counter_web\index.html -Force
python -m http.server 8080 --bind 127.0.0.1 --directory _build\js\debug\build\examples\counter_web\
```
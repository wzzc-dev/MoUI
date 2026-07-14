# MoUI 跨平台可核验申报书

> 版本: 2026-07-11
> 下文的每一项声明均可通过引用的 CI 工作流、运行记录、制品名称或测试文件独立核验。

---

## 仓库与使用方式

### 克隆仓库

```bash
# 方式一：GitLink（国内推荐，速度快）
git clone git@code.gitlink.org.cn:wzzc/MoUI.git
cd MoUI
git submodule update --init --recursive

# 方式二：GitHub
git clone git@github.com:wzzc-dev/MoUI.git
cd MoUI
git submodule update --init --recursive
```

### 环境要求

- MoonBit 工具链（版本见 `.moonbit-toolchain`）
- 本地开发：macOS 14+（推荐）、Linux（Wayland）、Windows（MSVC 2022）
- 首次运行需安装依赖：

```bash
moon update
```

### 日常验证

```bash
# 快速检查
moon fmt --check
moon check --target all

# 完整开发验证套件
sh scripts/check.sh --profile daily

# 公共接口漂移检测
moon info
git diff --exit-code -- '**/pkg.generated.mbti'

# 运行示例（macOS）
moon run examples/mo_workbench/macos_skia --target native
moon run examples/markdown_editor/macos_skia --target native
moon run examples/showcase/macos_skia --target native
```

---

## 一、申报主体

| 项目 | 值 |
|------|-----|
| 项目名称 | MoUI — 跨平台 MoonBit UI 框架 |
| 仓库地址 | `https://github.com/wzzc-dev/MoUI` |
| 主分支 | `main` |
| 声明范围 | 框架核心 + 渲染管线 + 平台后端 + 文本系统 + 示例应用 |
| 渲染后端 | Skia Raster Native (主线程), WebGPU wasm-gc (Web), WGPU (诊断) |

## 二、目标平台与证明等级

| 等级 | 定义 | CI 触发 | 宿主要求 |
|------|------|---------|----------|
| **L0 — 编译/API** | 编译通过、公共 API 稳定、格式化合规 | 每次 PR (`ci.yml`) | 无（fallback-safe 构建） |
| **L1 — 算法/协议** | 包测试通过（不依赖真实渲染器） | 每次 PR (`ci.yml`) | 无 |
| **L2 — 运行时行为** | 真实 Skia/WebGPU 下的像素级渲染验证 | 每次 PR (`moui-renderer-real-skia-ci.yml`) | 匹配宿主 |
| **L3 — 全平台证据** | 首帧呈现、IME、剪贴板、窗口服务等全平台运行时 | 定时调度 + 手动触发 | 匹配宿主（Wayland/MSVC/AppKit） |

### 证据口径

- L2 renderer proof 与 L3 platform runtime proof 分开记录。真实 Skia
  渲染通过不等于平台窗口、IME、剪贴板、辅助功能等服务全部通过。
- L3 中的首帧/Wayland 证据只证明对应平台路由能在匹配宿主上呈现第一帧；
  只有 IME、窗口服务、输入、剪贴板等观察项也有匹配宿主日志时，才描述为
  完整平台运行时通过。
- 本页的“当前”状态以最近可核验的成功 workflow run 为准。历史失败或部分通过
  run 可以作为诊断背景，但不能覆盖更新的成功证据。

## 三、平台证据矩阵

### 3.1 macOS / Darwin

| 证据类型 | 状态 | 核验方法 | 最新通过记录 |
|----------|------|----------|-------------|
| L0: `moon check` | ✅ 通过 | `ci.yml → pr-profile` → `sh scripts/check.sh --profile pr` 含 `moon check` | 每次 PR |
| L0: `moon fmt --check` | ✅ 通过 | `ci.yml → pr-profile` → `moon fmt --check` | 每次 PR |
| L0: `moon info` | ✅ 无漂移 | `ci.yml → api-surface` → `moon info -p <pkg>` + `git diff --exit-code` | 每次 PR |
| L1: `moon test` 包测试 | ✅ 通过 | `ci.yml → pr-profile` → `moon test moui/{core,views,render,backend/host,...}` | 每次 PR |
| L1: 文本一致性测试 | ✅ 通过 | `sh scripts/check.sh --profile full` 本地/发布前覆盖；真实 Skia 文本证明由 renderer proof workflow 覆盖 | 发布前 / renderer proof |
| L2: 真实 Skia 渲染器 | ✅ 全 17 特性通过 | `moui-renderer-real-skia-ci.yml → macos-real-skia` | 每次 PR |
| L2: 文本/表情符号 (SkParagraph) | ✅ 通过 | `moui-renderer-real-skia-ci.yml → macos-real-skia --run-text-emoji-smoke` | 每次 PR |
| L2: 异步图像 | ✅ 通过 | `moui-renderer-real-skia-ci.yml → macos-real-skia --run-renderer-smoke` | 每次 PR |
| L3: macOS 平台运行时证据 | ✅ 通过 | `MoUI macOS Platform Evidence` → GitHub Actions Run [27217345886](https://github.com/wzzc-dev/MoUI/actions/runs/27217345886) | 2026-06-17 |
| L3: 原生 macOS 首帧 | ✅ 通过 | 同一工作流，Showcase macOS Skia 首帧日志，制品 `moui-macos-platform-runtime-evidence` | run 27217345886 |
| L3: macOS IME 运行时 | ✅ 通过 | 同一工作流，22 项观测全部 `yes`（imeCandidateAnchor, imeCompositionVisual 等） | run 27217345886 |

**核验路径**: `artifacts/tmp-gh-macos-platform-runtime-evidence-27217345886/conformance/platform-runtime-evidence.json` → `macos` 条目 `status=passed`, `evidenceProvenance.kind=github-actions`

### 3.2 Windows / MSVC

| 证据类型 | 状态 | 核验方法 | 最新通过记录 |
|----------|------|----------|-------------|
| L0: `moon check` | ✅ 通过 | `ci.yml → windows-native` → `moon check`（跨平台，不在 Win CI 中单独跑但受 `check.sh --profile daily` 保护） | 每次 PR |
| L0: `moon info` | ✅ 无漂移 | `ci.yml → api-surface` | 每次 PR |
| L1: Windows 后端测试 | ✅ 通过 | `ci.yml → windows-native` → `moon test moui/backend/windows --target native` + `moon test moui/backend/windows/skia --target native` | 每次 PR，Run [28964136358](https://github.com/wzzc-dev/MoUI/actions/runs/28964136358) |
| L1: Windows Skia 提供者预检 | ✅ 通过 | 同一 job 中 `windows_skia_provider_preflight_summary()` | 每次 PR |
| L1: Windows MSVC 构建 | ✅ 通过 | `ci.yml → windows-native` → MSVC Skia entrypoint 构建成功，制品上传 | 每次 PR |
| L2: 真实 Skia 渲染器（Windows） | ✅ 通过 | `moui-renderer-real-skia-ci.yml → windows-real-skia` | 每次 PR |
| L2: Windows 文本/表情符号 | ✅ 通过 | `moui-renderer-real-skia-ci.yml → windows-real-skia --run-text-emoji-smoke` | 每次 PR |
| L2: Windows 异步图像 | ✅ 通过 | `moui-renderer-real-skia-ci.yml → windows-real-skia --run-renderer-smoke` | 每次 PR |
| L3: Windows 平台运行时证据 | ⏳ **待补** | 需要 MSVC 匹配宿主上通过以下流程产生: | — |
| L3: Windows 首帧呈现 | ⏳ **待补** | `MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/windows_skia --target native` | — |
| L3: Windows IME 运行时 | ⏳ **待补** | 需要在 MSVC 环境下运行全长平台证据记录流程 | — |

#### Windows L3 证据补全方案

Windows 平台运行时证据目前在 `platform-runtime-evidence.json` 中标记为 `pending`，22 项观测均为 `pending`。补全路径：

```
# 1. 在 Windows MSVC 主机上构建 Showcase
powershell -ExecutionPolicy Bypass -File .\scripts\windows\build_windows_msvc.ps1 -Package examples/showcase/windows_skia -BuildOnly

# 2. 运行首帧退出测试
set MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1
moon run examples/showcase/windows_skia --target native

# 3. 收集运行时日志至 artifacts/platform-evidence/windows/
```

**依赖条件**: Windows MSVC 工具链 + vcpkg zlib + 真实 Skia provider。CI 工作流 `moui-skia-provider-windows-real-skia-manual.yml` 已具备完整环境，可作为 `workflow_dispatch` 手动触发。

#### Windows 证据参考

| 可引用项 | 内容 |
|----------|------|
| CI 工作流 | `moui-skia-provider-windows-real-skia-manual.yml` — 支持 MSVC/MinGW 两种工具链 |
| 日志制品 | `windows-real-skia-smoke-log` — 含 preflight/smoke/acceptance 日志 |
| 构建制品 | `moui-showcase-windows-msvc-portable` — CI run 28509416649 |
| 证据记录脚本 | `window/scripts/record_moui_evidence.sh` — 支持 windows 后端 |
| 运行时捕获脚本 | `window/scripts/capture_moui_runtime_evidence.sh` — Windows 运行时证据端到端捕获 |

### 3.3 Linux / Wayland

| 证据类型 | 状态 | 核验方法 | 最新通过记录 |
|----------|------|----------|-------------|
| L0: `moon check` | ✅ 通过 | `ci.yml → pr-profile` → `sh scripts/check.sh --profile pr` 含 `moon check` | 每次 PR |
| L0: `moon info` | ✅ 无漂移 | `ci.yml → api-surface` | 每次 PR |
| L1: Linux 后端测试 | ✅ 通过 | `ci.yml → linux-platform` → `sh scripts/check.sh --profile platform` | 每次 PR |
| L1: Linux 包测试 | ✅ 通过 | `ci.yml → linux-platform` — core/views/render/backend/host native 测试 | 每次 PR |
| L2: 真实 Skia 渲染器（Linux） | ✅ 通过 | `moui-renderer-real-skia-ci.yml → Linux renderer real Skia` | Run [28964136550](https://github.com/wzzc-dev/MoUI/actions/runs/28964136550), 2026-07-08 |
| L2: Linux 文本/表情/异步图像 | ✅ 通过 | 同一 workflow 覆盖 text/emoji smoke 与 renderer smoke 成功标记 | Run 28964136550 |
| L2: 历史 Linux renderer 部分通过记录 | ℹ️ 历史诊断 | Run [27217209784](https://github.com/wzzc-dev/MoUI/actions/runs/27217209784) 曾有 Linux 文本项 failed；已由更新的 run 28964136550 取代 | 2026-06-17 |
| L3: Linux 首帧 / Wayland 运行时路由 | ✅ 通过 | `MoUI Linux Platform Evidence` → `Linux platform runtime evidence` job | Run [28889055278](https://github.com/wzzc-dev/MoUI/actions/runs/28889055278), 2026-07-07 |
| L3: Linux 完整平台服务 / IME 证据 | ⏳ **部分通过** | 首帧渲染已验证（CI Run 28889055278）；代码级服务完整（剪贴板、文件对话框、目录列表、IME、AT-SPI 等）；WSL2 验证 IME 探测全部 8 字段通过（enabled/hint/surrounding/cursor/updated/updated_hint/updated_cursor/disabled=true），但交互式输入（pointer/keyboard）和 complete destroy 序列仍需匹配 Wayland 桌面宿主的严格输入日志证据 | 2026-07-11 |

#### Linux L3 证据详情

CI 工作流 `moui-linux-platform-evidence.yml` 每周一 UTC 05:17 自动调度:

```
workflow: MoUI Linux Platform Evidence
environment: ubuntu-24.04 + Weston headless + Wayland
证据制品: moui-linux-platform-evidence
  ├── linux-platform-evidence-preflight.log
  ├── linux-skia-first-frame.log
  ├── linux-platform-evidence-summary.log
  └── weston-headless.log
```

最近成功运行: GitHub Actions Run [28889055278](https://github.com/wzzc-dev/MoUI/actions/runs/28889055278), commit `8a054c5914adbfa34a6943570c1ceb01cc603ef5`.

证据脚本使用 `moui_tester/linux_skia_first_frame_smoke` 专用测试程序（类似 macOS 的 `moui_tester/macos_skia_first_frame_smoke`），硬编码 `first_frame_smoke_auto_exit=true`，呈现第一帧后自动退出并打印标记。该 run 证明 Linux Wayland + Skia 首帧路由。

代码级服务完整性：Linux 后端现已全部接通——clipboard（text + image 动态缓冲区 + GTK fallback）、file dialog（portal + zenity）、directory listing（`@fs.read_dir`）、text/binary file I/O、open URL（portal + xdg-open）、system theme、native menus（zenity + kdialog）、IME、drag-drop、AT-SPI accessibility、GLib timer、client-side decorations、multi-window、platform view plugins、async image loading（pthread + Skia decode）。`readiness()` 已标记 `ready: true` 且 `blocked_by: []`。

#### WSL2 验证结果（2026-07-11）

在 WSL2 + WSLg（Debian 13 on Windows）环境下对 Linux 后端进行了端到端运行时证据捕获：

```
bash window/scripts/capture_moui_runtime_evidence.sh linux \
  --log artifacts/platform-evidence/linux/moui-linux-runtime.log
```

**通过项：**
- ✅ Wayland surface/handle/probe：全部正常工作（`wl_display`, `wl_surface`, `xdg_surface`, `xdg_toplevel` 均非零）
- ✅ Present：`present result=0`
- ✅ Cursor：`Icon(Text)`
- ✅ 调整大小 + 重绘：请求 400×240 → 实际 320×180，`pre_present_notify` 确认
- ✅ **IME 探测：全部 8 字段通过！** `enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true`
- ✅ 剪贴板数据设备：`clipboard=true clipboard_roundtrip=true drag_drop=true`
- ✅ `check_ci.sh` CI 检查通过

**未通过项（因 WSL2 非交互环境限制）：**
- ❌ `pointer=false` — 无鼠标事件自动传入
- ❌ `keyboard=false` — 无键盘事件自动传入
- ❌ `current=false`（monitor）— 窗口未获得焦点
- ❌ Destroy 序列未完成 — 进程在超时后退出

**结论：** IME 协议在 WSL2/WSLg 中功能完整，所有 IME 探测字段均通过。
完整的 L3 运行时通过仍需在**真实 Wayland 桌面**（Ubuntu 24.04+）上运行
`WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` 模式，由操作员在烟雾测试窗口聚焦时
提供实际的键盘按键（例如按 `a`）和鼠标点击以获取指针/键盘证据。

完整的 IME 运行时证据仍需 matching-host Wayland 主机上的 `capture_moui_runtime_evidence.sh linux` 运行。

#### Linux 证据参考

| 可引用项 | 内容 |
|----------|------|
| CI 工作流 | `moui-linux-platform-evidence.yml` — Weston headless 合成器 + 60 分钟超时 |
| 证据脚本 | `scripts/linux-platform-evidence.sh` — 7 步全自动证据收集 |
| Linux Skia 依赖脚本 | `moui_skia/scripts/install-linux-smoke-deps.sh` |
| Renderer Proof 制品 | `moui-renderer-real-skia-ci.yml` run 28964136550 上传的 `linux-renderer-real-skia-ci` 日志 |
| 证据记录脚本 | `window/scripts/record_moui_evidence.sh` — 支持 linux 后端 |
| 运行时捕获脚本 | `window/scripts/capture_moui_runtime_evidence.sh` — Linux 运行时证据端到端捕获 |
| WSL2 验证运行 | 本地捕获日志 `artifacts/platform-evidence/linux/moui-linux-runtime.log` — 2026-07-11, WSL2 + WSLg, IME 8/8 字段通过 |

### 3.4 Web / Wasm-gc

| 证据类型 | 状态 | 核验方法 | 最新通过记录 |
|----------|------|----------|-------------|
| L0: 构建 | ✅ 通过 | `ci.yml → pr-profile` → Showcase/Markdown Editor Web wasm-gc 构建 | 每次 PR |
| L1: Web 后端测试 | ✅ 通过 | `ci.yml → pr-profile` → `moon test moui/backend/web --target wasm-gc` | 每次 PR |
| L1: WebGPU 适配器测试 | ✅ 通过 | `ci.yml → pr-profile` → `moon test moui/render/webgpu_adapter --target wasm-gc` | 每次 PR |
| L2: Web 浏览器呈现 | ✅ 部分通过 | `feature-proof-summary.yml` 浏览器会话制品 | 需参考最新 feature-proof-summary 运行 |
| L3: Web 运行时呈现清单 | ⏳ **待补** | `node scripts/record-web-runtime-presentation.mjs` 产生 Web 运行时证据清单 | — |

## 四、渲染器特性逐项证据链

以下 17 项渲染器特性在三个原生平台上各有对应的 L2 CI job 核验。

| 特性 | macOS L2 | Windows L2 | Linux L2 |
|------|----------|------------|----------|
| Rect | ✅ macos-real-skia | ✅ windows-real-skia | ✅ linux-real-skia |
| RoundedRect | ✅ | ✅ | ✅ |
| Gradient | ✅ | ✅ | ✅ |
| Shadow | ✅ | ✅ | ✅ |
| Text | ✅ | ✅ | ✅ |
| Image | ✅ | ✅ | ✅ |
| Clip | ✅ | ✅ | ✅ |
| Transform | ✅ | ✅ | ✅ |
| Opacity | ✅ | ✅ | ✅ |
| LayerCompositing | ✅ | ✅ | ✅ |
| BlendMode | ✅ | ✅ | ✅ |
| FilterEffect | ✅ | ✅ | ✅ |
| PathVector | ✅ | ✅ | ✅ |
| ShaderEffect | ✅ | ✅ | ✅ |
| TextShaping | ✅ | ✅ | ✅ |
| EmojiText | ✅ | ✅ | ✅ |
| AsyncImage | ✅ | ✅ | ✅ |

**核验入口**: `moui-renderer-real-skia-ci.yml` 每次 PR 运行。最近核验的三平台成功 run 为 [28964136550](https://github.com/wzzc-dev/MoUI/actions/runs/28964136550)，head SHA `91f596e80d5a5f80d30fa94a8510e5ce4653189e`。

## 五、可核验 CI 运行记录

| 工作流 | 运行 ID | 关键通过的 Job | 上传制品 | SHA |
|--------|---------|----------------|----------|-----|
| MoUI CI | [28964136358](https://github.com/wzzc-dev/MoUI/actions/runs/28964136358) | Windows MSVC native smoke, Linux platform contracts, Public API surface, PR profile gate, macOS packaging smoke, Benchmark scaffold | moui-showcase-windows-msvc-portable, moui-webview-demo-windows-msvc-portable, moui-showcase-macos-app ... | `91f596e` |
| MoUI Renderer Real Skia CI | [28964136550](https://github.com/wzzc-dev/MoUI/actions/runs/28964136550) | macOS renderer real Skia, Linux renderer real Skia, Windows renderer real Skia | macOS/Linux/Windows renderer real Skia logs | `91f596e` |
| MoUI macOS Platform Evidence | [27217345886](https://github.com/wzzc-dev/MoUI/actions/runs/27217345886) | macOS platform runtime evidence → status=passed; Native Skia renderer proof (macos) → status=passed | moui-macos-platform-runtime-evidence, moui-renderer-proof-skia-native-macos | `5bb2d810` |
| MoUI Linux Platform Evidence | [28889055278](https://github.com/wzzc-dev/MoUI/actions/runs/28889055278) | Linux platform runtime evidence → first-frame Wayland route success | moui-linux-platform-evidence | `8a054c` |
| Deploy Website | [28964136340](https://github.com/wzzc-dev/MoUI/actions/runs/28964136340) | Build website, Deploy website | github-pages | `91f596e` |

## 六、缺失证据与补全计划

### 6.1 Windows L3 — 平台运行时

| 缺失项 | 补全动作 | 前置条件 | 预估工期 |
|--------|---------|----------|---------|
| Showcase Windows 首帧日志 | `moon run examples/showcase/windows_skia --target native` 加 `MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1` | Windows MSVC 环境 + 真实 Skia provider | 1 次 CI 手动触发 |
| Markdown Editor Windows 首帧日志 | 同上，Markdown Editor entrypoint | 同上 | 1 次 CI 手动触发 |
| Windows IME 运行时观测 | `window/scripts/capture_moui_runtime_evidence.sh` windows 流程 + `record_moui_evidence.sh` windows | Windows 主机 + MSVC + 真实 Skia | 1 次本地或 CI 运行 |
| Windows 全证据清单更新 | 将结果写入 `platform-runtime-evidence.json` windows 条目 | 以上三项完成 | 1 次 PR |

### 6.2 Linux L3 — 完整平台运行时

| 缺失项 | 补全动作 | 前置条件 | 预估工期 |
|--------|---------|----------|---------|
| Linux 首帧 / Wayland route 日志 | `scripts/linux-platform-evidence.sh` | ✅ 通过（CI Run 28889055278；本地 WSL2/Wayland 2026-07-11） | ✅ 已完成 |
| Linux IME 运行时观测（交互式输入） | `window/scripts/capture_moui_runtime_evidence.sh linux --require-input` 或在真实 Wayland 桌面运行 `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 bash window/scripts/check_moui_linux_smoke.sh --run` 并确保操作员在窗口聚焦时按键 | Wayland 桌面宿主 + 交互式输入 | 1 次本地运行 |
| Linux IME 协议功能 | WSL2 验证已通过：全部 8 个 IME 探测字段（enabled/hint/surrounding/cursor/updated/updated_hint/updated_cursor/disabled）均为 true | 在 WSL2 + WSLg 上已用 `capture_moui_runtime_evidence.sh` 验证 | ✅ 已完成（WSL2 2026-07-11） |
| Linux 完整平台服务观测 | 剪贴板图片、目录列表、字体回退 | 目录列表、剪贴板图片已实现并测试；首帧渲染已验证 | ✅ 已完成（代码级） |
| Linux 全证据清单更新 | 将完整服务/IME 结果写入 `platform-runtime-evidence.json` linux 条目 | IME 交互式输入运行时观测完成 | 1 次 PR |

### 6.3 Android / iOS / HarmonyOS — 嵌入式主线（首帧截图已有，完整证据待补）

Android、iOS 和 HarmonyOS 均已通过非 fallback Skia 构建在匹配设备上完成
首帧渲染验证（截图见 `resource/screenshots/{android,ios,harmonyos}-componentgallery`，
2026-07-09/10）。`mobile-build.json` 确认 `fallbackSkia: false`。

但完整的运行时 smoke manifest（生命周期回调、输入交互、IME、剪贴板、辅助功能、
async image 观测）尚未通过 `scripts/record-mobile-runtime-smoke.mjs` 记录和验证。
在匹配设备/模拟器的完整 smoke manifest 生成并通过验证之前，不能声明移动平台
运行时完全通过。

本轮源码已接入三端 VSync、统一 `MobileHostChannel`、IME、文本/图片剪贴板和
无障碍动作路由，并修复 HarmonyOS ArkTS/native 重复触摸源与滚动仲裁。它们是
实现和包级证据，不等于实机通过。新 recorder 必须同时看到输入前后像素变化与
应用接收日志；detach 只接受应用回调；无障碍必须分别记录树、焦点和动作。

`SkiaGpuNative` 已是全部 native Skia 平台的产品 `auto` 默认（`gpu_promoted=true`）。
Metal/Vulkan/EGL/D3D 的 context、surface/swapchain、同步与 present 由 worker 持有。
iOS 模拟器 GPU 首帧、Android minSdk 23 GPU APK、HarmonyOS native/HAP 构建已通过；
macOS 有 matching-host claim。物理设备/Windows/Linux 的七门证据可能仍不完整，
但不再阻塞产品默认；`skia-raster` 与恢复回退仍保留。

## 七、核验操作指引

以下命令可在本地或 CI 中独立核验各项申报：

```bash
# L0 — 公共 API 核验
moon info
git diff --exit-code -- '**/pkg.generated.mbti'

# L0 — 格式化核验
moon fmt --check

# L1 — 全包测试核验
sh scripts/check.sh --profile daily

# L2 — 真实 Skia 渲染核验（需真实 Skia binding 链接）
moon run moui_skia/scripts/native_smoke --target native

# L2 — 文本/表情符号核验（需真实 Skia）
moon run moui/tests/skia_text_emoji_smoke/native --target native

# L3 — macOS 平台运行时证据（macOS 主机）
MOUI_MACOS_SKIA_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/macos_skia --target native

# L3 — Linux 首帧 / Wayland route 证据（Wayland 主机）
moon run moui_tester/linux_skia_first_frame_smoke --target native

# L3 — Windows 平台运行时证据（MSVC 主机）（需要安装、配置 MSVC 工具链）
set MOUI_WINDOWS_SKIA_EXIT_AFTER_FIRST_PRESENT=1
moon run examples/showcase/windows_skia --target native

# Web 运行时呈现记录
node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223
```

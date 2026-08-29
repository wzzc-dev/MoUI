# MoUI 跨平台可核验申报书

> 版本: 2026-08-29
> 下文的每一项声明均可通过引用的 CI 工作流、运行记录、制品名称或测试文件独立核验。

---

## 产品承诺矩阵（product_class）

本表是对外「能不能当产品主线用」的单一口径。它与 `docs/maintenance.md` 的
mainline/diagnostic **工程门禁** 不同：后者描述日常 `check.sh` 范围，不描述
OS 产品完成度。

| 平台 | product_class | `ready` 语义（宿主 API） | 证据摘要 | 尚未承诺 |
|------|---------------|-------------------------|----------|----------|
| **macOS** | **committed** | 产品主线可用 | L0–L2 PR 门禁 + L3 平台运行时 passed（`checks/platforms/macos.json`） | — |
| **Web** | **committed** | 产品主线可用 | 每日 wasm-gc + browser WebGPU；`checks/platforms/web.json` runtimeL3=passed | — |
| **Windows** | **committed** | 产品主线可用 | L0–L2 PR/real Skia；匹配宿主 Win32 运行时 smoke + Showcase 首帧（`checks/platforms/windows.json` `runtimeL3=passed`，2026-08-29，ADR 0031） | — |
| **Linux** | **committed_with_gaps** | 宿主 `ready=true` = 代码路径可用，**≠** L3 全绿 | L0–L2 + 首帧 L3；交互 IME 等 partial | 完整交互 L3 |
| **Android** | **experimental** | `ready=false`：window-hosted template + session 可编译且 host-sim tests 通过，但不做任何开发/演示可用性或产品承诺；`status=experimental` | `HostCmd` host-sim 和 MoUI adapter tests 通过 | matching-device presenter/service evidence；GPU seven-gate claim；可用性承诺 |
| **iOS** | **experimental** | 同上 | `HostCmd` host-sim 和 MoUI adapter tests 通过 | matching simulator/device presenter 和 VoiceOver evidence；GPU seven-gate claim；可用性承诺 |
| **HarmonyOS** | **experimental** | 同上 | `HostCmd` host-sim 和 MoUI adapter tests 通过 | signed-device presenter/service evidence；GPU seven-gate claim；可用性承诺 |

### Linux RISC-V64 架构变体

`linux-skia-riscv64` 登记在 `checks/platform-matrix.json` 的
`architectureVariants` 中，不是新的 canonical platform route。它使用
`riscv64-linux-gnu`、Tier 3、`experimental`、`ready=false`，并固定为
Skia Raster static provider。

| 证据级别 | 首版契约 | 晋升边界 |
|---|---|---|
| L0 | 交叉构建现有 `examples/showcase/linux_skia` 的 ELF64 RISC-V binary | 锁定 sysroot/Zig、LP64D interpreter 与 ELF report |
| L1 | 目标包、header、`.pc` 与 link 检查 | GLib、Wayland、fontconfig、FreeType、HarfBuzz |
| L2 | QEMU rootfs 内的 Skia renderer 与 text/emoji smoke | pixels、async second frame、真实 SkParagraph marker |
| L3 | `pending` | 真实 RISC-V64 Wayland 设备的首帧、输入、IME、剪贴板与服务 |

独立证据文件为
`checks/architecture-evidence/linux-skia-riscv64.json`。QEMU L2 不得提升
`checks/platforms/linux.json` 或 Linux Wayland L3。

### 禁止的两种错误表述

1. **不要**写「六端均已产品就绪 / L3 全绿」。
2. **不要**写「三个嵌入运行时后端完全不行 / 生命周期胶水代码未接线 / 只有 Counter 应用」——嵌入运行时后端、IME/clipboard/a11y 通道已存在；缺口在 **证据闭环与晋升**，不是没有宿主路线。

### 三套状态不要混

| 维度 | 含义 |
|------|------|
| 宿主可用性 (`ready`) | 仅当开发/演示可以依赖 window-hosted template + MoUI session 时为 `true`（对齐 Linux：代码完整可用）；`experimental` 平台在匹配设备证据落地前为 `false` |
| 运行时证据 (`status` / smoke) | 匹配宿主观察：`passed` / `partial` / packaging-only；移动端 product_class `experimental` 刻意低于 `runtime_partial` |
| 产品完整承诺 | L3 全绿 + `actualPresenterRoute` verified + GPU seven-gate claimed |

移动端 product_class `experimental` 的含义是：代码路径可编译且 host-sim
tests 通过，但在匹配设备 presenter/service 证据记录之前，**不**做任何
开发/演示可用性或产品承诺。这是对先前 `runtime_partial` 声明的**降级**
（见 ADR 0021）；它**不是**宣称后端不可用。

结构化状态源：`checks/platforms/{macos,windows,linux,web,android,ios,harmonyos}.json`。
**无新证据时不得抬高** `runtimeL3` / `actualPresenterRoute`。

GPU 产品默认（`NativeGpuPlatform::gpu_promoted=true`）与 seven-gate **质量声明** 双轨；见 ADR 0006。

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
| 渲染后端 | Skia Raster Native（主线程）, WebGPU wasm-gc（Web）, WGPU（实验性；工程门禁 `diagnostic`） |

## 二、目标平台与证明等级

| 等级 | 定义 | CI 触发 | 宿主要求 |
|------|------|---------|----------|
| **L0 — 编译/API** | 编译通过、公共 API 稳定、格式化合规 | 每次 PR (`ci.yml`) | 无（fallback-safe 构建） |
| **L1 — 算法/协议** | 包测试通过（不依赖真实渲染器） | 每次 PR (`ci.yml`) | 无 |
| **L2 — 运行时行为** | 真实 Skia/WebGPU 下的像素级渲染验证 | 每次 PR (`moui-renderer-real-skia-ci.yml`) | 匹配宿主 |
| **L3 — 全平台证据** | 首帧呈现、IME、剪贴板、窗口服务等全平台运行时 | 定时调度 + 手动触发 | 匹配宿主（Wayland/MSVC/AppKit） |

### 证据口径

- L2 渲染器证明与 L3 平台运行时证明分开记录。真实 Skia
  渲染通过不等于平台窗口、IME、剪贴板、辅助功能等服务全部通过。
- L3 中的首帧/Wayland 证据只证明对应平台路由能在匹配宿主上呈现第一帧；
  只有 IME、窗口服务、输入、剪贴板等观察项也有匹配宿主日志时，才描述为
  完整平台运行时通过。
- 本页的“当前”状态以最近可核验的成功工作流运行记录为准。历史失败或部分通过
  运行记录可以作为诊断背景，但不能覆盖更新的成功证据。

## 三、平台证据矩阵

### 3.1 macOS / Darwin

| 证据类型 | 状态 | 核验方法 | 最新通过记录 |
|----------|------|----------|-------------|
| L0: `moon check` | ✅ 通过 | `ci.yml → pr-profile` → `sh scripts/check.sh --profile pr` 含 `moon check` | 每次 PR |
| L0: `moon fmt --check` | ✅ 通过 | `ci.yml → pr-profile` → `moon fmt --check` | 每次 PR |
| L0: `moon info` | ✅ 无漂移 | `ci.yml → api-surface` → `moon info -p <pkg>` + `git diff --exit-code` | 每次 PR |
| L1: `moon test` 包测试 | ✅ 通过 | `ci.yml → pr-profile` → `moon test moui/{core,views,render,backend,...}` | 每次 PR |
| L1: 文本一致性测试 | ✅ 通过 | `sh scripts/check.sh --profile full` 本地/发布前覆盖；真实 Skia 文本证明由渲染器证明工作流覆盖 | 发布前 / 渲染器证明 |
| L2: 真实 Skia 渲染器 | ✅ 全 17 特性通过 | `moui-renderer-real-skia-ci.yml → macos-real-skia` | 每次 PR |
| L2: 文本/表情符号 (SkParagraph) | ✅ 通过 | `moui-renderer-real-skia-ci.yml → macos-real-skia --run-text-emoji-smoke` | 每次 PR |
| L2: 异步图像 | ✅ 通过 | `moui-renderer-real-skia-ci.yml → macos-real-skia --run-renderer-smoke` | 每次 PR |
| L3: macOS 平台运行时证据 | ✅ 通过 | `MoUI macOS Platform Evidence` → GitHub Actions 运行记录 [27217345886](https://github.com/wzzc-dev/MoUI/actions/runs/27217345886) | 2026-06-17 |
| L3: 原生 macOS 首帧 | ✅ 通过 | 同一工作流，Showcase macOS Skia 首帧日志，制品 `moui-macos-platform-runtime-evidence` | 运行记录 27217345886 |
| L3: macOS IME 运行时 | ✅ 通过 | 同一工作流，22 项观测全部 `yes`（imeCandidateAnchor, imeCompositionVisual 等） | 运行记录 27217345886 |

**核验路径**: `artifacts/tmp-gh-macos-platform-runtime-evidence-27217345886/conformance/platform-runtime-evidence.json` → `macos` 条目 `status=passed`, `evidenceProvenance.kind=github-actions`

### 3.2 Windows / MSVC

| 证据类型 | 状态 | 核验方法 | 最新通过记录 |
|----------|------|----------|-------------|
| L0: `moon check` | ✅ 通过 | `ci.yml → windows-native` → `moon check`（跨平台，不在 Win CI 中单独跑但受 `check.sh --profile daily` 保护） | 每次 PR |
| L0: `moon info` | ✅ 无漂移 | `ci.yml → api-surface` | 每次 PR |
| L1: Windows 后端测试 | ✅ 通过 | `ci.yml → windows-native` → `moon test moui/backend/windows --target native` + `moon test moui_skia_renderer --target native` | 每次 PR，运行记录 [28964136358](https://github.com/wzzc-dev/MoUI/actions/runs/28964136358) |
| L1: Windows Skia composition wiring | ✅ 通过 | 同一作业构建 `examples/showcase/windows_skia`，并运行 backend 与 renderer package tests | 每次 PR |
| L1: Windows MSVC 构建 | ✅ 通过 | `ci.yml → windows-native` → MSVC Skia 入口点构建成功，制品上传 | 每次 PR |
| L2: 真实 Skia 渲染器（Windows） | ✅ 通过 | `moui-renderer-real-skia-ci.yml → windows-real-skia` | 每次 PR |
| L2: Windows 文本/表情符号 | ✅ 通过 | `moui-renderer-real-skia-ci.yml → windows-real-skia --run-text-emoji-smoke` | 每次 PR |
| L2: Windows 异步图像 | ✅ 通过 | `moui-renderer-real-skia-ci.yml → windows-real-skia --run-renderer-smoke` | 每次 PR |
| L3: Windows 平台运行时证据 | ✅ 通过 | 匹配宿主采集（2026-08-29）：`window/scripts/capture_moui_runtime_evidence.sh windows` 全链路 —— `check_ci.sh` + 运行时 smoke + `check_moui_runtime_log.sh windows` 转录校验 | 本地匹配宿主运行，MSVC 2022（ADR 0031） |
| L3: Windows 首帧呈现 | ✅ 通过 | `scripts/windows-platform-evidence.sh` → `MOUI_FIRST_FRAME_EXIT=1 moon run examples/showcase/windows_skia --target native`；标记 `Windows renderer presented first frame; exiting by request; title=MoUI Showcase`；`MoUI Windows Platform Evidence` 工作流按周核验 | 2026-08-29（本地匹配宿主） |
| L3: Windows IME 运行时 | ✅ 通过 | 运行时转录 IME 探测行 `enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true`，且 IME 文本投递（`ime text=a`）先于 `ready` | 2026-08-29（本地匹配宿主） |

#### Windows L3 证据记录

Windows 平台运行时证据已于 2026-08-29 在 Windows 匹配宿主（MSVC 2022，部署底线 Windows 10）上采集。完整链路：

```
# 1. window 仓库：匹配宿主 CI 分支 + 运行时 smoke 转录
bash window/scripts/capture_moui_runtime_evidence.sh windows \
  --log <moui>/artifacts/platform-evidence/windows/moui-windows-runtime.log

# 2. MoUI Showcase 首帧呈现
bash scripts/windows-platform-evidence.sh
```

运行时转录满足 `check_moui_runtime_log.sh windows` 契约：surface 探测、非零 HWND/HINSTANCE 且 raw display/window 身份保持一致、monitor/current-monitor 探测含原生 id、cursor `Icon(Text)`、IME 探测行 `enabled=true hint=true surrounding=true cursor=true updated=true updated_hint=true updated_cursor=true disabled=true`、resize 投递与 `pre_present_notify` 重绘、pointer 与键盘 `key=a` / IME `text=a` 投递（均先于 `ready`）、以及 `ready → destroy requested → destroyed → finished` 完整销毁序列。原始转录与 preflight/summary 日志保存在 `artifacts/platform-evidence/windows/`（生成证据不入 git）。

**依赖条件**: Windows MSVC 2022 工具链 + vcpkg zlib + 真实 Skia provider（release 缓存按 `moui_skia/skia-provider-lock.json` 自动解析）。

#### Windows 证据参考

| 可引用项 | 内容 |
|----------|------|
| CI 工作流 | `moui-windows-platform-evidence.yml` — 按周采集 Showcase 首帧证据 |
| 首帧驱动脚本 | `scripts/windows-platform-evidence.sh` — 解析 Skia、构建、运行并校验标记 |
| 运行时转录驱动脚本 | `window/scripts/capture_moui_runtime_evidence.sh windows` + `check_moui_windows_smoke.sh --run` + `check_moui_runtime_log.sh windows` |
| 证据记录脚本 | `window/scripts/record_moui_evidence.sh windows` — 标准证据条目 |
| MSVC 工具链支持 | `moui-skia-provider-windows-real-skia-manual.yml` — 支持 MSVC/MinGW 两种工具链，制品 `windows-real-skia-smoke-log` |
| 构建制品 | `moui-showcase-windows-msvc-portable` — CI 运行记录 28509416649 |

### 3.3 Linux / Wayland

| 证据类型 | 状态 | 核验方法 | 最新通过记录 |
|----------|------|----------|-------------|
| L0: `moon check` | ✅ 通过 | `ci.yml → pr-profile` → `sh scripts/check.sh --profile pr` 含 `moon check` | 每次 PR |
| L0: `moon info` | ✅ 无漂移 | `ci.yml → api-surface` | 每次 PR |
| L1: Linux 后端测试 | ✅ 通过 | `ci.yml → linux-platform` → `sh scripts/check.sh --profile platform` | 每次 PR |
| L1: Linux 包测试 | ✅ 通过 | `ci.yml → linux-platform` — core/views/render/backend native 测试 | 每次 PR |
| L2: 真实 Skia 渲染器（Linux） | ✅ 通过 | `moui-renderer-real-skia-ci.yml → Linux renderer real Skia` | 运行记录 [28964136550](https://github.com/wzzc-dev/MoUI/actions/runs/28964136550), 2026-07-08 |
| L2: Linux 文本/表情/异步图像 | ✅ 通过 | 同一工作流覆盖 text/emoji smoke 与 renderer smoke 成功标记 | 运行记录 28964136550 |
| L2: 历史 Linux renderer 部分通过记录 | ℹ️ 历史诊断 | 运行记录 [27217209784](https://github.com/wzzc-dev/MoUI/actions/runs/27217209784) 曾有 Linux 文本项 failed；已由更新的运行记录 28964136550 取代 | 2026-06-17 |
| L3: Linux 首帧 / Wayland 运行时路由 | ✅ 通过 | `MoUI Linux Platform Evidence` → `Linux platform runtime evidence` 作业 | 运行记录 [28889055278](https://github.com/wzzc-dev/MoUI/actions/runs/28889055278), 2026-07-07 |
| L3: Linux 完整平台服务 / IME 证据 | ⏳ **部分通过** | 首帧渲染已验证（CI 运行记录 28889055278）；代码级服务完整（剪贴板、文件对话框、目录列表、IME、AT-SPI 等）；WSL2 验证 IME 探测全部 8 字段通过（enabled/hint/surrounding/cursor/updated/updated_hint/updated_cursor/disabled=true），但交互式输入（pointer/keyboard）和完整 destroy 序列仍需匹配 Wayland 桌面宿主的严格输入日志证据 | 2026-07-11 |

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

最近成功运行: GitHub Actions 运行记录 [28889055278](https://github.com/wzzc-dev/MoUI/actions/runs/28889055278), 提交 `8a054c5914adbfa34a6943570c1ceb01cc603ef5`.

证据脚本使用 `moui_tests/tester/linux_skia_first_frame_smoke` 专用测试程序（类似 macOS 的 `moui_tests/tester/macos_skia_first_frame_smoke`），硬编码 `first_frame_smoke_auto_exit=true`，呈现第一帧后自动退出并打印标记。该运行记录证明 Linux Wayland + Skia 首帧路由。

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

完整的 IME 运行时证据仍需匹配宿主 Wayland 主机上的 `capture_moui_runtime_evidence.sh linux` 运行。

#### Linux 证据参考

| 可引用项 | 内容 |
|----------|------|
| CI 工作流 | `moui-linux-platform-evidence.yml` — Weston headless 合成器 + 60 分钟超时 |
| 证据脚本 | `scripts/linux-platform-evidence.sh` — 7 步全自动证据收集 |
| Linux Skia 依赖脚本 | `moui_skia/scripts/install-linux-smoke-deps.sh` |
| Renderer Proof 制品 | `moui-renderer-real-skia-ci.yml` 运行记录 28964136550 上传的 `linux-renderer-real-skia-ci` 日志 |
| 证据记录脚本 | `window/scripts/record_moui_evidence.sh` — 支持 linux 后端 |
| 运行时捕获脚本 | `window/scripts/capture_moui_runtime_evidence.sh` — Linux 运行时证据端到端捕获 |
| WSL2 验证运行 | 本地捕获日志 `artifacts/platform-evidence/linux/moui-linux-runtime.log` — 2026-07-11, WSL2 + WSLg, IME 8/8 字段通过 |

### 3.4 Web / Wasm-gc

| 证据类型 | 状态 | 核验方法 | 最新通过记录 |
|----------|------|----------|-------------|
| L0: 构建 | ✅ 通过 | `ci.yml → pr-profile` → Showcase/Markdown Editor Web wasm-gc 构建 | 每次 PR |
| L1: Web 后端测试 | ✅ 通过 | `ci.yml → pr-profile` → `moon test moui/backend/web --target wasm-gc` | 每次 PR |
| L1: WebGPU 适配器测试 | ✅ 通过 | `ci.yml → pr-profile` → `moon test moui_web_renderer --target wasm-gc` | 每次 PR |
| L2: Web 浏览器呈现 | ✅ 通过 | `checks/platforms/web.json` `rendererL2=passed`（`browser-webgpu`）；CI / Pages 浏览器会话 | 与结构化平台契约对齐 |
| L3: Web 运行时呈现清单 | ✅ 通过 | `checks/platforms/web.json` `runtimeL3=passed`（浏览器呈现清单）；`scripts/ci-web-runtime-presentation.sh` / `record-web-runtime-presentation.mjs` | 与结构化契约对齐；无新证据时勿降级 |

## 四、渲染器特性逐项证据链

以下 17 项渲染器特性在三个原生平台上各有对应的 L2 CI 作业核验。

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

**核验入口**: `moui-renderer-real-skia-ci.yml` 每次 PR 运行。最近核验的三平台成功运行记录为 [28964136550](https://github.com/wzzc-dev/MoUI/actions/runs/28964136550)，head SHA `91f596e80d5a5f80d30fa94a8510e5ce4653189e`。

## 五、可核验 CI 运行记录

| 工作流 | 运行 ID | 关键通过的作业 | 上传制品 | SHA |
|--------|---------|----------------|----------|-----|
| MoUI CI | [28964136358](https://github.com/wzzc-dev/MoUI/actions/runs/28964136358) | Windows MSVC 原生 smoke, Linux 平台契约, 公共 API surface, PR profile 门禁, macOS 打包 smoke, Benchmark 脚手架 | moui-showcase-windows-msvc-portable, moui-webview-demo-windows-msvc-portable, moui-showcase-macos-app ... | `91f596e` |
| MoUI Renderer Real Skia CI | [28964136550](https://github.com/wzzc-dev/MoUI/actions/runs/28964136550) | macOS renderer real Skia, Linux renderer real Skia, Windows renderer real Skia | macOS/Linux/Windows renderer real Skia 日志 | `91f596e` |
| MoUI macOS Platform Evidence | [27217345886](https://github.com/wzzc-dev/MoUI/actions/runs/27217345886) | macOS platform runtime evidence → status=passed; Native Skia renderer proof (macos) → status=passed | moui-macos-platform-runtime-evidence, moui-renderer-proof-skia-native-macos | `5bb2d810` |
| MoUI Linux Platform Evidence | [28889055278](https://github.com/wzzc-dev/MoUI/actions/runs/28889055278) | Linux platform runtime evidence → first-frame Wayland route success | moui-linux-platform-evidence | `8a054c` |
| Deploy Website | [28964136340](https://github.com/wzzc-dev/MoUI/actions/runs/28964136340) | Build website, Deploy website | github-pages | `91f596e` |

## 六、缺失证据与补全计划

### 6.1 Windows L3 — 平台运行时 ✅ 已完成（2026-08-29，ADR 0031）

| 事项 | 状态 | 证据 |
|--------|---------|----------|
| Showcase Windows 首帧日志 | ✅ 已完成 | `scripts/windows-platform-evidence.sh` → 匹配 MSVC 宿主运行 `MOUI_FIRST_FRAME_EXIT=1 moon run examples/showcase/windows_skia --target native`；标记已校验，`showcase_exit_status=0` |
| Windows IME / 平台服务运行时观测 | ✅ 已完成 | `window/scripts/capture_moui_runtime_evidence.sh windows` 转录经 `check_moui_runtime_log.sh windows` 校验通过（IME 8 字段探测、pointer/键盘/IME 文本投递、销毁序列） |
| Windows 状态清单更新 | ✅ 已完成 | `checks/platforms/windows.json` `runtimeL3=passed` + `checks/platform-matrix.json` `productClass=committed`（ADR 0031） |

说明：此前的 "Markdown Editor Windows 首帧日志" 补全项已作废 —— Markdown Editor
示例没有 Windows 入口点；Showcase 路由是 Windows 呈现证据的规范来源。已退役的
`platform-runtime-evidence.json` 清单（移除于 `7b48bd5e`）由结构化的
`checks/platforms/*.json` 记录取代。

### 6.2 Linux L3 — 完整平台运行时

| 缺失项 | 补全动作 | 前置条件 | 预估工期 |
|--------|---------|----------|---------|
| Linux 首帧 / Wayland 路由日志 | `scripts/linux-platform-evidence.sh` | ✅ 通过（CI 运行记录 28889055278；本地 WSL2/Wayland 2026-07-11） | ✅ 已完成 |
| Linux IME 运行时观测（交互式输入） | `window/scripts/capture_moui_runtime_evidence.sh linux --require-input` 或在真实 Wayland 桌面运行 `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1 bash window/scripts/check_moui_linux_smoke.sh --run` 并确保操作员在窗口聚焦时按键 | Wayland 桌面宿主 + 交互式输入 | 1 次本地运行 |
| Linux IME 协议功能 | WSL2 验证已通过：全部 8 个 IME 探测字段（enabled/hint/surrounding/cursor/updated/updated_hint/updated_cursor/disabled）均为 true | 在 WSL2 + WSLg 上已用 `capture_moui_runtime_evidence.sh` 验证 | ✅ 已完成（WSL2 2026-07-11） |
| Linux 完整平台服务观测 | 剪贴板图片、目录列表、字体回退 | 目录列表、剪贴板图片已实现并测试；首帧渲染已验证 | ✅ 已完成（代码级） |
| Linux 全证据清单更新 | 将完整服务/IME 结果写入 `checks/platforms/linux.json` linux 条目 | IME 交互式输入运行时观测完成 | 1 次 PR |

### 6.3 Android / iOS / HarmonyOS — Window-hosted 主线

唯一的移动端路线是 `wzzc-dev/window` `HostCmd` → `EventLoop` →
`ApplicationHandler` → MoUI `*EmbeddedRuntimeBackend`。host-sim 覆盖无需 emulator，验证
template callback path、backend adapters 和 Counter entrypoints：

```sh
sh scripts/window-hosted-hostsim-smoke.sh
```

| 平台 | 当前证据 | 剩余工作 |
|------|--------|------|
| Android | host-sim 和 package checks | matching-device presentation、input、lifecycle 和 service evidence |
| iOS | host-sim 和 package checks | matching simulator/device presentation、input、lifecycle 和 service evidence |
| HarmonyOS | host-sim 和 package checks | signed-device presentation、input、lifecycle 和 service evidence |

对应 target 可用时，在 `scripts/window-hosted-vm-smoke.sh` 上设置一个
`WINDOW_HOSTED_ANDROID_AVD=1`、`WINDOW_HOSTED_IOS_SIM=1` 或
`WINDOW_HOSTED_HARMONYOS_HVD=1`。

GPU seven-gate（`gpuPromotionEvidence.claimed=true`）仍是独立 L3 质量声明，
本轮不声明。

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
moon run moui_tests/skia_text_emoji_smoke/native --target native

# L3 — macOS 平台运行时证据（macOS 主机）
MOUI_FIRST_FRAME_EXIT=1 moon run examples/showcase/macos_skia --target native

# L3 — Linux 首帧 / Wayland route 证据（Wayland 主机）
moon run moui_tests/tester/linux_skia_first_frame_smoke --target native

# L3 — Windows 平台运行时证据（MSVC 主机）（需要安装、配置 MSVC 工具链）
set MOUI_FIRST_FRAME_EXIT=1
moon run examples/showcase/windows_skia --target native

# Web 运行时呈现记录
node scripts/record-web-runtime-presentation.mjs --base-url http://127.0.0.1:18080 --cdp-url http://127.0.0.1:9223
```

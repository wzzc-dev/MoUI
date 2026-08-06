# Plan: window 跨平台对齐 macOS + 移动端按 winit 补齐

- **Status**: active
- **Goal**: 将 `window`（`wzzc-dev/window` / 本地 `window/`）的 Windows / Linux / Web 在 **MoUI-ready 语义与证据** 上对齐 macOS 参考实现；Android / iOS / HarmonyOS 按 [winit](https://github.com/rust-windowing/winit) 的 hosted / mobile 模型补齐 HostCmd、原生胶水与 M3 present，达到 `docs/moui-ready-matrix.md` 与 `docs/mobile-hosted-backend.md` 的 MoUI-ready 门槛。
- **Owner surface**: 子模块 `window/`（通过 `sh scripts/window-dev-mode.sh on` 接入工作区；**禁止**把 `./window` 写进 `moon.work` 常驻）。
- **Upstream pin**: `moonbit-community/window@0.5.4` + 行为参考 `rust-windowing/winit`（见 `window/docs/upstream.md`）。
- **Acceptance bar**: **MoUI-ready parity**，不是完整 winit / 不是 macOS 独有 API 1:1。

## 2026-08-06 Windows interactive resize follow-up

- [x] Reproduce Showcase resize with a real `HTBOTTOMRIGHT` drag using the
  published Windows window dependency; the validated default route is
  `skia-raster`.
- [x] Keep resize redraw synchronous with the Win32 callback while the OS
  modal move/size loop owns message dispatch.
- [x] Validate first-frame DPI metrics, resize repaint, and post-resize mouse
  message responsiveness through the MoUI Showcase consumer.
- [x] Decode Windows pointer, wheel, and drag coordinates with the window's
  current DPI scale so physical Win32 client positions match logical layout
  and hit testing.
- [x] Keep root `moon.work` on the published window dependency; the local
  `window/` checkout is not a workspace member by default.

The Windows D3D12 host-surface route is wired through the neutral
`SurfaceContext` descriptor. `@render_skia.from_env()` controls whether the
GPU factory is selected (`MOUI_SKIA_RENDERER=gpu`) or whether `auto` tries GPU
before the raster fallback. Interactive resize now reuses the existing HWND
swap chain and calls `ResizeBuffers` only after the wrapped Skia back buffer is
released, avoiding the previous second-swap-chain `DXGI_ERROR_INVALID_CALL`
path. A matching-host interactive GPU resize smoke remains the final runtime
evidence item; CPU raster remains the explicit recovery/fallback route.

The Windows native event queue reports `WM_MOUSE*` positions in physical
client pixels. The backend now supplies the current `Window::scale_factor()`
when decoding those events; previously only `last_pointer` was normalized,
leaving direct pointer hit testing offset on scaled displays.

## Why now

| 平台 | 现状（2026-07 调研） | 阻塞 MoUI 的点 |
|------|----------------------|----------------|
| **macOS** | 参考实现；AppKit smoke passed | 仅作对齐基准；`content_view_handle` 为 macOS-only |
| **Windows** | Win32 preview；matching-host runtime smoke passed（2026-06-07） | Preview 语义合同、IME 原生路径深度、L3 服务证据 |
| **Linux** | Wayland + xdg-shell preview；WSL2 部分验证 | matching-host interactive input 证据、`REQUIRE_INPUT` 严格门、装饰/monitor 元数据 |
| **Web** | canvas + DOM；build + browser consumer smoke passed | 桌面窗口 API 的 explicit `NotSupported`/`no-op` 合同文档化；与 macOS 消费者路径一致性 |
| **Android / iOS / HarmonyOS** | Hosted backend + host-sim + C queue + soft present；templates 存在 | 设备侧真实 handle（M2）、至少一帧 present/clear 或 swapchain（M3）、MoUI cutover（M4）；相对 winit android/ios 的 lifecycle 语义 |

公开 `Window::` 方法数量已接近 macOS（macos 113；其它 116–124）。**缺口几乎不在“缺方法名”，而在：实现深度、合同（NotSupported / state-only / no-op / placeholder）、matching-host 证据、移动端原生所有权。**

## Non-goals（本计划明确不做）

- 完整 winit 功能全集（DnD 产品化、exclusive fullscreen 产品化、多窗口移动端等）。
- X11 后端（除非后续 RFC）。
- 把 macOS 独有 API（`content_view_handle`、系统菜单产品、tabbing）强推到其它平台。
- 在 `window` 内重做第二套 MoUI 专用 ABI 或 PlatformView 产品。
- 把 `./window` 加入根 `moon.work`。
- 把未经验证的 matching-host 日志记为 `passed`。

## Success criteria

### A. Desktop / Web ↔ macOS（MoUI-ready）

对 **Windows / Linux / Web**，以下全部为真，或差距有 **显式合同** 写入 `window/docs/platform-gaps.md`：

1. **Critical path**（`window/docs/moui-ready-matrix.md`）行为与 macOS 一致：EventLoop + ApplicationHandler、create_window / size / scale、raw handle（平台原生语义）、resize/redraw、pointer、keyboard/text、request_ime_update（按合同：native / state-only / n/a）、monitor/cursor（native 或 documented placeholder）、clean exit。
2. **合同收敛**：每个与 macOS 行为不同的 API 落在 `NotSupported` | `state-only` | `no-op` | `placeholder` 之一，**禁止静默假成功**。
3. **证据**：
   - Windows：matching-host `scripts/check_moui_windows_smoke.sh --run` + runtime log 校验；必要时刷新 `artifacts/` 外的记录说明于 `platform-gaps.md`。
   - Linux：matching-host `scripts/check_moui_linux_smoke.sh --run`；交互输入用 `WINDOW_MOUI_LINUX_REQUIRE_INPUT=1` 后才能从 “core only” 升到 full MoUI-ready。
   - Web：`scripts/check_moui_web_smoke.sh` + browser consumer（`scripts/smoke_runtime.sh web`）保持 passed。
4. **消费者侧**：`window/docs/moui-integration-smoke.md` 要求的 MoUI consumer 字段可被记录为 passed 或明确 pending + 命令。

### B. Mobile（参考 winit，Hosted 模型）

Android / iOS / HarmonyOS 共享语义机（已有骨架），里程碑：

| ID | 含义 | 完成定义 |
|----|------|----------|
| **M1** | Hosted loop + host-sim + template | 已基本具备；补齐三端一致性与文档 |
| **M2** | 真实 raw handles | GPU 消费者可读到非零、可重建的 ANativeWindow* / UIView* / XComponent handle；generation 跨 epoch 变化可测 |
| **M3** | 至少一帧 present | soft `present_rgba_pixels`/`clear_color` 设备路径 **或** 成功创建 GPU swapchain；host-sim 不得冒充 device M3 |
| **M4** | MoUI cutover | background destroy_surfaces → 再 can_create_surfaces 无崩溃；surface_generation 单调 |

**MoUI-ready on mobile = M3+**，且 host-sim 测试 + hosted smoke 脚本绿。

winit 对齐要点（实现时对照，不照搬 Rust）：

- **Android**: Activity / NativeActivity 生命周期 → `Start/Resume/Pause/Stop/Destroy`；`Surface` 回调 → `SurfaceInit/Term/Resize`；指针流；主线程规则。
- **iOS**: UIApplication / UIView 生命周期与 main-thread only；touch → pointer；scale/safe area 最小集合（safe area 可 MVP 后置，但不得假数据当证据）。
- **HarmonyOS**: Ability + XComponent 回调为唯一 surface/pointer/resize/detach 源（与 MoUI `EmbedderHostChannel` 约定一致）；勿双栈 inject。

## Workstreams

### WS0 — 基线冻结与门禁（先做）

- [ ] `sh scripts/window-dev-mode.sh on` 仅在编辑 session 使用；提交前确认根 `moon.work` 无 `./window`。
- [ ] 冻结对照表：以 `window/macos/pkg.generated.mbti` + `window/docs/moui-ready-matrix.md` 为基准，生成/更新 **per-backend contract sheet**（可并入 `platform-gaps.md` 或独立 `window/docs/api-contract-matrix.md`）。
- [ ] 确认默认门：`bash window/scripts/check_ci.sh`（host-aware）+ 各 `check_moui_*_smoke.sh` 路径；移动端 `check_{android,ios,harmonyos}_hosted_smoke.sh`。
- [ ] 在 MoUI 侧记录本计划；不把未刷新的旧 Windows log 自动当永远有效。

### WS1 — Windows ↔ macOS

**范围**：`window/windows/*`、`native_window.c`、`native_monitor.c`、examples/smoke。

- [ ] 审查相对 macOS 的 **语义差**（不是方法名）：cursor grab、IME（Imm/TSF 路径深度）、monitor/dpi、raw display/window handle 身份、最大化/最小化/可见性、resize 请求回传。
- [ ] 每个 gap 标记合同；能 native 的补 native，不能的 `NotSupported`/`state-only`。
- [ ] `moui_critical_api_wbtest` 与 runtime smoke 覆盖 critical path。
- [ ] matching-host：`WINDOW_CI_HOST=windows bash scripts/check_ci.sh`；`scripts/check_moui_windows_smoke.sh --run`；`scripts/check_moui_runtime_log.sh windows <log>`；用 `record_moui_evidence.sh` 更新 `platform-gaps.md`。
- [ ] （可选衔接）MoUI `moui/backend/windows` consumer 证据按 `moui-integration-smoke.md` 记一条。

### WS2 — Linux ↔ macOS

**范围**：`window/linux/*`、Wayland/xdg 协议生成物、SHM present。

- [ ] 固化 Wayland core：surface / wl_display / xdg_toplevel / present_rgba / monitor from wl_output。
- [ ] IME：text-input 协议状态已部分验证 → 补齐 **交互输入** 证据路径与 `REQUIRE_INPUT` 文档。
- [ ] decorations / client decorations / skip_taskbar：合同化（state-only 或 NotSupported）。
- [ ] matching-host capture：`capture_moui_runtime_evidence.sh linux`；interactive 单独记录。
- [ ] 明确 **不** 把 WSL2-only 结果当作桌面 Wayland 全绿，除非 compositor 声明清楚。

### WS3 — Web ↔ macOS

**范围**：`window/web/*`、`runtime.js`、wasm-gc examples。

- [ ] 桌面窗口语义（drag_window、fullscreen 变体、decorations 等）统一为 `NotSupported` 或 `no-op` + 文档。
- [ ] canvas_id / surface size / scale / redraw / pointer / keyboard / resize 保持与 smoke 一致。
- [ ] IME：浏览器 input 合同写清（n/a vs state-only），避免假 native IME。
- [ ] 门禁：`check_web_assets.sh` + `check_moui_web_smoke.sh` + browser `smoke_runtime.sh web`。

### WS4 — Mobile：Android / iOS / HarmonyOS（winit 参考）

共享：

- [ ] 三端 `HostCmd` 枚举与 drain 顺序一致；generation 语义一致；**禁止** 重新引入 `inject_*` / `bind_surface`。
- [ ] `host_sim` + `native_*_host` 桥测试覆盖 Start→SurfaceInit→Pointer→Resize→SurfaceTerm→Destroy。
- [ ] Templates 可安装最小 host（现有 `window/{android,ios,harmonyos}/template`），文档指向如何接 MoonBit EventLoop。

**Android（优先，winit android 最成熟）**

- [ ] M2：`ANativeWindow*` 从 Activity/SurfaceView/NativeActivity 进入 C queue → MoonBit handle；`__ANDROID__` 路径与 host-sim 分清。
- [ ] M3：`ANativeWindow_lock` soft present 设备验证 **或** 文档声明 GPU 由消费者持有且本库只交付 handle。
- [ ] 线程：Activity/looper；debug assert。
- [ ] 证据：`moon test window/modules/window/android --target native` + 设备/模拟器 present 记录进 `platform-gaps.md` / mobile changelog。

**iOS**

- [ ] M2：UIView* / 可选 CAMetalLayer 宿主指针；UIKit 主线程。
- [ ] M3：host-sim 与 device 路径分离；device 至少 clear/present 或 Metal 创建证据之一。
- [ ] 对照 winit-ios：lifecycle、touch、scale。

**HarmonyOS**

- [ ] M2/M3：XComponent NAPI → C host queue；**唯一** surface/pointer/resize/detach 源。
- [ ] 与 MoUI 后端的边界：window 只做窗口/lifecycle；MoUI 后端负责运行时和服务适配。
- [ ] HVD/设备证据单独记账，允许 M3 略滞后但语义机与 host-sim 不得降级。

### WS5 — 文档、证据与 MoUI 衔接

- [ ] 持续更新 `window/docs/platform-gaps.md`（唯一 readiness 账本）与 `moui-ready-matrix.md`。
- [ ] `window/docs/CHANGELOG-mobile-hosted.md` 记录破坏性/里程碑。
- [ ] MoUI：`docs/platform-readiness-declaration.md` / `checks/platforms/*.json` **仅在有新证据时** 升格；本计划不自动改 product_class。
- [ ] 若需跨包多周工作，保持本文件 Progress 表；session 事实可摘到 `memories/repo/`。

## Suggested sequencing

```text
WS0 基线
  ├─► WS3 Web（最快锁合同，风险低）
  ├─► WS1 Windows（已有 runtime 证据，补语义与刷新）
  ├─► WS2 Linux（依赖 matching host / compositor）
  └─► WS4 Mobile
        Android M2/M3 → iOS M2/M3 → HarmonyOS M2/M3
        三端 M1 一致性可并行
然后 WS5 文档与（可选）MoUI consumer 升格
```

并行原则：Web 合同与 Windows 语义审查可并行；Linux 交互证据与 Android 设备 present 可并行；**不要**在无设备证据时宣称 mobile MoUI-ready。

## Validation loops（最小）

| 变更面 | 命令 |
|--------|------|
| 任意 window 包 | `cd window && bash scripts/check_moon_baseline.sh`（或 host `check_ci.sh`） |
| FFI 导出 | `window/scripts/check_ffi_surface.sh` |
| macOS | `window/scripts/check_moui_macos_smoke.sh` |
| Windows | `WINDOW_CI_HOST=windows bash window/scripts/check_ci.sh` + `check_moui_windows_smoke.sh --run` |
| Linux | `WINDOW_CI_HOST=linux bash window/scripts/check_ci.sh` + `check_moui_linux_smoke.sh --run` |
| Web | `window/scripts/check_moui_web_smoke.sh` |
| Mobile hosted | `moon test window/modules/window/<android|ios|harmonyos> --target native` |
| 证据记录 | `record_moui_evidence.sh` + 人工粘贴 `platform-gaps.md` |
| MoUI 根（触及 guidance） | 根目录 static trio + 相关 backend tests；**勿**默认跑 full daily |

## Decision log

| Date | Decision |
|------|----------|
| 2026-07-21 | 对齐目标定为 **MoUI-ready**，非 winit 全集；macOS 为语义参考。 |
| 2026-07-21 | 移动端继续 **Hosted HostCmd** 模型，对齐 winit lifecycle，不引入 inject 双栈。 |
| 2026-07-21 | 公开 API 方法数已近齐；工作重心 = 语义合同 + matching-host/device 证据 + mobile M2–M4。 |
| 2026-07-21 | `content_view_handle` 保持 macOS-only；其它平台不得伪造。 |

## Progress

| Date | Note |
|------|------|
| 2026-07-21 | 开立计划；完成 `window/` 布局、`moui-ready-matrix`、`platform-gaps`、移动 hosted 文档与 API 数量对照调研。 |
| 2026-07-21 | WS0: `api-contract-matrix.md`；WS1: Windows `ShowCursor`；WS2: Linux focus+fullscreen；WS3: Web focus/fullscreen；WS4: iOS soft present device path。Windows/Linux matching-host runtime 证据仍待刷新。 |

## References

- `window/AGENTS.md`, `window/README.mbt.md`
- `window/docs/platform-gaps.md`, `moui-ready-matrix.md`, `mobile-hosted-backend.md`, `moui-integration-smoke.md`, `upstream.md`
- MoUI: `docs/platform-readiness-declaration.md`, `docs/android-support.md`, `docs/ios-support.md`, `docs/harmonyos-support.md`, `docs/window-hosted-moui.md`
- winit: https://github.com/rust-windowing/winit （android/ios 后端与 application lifecycle）

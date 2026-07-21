# Plan: window Android/iOS/HarmonyOS (winit-style) + MoUI cutover + VM pass

- **Status**: active  
- **Goal**: 参考 [winit](https://github.com/rust-windowing/winit) 完成 `wzzc-dev/window` 的 **Android / iOS / HarmonyOS** 托管后端；把 **MoUI** 对接到该 window 库（lifecycle/surface/input 以 window 为准）；在 **虚拟机/模拟器** 上验证可运行并通过测试。  
- **Related**: `docs/plans/active/window-cross-platform-parity.md`（桌面/Web 对齐）、`window/docs/mobile-hosted-backend.md`、`window/docs/moui-ready-matrix.md`  
- **Owner surfaces**:
  - `window/{android,ios,harmonyos,examples/mobile_hosted_smoke}`  
  - `moui/backend/{android,ios,harmonyos}`（cutover 消费层）  
  - 可选过渡：`moui_shell/*` **只读参考 / 临时兼容壳**，禁止成为 window 的运行时依赖  

## Architecture boundaries (non-negotiable)

```text
┌─────────────────────────────────────────────────────────┐
│  OS host (Activity / UIApplication / Ability)           │
│  window/<platform>/template  +  window/*/native_*_host.* │
└───────────────────────────┬─────────────────────────────┘
                            │ HostCmd / C queue
                            ▼
┌─────────────────────────────────────────────────────────┐
│  wzzc-dev/window/{android,ios,harmonyos}   ≈ winit      │
│  EventLoop · ApplicationHandler · Window · raw handles  │
└───────────────────────────┬─────────────────────────────┘
                            │ create_window / generation
                            │ pointer / text MVP / present or GPU handle
                            ▼
┌─────────────────────────────────────────────────────────┐
│  MoUI consumer                                          │
│  ApplicationHandler impl → runtime + Skia/renderer      │
│  (NOT inject_*/bind_surface dual stack)                 │
└─────────────────────────────────────────────────────────┘

Embedding API v1 / PlatformView / full IME product:
  → 可选第二阶段：薄壳适配到 window 世代，或逐步收缩
  → 不是 window 对齐 winit 的前置条件
  → winit 没有 Embedding API；见会话分析
```

| Layer | Owns | Must not own |
|-------|------|--------------|
| **window** | OS entry, surface epoch, HostCmd, handles, basic input, soft present MVP | Embedding ABI, PlatformView product, shell.json plugins |
| **MoUI backend** | AppRuntime session, renderer provider, TEA program | Raw OS Activity code (prefer thin entry) |
| **moui_shell** | Legacy managed packaging / Embedding v1 during transition | New window lifecycle source of truth |

## Current baseline (2026-07)

| Area | State |
|------|--------|
| window mobile packages | Hosted HostCmd + host-sim + C queue + soft present；templates 存在 |
| Android device path | `ANativeWindow` present under `__ANDROID__`；JNI in `native_android_host.c` |
| iOS device path | UIKit host app + soft present to `UIView.layer.contents`（近期补） |
| HarmonyOS | Host queue + host-sim；XComponent 设备路径仍弱 |
| MoUI backends | 仍以 **Embedding adapter + shell descriptor** 为主；已 declare dep `wzzc-dev/window/{android,ios,...}`，**尚未**以 ApplicationHandler 为唯一 lifecycle |
| Evidence | host-sim smoke scripts green path exists；emulator L3 for **window-hosted MoUI** 尚未建立 |

## Success criteria

### A. window mobile = MoUI-ready hosted (winit-shaped)

三端均满足 `window/docs/moui-ready-matrix.md` **mobile 行** + `mobile-hosted-backend.md` 里程碑：

| ID | 定义 | 验收 |
|----|------|------|
| **M1** | Hosted loop + host-sim + template | `check_*_hosted_smoke.sh` 绿；host-sim 覆盖 Start→SurfaceInit→Pointer→Resize→Term→Destroy |
| **M2** | 真实 raw handle | 非零 ANativeWindow* / UIView* / XComponent handle；generation 跨 epoch 变化可测 |
| **M3** | 至少一帧 present | soft present **或** GPU swapchain create 在 **模拟器** 上可见/可断言 |
| **M4** | Cutover 安全 | background `destroy_surfaces` → 再 `can_create_surfaces` 无崩溃；handle 失效可测 |

**Ordering invariants**（破坏即失败）：

1. `resumed` before `can_create_surfaces`  
2. `destroy_surfaces` before `suspended` when surface dies but process lives  
3. `create_window` without surface readiness → hard `RequestError`  
4. 禁止 `inject_*` / `bind_surface` 公共 API  

### B. MoUI on new window

| 项 | 验收 |
|----|------|
| 单一 lifecycle 源 | MoUI 移动会话的 surface/input 以 **window HostCmd / ApplicationHandler** 为准，无双栈 inject |
| 可运行 demo | 至少 `examples/counter`（或专用 `*_window_hosted` entry）在三端模拟器/可替代 VM 上启动并 **首帧非空白**（或 soft-present 等价断言） |
| 编译门 | `moon check/test` 相关 backend + app entry 在 native target 通过 |
| 文档 | cutover 路径写入 `docs/android-support.md` / `ios` / `harmonyos` 或独立 `docs/window-hosted-moui.md` |

### C. 虚拟机测试通过（本目标的硬门）

| 平台 | VM | 最低通过命令 / 证据 |
|------|-----|---------------------|
| **Android** | AVD emulator | `window` hosted smoke + 安装 window-hosted 或 cutover APK；首帧/ present 断言；`adb` log 无致命崩溃 |
| **iOS** | Simulator | hosted smoke + Simulator 安装；首帧/ present；无崩溃 |
| **HarmonyOS** | HVD / DevEco emulator（若环境可用） | hosted smoke + HAP 安装；首帧/ present；若 HVD 不可用：host-sim + 官方文档记录 **blocked-by-tooling**，但 **不得** 假装 device M3 passed |

**Pass 定义（记录进 `window/docs/platform-gaps.md` 或 `artifacts/` 外的证据笔记）**：

- window opened / surface ready = yes  
- resize or redraw path exercised = yes  
- representative pointer (tap) = yes（模拟器可合成）  
- clean exit or destroy_surfaces path = yes  
- MoUI consumer first-frame 或 soft present success = yes  

## Non-goals

- 完整 winit 功能全集（多窗口移动端、完整 soft keyboard UI、DnD 产品化）  
- 在 window 内重做 Embedding API v1 / PlatformView 产品  
- 宣称六平台 product_class 全 `committed`（需单独 readiness 升格 + 证据）  
- 把 `./window` 常驻写进根 `moon.work`（仅 `window-dev-mode.sh on` 开发时）  
- 无模拟器证据时把 host-sim 记为 device/VM **passed**

## Workstreams

### WS0 — 基线与 dev 模式

- [ ] `sh scripts/window-dev-mode.sh on` 仅在编辑 window 时；提交前 `off`  
- [ ] 冻结对照：`mobile-hosted-backend.md` HostCmd 表 + 三端 `host_queue.mbt` 一致性审计  
- [ ] 列出 MoUI 现有 `embedding_adapter` 调用面 vs window ApplicationHandler 映射表  

### WS1 — window Android（优先，winit 最成熟）

- [ ] 对齐 winit-android 语义：Activity resume/pause/stop、Surface 回调、主线程  
- [ ] 巩固 M2：`ANativeWindow_fromSurface` → HostCmd SurfaceInit handle  
- [ ] 巩固 M3：soft present lock/unlock；可选 Skia consumer 后置  
- [ ] Template `HostedActivity` ↔ JNI 符号与 `moon` 可执行入口联通  
- [ ] `examples/mobile_hosted_smoke` Android 路径在 **AVD** 上跑通  
- [ ] 证据：`check_android_hosted_smoke.sh` + emulator 运行记录  

### WS2 — window iOS

- [ ] 对齐 winit-ios：main thread、UIApplication lifecycle、touch → pointer  
- [ ] M2 UIView* handle；M3 soft present（layer.contents 或 Metal 其一）  
- [x] `ios/template/Sources` UIKit host 与 MoonBit EventLoop 链接策略落地  
- [ ] **Simulator** install + smoke  
- [ ] 证据：`check_ios_hosted_smoke.sh` + simulator log  

### WS3 — window HarmonyOS

- [ ] XComponent 回调为 **唯一** surface/pointer/resize/detach 源  
- [ ] HostCmd 与 Android 同序；soft present 或明确 GPU app-owned + handle 交付  
- [ ] Template Ability 最小宿主  
- [ ] **HVD** 或文档化 tooling gap；host-sim 必须绿  
- [ ] 证据：`check_harmonyos_hosted_smoke.sh` + HVD 若可得  

### WS4 — MoUI cutover（对接新 window）

分两阶段，避免 big-bang：

**Phase 1 — Window-hosted MoUI thin entry（先跑通）**

- [ ] 新增（或改造）薄入口：`examples/counter/android_window_hosted`（及 ios/harmonyos 对称）  
- [ ] 实现 `ApplicationHandler`：在 `can_create_surfaces` 中 `create_window`，绑定 Skia/raster present  
- [ ] **不**调用 Embedding `attach_surface` 作为 surface 源；若临时仍需 shell 打包，仅作 APK 外壳且 lifecycle 转发到 window HostCmd  
- [ ] 模拟器验证首帧  

**Phase 2 — Backend 主路径切换**

- [ ] `moui/backend/{android,ios,harmonyos}`：RuntimeSession 从 window Window/handle/generation 驱动  
- [ ] Embedding adapter 降级为 **可选服务通道**（IME/clipboard/PlatformView），或标记 deprecated dual-path  
- [ ] 禁止双栈：同一 surface 不得既 inject 又 HostCmd  
- [ ] 更新 `platform-readiness-declaration` **仅在有 VM 证据后**  

### WS5 — 虚拟机测试门禁与文档

- [ ] 脚本化（可新 `scripts/window-hosted-vm-smoke.sh` 或扩展 hosted smoke）：  
  - Android: start AVD → install → launch → screenshot/log assert  
  - iOS: boot simulator → install → launch → assert  
  - HarmonyOS: HVD path or skip with explicit reason  
- [ ] 结果写入 `window/docs/platform-gaps.md` Latest + MoUI `docs/*-support.md`  
- [ ] CI：host-sim 可 PR；VM 证据 path-triggered / nightly（与现有 shell evidence 策略一致）  

## Suggested sequencing

```text
WS0
 ├─► WS1 Android M1–M3 + AVD
 ├─► WS2 iOS M1–M3 + Simulator   (可与 Android 部分并行)
 └─► WS3 HarmonyOS M1–M2 + host-sim (HVD 并行若有机器)
        │
        ▼
     WS4 Phase 1 thin MoUI entry on Android AVD first
        │
        ▼
     WS4 Phase 1 iOS Simulator → HarmonyOS HVD
        │
        ▼
     WS4 Phase 2 backend cutover (single lifecycle)
        │
        ▼
     WS5 formalize VM gates + docs
```

## Validation loops (minimal)

| 变更 | 命令 |
|------|------|
| window android | `cd window && bash scripts/check_android_hosted_smoke.sh` |
| window ios | `bash scripts/check_ios_hosted_smoke.sh` |
| window harmonyos | `bash scripts/check_harmonyos_hosted_smoke.sh` |
| window baseline | `bash scripts/check_moon_baseline.sh` |
| MoUI android backend | `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1 moon test moui/backend/android --target native` |
| MoUI ios backend | 对称 `moui/backend/ios` |
| AVD | 见 `docs/android-support.md` emulator 段；window-hosted APK install |
| Simulator | `docs/ios-support.md`；window-hosted app install |
| 根 guidance 变更 | static trio validators |

## Decision log

| Date | Decision |
|------|----------|
| 2026-07-21 | 目标：window mobile winit 形 + MoUI 对接 + **VM 通过**；非完整 Embedding 重写。 |
| 2026-07-21 | Embedding API v1 **不是** winit/window 前置；cutover 以 HostCmd 为 surface 真源。 |
| 2026-07-21 | moui_shell 可过渡打包，不可作为 window 运行时依赖或 inject 双栈。 |
| 2026-07-21 | **Policy superseded**: 不保留 moui_shell / Embedding v1；见 `window-only-mobile-no-shell-embedding.md`。 |
| 2026-07-21 | 模拟器优先：Android AVD → iOS Simulator → HarmonyOS HVD。 |
| 2026-07-21 | MoUI cutover 分 Phase1 薄入口跑通，再 Phase2 backend 主路径。 |

## Progress

| Date | Note |
|------|------|
| 2026-07-21 | 开立本计划；基线：hosted 骨架 + MoUI 仍 embedding 主路径；VM window-hosted 证据缺失。 |
| 2026-07-21 | Phase1: `*WindowHostedApp` 三端 + host-sim 测试绿；counter `*_window_hosted` check 绿；hosted smoke 脚本路径修复；`scripts/window-hosted-hostsim-smoke.sh`；真机/VM 安装仍 pending。 |

## References

- `window/docs/mobile-hosted-backend.md`, `moui-ready-matrix.md`, `platform-gaps.md`, `api-contract-matrix.md`  
- `docs/embedding-api-v1.md`（边界：壳↔runtime，非 window）  
- `docs/android-support.md`, `docs/ios-support.md`, `docs/harmonyos-support.md`  
- `docs/platform-readiness-declaration.md`  
- winit android/ios backend lifecycle（行为参考，不照搬 Rust）  

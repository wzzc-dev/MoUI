# Plan: MoUI 全宿主逻辑生命周期统一

- **Status**: done; implementation and published-dependency migration complete (archived)
- **Goal**: 让 `wzzc-dev/window` 只负责物理 event loop、native queue、raw surface 和 callback dispatch；让 MoUI 的 `window_host` 统一拥有逻辑生命周期、surface generation、窗口注册和 frame coordination。
- **Owner surfaces**: `window/modules/window/internal/embedded_dispatch`、`moui/backend/common`、`moui/backend/common/embedded`。
- **Migration rule**: 一次性迁移，不保留 `moui/runtime` coordinator 或旧 window kernel 的 deprecated alias；默认 `moon.work` 不包含本地 window override。

## Workstreams

- [x] WS1: upstream embedded callback dispatch 无状态化，保持 `HostCmd`/`ApplicationHandler` ABI。
- [x] WS2: 建立 MoUI `window_host` owner，迁移 coordinator、runtime slots、surface actions 和共享 frame 状态机。
- [x] WS3: embedded runtime 保留 session/service 能力，通过 embedded coordinator 使用共享 frame hooks。
- [x] WS4: 迁移七个平台和 runtime API，更新 package imports 与 generated interfaces。
- [x] WS5: ADR 0024、架构/不变量/hosted 文档和 boundary validator。
- [x] WS6: focused tests、host-sim、PR/platform gates，关闭 window dev mode。

## Progress

| Date | Note |
|---|---|
| 2026-08-05 | 建立计划；确认现有工作树已有平台桥和 embedded_runtime 重命名，但 coordinator 仍位于 runtime，window 仍使用 stateful embedded dispatch kernel。 |
| 2026-08-05 | `wzzc-dev/window` commit `b80f2a2b486f4d660745a809df72421f08081850` 发布为 `0.5.4-0.1.6`；七个 consumer 完成统一 pin，默认 workspace 恢复 published mooncakes mode。 |
| 2026-08-05 | window-host boundary、host import、platform bridge、API、guidance、doc-reference、PR 与 platform gates 通过；published-mode hostsim 通过。 |
| 2026-08-05 | `window_host` native 7/7、wasm-gc 7/7，`embedded_runtime` 11/11，runtime 91/91，Windows 24/24、Linux 25/25、Web 39/39 通过；Web presentation manifest 通过。 |

## Acceptance evidence

`moon info`、`node scripts/validate-window-lifecycle-boundary.mjs`、相关 backend/window package tests、`scripts/window-hosted-hostsim-smoke.sh` 以及 PR/platform profiles 均已通过。

macOS Skia renderer smoke 在本机通过 radial/transform 像素后，因既有测试直接向 renderer 传本地文件路径而未注入 host image completion，未能记录 local-file ready image；这属于 renderer smoke 的现有 HostImageSource 契约缺口，不是本次 window-host 生命周期迁移引入的回归，仍需后续 renderer smoke 修复后补跑。

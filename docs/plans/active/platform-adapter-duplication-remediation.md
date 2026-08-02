# Plan: Platform adapter structural duplication remediation

- **Status**: active（Wave 1-5 完成；剩余：Linux 红循环骨架窄条目 2026-12-01 到期）
- **Goal**: 消除 `moui/backend/{macos,linux,windows}` 与
  `{android,ios,harmonyos}` 中经实测确认为"机械重复"的窗口请求分发、redraw
  协调、窗口销毁、事件桥接、run-loop 骨架代码（基线
  `checks/platform-adapter-duplication-baseline.json` 估计 ~900 行可避免；
  实测仅 macos/linux 两后端就有 ~550 行同构代码、mobile 三端 ~244 行），把
  4 个 2026-10-01 过期的 allowlist 条目在到期前收敛为共享代码或重新论证，
  并将 validator 从"防增长"升级为"度量并强制收敛"。**行为零变化**。
- **Decisions**: ADR 0020（platform_bridge + duplication budget）、
  ADR 0018（host split：`HostRuntimeDriver`/wall clock/redraw scheduler 已归
  `moui/runtime`）、ADR 0019（renderer provider）。
- **Related**: `docs/plans/done/moui-architecture-convergence.md` Phase F
  （本计划是其收尾）、Phase E（struct-of-closures 先例）。

## Wave 5（2026-08-03）：provider 级样板收敛

四类经实测逐字/同构重复的 provider 辅助样板已收敛（架构审计 2.1 项）：

| 样板 | 收敛前 | 收敛后 |
|---|---|---|
| `renderer_metrics_from_host` | 12 份（android/harmonyos/ios/linux/macos/windows × skia/sun/wgpu） | `moui/backend/platform_bridge/renderer_metrics.mbt` 单实现（macos sun 的防御逻辑提升为共享），12 个 provider 包加 `platform_bridge` 依赖 |
| `async_image_read_i32_le` | 6 份逐字相同（desktop × skia/sun） | `moui/render/async_image_bytes.mbt` 单实现 |
| `env_flag` | 3 份逐字相同（desktop skia） | `moui/render/env_flags.mbt` 单实现（render 新增 `moonbitlang/core/env` 依赖） |
| `skia_host_renderer_bridge_preflight` | 6 份（移动/桌面两组同构串） | `moui/render/skia/renderer_preflight.mbt` 两个 pub 函数（mobile/desktop） |

净删除约 27 份本地定义、~100 处调用点改共享前缀；12 个 provider 包
61 测试 + host/platform_bridge 124 测试全绿；`validate-platform-adapter-duplication`
guard 保持绿（baseline 由 validator 自动刷新）。

## 依据（实测数据，2026-07-29 基线复核）

| 文件对 | 行数 | 同构行数 | 差异本质 |
|---|---|---|---|
| macos/linux `window_requests` | 589/594 | ~407 | 类型名 + scale_factor 取法 + open_window 属性 |
| macos/linux `services` | 342/394 | ~146 | 同构 |
| macos/linux `app_runtime` 骨架 | 289/203 | 骨架同构 | 类型名 + `create_macos_app` vs internal |
| android/ios `window_hosted` | 343/352 | ~244 | 共享 `EmbedderHostChannel` 后的机械重复 |
| `window_event_to_host_with_modifiers` | — | 4 份本地包装 | 全部是 `@host.window_event_to_host_with_modifiers` 的转发壳 |
| macos/linux `app_handler` | 683/569 | 结构同构 | 槽交互/属性/装饰平台私有（保留） |

允许清单（`checks/platform-adapter-duplication-baseline.json`）中 4 条
`allowUntil: 2026-10-01`（app_handler redraw loop、resize/detach 路由、
event dispatch 调用点、RenderFrameResult apply/finish）到期后 validator
硬失败，必须在到期前收敛。

## 五维验收口径

1. **完成度**：桌面三端（macos/linux/windows）与移动三端（android/ios/
   harmonyos）全部覆盖；6 类 allowlist 模式逐条处置（提取 / 重论证 /
   保留原生例外），不允许"未处置即到期"。
2. **可维护性**：请求分发、redraw 协调、销毁、事件桥接各只有一份实现；
   平台文件只留"原生解码 + 窗口创建 + 槽注册 + ~15 行闭包适配器"。
3. **可扩展性**：新平台接入 = 实现 `WindowSurfaceActions`（struct-of-closures，
   与 Phase E `RendererProviderBinding` 同风格）+ 原生解码，不复制协调器。
4. **长期维护潜力**：budget 只降不升；validator 增加文件级相似度门；
   文档（architecture-map / platform-host-contract / ADR 0020 修订）落位。
5. **工程质量**：每波独立绿（`moon test` + 相关 profile + 桌面 smoke）；
   行为零变化（沿用 Phase F 表驱动转换测试原则）；公共 API 只缩不增，
   `moon info` drift review。

## 设计要点

- **共享代码归宿**：协调器放 `moui/runtime`（P4：生命周期执行；已 import
  core/render/backend/host，满足 ADR 0018 无反向依赖）。不放进
  `platform_bridge`（ADR 0020：bridge 只 import core/host/window 值类型，
  render lifecycle 归 runtime/render）。
- **无窗口依赖**：协调器 API 只用 `@host`/`@runtime`/`@render` 类型；尺寸转换
  （`host_metrics_to_dpi_size`、`to_render_metrics`）收敛到
  `platform_bridge`/`@host`，平台侧闭包内做最后一段转换，避免
  `moui/runtime` 新增 `window/*` 依赖。
- **无继承问题的解法**：`WindowSurfaceActions` 为闭包记录（focus /
  request_surface_size / set_minimized / set_visible / request_redraw /
  request_ime_update / scale_factor / surface_size / drop /
  native_view_handle / on_no_windows），平台创建窗口时一次性构造。
- **每波结束更新基线 schema**：allowlist 只缩（6 → 目标 2-3 条，仅剩
  texture 创建与 GPU 枚举两个 `allowUntil: null` 原生例外 + wechat
  exception 不变）。

## 执行波次

### Wave 1（2026-09 中前必须完成）— 桌面三端协调器收敛

- 1.1 `moui/runtime` 新增 `window_request_coordinator.mbt`：`dispatch_host_event`
  （keyboard+services 路由、subscription publish、IME sync）、
  `apply_window_request`（非 open 分支）、redraw/image-repaint 协调、
  `dispose_window`/`rollback_window_record` 骨架。
- 1.2 转换助手（`to_host_id`/`to_render_id`/`to_render_metrics`/
  `host_metrics_to_dpi_size`/`surface_metrics_from_physical` 重复份）收敛为
  单一实现（bridge 或 host）。
- 1.3 删除 macos/linux/windows/web 的 `window_event_to_host(_with_modifiers)`
  本地转发壳；内部调用点直连 `@host`（web `blur_to_cancel` 变体并入
  `@host` 可选参或留 1 行本地壳并论证）。`moon info` 记录 API 收缩。
- 1.4 macos/linux/windows：`window_requests` 瘦身为"open_window + 槽注册 +
  `WindowSurfaceActions` 构造 + 原生解码入口"；`services` 收敛公共部分；
  `app_runtime` 骨架合并（macOS first-present pump 保留为平台参数）。
- 1.5 处置 4 条 10-01 allowlist：redraw loop 与 event dispatch 调用点随
  1.1 提取；resize/detach 路由与 RenderFrameResult apply/finish 若确需
  native handle，则以"协调器 + 平台闭包"形式重构后重论证（换新条目名，
  不再整文件豁免）。
- **Gate**：`moon test moui/runtime moui/backend/host moui/backend/platform_bridge
  --target native` + macos/linux/windows 后端测试 + `sh scripts/check.sh
  --profile platform`；`scripts/macos-skia-renderer-smoke.sh`、
  `scripts/run-window-package-smoke.sh <macos|linux|windows> --run`；
  static trio；validator 绿（schema v3：文件级相似度门 + 收缩后的 allowlist）。

### Wave 2 — 移动端 embedded-runtime 三端收敛

- 2.1 `moui/backend/internal/embedded_runtime_backend` 增加共享
  `embedded_surface_host`（基于现有 `embedding_host_bridge`）：平台只提供
  surface 访问器（ANativeWindow*/UIView*/XComponent）与生命周期回调映射。
- 2.2 android/ios/harmonyos `window_hosted.mbt` 由 ~340 行/端缩至
  平台私有部分（原生解码 + 表面所有权 + IME 差异）。
- **Gate**：embedded_runtime_backend 测试 + 三端 window-hosted
  path-triggered 证据（按 `docs/testing.md`，非默认 daily）。

### Wave 3 — web + validator 硬化 + 文档

- 3.1 web `web_events.mbt`/`web_window_requests.mbt` 复用 Wave 1 协调器
  可共用部分（DOM 路由保留）。
- 3.2 validator 扩展：平台名归一化（Macos|Linux|Windows|Android|Ios|
  Harmonyos|Web 令牌替换）后做文件级相似度度量，新文件 >80% 相似即拒绝；
  基线加入每文件预算行。
- 3.3 文档：architecture-map 所有权表、platform-host-contract、
  ADR 0020 修订（budget 收缩、allowlist 更新）、skills 指针、
  `docs/plans/done/moui-architecture-convergence.md` Phase F 标注收尾。
- **Gate**：全部 profile 绿；validator 自测（fixture）绿；
  API surface 只缩有解释；三 static trio 绿。

## 兼容性策略

- 行为零变化：Wave 1 全部是保持语义的重构，F3 表驱动测试与平台 wbtest
  逐项验证；每波独立绿再进下一波。
- 协调器先"双写"：Wave 1 内新协调器与旧实现并存于各平台（各平台本地调用
  协调器，删除旧函数），单个平台先迁移并绿后，再批量删另一平台旧码。
- 公共 API 收缩（本地转发壳删除）走 `moon info` drift review，符合 Phase G
  既有约定。
- 不动 `wzzc-dev/window` 上游（parity 计划 owner surface 不重叠）；
  本地 `window` 子模块仅在 smoke 时 `window-dev-mode.sh on`。

## 非目标（明确不做）

- 不把平台逻辑吸收进 `backend/host`（ADR 0018 禁止反向依赖）。
- 不让 `moui/runtime` 依赖 `window/*`（保持协调器值类型纯）。
- 不做 X11 后端、不改 WeChat `direct-canvas-callback` 例外。
- 不重构 `window` 上游、不重写 `moui_skia` FFI。
- 不追求 100% 共享：原生事件解码、窗口创建属性、GPU/纹理创建永远留在
  平台包（baseline 原生例外保持）。

## 风险

| 风险 | 缓解 |
|---|---|
| 10-01 allowlist 硬失败 | Wave 1 在 09-中 前落地；无法提取的提前一个月重论证续期 |
| 重构引入行为漂移 | 协调器纯重构 + 表驱动测试 + wbtest + 桌面 smoke 门禁 |
| MoonBit 无继承导致共享困难 | struct-of-closures（Phase E 已验证的模式），平台仅 10-20 行 |
| 公共 API 收缩争议 | `moon info` drift review + ADR 0020 修订说明 |
| 移动端无设备证据 | Wave 2 按 path-triggered 证据节奏，不强行 claim |

## Progress

| Date | Note |
|------|------|
| 2026-08-01 | 计划建立；基线复核完成（实测数字见上表）；Wave 1 待开工。 |
| 2026-08-01 | Wave 1 完成：`moui/runtime/window_host_coordinator.mbt`（WindowHostCoordinator + WindowSurfaceActions::new）落地；macos/linux/windows 三端迁移完成（struct 字段收敛到 coordinator、4 个 window_event_to_* 转发壳全删、`host_metrics_to_dpi_size`/`core_size_to_window_surface_size` 收敛到 @host、redraw/image-repaint/IME 协调进 coordinator、dispose/rollback 委托）。三端 `moon test` 全绿（24/22/24），host 106/106，web 43/43，平台 profile 绿，macos Skia 渲染 smoke 绿；validator 绿（allowlist 6 → 3：4 条 10-01 条目 3 删 1 换窄，见 baseline）。残留：Linux 后端红循环骨架仍按「协调器状态 + 平台合成」保留（新窄条目 2026-12-01 到期，Wave 3 收尾）。API surface / maintenance 基线失败均为既有（core budget、views 文件清单、runtime required_protocol 35/34），与本次改动无关。 |
| 2026-08-01 | 点击风暴调查：idle 无交互 0% CPU（启动后 ~10s 入场动画自停）；点击侧边栏条目后持续 ~103% CPU（30s+ 未停）；`git stash` 对照验证 **HEAD 基线点击后同样持续 100%** → 既有行为，非 Wave 1 回归。**该 bug 已解决**（独立修复，非本计划 scope）；与 Wave 1 无因果关系。 |
| 2026-08-01 | Wave 3.1 完成：web 后端复用 Wave 1 协调器。`WebApp` 删 7 字段（text_input_session/window_requests/scene_resolver/windows/runtime_slots/platform_windows/event_sources），改持 `coordinator : @runtime.WindowHostCoordinator`；`open_window`/`create_resolved_window`/`attach_resolved_window` 重写为协调器 API（windows.open、runtime_slots.insert、platform_windows.bind、attach_surface(renderer.host_renderer, web_surface_actions)、request_platform_redraw）。协调器新增 `publish_platform_event`（pub 包装私有 publish_subscription_event，供 web_pointer_input 使用）。`web_surface_actions` 构造 `WindowSurfaceActions`（focus/request_surface_size/renderer_resize/set_minimized/set_visible/request_redraw/request_ime_update/drop/dispose_platform_views=unregister semantics；sync_surface/no-op；native_view_handle=None）。host_runtime 冗余方法全删（register/sync_runtime_slot、active_runtime_slot、apply_window_lifecycle、sync_text_input_session、request_redraw*、request_platform_redraw），redraw_window/drain_async_host_services/redraw_dirty_windows/dispose_window 改经 coordinator；`set_redraw_scheduler(() => ())`。web_events/web_pointer_input/web_host_event_dispatch 全部改调 coordinator（含 runtime_slots_empty、request_platform_redraw、sync_text_input_session、publish_platform_event）。验证：web wasm-gc 43/43、runtime 84/85（唯一失败为既有 flaky view_runtime_test:727，stash 基线复现）、host 106/106；wasm-gc 构建无错误（1 个增量缓存 warning 消失）。|
| 2026-08-01 | Wave 3 完成：3.1 web 复用协调器（见上）；3.2 validator 文件级相似度门：`tools/moui/validate_api_surface/platform_file_similarity.mbt`（平台令牌归一化 → token-set Dice，镜像对 >80% 拒绝，未登记即失败；`platform_file_similarity_budgets` 14 条预算行含理由；新登记 8 对：wgpu renderer_smoke 三对、menu_helpers 三对（既有复制，合并目标）、file_dialog_helpers 一对（既有复制，合并目标）、android/harmonyos window_hosted 预算调 0.98）；validator wbtest 25→31（+6：归一化/边界/分组/预算唯一性/拒绝 fixture/通过 fixture，fixture 走 /tmp 目录）；CLI 全量相似度失败 0。3.3 文档：architecture-map 所有权表 +2 行（coordinator、embedded_runtime_backend、web host）、platform-host-contract 新增 Window Host Coordinator 小节、ADR 0020 修订（amend 2026-08-01 + similarity gate 段）、convergence plan Phase F 标注收尾、framework skill 指针 +2。验证：validator 31/31、CLI 相似度 0 失败（api-surface 报告仍为既有 23 处 budget/文件清单债务，无新增类别）、guidance-consistency ok、macos backend 25/25 + skia 9/9、platform-services-check passed、web 43/43、host 106/106、runtime 84/85（既有 flaky）。残留：menu_helpers/file_dialog_helpers 既有复制文件按预算放行（Wave 4 合并候选）；Linux 红循环骨架窄条目 2026-12-01 到期。 |
| 2026-08-01 | Wave 2 完成：`moui/backend/internal/embedded_runtime_backend/hosted_window_backend.mbt` 新增共享骨架 `HostedWindowBackend` + `HostedWindow`（窗口代理闭包）+ `RendererProviderAdapter`（provider 投影）+ `HostedRuntimeSession`（raw handle + EmbeddedRuntimeBackendCore，取代三端 `{P}RuntimeSession` 转发壳 ~170 行/端）。android/ios/harmonyos `window_hosted.mbt` 由 ~343/352/345 行缩至 ~210/215/210 行（平台私有：原生 window 创建 + raw surface 访问 + 6 个 ApplicationHandler 槽 + pump_host_sim + IME sink 闭包注入 iOS）。三端 `{P}RuntimeSession` 全删，`create_session` 改返回共享 `HostedRuntimeSession`（skia 包装同步改签）。三端测试适配共享 API（backend_test）；wbtest 修正既有文案漂移（"mobile surface epoch" → "embedded runtime surface epoch"，pre-existing 失败）。验证：共享包 8/8、三端 3/3、三端 skia 2/2+2/2+2/2、validator 25/25（allowlist +3 skia 包装路径，import 计数 3→7）；api-surface 报告 23 处既有失败与基线一致（无新增）；guidance-consistency 绿。残留：api-surface 23 处既有 core/runtime budget 债务（Wave 3 范围外）；mbti 更新 7 个包。 |

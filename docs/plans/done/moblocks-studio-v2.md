# Plan: MoBlocks Studio v2 — Web 拖拽回归修复、榫卯积木与四区布局

- **Status**: done
- **Superseded by**: [studio.md](../active/moui-studio.md)（2026-09-27：MoUI Studio统一取代 Mo易/MoBlocks 双 Studio，相关代码已删除，salvage 映射见新计划第 11 节）
- **Goal**: 偿还 MoBlocks Studio 冻结后发现的产品完善项：修复 Web 端画布拖拽整体失效的框架回归（P0），把长方形积木升级为榫卯/拼图形状并按分类配色，把底部 35+ 控件的大滚动面板重构为四区 IDE 布局，并偿还 ExecTick 无驱动等高优功能债务。
- **Non-goals**: 不改图模型语义（trigger/flow 端口图，不做 Scratch 栈式嵌套）；不改导出 bundle 格式；MCP 集成、minimap/框选/吸附仍留在赛后路线图。
- **Supersedes**: 无（是 `moblocks-studio.md` M5 冻结之后的增量完善，不重开其里程碑）。

## Background (root causes, verified 2026-09-26)

1. **Web 拖拽失效（P0 框架回归）**：`moui/backend/web/browser_runtime.js` 的
   `button: Number(event?.button) || 0` 把 pointermove 的 DOM `button = -1`
   （W3C Pointer Events：move 时无按钮变化即 -1）原样透传；`moui/core/modifier_event.mbt`
   的拖拽状态机自 `ad513a290`（2026-09-20，主键过滤）起要求 `event.button == 0`，
   于是 Move 全部被忽略、手势永远 Pending。native decode
   （`moui/backend/common/input/window_event_decode.mbt`）对 Move 不传 button
   （默认 0），故仅 Web 失效。同族缺陷：DOM 按钮码（0左/1中/2右）未映射 core 码
   （0左/**1右**/2中），Web 右键永不触发二级点击、中键误触发。
2. **积木形状**：`examples/moblocks_studio/app/canvas.mbt` 只有
   FillNode/StrokeNode 圆角矩形 op。`@core.PathSpec`（MoveTo/LineTo/QuadTo/CubicTo/Close）
   在 Skia/Web(WebGPU)/Canvas2D/native WGPU 四渲染器均为真实现
   （`docs/renderer-capability-report.md` Path/vector 全 supported），榫卯形状纯 app 层可画；
   无路径 clip，凹槽必须画进外轮廓而非挖洞。
3. **布局**：`app.mbt` `bottom_panel` 是单个 scroll_view 塞 35+ 控件
   （运行控制/时间线/工具箱/模板/选择积木），源于当时怀疑 row 子级命中缺陷；
   该缺陷已于 2026-09-26 复核为坐标系误用的测试误判
   （`docs/plans/done/row-child-hit-testing.md`），四区布局可以放心做。
4. **ExecTick 无驱动**：`app.mbt` 定义并处理 `ExecTick`，但无人派发；超时机制仅测试可达。
   先例：`three_d_physics_viewer` 的 `Subscription::timer` + 入口传 `app_environment()`。

## Milestones

### M1 — Web 拖拽回归修复（P0，框架层）

- [x] `moui/backend/web/web_pointer_input.mbt`：decode 规范化——Move/Exit/Cancel
  强制 button=0；Down/Up 做 DOM→core 按钮码映射（镜像 `mouse_button_to_core`）。
- [x] `moui/backend/web/browser_runtime.js`：仅 Down/Up 透传 `event.button`，Move 传 0。
- [x] 回归测试：`moui/backend/web` wbtest（move + button=-1 → 规范化为 0）；
  `moui/core` 契约测试（Move 带非主键 button 仍驱动拖拽）。
- [x] 浏览器 smoke：`record-web-runtime-presentation.mjs` 增加拖拽序列
  （press → ≥2 次 move >3px → release），断言至少一个 `pointer_move` 观测事件
  `flags & 1`（修复前为 0，此断言可捕获本回归）。
- [x] 双端验证：native 测试全绿 + web 构建浏览器实测拖拽。

### M2 — 榫卯积木形状 + 分类配色（app 层）

- [x] `canvas.mbt`：积木单条外轮廓 `PathSpec`（圆角矩形主体 + 顶边凹槽两段 cubic
  + 底边凸起两段 cubic，kappa≈0.5523 逼近）；fill=分类色；
  选中蓝描边/运行金色聚光灯沿用同路径 stroke。
- [x] 分类配色映射：事件=黄、AI=紫、安全=红、控制=蓝、数据=绿 + 文字对比色。
- [x] 命中测试升级：AABB 粗筛 + 凹槽/凸头区域精确判定（app 侧 ray-crossing/圆判定）。
- [x] 测试：draw plan 形状/数量基线、hit_test 边界用例、配色映射；双端全绿。

### M3 — 四区 IDE 布局重构（app 层 view-only 为主）

- [x] 顶部 toolbar：项目名、模板 menu、撤销/重做、缩放、运行控制、provider 状态徽章。
- [x] 左侧积木箱：按 5 分类分组的 17 积木按钮（复用 AddBlock Msg）。
- [x] 右侧检查器分区：属性 / AI 提案 / provider。
- [x] 底部时间线：运行步骤 + 审计；notice 改 banner。
- [x] `moblocks_ui_test.mbt` 定位路径更新 + 布局冒烟断言；双端全绿。

### M4 — 功能债务修复

- [x] ExecTick 定时驱动：`program()` 传 `subscriptions`（Running/WaitingConfirmation
  时 `timer.subscription(interval≈50ms, key="moblocks:exec-tick")`，否则 none）；
  两个入口传 `environment=@web.app_environment()` / `@macos_backend.app_environment()`。
- [x] Web 真实 provider 降级提示（入口注入可用性标志，消除静默挂起）。
- [x] `project_codec` next_id 缺省回退 `max_id+1`，删死代码。
- [x] `step_policy` 按真正上游 Retry/Timeout 节点推导 + 语义测试。
- [x] 小项：`block_catalog()` 提文件级常量；`sample_graph` 去魔数 id。
- [x] 护栏：sync_kernel `--check` 进 daily profile；README 故障排查补 index.html 路径说明。

### M5 — L1 交互（可选后续）

端口圆点/标签绘制、端口拖线连接（含类型即时反馈）、滚轮缩放、连线贝塞尔化。

## Acceptance

- Web 浏览器中画布积木可点选、可拖拽移动（拖拽 smoke 断言 handled flags）。
- 积木呈榫卯外形、5 类配色；凸头/凹槽区域命中正确。
- 界面为「顶工具栏 / 左积木箱 / 中画布 / 右检查器 / 底时间线」；无 35+ 控件单面板。
- 执行运行中超时可由 Tick 真实触发；Web 真实 provider 模式有降级提示。
- 全量：app/export/model_provider 双端测试全绿；`--profile pr` 通过。

## Risks

- 改 `moui/backend/web` / `moui/core` 触及发布闭包与静态校验组——每步跑
  validate-* 四件套与受影响包测试。
- 导出 bundle 的 vendored JS 由 `moon build` 再生成（无需手工同步），但
  moblocks 自身 `web_wasm/index.html` 直接 import 仓库 runtime.js，开发页立即生效。
- M2 命中测试与绘制基线变更会动 moblocks_test 的数量断言，逐条更新并保留语义。

## Progress

| Date | Progress |
|------|----------|
| 2026-09-26 | 立案：根因调查完成（Web button=-1 透传 × 主键过滤；PathSpec 全渲染器可用；bottom_panel 35+ 控件现状）。基线：app 52/52 native 全绿。 |
| 2026-09-26 | M1 完成：web decode 层按钮规范化（Move/Exit/Cancel→0，Down/Up DOM→core 映射）+ browser_runtime.js 仅按压透传；wbtest + native decode 契约测试；浏览器 smoke 增加拖拽探针与 dragInput=handled 断言，完整 smoke 通过（dragInput=yes）；真机浏览器拖拽实测恢复。app 52/52 双端绿。 |
| 2026-09-26 | M2 完成中发现并修复框架 P1 bug：`moui/render/common/advanced_execution.mbt` 的 `append_zeno_vertices` 把 zeno 顶点枚举的方向向量当坐标压入（`Middle(Vector,Point,Vector)`/`End(Vector,Point,Bool)` 首字段误绑），且按 3 个轮廓点分组当三角形并非三角化——所有经 zeno 三角化的路径填充（Web WebGPU/Web Canvas2D/native WGPU）产出垃圾三角形；此前被静默吞错掩盖（`render_frame` catch 全吞）。重写为命令展平（quad 12/cubic 16 段）+ 耳切三角化，新增面积守恒回归测试 3 项（曲线轮廓/凹多边形/退化轮廓）。榫卯形状落地：单条外轮廓（圆角主体+顶边凹槽+底边凸头，cubic kappa 逼近）、分类配色沿用、命中测试升级（凸头/凹槽精确判定）、选中/聚光灯外扩轮廓描边。app 55/55 双端绿，静态校验组通过，浏览器实测榫卯渲染与拖拽选中正常。 |
| 2026-09-26 | M3 完成：四区 IDE 布局——顶栏（项目操作/撤销重做/缩放/provider 状态徽章）+ 运行控制条 + 左侧积木箱（5 分类分组、"+"前缀添加按钮、模板、选择积木）+ 中央画布 + 右侧检查器（AI 生成→选中属性→Provider）+ 底部时间线；notice 固定 32px 通知条。UI 测试画布偏移魔数改为从语义树读「积木画布」帧（布局再调整无需改测试）；工具箱按钮加 "+" 前缀消除与画布积木标题的同名帧歧义。踩坑记录：scroll_view 无固有高度上限会把 flexible 中行撑出视口（用 frame(height) 封顶解决）；检查器控件统一 width=270。app 55/55 双端、export 8/8、provider 5/5 全绿；浏览器实测四区渲染正常。 |
| 2026-09-26 | M4 完成：(1) ExecTick 定时驱动——program() 增加 subscriptions（Running/WaitingConfirmation 时 50ms timer.subscription，状态离开自动取消），两个入口传 platform app_environment（先例 three_d_physics_viewer/mo_desktop；AppEnvironment 传 program 而非 runtime 的 environment 参数）。(2) Web 真实 provider 守卫——Model 增 real_provider_available 字段（入口注入），无 worker 入口拒绝切换并提示，消除静默挂起；测试更新为双语义。(3) project_codec next_id 缺省回退 max_id+1（删死代码），sync_kernel 再生成内核副本。(4) step_policy 重写——upstream_closure 反向可达（含自身），Retry attempts 钳制 [0,3]、总尝试=attempts+1（默认 3 与既有 4 次失败测试一致），Timeout 取真正上游最小预算；新增语义回归测试。(5) sample_graph 去魔数 id（显式跟踪分配 id、按 kind 收集外发节点）。(6) 决策：block_catalog() 常量化跳过（共享可变数组风险 > 每消息重建开销）；daily profile includes pr，sync 漂移门已覆盖 daily 无需新增。护栏：README 故障排查补 debug 产物路径说明；app.mbt 超源码行硬限→按原产品架构拆出 view.mbt（407 行），smoke 脚本 ratchet 按实测 1368 重新登记。app 56/56 双端、export 8/8、provider 5/5 全绿；浏览器实测自动运行→闸门暂停→时间线正常。 |

| 2026-09-26 | 收口：全量 pr profile 通过（含 source-file policy、格式门、生成接口刷新）。遗留：M5 可选项（端口拖线连接/滚轮缩放/端口标签）未启动，留待下一迭代；MoonBit 语言点与布局陷阱已沉淀 `memories/repo/moblocks-studio.md`。 |
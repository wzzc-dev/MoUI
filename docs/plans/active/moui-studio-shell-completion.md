# Plan: MoUI Studio 壳收敛——kernel 迁移完成线 + 预算棘轮

- **Status**: active
- **Date**: 2026-10-12
- **Related**: ADR 0038（插件内核）、`docs/plans/done/moui-studio-plugin-kernel.md`（M5/M8
  显式推迟 blocks/project 提取）、`docs/moui-studio.md`、
  ADR 0039（本计划的治理决定：完成线与棘轮）
- **Goal**: 结束「插件内核迁移无限并行」的状态：先给 app 旧壳上**只降不升的
  四项预算棘轮**（冻结今日基线），再按 ai/terminal/markdown 三次验证过的插件
  模式（状态切片 + `Feature::scope` 委托 + `[Msg]` 泛型视图构建器）分片把六个
  域搬出 app，直到 app 只剩壳 + 组合根，抵达可验收的**完成线**。
- **Non-goals**: 不动 `services/export`（12.7k 行，另行立项）；不动 `domain/*`
  （已干净）；不引入运行时插件动态性（ADR 0038 能力边界）；不为迁移改变任何
  用户可见行为；不把 app 归零（壳/组合根/共享漏斗/壳级回归测试是合法常驻）。

## 背景（2026-10-12 实测）

- app 包：**53 个源文件 / 37,279 行源码**（另有 35 个测试文件 14,956 行、
  `i18n_catalog_generated.mbt` 3,909 行生成物——两者不计入预算口径）。
- `Model` **155 字段**、`Msg` **291 变体**（ADR 0038 立项时约 100/150，持续增重）。
- kernel（1.1k）+ plugins（ai/markdown/terminal 合计 2.2k）≈ 3.3k 行，迁移
  完成度约 6%。
- 没有任何机制阻止新功能继续落进旧壳——每加一个功能都在给旧壳加权。

## 完成线（Definition of Done）

app 包 = 壳 + 组合根，四项预算全部达标（口径：`moui_studio/app/*.mbt`，
排除 `*_test.mbt`、`*wbtest.mbt`、`i18n_catalog_generated.mbt`）：

| 预算 | 基线（冻结） | 完成线 | 语义 |
|---|---|---|---|
| 源码行 | 37,279 | ≤ **18,000** | 只降不升；上调必须改预算表并写 reason |
| 源文件数 | 53 | ≤ **30** | app 新增源文件需预算表登记 |
| `Model` 字段 | 155 | ≤ **55** | 壳状态 + 每插件一个切片字段 |
| `Msg` 变体 | 291 | ≤ **90** | 壳消息 + 每插件 1–2 个包装变体 |

结构性标准（与预算同时验收）：

1. 六个域提取为插件包（状态切片 + update + `[Msg]` 泛型视图构建器 + 测试随包）：
   project / run / ai（补完）/ blocks / design / code。terminal、markdown 不动。
2. 三共享真源（program IR、选中三元组 `selected_control`/`selected_handler`/
   `side_target`、当前会话指针）root 持有，插件只读投影。
3. 跨域协作只走 EventBus 事件 + `StudioServices` + root 委托臂；插件互不
   import；插件包禁 import app（组合根是唯一反向边）。
4. 棘轮四预算在 pr profile 常驻。

## 棘轮机制（S0 落地，先于一切切片）

- 载体：扩展现有 MoonBit 校验器 `tools/moui/validate_maintenance_baseline`
  （它已在静态三件套与 pr profile 中，扩展即全链生效，零新 CI 步骤；
  仓库策略优先 MoonBit-backed 校验器，不写 Node 脚本）。
- 新增四个计数器：app 源码行、app 源文件数、`Model` 字段数
  （`pub(all) struct Model {` 块内字段行）、`Msg` 变体数
  （`pub(all) enum Msg {` 块内变体行）。
- 预算数字带 reason 注释记录在 MoonBit 预算目录（`CountBudget` 同形态）；
  上调预算 = 改目录 + 写 reason，即审计记录。
- 破断验证：故意超线一次确认会红，再复位。

## 切片

### S0 治理 + 棘轮（先行，零行为变化）

本计划文档 + ADR 0039 + 校验器扩展 + 破断验证。

### S1 共享视觉原子出壳 → `moui_studio/chrome` 新包

- 搬 `app/theme.mbt`（studio_theme / studio_product_theme /
  studio_window_background / ide_* 调色助手）与 `app/ide_chrome.mbt` 的
  共享原子（fill_row / action_chip / topbar_chip / wrap_text_lines /
  hint_lines_view / fit_label / ghost_icon_button / inline_card 等）。
- chrome 只 import moui 框架包（+ 必要的 geometry/graphics），禁 import
  app/kernel/插件；此后插件视图构建器 import chrome 取主题与原子。
- i18n 生成目录**不迁**（生成物留 app；插件以 `(String) -> String`
  translator 参数注入，markdown/terminal 既有先例）。

### S2–S7 每域一片（先浅后深；每片独立可验收、可中止，≤ ~5k 行）

| 片 | 目标包 | 搬走文件（实测行数） | 约行数 |
|---|---|---|---|
| S2 | plugins/project | project_explorer 2145、project_workbench 1046、new_project 462、code_project 217、search_pane、search_task、direct_scan 289 | ~4.6k |
| S3 | plugins/run | update_run 1429、preview_frame 875、preview_workspace 469、preview_web_slot、preview_semantics 282 | ~3.2k |
| S4 | plugins/ai 补完 | ide_ai 1642、update_ai 952、ai_sessions_pane 485、ai_workspace_panel 346 | ~3.4k |
| S5 | plugins/blocks | update_blocks 1038、blocks_canvas 1267、blocks_pane 743、blocks_slot_hit 256、statement_palette 480 | ~3.8k |
| S6 | plugins/design | canvas 850、form_design_canvas 263、form_design_session、stage_layout、update_selection + update_selection_msgs 584 | ~2.5k |
| S7 | plugins/code | code_view 1342、code_intel、views_compile 637、problems_pane 219 | ~2.4k |

**每片统一机制**（terminal/ai 既有先例，零新内核机制）：

1. 建包 `plugins/<name>`（import：moui 框架 + 所需 domain/services + chrome；
   禁 import app）。
2. 状态：从 Model 抽出该域字段组 → `ChildModel`；该域 Msg 子集 → `ChildMsg`。
3. update：`update_pure` 链中该域分支整体搬为
   `(ChildModel, ChildMsg) -> (ChildModel, Effect[ChildMsg])`。
4. 视图：面板/页签构建器改
   `pub fn[Msg] xxx_view(state, t~, callbacks…, width, height) -> View[Msg]`。
5. root 接线：Model 加一个切片字段、Msg 加一个包装变体、
   `Feature::scope(read, write, wrap)` 委托臂替换原 update 链分支；组合根
   注册 PanelView/BottomTab/CommandContribution。
6. 跨域契约：事件仍由 root 委托臂在事实发生处发（插件提供纯判定/签名
   函数，sessions_signature 模式）；undo 走 root 臂统一 `with_undo_point`
   （program_signature 前后比对判 no-op，语义与今日相同）；通知漏斗
   `with_notice` 留壳层。
7. 测试随迁：wbtest 随包走（internal 访问权）；黑盒 `*_test` 转向插件
   pub API；壳级回归（shell_layout 等）留 app。
8. 每片完成即降四预算并写 reason。

### S8 收官

- `update_pure` 链清空为纯路由；四预算降至终值；同步 `docs/moui-studio.md`、
  `moui_studio/README.md` 包结构图、`memories/repo/moui-studio.md`；
  计划迁 `docs/plans/done/`。

## 每片验收

- `moon test moui_studio/app --target native|wasm-gc` 全绿（基线 331/331，
  消息分布变化同步计数）+ 新插件包双目标全绿。
- 六静态门 + `sh scripts/check.sh --profile pr` 绿；`moon fmt --check` 仅对
  触碰文件。
- 行为零变化抽查：命令面板命令数、撤销/重做、两轨运行与切换、AI 提案
  校验链。
- 终态加一次真机冒烟（macos_skia：三模式切换、终端页签、AI 会话流、
  设计画布拖拽）。

## Risks

1. **循环依赖**（插件需要壳类型）→ 视图构建器以回调/translator 参数注入；
   插件禁 import app；root 是唯一反向边。
2. **undo 语义漂移** → root 臂单点 `with_undo_point`，签名判 no-op 不入栈。
3. **wbtest 白盒断裂** → 随包迁移；跨包断言转黑盒 `*_test.mbt`。
4. **迁移与新功能冲突** → S0 棘轮先上线：旧壳无法增行，新功能天然落插件包。
5. **单片过大** → 每片 ≤ ~5k 行、独立提交、可中止；S2 最重，必要时
   project_workbench 与 explorer 分两步。
6. **预算数字过紧** → 预算表 + reason 即审计通道，防的是「无声增重」，
   不是绝对行数。

## Decision log

| Date | Decision |
|------|----------|
| 2026-10-12 | 计划获批（ExitPlanMode）：完成线四预算 18,000/30/55/90；棘轮先于切片；六域顺序 project→run→ai→blocks→design→code（浅耦合先行，M5/M8 记录「先 project 后 blocks」） |
| 2026-10-12 | 棘轮载体 = 扩展 `validate_maintenance_baseline`（MoonBit-backed、已在 CI 常驻），不写 Node 脚本 |
| 2026-10-12 | i18n 生成目录留 app（不迁）；插件视图经 translator 参数注入文案——markdown/terminal 先例 |
| 2026-10-12 | 事件/undo/通知三跨域面全部留在 root 委托臂，插件只提供纯判定函数——ADR 0038「纯监听器 + 副作用走 update 臂」纪律，零新内核机制 |

## Progress

| Date | Note |
|------|------|
| 2026-10-12 | S0a 计划落盘 |
| 2026-10-12 | S0b ADR 0039 落盘并登记 decisions README 索引 |
| 2026-10-12 | S0c `tools/moui/validate_maintenance_baseline` 新增 `studio_shell_budgets.mbt`：四计数器（app 源码行 / 源文件数 / Model 字段 / Msg 变体），基线冻结 37,279 / 53 / 161 / 291 |
| 2026-10-12 | S0d 破断验证：三项预算各临时降 1，确认计数器红（lines=37,279、fields=161、variants=291，与实测一致）后复位 |
| 2026-10-12 | S0e 静态门全绿：doc-references / guidance / api-surface / release-closures / renderer-capability / maintenance-baseline + moon fmt |
| 2026-10-12 | **S1 chrome 出壳完成**：`moui_studio/chrome`（theme.mbt 606 + chrome.mbt 910）迁出 theme.mbt、ide_chrome 共享原子（fill_row/panel_head/tree_row/kv_row/action_chip/pill 等 21 个 `[Msg]` 泛型原子 + 19 个尺寸常量 + ChipTone/IconTint）与 fit_label；app 保留 6 个 Msg 绑定壳件（icon_button/ghost_icon_button/shortcut_*/round_send_button/topbar_action）。39 个 app 文件改限定名；撞名修复：canvas 字段 empty_hint、SlotHole 模式变量 pill、测试局部 empty_hint。验收：app 双目标 435/435 全绿，入口双目标 0 错误，i18n 目录 --check ok。预算首降：35,721 / 52（fields/variants 不变，S1 是纯共享面提取） |

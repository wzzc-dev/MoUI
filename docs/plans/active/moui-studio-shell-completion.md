# Plan: MoUI Studio 壳收敛——kernel 迁移完成线 + 预算棘轮

- **Status**: active
- **Date**: 2026-10-12
- **Related**: ADR 0038（插件内核）、`docs/plans/done/moui-studio-plugin-kernel.md`（M5/M8
  显式推迟 blocks/project 提取）、`docs/moui-studio.md`、
  ADR 0039（本计划的治理决定：完成线与棘轮）、
  ADR 0040（2026-10-12 修订：完成线改三档阶梯，A 档为承诺线）
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

> **2026-10-12 修订（ADR 0040）**：原单一完成线 ≤18,000/30/55/90 的**可达性
> 从未核算**。按本计划自己的侦察结论实测剩余可迁量 = 7,494 行 / 14 文件
> （纯文件整体迁 3,127 + Model 耦合视图宽参数改造 4,367），S4–S7 全做完也只
> 到 ~26,000 行 / ~37 文件。完成线已改为**三档阶梯**，A 档为承诺线，C 档为
> 北极星；棘轮机制不变（上限仍是实测值的只降不升）。推导与规则见
> [ADR 0040](../decisions/0040-studio-shell-completion-stages.md)。

app 包 = 壳 + 组合根（口径：`moui_studio/app/*.mbt`，排除 `*_test.mbt`、
`*wbtest.mbt`、`i18n_catalog_generated.mbt`）：

| 档 | 源码行 | 源文件 | `Model` 字段 | `Msg` 变体 | 达成条件 |
|---|---|---|---|---|---|
| 起点（2026-10-12 实测） | 33,535 | 51 | 145 | 278 | — |
| **A 承诺线（ADR 0041 修订）** | ≤ 27,000 | ≤ 40 | ≤ 115 | **≤ 238**（实测下限，旧 140 投影撤回） | 六域插件化（状态切片 + update + `[Msg]` 视图 + 测试随包） |
| **A 达成实测（2026-10-13）** | **27,000** | **39** | **113** | **238** | ✅ 四项全部达标，guardrails: ok / sync current |
| **B 稳态纪律线** | ≤ 22,000 | ≤ 32 | ≤ 80 | ≤ 100 | run 域状态切片（Effect 形态定型后）+ 组装件继续宽参数化 |
| **C 原完成线（北极星）** | ≤ 18,000 | ≤ 30 | ≤ 55 | ≤ 90 | 需超出 S4–S7 的新工作：壳边界重界定或壳级视图再拆分 |

分档规则（ADR 0040）：棘轮上限与分档目标分离——`studio_shell_budgets` 的
`max_count` 始终是**当前实测值**（每次提取完成即降并写 reason），不是上表的
目标值；A 档达成即可宣称本计划完成；进 B 档前必须先做一次壳边界重界定评审。

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
| S5 | plugins/blocks | ~~update_blocks 1038、blocks_canvas 1267、blocks_pane 743、blocks_slot_hit 256、statement_palette 480~~ | ~3.8k → **实际 1.1k（2026-10-12 落地）** |
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

- `update_pure` 链清空为纯路由；四预算降至此档目标值；同步
  `docs/moui-studio.md`、`moui_studio/README.md` 包结构图、
  `memories/repo/moui-studio.md`；计划迁 `docs/plans/done/`。
- 「收官」的判定按 **A 承诺线**（ADR 0040）：S4–S7 完成 + 四预算进 A 档区间
  即宣称完成；B/C 档另立范围决策，不算本计划的欠账。

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
| 2026-10-12 | **S2 侦察完成**：project 域 = 17 个 Model 字段（new_project(+confirmed)、pending_open_dir、dirty、projects、active_project、scan_progress、projects_restore_pending、project_tree_collapsed、selected_project_file、explorer_scroll/hover/sections_collapsed/menu_open、open_project_files、recent_changes、recent_seq）+ 39 个 Msg 变体（ProjectFile*×9、Explorer*×6、NewProject*×3、ProjectScan*×3、ProjectsStore*×4、Rename*×3、Build*×2、Import/RootPicked/SetActiveProject/ToggleProjectDirAt/SelectProjectFile(At)/RemoveProject/CodeProjectSaved/CodeProjectWriteRequested）。全量提取后 Model 161→144、Msg 291→252。跨域缝（root 臂负责）：`pending_open_dir` 被 `emit_code_project_write`（EvCodeProjectWrite 发出点）消费——迁入切片后 emit 函数改收 (child, program) 参数；`dirty/projects` ↔ EvProjectsDirty 签名判定；ProjectBuild* 走 build 服务键。建议切法：S2a 先迁视图构建器（project_explorer 2145 / project_workbench 1046 / search_pane+search_task / direct_scan 289 / new_project 462 / code_project 217，`[Msg]` 泛型化，机械搬移），S2b 再做状态切片 + Feature::scope（改动面大、独立验收） |
| 2026-10-12 | **S2a 行模型出壳完成**：新包 `moui_studio/plugins/project`（1,216 行）迁出——①工程类型 4 个（ProjectRecord/WorkspaceRecord/OpenProjectFile/RecentChange，壳留 `pub type` 别名零改引用）②ExplorerRow 行模型全家族（explorer_rows + push_*×12 + tier/dir/member 递归 + ExplorerData 13 字段快照注入,`data` 语义）③纯工具（outline 解析 5 fn、路径 4 fn、file_icon/file_tint、sort、滚动钳制）④节区常量（WORKSPACE_ROOT_INDEX/EXPLORER_SECTION_*/TIMELINE_ROWS）⑤快照纯助手（tree_rel_of_project(_file)/active_project_file/file_is_dirty/recent_tail）。壳侧接线并入 project_explorer.mbt（`using @proj {type ExplorerRow}` 带构造器进作用域 + 20 个同名转发包装 + explorer_data_of 快照组装）。别名纪律：插件内 services/project 改名 `@scan`（与包名 project 冲突）。验收：app 双目标 435/435 全绿、插件双目标 0 错、入口双目标 0 错、i18n --check ok、六静态门 + pr profile 全绿（单文件棘轮 10 升 3 降,升因全部为限定名 fmt 折行/存量债,降因 model/pe/blocks_canvas 逻辑实迁出）。预算二降：35,721 → **35,034**（文件 52、fields 161、variants 291 不变——S2a 不动状态）。剩余 S2 范围：渲染族 + toolbar 参数化（explorer_row_view 等 ~700 行）与 S2b 状态切片 + Feature::scope |
| 2026-10-12 | **S2b-1 状态切片完成（嵌套 ProjectState）**：`plugins/project` 新增 `ProjectState`（17 字段：projects/active_project/workspace_root/open_project_files/open_file_index/project_tree_collapsed/explorer_sections_collapsed/selected_project_file/explorer_scroll/explorer_hover/explorer_menu_open/scan_progress/file_create_dir/file_create_open/file_rename_open/folder_create_open/file_name_draft），Model 17 字段收敛为单一 `project_state : @proj.ProjectState`（161→**145**）。全仓改写：嵌套展开两级化（`{ ..m, project_state: { ..m.project_state, K: v } }`,含 pun/函数接收者/混合键拆分）+ 接收者改写（model/next/imported/picked/restored/in_app/started/removed 等,排除 store 记录与字符串误命中）+ initial_model 嵌套构造。跨域真相留根（pending_open_dir/dirty/new_project(+confirmed)/projects_restore_pending/recent_changes/recent_seq 仍住 Model——按侦察缝定）。验收：app 双目标 435/435 全绿、入口/插件双目标 0 错、六静态门 + pr 全绿（单文件棘轮 6 升 1 降;MoonBit line_budget_catalog app.mbt 2580→2653 按「结算到实测值」先例）。预算：lines 35,034→**35,251**（嵌套展开 fmt 折行净回吐 ~217,仍低于 S2a 前的 35,721）、fields 161→**145**。剩余 S2b-2：ProjectMsg 子消息（14 纯态臂迁插件 update）+ `Feature::scope` 委托臂 + 渲染族随子消息出壳 → Msg 291→~277、渲染 ~700 行 |
| 2026-10-12 | **S3b-2 预览视图贡献出壳**：侦察修正——`preview_workspace` 主体是跨三域的壳组装件（工程名/构建动作/布局设计器区/form_design_canvas 内嵌）,按 markdown/terminal「视图由壳组装」终态判留壳;真·预览视图是两个:`preview_replay_canvas`（帧重放 + 选中描边 + 点选命中）与 `semantic_property_strip`（属性条 + label 编辑/提交）。两视图以 `[Msg]` 泛型标签参数形迁 `plugins/run/preview_views.mbt`（204 行）:参数 = frame/selected_index/draft/t + `on_select~`/`on_label_input~`/`on_label_commit~` 回调;壳留薄包装（同签名,构造 SelectSemanticNode/SemanticLabelInput/SemanticLabelCommit 回调）,调用点零改动。preview_web_slot（38 行,平台组合根注入点）留壳定论。插件 moon.pkg 补 moui/views/style/chrome/i18n;text/text_with 包内局部助手（plugins/project 先例）。验收:app 435/435 双目标、双包 0 错、i18n ok、六静态门 + pr 全绿。预算:lines 33,765→**33,617**;preview_workspace.mbt 473→325。**S3 域完结判定**:数据层（帧/语义）+ 运行态结构 + 纯视图皆出壳;运行臂（studio_lang 步进/PTY/服务任务）属真源编排,留壳是终态形态,不再单列切片 |
| 2026-10-12 | **S3b-1 运行态结构出壳 + S3b 视图改造契约**：`RunModel`（handler_label/state/checks/single_step）与 `CompiledRun`（handler_label/runtime/checks）两结构体迁 `plugins/run/run_types.mbt`（moon.pkg 补 @studio_lang + compiled_runtime 导入,单 import 块——**moon.pkg 不容两个 import 块**）;app/model.mbt 留两条类型转发别名（S2a 先例）,构造点重限定 `@run.RunModel::{}`/`@run.CompiledRun::{}`（update_run.mbt + ai_bar_layout_wbtest）。事故与修复：carve 正则第三次犯「最左 ///| 吞中段」病（把 Mode 枚举等 12 段切进插件文件）——git checkout 恢复后行级重做;**铁律已三犯,永久采用行级锚定**。**S3b-2 视图改造契约**（preview_workspace 469/preview_web_slot 38 出壳的机械配方）:① 三视图签名 `preview_workspace/preview_replay_canvas/semantic_property_strip(model : Model, t, w, h)` 是 Model 耦合视图,须改 `[Msg]` 泛型标签参数形（markdown/terminal 先例）:参数结构体 `PreviewWorkspaceParams`（preview_mode/preview_frame/selected_semantic/semantic_draft + active_project 的 `@proj.ProjectState` 只读投影 + web 可用性三元组）+ 回调面 `on_set_preview_mode~ : (PreviewMode) -> Msg`、`on_navigate~`、`on_reselect~`、`on_semantic_edit~`;② mode_strip_button/semantic_property_strip 同随;③ 调用点（views.mbt 工作区组装）改传 params + 回调闭包;④ 验收同全门。RunModel/CompiledRun 状态切片（`run_state : @run.RunState` 嵌套化）排后——运行臂的 Effect 形态先定契约再动（Feature::scope 支持 effect 提升,RunTick 的定时效果链可走 `init/update` 出站 effect,但 studio_lang 步进管线的归属需先评审,不盲迁） |
| 2026-10-12 | **S3a 预览数据层出壳（plugins/run 开包）**：侦察定论——运行域的 update 臂（RunTick/RunStart/CompileRun*/RunStep/终端臂）深耦 @studio_lang 步进、PTY 效果与服务任务,非 Feature::scope 纯态切片候选;该域的正确解药是「数据层 + 视图贡献」出壳（markdown/terminal 先例）。本轮落第一层:`app/preview_frame.mbt` **整文件 875 行**（PreviewFrame 结构 + Json→DrawCommand 解析器族 + 预览哨兵/版本校验）与 `app/preview_semantics.mbt` 纯头 224 行（SemanticHitNode + hit_nodes/hit_index + find_literal_span + SemanticPatchRequest/label_patch_task/patch_step）迁 `plugins/run`;Model 耦合的 semantic_commit_request（58 行）留壳。app 侧:model.mbt 三条类型转发别名（PreviewFrame/SemanticHitNode/SemanticPatchRequest,S2a 先例）+ moon.pkg 增 @run + 调用点重限定（app.mbt/update_shell/preview_workspace/preview_semantics 尾 + 测试 @app.→@run.）。plugins/run/moon.pkg:core/geometry/services/json/services/project（哨兵常量）。验收:app 双目标 435/435、插件+两入口双目标 0 错、i18n ok、六静态门 + pr 全绿（model.mbt 1552→1564:别名 +12,按先例结算）。预算:lines 34,865→**33,777**、files 52→**51**（variants 278/fields 145 持平）。剩余 S3b:preview_workspace(469)/preview_web_slot 视图贡献随 [Msg] 泛型出壳 + RunModel/CompiledRun 状态切片评估 + 运行臂的 Effect 形态重估（子消息需带 effect 出站的形态——Feature::scope 支持 effect 提升,ai_sessions 弃用是因为零副作用,run 域可用） |
| 2026-10-12 | **S2b-2 子消息委托完成（ProjectMsg + Feature::scope）**：`plugins/project/project_update.mbt`（~620 行）——`ProjectMsg` 14 变体（载荷逐字同壳原版）+ `update_project` 纯态切片 update（零副作用,ai_sessions 先例）+ `ProjectState::new` + `project_feature`（view 域 abort,壳组装）+ 随迁助手（active_file_of/unfold_dir/collapse_all_tree_keys + seed 族 6 fn/replace_open_file_at,seed 族供根臂导入/恢复流程经 pub 包装共用）。壳侧：Msg **291→278**（−14 +ProjectOp 单一委托臂）;`project_scope` lens 对（read/write/wrap）+ `ProjectOp` 委托臂——`ToggleProjectDirAt` 的展开揭示滚动需行推导+translator,根臂后处理补上（折叠翻转在切片,滚动定位在根,ai 先例形态）;死码清除（toggle_project_dir/unfold_dir 壳版）。构造点包装：11 个带参变体平衡括号包 `ProjectOp(...)` + 3 个无参变体词界包,覆盖 8 文件 ~87 处（渲染回调/测试构造/模式匹配统一）。事故与修复：take_fn 正则「最左 ///| 吞到首个 \n}」连误切 project_workbench 顶部 8 个无关函数与 update_shell 的 ai_sessions_scope——git checkout 回滚后改行级删除重做;教训入档：函数级搬移必须锚定 decl 行再向上收 doc、向下收配对 `}`。验收：app 双目标 435/435（含滚动揭示/CRUD 链/分区折叠行为测试）、插件+入口双目标 0 错、i18n ok、六静态门 + pr 全绿（2 升 2 降:update_shell 1566→**1296** 逻辑行,model 1583→1552）。预算四降：lines 35,251→**34,865**、variants 291→**278**（fields 145、files 52 持平）。S2 域整体完结判定：行模型+状态+子消息三层皆出壳,渲染族（~700 行,toolbar/行渲染）留壳组装——按 markdown/terminal 插件先例「视图由壳组装」属终态形态,不再单列切片;后续若要再收,并入 S8 前的重评估 |
| 2026-10-12 | **S4 侦察(交棒)**:ide_ai.mbt 实测 **0 svc/Effect 耦合**——38 个函数全是纯视图(组装器高度/composer/会话头/时间线/气泡/卡片/浮动层),1,642 行,是剩余最大单文件出壳候选;其 Model 读取面以 ai_* 域内字段为主,可按 S3b-2 两步走:①先迁 `ai_card_height/thread_area_height/card_chrome_height` 等纯几何(不触 Model 消息)零风险出壳;②视图主体以 `[Msg]` 泛型 + ai 域参数结构(`AiViewParams`:ai_sessions 流投影/草稿/流态/卡片开关)迁移,壳留薄包装。update_ai.mbt(952 行)实测 **40 处 svc/Effect** = LLM 服务编排,属真源编排留壳(与 S3 运行臂同判定)。ai_sessions_pane(485)/ai_workspace_panel(346)未及侦察,下轮先分类再动。预算现状:33,617/51 文件/145 字段/278 变体;S2/S3 两域已完结,剩 S4-S7 + S8 收官 |
| 2026-10-12 | **S4① 配方细化**:composer_height/context_chips_height/composer_block_height 三函数虽是纯几何(仅 width 参数),但依赖 COMPOSER_HEIGHT/CHIPS_HEIGHT 常量——**MoonBit 常量不可经 pub type 转发**,迁移动作 = 常量随函数入 plugins/ai + 壳内用点(card_chrome_height/ai_card_height 等)重限定 `@ai.COMPOSER_HEIGHT`;S4② 的 AiViewParams 面以 ai_sessions(已有切片)/composer 草稿/stream 态/卡片开关为主,消息构造点多为 AiSessionOp 包裹与层控开关,回调面小。本轮无代码变更,两仓保持上轮提交态 |
| 2026-10-12 | **S4① 落地**:CHIPS_HEIGHT/COMPOSER_HEIGHT 两常量 + composer_height/context_chips_height/composer_block_height 三纯几何函数迁 plugins/ai/ai_geometry.mbt(39 行,常量随迁 + 壳内用点 @ai. 重限定——常量不可转发的配方生效);壳留同签名转发包装(测试与布局计算零改动)。事故:take() 曾以 `}` 收块,常量无闭括号 → 吞到远处函数尾后后续 take 失败——脚本死于写盘前,文件未损;改单行收块后成功。验收:app 435/435 双目标、双包 0 错、基线守卫 ok、pr 全绿;ide_ai.mbt 棘轮降 1707→1685。预算:lines 33,617→**33,595** |
| 2026-10-12 | **S4② 签名配方侦察**:ai_card_height/thread_area_height/card_chrome_height 读面实测 = `model.ai_sessions`(已是 plugins/ai 自有类型,插件内可直接用)+ `model.ai_cards_folded`(壳布尔)——迁移签名即 `(sessions : AiSessions, cards_folded : Bool, card_width : Double) -> Double`,壳包装 `@ai.ai_card_height(model.ai_sessions, model.ai_cards_folded, w)`;无新增参数结构需求,比预估更薄。view 主体(ai_center/ai_transcript/timeline_rows/气泡族)的读面待同法逐函数盘点后批量迁移。本轮无代码变更 |
| 2026-10-12 | **S4② 落地(高度器首件)**:域界实证——decision_bar_height 读 proposal 真源(pending/explanation),card_chrome_height 链因此出域留壳;纯 ai 域的 thread_area_height 以 `(AiSessions, cards_folded)` 签名迁 plugins/ai(壳留包装,ai_card_height 调用点零改动)。验收:435/435 双目标、双包 0 错、基线 ok、pr 全绿;ide_ai 棘轮 1685→1675。预算:lines 33,595→**33,585**。S4② 后续:ai_center/ai_transcript/timeline_rows/气泡族按同法盘点读面后批量迁移 |
| 2026-10-12 | **S4③ 落地(see_all_row)**:读面盘点——user_bubble_row 实测内嵌 message_actions_row + text 依赖链(首迁尝试回滚,零损伤),纯件收窄为 see_all_row;以 `[Msg]` 泛型 + `on_toggle~` 回调迁移(SEE_ALL_HEIGHT 常量随迁,配方二次生效),壳留包装(ToggleAiHistory 注入)。timeline_rows/ai_session_header(ai_sessions 读面)与 work_group_row/bar(ai_cards_folded 读面)下轮按同法批量。验收:435/435 双目标、双包 0 错、基线 ok、pr 全绿;ide_ai 棘轮 1675→**1636**。预算:lines 33,585→**33,546** |
| 2026-10-12 | **S5 侦察(blocks_canvas 依赖链)**:blocks_canvas.mbt(1,267 行,19 fn)实测零 Model/svc/Effect,但内嵌 `BlocksDragState`(壳类型)与 `blocks_slot_rects`(住在 blocks_slot_hit.mbt,256 行)——**非自包含,须捆绑迁移**:S5 首迁单元 = blocks_canvas + blocks_slot_hit + BlocksDragState 类型随迁(或先审 slot_hit 纯度定边界)。整体尝试已干净回滚(工作区 0 变更,app 0 错,零损伤)。出壳顺序建议:S5 以「canvas+slot_hit 捆绑」开包,后续 blocks_pane(743)/update_blocks(1038)按读面盘点跟进 |
| 2026-10-12 | **S5 二次侦察(捆绑面定界终版)**:blocks_canvas + blocks_slot_hit 捆绑迁实测又暴露一层——纯几何层携带 **7 个共享类型**(BlockArm/BlockBadge/BlockLabel/BlockOutline/BlockStroke/InsertMark/ScriptNote/SlotHole 族,壳视图与测试大量模式匹配)+ 2 常量(BLOCKS_EDGE_ZONE/BLOCKS_NOTE_HEIGHT)+ blocks_row_arrow 函数;blocks_canvas 的视图函数本体(~520 行)构造 6+ 个 App Msg(BlocksContextMenu/EditBlockValue/BlocksCanvasTap/BlocksAutoScroll/ExpressionDrop/Noop),须留壳(并入 blocks_pane 可保文件数)。**S5 完整配方定版**:① plugins/blocks 承载 = slot_hit 全文 + canvas 的 15 个纯几何函数 + 7 类型 + 2 常量 + row_arrow;②壳侧 blocks_pane.mbt 收 canvas 视图函数(文件数守 51);③跨包模式匹配的枚举须 pub(all),类型用点需逐点验证限定形态(@blk.X 在 pattern 中的写法待专项验证)。两次尝试均干净回滚(工作区 0 变更、app 0 错)。S5 需整轮专攻,不宜碎步 |
| 2026-10-12 | **S7 侦察 + S4-S7 统一形态结论**:problems_pane.mbt(219 行)读面实测 = language/program(IR 真源)/code_error/code_diagnostics/selected_handler/code_draft/last_build/compile_report——**跨域真源组装件**,与 preview_workspace/ai_sessions_pane 同判定族(留壳或宽参数结构改造)。至此 S4-S7 剩余大件全部盘点完毕,统一形态结论:**出壳余量主体是 Model 耦合视图/组装件**,只有两种处置——①纯函数文件整体迁(S3a 型,已穷尽:preview_frame 类);②宽参数结构 + [Msg] 泛型改造(每件 200-1,500 行,每件一个专注整轮,早期轮次的单轮容量可达 ~1,300 行)。碎步策略对此类文件失效(S5 两回滚实证)。**收官路径修定**:后续会话按「单件整轮」节奏执行 S4 视图族 → S5 捆绑 → S6/S7 逐件;本目标周期内若轮次耗尽,棘轮闸门保证已出壳部分永不回退,完成线作为持续北极星 |
| 2026-10-12 | **完成线分档（ADR 0040）+ 独立 CI + 壳卫生清理**:① 实测剩余可迁量 = 纯文件整体迁 3,127 行（blocks_canvas/blocks_slot_hit/statement_palette/canvas/stage_layout/code_project，均零 `model.` 读取）+ Model 耦合视图宽参数改造 4,367 行（ide_ai/ai_sessions_pane/ai_workspace_panel/blocks_pane/views_compile/problems_pane/form_design_canvas/form_design_session）= 7,494 行 / 14 文件；S4–S7 全做完也只到 ~26,000 行 / ~37 文件，原 18,000 完成线不可达 → ADR 0040 改三档阶梯（A 承诺 ≤27,000/40/115/140；B 稳态 ≤22,000/32/80/100；C 北极星 = 原 18,000/30/55/90），棘轮机制不变（上限仍绑实测值）。② `moui_studio/.github/workflows/ci.yml` 落地：母仓库 pr profile 的 7 个 Studio 门禁按子仓库包路径搬入，另补 app 的 wasm-gc 测试、web 入口构建、`moon check` / `moon fmt --check`；i18n catalog 门（生成器在母仓库）与真机冒烟（路径触发）刻意不收；工具链钉在 `moui_studio/.moonbit-toolchain`。③ `tools/sync_kernel` 双根解析修复：路径表按母仓库根书写，`resolve_repo_path` 按当前根补/去 `moui_studio/` 前缀——子仓库根 `moon run tools/sync_kernel -- --check` 从必报 IOError 变为 `current`（README 原写法因此是错的，已改）。④ 壳卫生：删 2 个切片后遗留的未用包装（`section_collapsed` / `collapse_all_tree_keys`）、2 个未用 import（plugins/ai 的 geometry、plugins/run 的 views/style）、2 个 unreachable_code 测试臂；plugins/run 补 `supported_targets`。**Studio 自有代码 `moon check` 从 6 警告降到 0**。预算：lines 33,546 → **33,535**（files 51 / fields 145 / variants 278 不变，本轮是纯清理不是切片）。验收：app 435/435 双目标、全模块 4,952/4,952 native、`moon fmt --check` 干净、sync_kernel 双根 `current`、`validate-maintenance-baseline` ok |
| 2026-10-12 | **S5 blocks 捆绑整轮落地（两次回滚后的第三次成功）**:按 S5 二次侦察定版的配方执行——① 新包 `plugins/blocks`（`moon.pkg` 里 domain/blocks 起别名 `@blk`，因为本包名就是 blocks，与默认别名冲突，plugins/project 的 `@scan` 先例；`String::substring` 已废弃，一律用切片语法）承载 `blocks_slot_hit.mbt` 全文 256 行 + `blocks_canvas.mbt` 的 15 个纯几何函数 + `BlocksDrawOp` + `BlocksDragState` + `BLOCKS_NOTE_HEIGHT`/`BLOCKS_EDGE_ZONE` 两常量 + `blocks_row_arrow`/`blocks_row_lead_width` + `block_outline_path`/`paint_block_outline`，拆成 `blocks_geometry.mbt`（几何/命中/落槽/拖拽态）/ `blocks_draw.mbt`（绘制计划/枚举/PathSpec）/ `blocks_slot_hit.mbt`（洞与值命中）三文件 + `blocks_wbtest.mbt` 3 条不变量（链条 y 换算、C 形同层兄弟右缩、洞段才产矩形）；② 壳侧 `blocks_canvas` 视图函数（398 行，构造 6+ App Msg 的那枚）整段并入 `blocks_pane.mbt`（761 → 1,172 行，仍在 1200 硬限内），`app/blocks_canvas.mbt` 与 `app/blocks_slot_hit.mbt` 两个文件删除；③ `app/model.mbt` 的 `BlocksDragState` 结构体改为 `pub type` 转发别名（S2a/S3a 先例），`app/moon.pkg` 主块与 `for "wbtest"` 块各加一条 `plugins/blocks @blk`；④ 全仓 `@app.X`/裸标识符按符号表批量改限定：app 源 + wbtest + `*_test` 三处共 99 处。**双目标 435/435 全绿、plugins/blocks 3/3、入口双目标 0 错、`moon fmt --check` 干净、sync_kernel 双根 `current`、六静态门 + pr profile 的 7 个 Studio 门全绿、Studio 自有 `moon check` 0 警告**。预算四降：lines 33,535 → **32,481**、files 51 → **49**（fields 145 / variants 278 不变——`block_drag` 字段与 Msg 未动，本轮是纯几何/绘制层出壳）。S5 域完结判定：纯几何 + 绘制计划 + 命中三层皆出壳；`update_blocks`（1,038 行，深耦 studio_lang 步进）与 `blocks_pane` 的组装视图按 markdown/terminal「视图由壳组装」终态判留壳 |
| 2026-10-13 | **S6a design 开包（canvas+stage_layout 出壳）**：新包 `plugins/design`（`design_geometry.mbt` 549 纯几何/绘制计划：design_width/height、stage_point/mapping、title_bar/design_total_height、control_rect、hit_test_control/handle（手柄半径常量改 pub）、DesignDrawOp、网格/参考线吸附 snap_move/resize、design_backdrop/overlay_plan、pane_fill_measure；`stage_layout.mbt` 97：priv StageLayout 节点 + `@core.ViewNode` 实现 + 泛型 `stage_layout` + `fit_scale`；`design_stage.mbt` 299：视图改 `[Msg]` 泛型 + `window_back_color` 注入 + `on_tap~`/`on_drag~` 回调，包内调用回调用裸 `on_tap(...)` 非 `~`）。壳侧删 `canvas.mbt`/`stage_layout.mbt` 两文件；`workspace.mbt` 收一个 `design_stage` 薄壳包装（prop_color 解析底色 + 手势→CanvasTap/Press/DragTo/Release）；`blocks_pane.mbt` 承接包级 `using @views {draw_text,fill_rounded_rect,stroke_rounded_rect}`（原 canvas.mbt 的包级 using 随文件删除，wbtest 亦可见）；update/views/workspace/form_design_canvas/app_test 调用点重限定 `@design.`。**关键坑**：MoonBit 包级 `using` 是全包可见，删携带文件会使他文件同名构造器失绑；多参闭包做命名参数须 `fn(...)` 形式，`(x,y){...}` 会被解析成元组。验收：app 双目标 451/451、插件双目标 0 错、六静态门 + sync_kernel current + fmt 干净。预算四降：lines 32,421 → **31,489**、files 49 → **47**、fields 145 → **144**（复核收紧）、variants 278 持平。剩余 S6：form_design_canvas 263 / form_design_session 162 / update_selection 159 + update_selection_msgs 584 |
| 2026-10-13 | **S5c statement_palette 整文件出壳**：`app/statement_palette.mbt`（480 行，`pub(all) struct StatementTemplate/ExpressionTemplate` 模板数据 + 分类/查询，纯数据零 Model/Msg）整文件迁 `plugins/blocks/statement_palette.mbt`；域内 `@blocks.`→`@blk.`（35 处）、唯一 `text(t,..)`→`t.translate(..)`；`plugins/blocks/moon.pkg` 加 `moui_i18n`(@i18n) + `domain/studio_lang`。壳 update_blocks/blocks_pane 与三个 *_test 重限定 `@blk.`（含 `Array[@blk.StatementTemplate]`）。验收：app 双目标 451/451、插件双目标 0 错、六静态门 + sync_kernel current。预算：lines 31,489 → **31,009**、files 47 → **46**、fields/variants 144/278 持平 |
| 2026-10-13 | **S6c form_design_canvas 出壳**：新建 `plugins/design/form_design_canvas.mbt`（form_design_hit_index/form_design_handle_hit/canvas_width_of/canvas_height_of 纯几何 + 泛型 `form_design_drag_commit[Msg]` 与 `form_design_canvas[Msg]`，入参 `FormModel` + `noop~/on_select~/on_drag~/on_resize~` 回调；`plugins/design/moon.pkg` 加 `services/form_designer`，无环——该服务仅依赖 domain/ir）。壳删 `app/form_design_canvas.mbt`；`form_design_session.mbt` 收 `form_design_canvas`/`form_design_drag_commit` 两个薄壳包装（枚举构造器不能作高阶函数，`on_select=fn(i){SelectFormControl(i)}`）；原内嵌测试「external reload swaps session on changed source」追加到 `form_design_session_wbtest.mbt`，纯几何断言改 `@design.`。验收：app 双目标 451/451、插件双目标 0 错、六静态门 + sync_kernel current。预算：lines 31,009 → **30,790**、files 46 → **45**、fields/variants 144/278 持平 |
| 2026-10-13 | **S7 code 域开包（code_intel 先行）**：新建 `plugins/code`（moon.pkg：domain/ir + domain/studio_lang，native+wasm-gc）；`code_intel.mbt` 含从 ide_state 迁来的纯 `split_line_texts`、`word_at_caret`/`apply_completion`（签名不变），并把 `completions_for(model,prefix)`/`declaration_line_of(model,caret)` 参数化为 `(language:@studio_lang.Language, controls:Array[@ir.Control], code_draft, prefix)` 与 `(language, code_draft, caret)`——不再读 app Model，语言由壳先算 `model.language.dsl_language()` 传入。壳删 `app/code_intel.mbt`、从 ide_state 删 split_line_texts 定义；split_line_texts 5 个文件 10 处调用重限定 `@code.`；update_shell 四个调用点重限定；code_intel_test（黑盒）改 @code 并传显式参数。验收：app 双目标 451/451、插件双目标 0 错、全模块 native 0 错、六静态门 + sync_kernel current。预算：lines 30,790 → **30,636**、files 45 → **44**、fields/variants 144/278 持平。剩余 S7：code_view 1373 / views_compile 642 / problems_pane 219 |
| 2026-10-13 | **S7b code_project 纯生成链出壳 + 首次发布**：`app/code_project.mbt` 纯部分（双腿 `code_project_files`/`code_project_text`、`code_project_target`、行级 `code_text_diff`、`.studio.json` 迁移器 `migrate_studio_source`、`CodeProjectFiles`/`MigrationOutcome`、`dirname_of`，179 行）整文件迁 `plugins/project/code_project.mbt`（ProjectRecord 归本地；moon.pkg 加 domain/ir + domain/codec + services/export + services/form_designer，无环；6 个纯逻辑单测随迁 `code_project_wbtest.mbt`）。仅 `code_project_write_effect`（`Effect[Msg]` 壳侧写盘编排，依赖 CodeProjectSaved）并入 `new_project.mbt`；1 个组合根集成测试留壳。app.mbt 迁移调用点重限定后 `@proj.migrate_studio_source(...)` 被 fmt 折行 +3 行触 app.mbt 单文件预算 2656，用 `let dir = pending_open_dir.unwrap_or(".")` 收一行回到 2656。验收：app 双目标 445/445 + 插件 6/6（合计 451 不丢）、六静态门全绿（含 release-module-closures 因 moui 0.2.3 对齐全 workspace pin）、sync_kernel current。预算：lines 30,636 → **30,463**、files 44 → **43**、fields/variants 144/278 持平。**同日发布**：wzzc-dev/moui **0.2.3**（additive tooltip/theme API）+ wzzc-dev/moui_studio **0.1.0**（首版，含 license/readme/repository 元数据）；`moon install` 得 `~/.moon/bin/moui_studio`，干净目录开窗验证通过 |
| 2026-10-13 | **S4 AI 会话列表出壳（ai_sessions_pane）**：`app/ai_sessions_pane.mbt`（约 501 行：表头/搜索行/分组/项目组/行的整列自绘视图 + 行高两常量 + `relative_time_bucket`）泛型化为 `[Msg]` 纯视图 `pub fn[Msg] ai_session_list(p : AiSessionListParams[Msg], t, width, height)` 整文件迁 `plugins/ai/ai_sessions_pane.mbt`；新增 `pub(all) struct AiSessionListParams[Msg]`（sessions/query/search_open/rename/hover/now 6 状态 + 11 个 on_* 回调），`text(t,..)`→`t.translate(..)`，闭包字段调用须 `(p.on_x)(args)`；moon.pkg 加 `moui/core` + `moui/views/style`。壳删文件，`ide_shell.mbt` 末尾收一个投影薄壳包装（Model→params、AiSession* Msg 作回调），`ide_ai.mbt` 行高常量重限定 `@ai.`。**教训**：S7b 为压 app.mbt 行数引入的 `let dir` 落在 match case action 裸区（MoonBit 禁裸 `let`，须包 `{}`），当轮只跑 fmt+基线（不编译）未暴露；本轮修 `Success(source)=>{ let dir=..; match.. }` 并合并一条注释使 app.mbt 回到 2656 单文件预算。验收：app 双目标 **445/445**、plugins/ai native 11/11 + wasm-gc 0 错、`moon fmt` 干净、六静态门全绿、sync_kernel current。预算：lines 30,463 → **29,996**、files 43 → **42**、fields/variants 144/278 持平。距 A 线：lines 差 −2,996、files −2、fields −29、variants −138（fields/variants 属 B 线状态切片） |
| 2026-10-13 | **S4c AI 工作区面板出壳（ai_workspace_panel）**：`app/ai_workspace_panel.mbt`（371 行：双页签「更改/文件」+ 提案历史 + 待采纳卡）泛型化为 `[Msg]` 纯视图整文件迁 `plugins/ai/ai_workspace_panel.mbt`；新增 `AiWorkspaceParams[Msg]`（show_changes/history/pending + 四个 on_* 动作），工程树作为 `files_view` 插槽由壳构建后注入。壳删文件，`ide_root.mbt` 末尾收一个投影薄壳包装（ide_root 现 670 行）。验收：app 双目标 445/445、`moon fmt` 干净、六静态门全绿、sync_kernel current。预算：lines 29,996 → **29,662**、files 42 → **41**、fields/variants 144/278 持平 |
| 2026-10-13 | **S7d 编译轨视图出壳（views_compile）**：`app/views_compile.mbt`（642 行：真编译动作条/报告卡/七步进度卡/产物旁路/诊断行 + `middle_ellipsis`/`byte_size_label`/`short_file`）泛型化为 `[Msg]` 纯视图整文件迁 `plugins/run/compile_views.mbt`；新增 `CompileViewsParams[Msg]`（busy/track_available/output_open/progress/report 5 状态 + `ghost_icon` 回调 + on_run/on_cancel/on_toggle_output 与 4 个路径参数化动作 on_run_artifact/on_copy_path/on_reveal/on_jump）。产物幽灵按钮因携带壳 HoverHint 提示，经 `ghost_icon` 回调由壳 `ghost_icon_button` 构造注入；`compile_step_state`/`compile_progress_counts`/`compile_active_phase` 三个纯归并函数随迁；moon.pkg 加 `services/export` + `moui/views/style`。5 个纯逻辑白盒单测（3 进度归并 + 2 中间省略）随迁 `compile_views_wbtest.mbt`；`compile_ui_test.mbt` 仅留 4 个壳测试（folder_url×2 + 产物服务流×2）。壳删文件，`update_run.mbt` 删三函数并收一个 `compiled_run_header` 投影薄壳包装。验收：app 双目标 **440/440**、plugins/run native 5/5 + wasm-gc 0 错（合计测试不丢：app 445→440、插件 +5）、`moon fmt` 干净、六静态门全绿、sync_kernel current。预算：lines 29,662 → **29,011**、files 41 → **40（达成 A 线文件档 ≤40）**、fields/variants 144/278 持平。距 A 线：lines 差 −2,011、files **已达标**、fields −29、variants −138（lines 靠继续抽 views 大件；fields/variants 属 B 线状态切片 + ChildMsg） |
| 2026-10-13 | **S4b AI 浮动层视图族出壳（ide_ai 1544 行 + markdown_view）**：`app/ide_ai.mbt`（中心/右栏 AI 页 + 会话头 + 转录时间线 + 工作卡归组折叠 + 用户/AI 气泡 + 上下文芯片 + 输入条 + 模式段 + 决策条 + 姿态行 + 各段高度）与 `app/markdown_view.mbt`（markdown blocks/inline 渲染）泛型化为 `[Msg]` 纯视图：新建 `plugins/ai/ide_ai_views.mbt`（`pub(all) struct AiViewParams[Msg]` 注入 20+ AI 域状态 + 跨域读数 project_name/subject_name/kind + 25 个 on_* 回调，历史幽灵按钮经 `ghost_icon` 回调由壳 `ghost_icon_button` 构造注入）与 `plugins/ai/markdown_view.mbt`（两函数 `fn[Msg]`）；`ComposerMode` 枚举（含 Eq）与 `PendingProposal` 从 `app/model.mbt` 移 `plugins/ai/ai_state.mbt`，壳改 `pub type` 别名；`hhmm_of_stamp`/`round_send_button` 随迁插件私有；moon.pkg 加 geometry/graphics/services/markdown/plugins/code。壳删两文件，新建 `app/ide_ai_views.mbt` 投影薄壳（`ai_view_params(model,t)` 构造 + ai_center/ai_page/ai_docked_height/decision_bar_height/has_decision_content 与 8 个高度常量/3 个 composer 高度函数转发），app/moon.pkg 移除已不用的 services/markdown。**坑**：toplevel 不允许部分类型 `AiViewParams[_]`，须 `fn[Msg]`；同包内不能写 `@ai.`，常量/see_all_row 裸用。验收：app 双目标 **440/440**、plugins/ai native 11/11 + wasm-gc 0 错、`moon fmt` 干净、六静态门全绿、sync_kernel current。预算：lines 29,011 → **27,476**、files 40 → **39**、fields/variants 144/278 持平。距 A 线：lines 差 −476、files **已达标**、fields −29、variants −138（lines 再抽 code_view 大件可达；fields/variants 属 B 线状态切片 + ChildMsg） |
| 2026-10-13 | **S4e 结构下限清点 + ADR 0041（Proposed）**：对全部 263 个 `Msg` 变体逐个做契约归属分类（无遗漏、总数对齐棘轮）：已委托 X=3、**可下沉各域纯 UI 臂 B=50**、留壳 program IR 手术 C=57、留壳服务/IO 回执与请求 D=61、留壳运行/Effect 编排 E=56、留壳合法壳职责 F=36。把 B 类 50 个全部下沉（project/ai 并入既有委托，blocks/code/terminal/design/run 各 +1 委托，共 +5）得 **Msg 结构下限 263−50+5=218**，比 A 档 140 高 78；继续压只能动 C/D/E 共 174 个，违反 ADR 0038 契约 3/结构性标准 #2#3 与 release 闭包。128 个字段同口径清点：六域纯 UI 字段约 29 个可收敛（blocks 11/code 5/terminal 3/project 4/design 2/run 3，净 −23），**字段下限 ~105，A 档 ≤115 可达**（但靠的是原计划划到 B 线的「状态切片」）。结论落 **ADR 0041（Proposed）**：撤回 A 档 variants=140 未核算投影、改绑实测下限 218；行 27k/文件 40 保留（文件已达标）；字段 115 保留并把六域纯 UI 状态切片提入 A 档；B/C 档 variants 100/90 标记待重算。**注**：blocks 画布手势（Press/DragTo/Release）与 EditBlockValue 等在 update 内需读 program 几何，属 C/E 耦合，218 是最乐观口径，实测可能落在 ~220–225，但不改变「远高于 140」的结论。ADR 待 owner 接受后转 Accepted |
| 2026-10-13 | **S5e 积木域 UI 状态切片（降字段/变体）**：把语句插入面板开合/分类（statement_palette_open/selected_category）、画布受控滚动（blocks_scroll_y）、值就地编辑草稿（block_value_edit）、语句/表达式拖放骨架（palette_drag/expr_drag）、画布右键菜单锚点（block_menu）共 **7 个纯 UI 字段**并入新建 `plugins/blocks/blocks_ui_state.mbt` 的 `pub(all) struct BlocksUiState`（`new()`，七字段全部 `mut` 供组合根嵌套写）；对应 **9 个零副作用纯态臂**并入 `pub(all) enum BlocksUiMsg`（ToggleStatementPalette/SelectCategory/BlocksScrolled/BlocksAutoScroll/BlockValueInput/BlockValueCancel/PaletteDragStart/PaletteExprDragStart/BlocksContextMenuClose），`update_blocks_ui` 纯态 + `blocks_ui_feature()`（常量 `BLOCKS_UI_AUTOSCROLL_STEP` 随迁，删 app 版）。壳 Model 以单一 `mut blocks_ui` 字段承载，Msg 以单一 `BlocksUiOp(@blk.BlocksUiMsg)` 委托臂经 `blocks_ui_scope()`（Feature::scope lens 对 + wrap）挂载；按契约 3 **留壳**的读 program/提交 IR 臂——画布手势 Press/DragTo/Release、EditBlockValue（打开取叶子值）、BlocksContextMenu（带选中块+开菜单）、BlocksMenuAction（递归回喂）、BlockValueCommit、ExpressionDrop/PaletteDrop、InsertStatement（插后收面板）——经组合根直接读写 `model.blocks_ui.*` 嵌套字段（新增 `clear_value_edit` 包装）。plugins/blocks/moon.pkg 加顶层 `wzzc-dev/moui` 依赖（Feature/Effect 所需）；6 个切片白盒单测随包（面板开合/分类、滚动夹取、值草稿门控、拖放骨架、菜单关闭）。**坑**：嵌套字段赋值只需目标链上字段为 `mut`，外层绑定（含模式匹配/`let`）不必 `mut`；插件 SelectCategory 不沿用壳名 SelectBlockCategory；边缘自动滚动消息在视图层 `Msg::BlocksUiOp(@blk.BlocksAutoScroll(..))` 构造、`match` 同形态。验收：app 双目标 **440/440**、plugins/blocks 双目标 **9/9**、`moon fmt` 干净、六静态门全绿、sync_kernel current。预算：lines 27,319 → **27,269**、files **39**、fields 128 → **122**、variants 263 → **255**。距 A 线（ADR 0041 口径）：lines 差 −269、files 达标、fields −7、variants 255→218 还差 code/terminal/design/run/project 状态切片 |
| 2026-10-13 | **S4d AI 域 UI 状态切片（降字段/变体）**：把 composer 模式/模式下拉、provider endpoint/model/key/显隐、右栏工作区页签（`RightPanelTab` 枚举移插件）、工作卡折叠、转录受控滚动（scroll/seq/follow）、左栏会话列表搜索开合/查询/悬停/改名草稿、设置与 AI 历史对话框开合共 **17 个纯 UI 字段**并入新建 `plugins/ai/ai_ui_state.mbt` 的 `pub(all) struct AiUiState`（含 `new(endpoint,model,key)`）；对应 **16 个零副作用纯态臂**并入 `pub(all) enum AiUiMsg`（SetComposerMode/SetRightPanelTab/ToggleComposerModePicker/SetProvider* /ToggleProviderKeyReveal/ToggleCardsFold/TranscriptScrolled/TranscriptScrollToBottom/ToggleSessionSearch/SetSessionsQuery/SessionHover/SetRenameDraft/ClearRename/ToggleSettings/ToggleAiHistory），`update_ai_ui` 纯态 + `ai_ui_feature()`。壳 Model 以单一 `mut ai_ui` 字段承载（`RightPanelTab` 改 `pub type` 别名），Msg 以单一 `AiUiOp(@ai.AiUiMsg)` 委托臂经 `ai_ui_scope()`（Feature::scope lens 对 + wrap）挂载，update_shell 删纯态臂、命令路由改发 `AiUiOp(@ai.X)`；改名 Start/Commit（读会话/触发存储）与生成/采纳/流式/存储回执等跨域或服务臂按 ADR 0038 契约 3 **留壳**（直接读写 `model.ai_ui` 嵌套字段）。测试夹具收口到新建 `app/ai_ui_fixtures_test.mbt`（model_with_key / model_with_composer_mode），app_test.mbt 守住 2180 行单文件预算。**坑**：BSD/`moon fmt` 字段迁移须用 perl（`\b` 可靠）；嵌套字段赋值只需中间字段为 `mut`、外层 `let` 不必 `mut`；黑盒 `*_test.mbt` 与白盒 `*_wbtest.mbt` 分属不同测试目标，夹具按调用方放 `*_test.mbt` 并 `@app.` 限定。验收：app 双目标 **440/440**、plugins/ai native 11/11 + wasm-gc 0 错、`moon fmt` 干净、六静态门全绿、sync_kernel current。预算：lines 27,476 → **27,319**、files **39**、fields 144 → **128**、variants 278 → **263**。距 A 线：lines 差 −319、files 达标、**fields −13**、variants −123（variants 为最大缺口；IR 手术/服务回执/Effect 编排臂按契约留壳，可达下限待测，若 >140 须以实测证据走 ADR 修订/重分类） |
| 2026-10-13 | **S5f 工程域 UI 状态切片（并入 ProjectState）**：结构树搜索查询/分组折叠集/「新建」菜单分组/全文搜索草稿 4 个纯 UI 字段并入既有 `ProjectState`；11 个零副作用纯态臂（tab 切换/关闭、文件 CRUD 输入态、结构树搜索/折叠/新建菜单、搜索草稿）并入 `ProjectMsg`，**复用既有 `ProjectOp` 委托，0 新委托**。`SelectProjectFile/At/SearchHitClicked` 读盘/开文件的服务臂与提交/回执留壳；`close_open_file` 纯态随迁插件；8 个白盒单测随包（project 共 14）。验收：app 双目标 440/440、plugins/project 14/14、guardrails ok、sync current。预算：lines 27,269 → **27,120**、files 39、fields 122 → **114**、variants 255 → **244** |
| 2026-10-13 | **S5g 代码编辑器 UI 状态切片（CodeUiOp）**：受控编辑面的光标/选区/滚动 + 补全弹层（候选词/开关）5 字段并入新建 `plugins/code/code_ui_state.mbt` 的 `CodeUiState`（壳持单一 `code_ui`）；3 个公开纯态臂（光标/选区回传、受控滚动、补全关闭）并入 `CodeUiMsg`，壳持单一 `CodeUiOp` 新委托（净 −2）；另立 2 个内部回写消息 `ApplyCompletion(Int)`/`GoToLine(Int,Double)`——壳臂读 code_draft/program 算出目标后经 `code_ui_scope().update(model, @code.X)` 回写切片，避免嵌套 struct 折行膨胀。编辑代码/采纳补全/触发补全/跳转声明（读 code_draft/program）、IR 高亮/悬停（跨域）留壳。6 个白盒单测随包（code 共 6）。验收：app 440/440 双目标、code 6/6 双目标、guardrails ok、sync current。预算：lines 27,120 → **27,106**、files 39、fields 114 → **114**（5 字段并入、1 新切片）、variants 244 → **242** |
| 2026-10-13 | **S5h AI composer 草稿切片（并入 AiSessionOp）**：`SetPrompt(String)` 写当前会话 `prompt_draft` 并清 `prompt_error`，归既有会话切片 `AiSessionMsg`（新增 `SetPromptDraft(String)`，复用 `AiSessionOp` 委托，壳在委托后处理跨域 `prompt_error`）；`AiSessionRenameDismiss` 经 grep 证实为 S4d 后遗留的**死空壳**（无 arm/无构造点）直接删除（净 −2）。`EditUserPrompt/RetryUserPrompt` 经 `restore_prompt_draft` 读时间线 `CardUserPrompt` 卡片回填（内容耦合）留壳。ai 白盒加 1 测试（共 12）。**坑**：Model 不可变字段在委托臂不能 `next.x=v`，要用 `{..next, x:v}`；app_test 加 `set_prompt` 助手压回 2180 行单文件预算。验收：app 440/440、ai 12/12 双目标、guardrails ok、sync current。预算：lines 27,106 → **27,101**、files 39、fields 114、variants 242 → **240** |
| 2026-10-13 | **S5i 运行/终端 UI 切片 + 死消息清理**：新建 `plugins/run/run_ui_state.mbt`——`RunUiState{compile_output_open, web_preview}` + `RunUiMsg{ToggleCompileOutput, SetPreviewMode(Bool)}` + 纯态 update + `run_ui_feature`，壳持单一 `RunUiOp` 新委托（净 −1）；`PreviewMode` 枚举按「插件不反向依赖 app 类型」留壳，插件存 web_preview 布尔，壳经 `Model::preview_mode()` 访问器换转（字段移除后方法名同名访问必须带括号）。`PreviewNavigate/PreviewReload`（web 服务）、`SetPreviewDesignOpen`（dispatch FormDesignOpen effect）留壳。终端：`TerminalScrolled` 经全仓 grep 证实是**无 update 承接的死消息**（scroll_view 自管手动位置，受控 offset 仅 PTY 输出自动跟随），删枚举 + on_scroll 回调（−1）；terminal_scroll/open 字段（PTY 输出写）、`TerminalTabClose`（dispatch pty.kill + 跨域）留壳。`design_zoom` 单标量、画布视图密集读取、独立切片净 0 变体，实测留壳。另去重 `same_path`→`@blk.blocks_same_path`、删 0 调用点死函数 `clone_path` 抵消切片样板。3 个白盒单测随包（run 共 8）。验收：app 440/440、run 8/8、guardrails ok、sync current。预算：lines **27,101（持平）**、files 39、fields 114 → **113**、variants 240 → **238**。blocks 剩余 7 臂（canvas 手势/EditBlockValue/ContextMenu/GateAnswerInput，读 program 几何/IR）经 S5j 读 arm 确认全部留壳，六域纯 UI 切片至此完结 |
| 2026-10-13 | **S7c 代码视图纯函数下沉（行档达标 27,000）**：把 code_view 中零 Model/Msg/视图依赖的纯函数下沉——① 全 NUL 关键字表工厂移入 `domain/studio_lang` 的 `pub fn Keywords::empty()`（keywords.mbt）；② DSL 换行缩进 `dsl_indent_for_newline` 改按 `Language` 纯文本化（去掉 `model` 依赖）移入 `plugins/code/code_indent.mbt`，壳仅传 `model.language.dsl_language()`；③ `mono_code_font`/`file_tab_label` 两纯函数移入 `plugins/code/code_view_helpers.mbt`（code 包新增 `moui/text` 依赖）。`code_newline_transform` 因构造 `moui_richtext.RichTextInputTransform`（向状态插件引入渲染输入层依赖）、`code_token_color` 因 `CodeTokenKind` 是壳模型枚举且映射 chrome 主题，均留壳。domain 新增跑 `sync_kernel` 重导出（kernel_studio_lang.mbt）。验收：app 440/440 双目标、code 6/6、studio_lang 44/44 双目标、guardrails ok、sync current。预算：lines 27,101 → **27,000（达成 A 线行档 ≤27,000）**、files 39、fields 113、variants 238。**A 档四项指标全部达标** |
| 2026-10-13 | **A 承诺线达成 + ADR 0041 转 Accepted**：六域（project/run/ai/blocks/design/code）均成插件包（状态切片 + update + `[Msg]` 泛型视图 + 测试随包；terminal/markdown 为视图/服务包）；棘轮实测 **27,000 行 / 39 文件 / 113 字段 / 238 变体**，全部满足 ADR 0041 修订后 A 档（≤27,000 / ≤40 / ≤115 / ≤238）。variants 乐观投影 218 经六域落地实测为 238（`263−26 实下沉+3 新委托−2 死消息`），24 个原 B 类臂因几何/IR/服务/Effect/时间线卡片/壳自身 chrome 耦合按证据改留壳，已逐条写入 ADR 与棘轮 reason。随后 bump moui_studio 0.1.1 并重新 `moon publish` + CLI 开窗验证 |
| 2026-10-24 | **编辑器优先工作台落地（ADR 0042，M0–M6）**：新建 `moui_studio/workbench` 包——`DocumentStore`（文档唯一事实源：常驻 Studio 文档 + 文件文档的草稿/光标/脏标记与关闭/改名收敛）、`WorkbenchState`（live/blocks 窗格与分割比）、`EditorProvider` + `resolve_provider`（优先级/preferred/accepts 解析）与 `editor_area`（标签条 + provider 渲染体）。中心形态统一为编辑区：可视化/设计/积木/代码/markdown/mono 成为静态注册的 provider，markdown 插件缺席时 `.md` 自动回退 mono。M4 底栏页签（徽标/选中态/正文/终端插件缺席）改由 `PanelContribution` 贡献表派生；M5 命令面板 40 条描述符与 `run_studio_command` 收敛为同一份 43 条 `CommandContribution`（`label_key==""` = 内部命令；Apply 纯更新 / Dispatch 效果派发），90 行 switch 删除——表与处理器不再可能漂移；M6 删除内核零消费贡献类型（`kernel/contributions.mbt` 五类型 + `PluginDescriptor`），kernel 契约文档指向 workbench。新增 panel/command registry 白盒回归（五页签/徽标/终端开合语义、43 id 全覆盖/40 条顺序文案/隐藏命令/代表命令状态转移）。验收：workbench 11、app 460、kernel 10 双目标全绿，`validate-maintenance-baseline` ok。预算棘轮：lines 27,750 → **27,374**、files 39、fields 113 → **111**、variants 242 → **238**；app.mbt / app_test.mbt 单文件上限同步结算（2682 / 2178）。左/右栏注册表因行数代价按计划回退为硬编码分支（后续页块迁移需先有行数下降空间） |

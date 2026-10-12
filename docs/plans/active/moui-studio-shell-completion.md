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

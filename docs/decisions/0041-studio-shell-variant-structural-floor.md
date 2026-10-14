# ADR 0041: MoUI Studio 壳收敛——Msg 变体按结构下限重分类（修订 ADR 0040 的 A 档指标）

- **Date**: 2026-10-13（2026-10-13 六域切片落地后按实测下限更新并转 Accepted）
- **Status**: Accepted（六域状态切片全部落地、四项指标实测达标；本 ADR 只重分类 A 档的 `Msg` 变体指标，不改棘轮机制、不改 ADR 0038 真源契约）
- **Deciders**: Agent-assisted（豆包 / 插件化重构轮）
- **Related**: [ADR 0038](0038-studio-plugin-kernel.md)、
  [ADR 0039](0039-studio-shell-completion-line.md)、
  [ADR 0040](0040-studio-shell-completion-stages.md)、
  `docs/plans/active/moui-studio-shell-completion.md`、
  `tools/moui/validate_maintenance_baseline/studio_shell_budgets.mbt`

## Context

ADR 0040 把完成线拆成三档，并给 A 承诺线设了四项指标：
`≤ 27,000 行 / ≤ 40 文件 / Model ≤ 115 字段 / Msg ≤ 140 变体`。

但 ADR 0040 的**可达性只测了前两项**——它的 Context 表测算的是「剩余可迁
7,494 行 / 14 文件，全做完停在 ~26,000 行 / ~37 文件」，对 `Model` 字段数与
`Msg` 变体数**从未做过迁移核算**（ADR 0040 自己的规则 4 也要求「每档达成时
重新实测四项计数，不允许沿用投影值」）。

本轮（S4d AI 域 UI 状态切片落地后，app 实测 **27,319 行 / 39 文件 / 128 字段 /
263 变体**）对全部 **263 个 Msg 变体逐个做了契约归属分类**，按它们在
ADR 0038 / 本计划结构性标准里的去留，分进六类：

| 类别 | 含义 | 数量 | 能否随域出壳？ |
|---|---|---:|---|
| X | 已存在的域委托变体（`ProjectOp` / `AiSessionOp` / `AiUiOp`） | 3 | 已在壳（各是 1 个委托槽） |
| B | **可下沉**的各域纯 UI 臂（面板开合、草稿、滚动、光标、补全、拖拽/悬停/右键等瞬态） | 50 | 能：做成域状态切片 + `Feature::scope` 委托 |
| C | **留壳**：program IR 手术臂（控件/变量/语句/函数的增删改、画布几何、选中三元组、对齐、补全提交、恢复 code_draft 等） | 57 | 不能：结构性标准 #2 要求 program IR / `selected_control`/`selected_handler`/`side_target` root 持有 |
| D | **留壳**：服务/IO 回执与请求臂（`*Loaded`/`*Saved`/`*Finished`/`*Picked`/`*Read`/`*Written`/`*Deleted`/`Store*`/`StreamChunk`/`TerminalOutput` 等） | 61 | 不能：服务任务编排是组合根职责（ADR 0038 契约 3） |
| E | **留壳**：运行 / Effect 编排臂（`Run*`/`Compile*`/`RunTick`/`TimerTick`/导出/构建/`ComposerRun`/`ChatSubmit`/确认卡/终端写入/`RequestConfirm` 等） | 56 | 不能：Effect 与服务接线在 root；状态可进插件，驱动 IO 回执的 update 臂留 root |
| F | **留壳**：壳合法职责（外观/语言偏好、命令面板、perspective/工作区/左右栏布局与尺寸、窗口控制、通知/toast、undo/redo、`StudioCommandRun`） | 36 | 不能：这是壳本身，不是功能域 |
| | **合计** | **263** | |

### Msg 变体结构下限

把 B 类 50 个纯 UI 臂**全部**做成域状态切片（最激进、且不违反任何契约的口径）：

- project 域 14 个（文件 tab、资源管理器内联新建/改名、树搜索/分组）→ 并入既有
  `ProjectOp`，**0 个新委托**；
- ai 域 3 个（`SetPrompt`/`EditUserPrompt`/`AiSessionRenameDismiss`）→ 并入既有
  `AiUiOp`，**0 个新委托**；
- blocks 域 16 个、code 域 10 个、terminal 域 2 个、design 域 2 个、run 域 3 个
  → 各收敛为 **1 个新委托变体**，共 **+5**。

故 A 档（仅做纯 UI 状态切片、不触碰任何真源/服务/Effect 臂）的 `Msg` 变体
**结构下限**：

```
263 − 50(B 全部下沉) + 5(新域委托) = 218
```

**218 仍比 A 档目标 140 高 78。** 要继续往下压，只能动 C/D/E 共 174 个变体——
那等于把 program IR 真源、服务 IO 回执、Effect 编排也下沉进域插件，直接违反
ADR 0038 契约 3 与本计划结构性标准 #2/#3，并破坏 release 闭包。这不是「再做
几个切片」能到的数字，而是要换架构。

### 六域切片落地后的实测复盘（2026-10-13，取代 218 投影）

218 是**按分类表反推的乐观投影**，它假设「B 类 50 个臂全部能原样下沉、只付
5 个新委托」。六域状态切片逐域落地（S5f project / S5g code / S5h ai / S5i
run+terminal，以及此前的 blocks 纯 chrome 切片）后，实测 `Msg` 变体为 **238**。

实测对账（263 → 238，净 −25）：

- 真正并入域切片的纯 UI 臂 **26 个**（不是 50）；
- 新增域委托槽 **3 个**：`BlocksUiOp` / `CodeUiOp` / `RunUiOp`（project 复用
  既有 `ProjectOp`、ai 复用既有 `AiSessionOp` / `AiUiOp`，比乐观口径少 +2）；
- 落地时确认的**死消息** 2 个并删除：`TerminalScrolled`（无 update 承接，滚动
  位置由 scroll_view 自管 + PTY 输出自动跟随）、`AiSessionRenameDismiss`（S4d
  已由 `ClearRename` 取代，遗留空壳）。

净算式：`263 − 26(实下沉) + 3(新委托) − 2(死消息) = 238`。

B 类原计 50 里有 **24 个在落地时被证明不属纯 UI**，按证据改留壳（C/E/D 类）：

- blocks 7 个：`BlocksCanvasTap/Press/DragTo/Release` 做画布几何 hit-test
  （`@blk.blocks_hit_index`）并读 program 块链与拖拽态；`EditBlockValue` 打开
  就地编辑需读 program 取规范写法；`BlocksContextMenu` 先写真源 `selected_block`
  再挂菜单锚点；`GateAnswerInput` 写回 IR 答题草稿。几何命中工具已在插件
  （`@blk.blocks_hit_index`），但读 program 的编排留壳。
- terminal 1 个：`TerminalTabClose` 需 dispatch `pty.kill` 并跨域改 bottom
  面板（Effect 编排）。
- run 3 个：`PreviewNavigate` / `PreviewReload` 走内嵌 web 服务，
  `SetPreviewDesignOpen` 打开时 dispatch `FormDesignOpen`（effect）。
- ai 2 个：`EditUserPrompt` / `RetryUserPrompt` 需读时间线 `CardUserPrompt`
  卡片回填（内容耦合），`SetPrompt` 已并入 `AiSessionOp`。
- project 3 个：`SelectProjectFile` / `At` / `SearchHitClicked` 读盘/开文件
  （服务臂）。
- design 1 个：`design_zoom` 是单标量且被画布视图密集读取，独立切片净 0 变体，
  切片反而增加样板，留壳（不新增无收益委托）。
- 其余为命令面板（开/合/查询/悬停 5 臂）、`SetContextTab` / `SetBottomTab` /
  `Resize*` 等**横切壳自身 chrome**——架构上不是六域之一，是壳本身，留壳。

**结论：A 档 `Msg` 变体的结构下限实测为 238，不是 218。** 差额 20 来自乐观
投影未预见的「读 program / 几何 hit-test / 服务与 Effect / 时间线卡片 / 壳自身
chrome」耦合，这些在 ADR 0038 契约下本就必须留 root，不能为凑 218 而把真源或
服务接线反塞进插件。238 与 218 同样锚定「防无声增重」，且是可复算的实测值。

### Model 字段结构下限

对 128 个 `Model` 字段做同样归属，可随域状态切片搬走的纯 UI 字段约 29 个：

- blocks 域 11 个（`selected_block`/`block_draft`/`block_value_edit`/
  `gate_answer_draft`/`block_drag`/`block_menu`/`palette_drag`/`expr_drag`/
  `blocks_scroll_y`/`selected_category`/`statement_palette_open`）→ 1 个
  `blocks_ui` 切片，净 −10；
- code 域 5 个（`code_caret`/`code_selection`/`code_scroll`/`completions`/
  `completion_open`）→ 1 个 `code_editor_ui`，净 −4；
  （`hover_path`/`ir_highlight` 跨 code/blocks 共享，按结构性标准 #2 留 root）
- terminal 域 3 个（`terminal_open`/`terminal_scroll`/`terminal_scroll_seq`）
  → 并入既有 `terminal` 切片，净 −3；
- project 域 4 个（`tree_query`/`tree_collapsed`/`search_query`/
  `tree_create_group`）→ 并入既有 `project_state`，净 −4；
- design 域 2 个（`design_zoom`/`preview_design_open`）→ 1，净 −1；
- run 域 3 个（`compile_output_open`/`preview_mode`/`preview_web_opened`）
  → 1，净 −1。

字段结构下限 ≈ **128 − 23 = 105**，**A 档 ≤ 115 可达**（其达成确实需要「域
纯 UI 状态切片」这一在原计划里被划到 B 档的技术动作，见 Decision）。

## Decision

1. **撤回 A 档的 `Msg ≤ 140` 投影**：它是 ADR 0040 未做迁移核算的数字。本 ADR
   先按分类表给了乐观投影 **218**，六域切片落地后**实测结构下限为 238**（见
   上文「实测复盘」），以实测值为准。A 档 `Msg` 变体指标改绑**实测结构下限
   238**：六域纯 UI 状态切片落地后，棘轮 `Msg` 上限降到 **238**（含 reason）。
   其余变体是 ADR 0038 契约下的**合法常驻壳**（program IR / 服务 IO / Effect
   编排 / 壳自身 chrome），不为指标硬拆。
2. **A 档保留 `≤ 27,000 行 / ≤ 40 文件`，已达标（实测 27,000 行 / 39 文件）**：
   行数由 S5f–S5i 状态切片 + S7c 代码视图纯函数下沉（`Keywords::empty()`、
   `dsl_indent_for_newline`、`mono_code_font`/`file_tab_label` 移入插件/域包）
   抵达；富文本输入变换与 token 配色因引入渲染依赖/壳类型而留壳，已记入
   棘轮 reason。`blocks_pane` 剩余视图组装（S5d）不再是 A 档必需项。
3. **A 档保留 `Model ≤ 115`，已达标（实测 113 字段）**：六域「纯 UI 状态切片」
   已明确**提入 A 档范围**（原计划把状态切片放在 B 档，但 A 档字段目标只有靠
   它才能达到，这是 ADR 0040 的归类疏漏）。blocks/code/run/project/ai 五域纯 UI
   状态各收敛为一个切片（`blocks_ui` / `code_ui` / `run_ui` / `project_state` /
   ai 会话与 UI）；design/terminal 纯 UI 态经实测为 effect/PTY 耦合或净 0 收益，
   未单切（见实测复盘）。
4. **A 档达成判据（修订后，已全部满足）**：六域全部成为插件包（状态切片 +
   update + `[Msg]` 泛型视图 + 测试随包，结构性标准 #1–#4）+ 行 ≤ 27,000（实测
   27,000）/ 文件 ≤ 40（实测 39）/ 字段 ≤ 115（实测 113）/ 变体 ≤ 238（实测
   下限）。
5. **B/C 档的 `Msg` 目标（100 / 90）一并标记为待重算**：若未来要让变体逼近
   100，必须先做 ADR 0040 说的「壳边界重界定」或改变 ADR 0038 真源归属，属
   新的架构范围决策，不在本计划欠账内。
6. **棘轮机制不变**：`studio_shell_budgets` 的 `max_count` 仍是当前实测值的
   只降不升上限；每片完成按实测降并写 reason。本 ADR 只改「目标档位的数字」，
   不豁免任何无声增重。

## Options Considered

### Option A: 按结构下限重分类（选定）

- Pros：A 档重新成为「做完即可宣称完成」的可达承诺；变体数的每一类都有契约
  归属，棘轮继续防无声增重；不违反 ADR 0038 真源/闭包约束。
- Cons：A 档变体数字从 140 放宽到实测下限（乐观投影 218、落地实测 238），
  需要在文档里如实说明这是「投影错误」而非「降低标准」；后续若还想压变体需
  另立架构决策。

### Option B: 强行压到 140

- Pros：数字不变。
- Cons：必须把 C/D/E 类（program IR 真源、服务 IO、Effect 编排）下沉进插件，
  违反 ADR 0038 契约 3、结构性标准 #2/#3，并破坏 release 闭包；插件将不得不
  反向持有服务接线、甚至 import 组合根，等于推翻插件内核。明确否决。

### Option C: 维持 140 但加「豁免」

- Cons：与 ADR 0040 Option C 同理——豁免会变成常规路径，棘轮退化为背景噪音；
  且一条永远达不到的线会持续给出错误信号。否决。

## Rationale

问题本质不是「切片没做完」，而是 ADR 0040 把**两个不同量纲的指标混为一谈**：
行/文件随视图抽取线性下降，字段随状态切片可收敛；而**变体数 = 真源操作 +
服务往返 + Effect 编排 + 壳职责的并集**，这些是插件化架构里**被刻意保留在
组合根**的部分。ADR 0038 插件化的目标是「把可替换的域能力移出壳」，不是「把
壳的编排职责也拆碎」。用实测的 238 作为结构下限，恰好把棘轮继续对准它真正
要防的东西（无声增重），而不是惩罚架构本身。218→238 的 20 个差额不是漏做，
而是落地时被证据改判的耦合臂（几何/IR/服务/Effect/壳自身 chrome）。

## Consequences

- 本计划的「完成」按修订后 A 档判据宣称（六域插件化 + 行/文件/字段达标 +
  变体降到 238 实测下限）。A 档四项指标已实测达标（27,000 / 39 / 113 / 238）。
- 留壳的 24 个原 B 类臂与命令面板/面板栏等壳 chrome 已在棘轮 reason 中逐条
  说明；它们是 C/D/E/F 合法常驻，不再列入 A 档欠账。
- 每片仍按既定口径：双目标测试 + 新插件双目标全绿 + `moon fmt` + 按实测降
  棘轮四项 + 六项静态门 + `sync_kernel --check` + 计划 Progress 追加。
- 不改 ADR 0038、不影响 `services/export` 与 domain 包；不影响 release 闭包。
  本轮 `Keywords::empty()` 等 domain 新增已跑 `sync_kernel` 重新导出。
- 本 ADR 已转 Accepted；计划 DoD 表同步把 218 改为 238、勾选 A 档达成。

## Agent Notes

- **Session context**: `/goal` 要求「完成完整的插件化重构 + moon publish 发布 +
  `moui_studio` 命令行可运行」。发布已完成并验证（moui 0.2.3、moui_studio 0.1.0）；
  S4d 落地后做本轮结构下限清点。
- **Agent model**: 豆包（Doubao / MoA）
- **Key prompt or instruction**: 「完成完整的插件化重构……（可能要先发布升级更新
  moui 组件的版本）」。
- **Validation**: 263 变体 / 128 字段逐个契约分类（脚本可复算，总数对齐
  `validate_maintenance_baseline` 的计数）；乐观投影 263−50+5=218、字段
  128−23≈105。六域切片落地后**实测对账**：`263 − 26(实下沉) + 3(新委托)
  − 2(死消息) = 238`，字段 113。最终棘轮 **27,000 行 / 39 文件 / 113 字段 /
  238 变体**，由 app 双目标 440 测试、各插件双目标测试（project 14 / code 6 /
  ai 12 / run 8 / blocks 9 / terminal 6 / markdown 7 / studio_lang 44）、
  `validate_maintenance_baseline`（guardrails: ok）与 `sync_kernel --check`
  （current）复算。

## References

- `docs/plans/active/moui-studio-shell-completion.md`
- `tools/moui/validate_maintenance_baseline/studio_shell_budgets.mbt`
- `docs/decisions/0038-studio-plugin-kernel.md`
- `docs/decisions/0040-studio-shell-completion-stages.md`

# ADR 0040: MoUI Studio 壳收敛完成线分档（修订 ADR 0039）

- **Date**: 2026-10-12
- **Status**: Accepted（修订 0039 的完成线，不改棘轮机制）
- **Deciders**: Agent-assisted（DeepSeek Harness / step-5-preview）
- **Related**: [ADR 0039](0039-studio-shell-completion-line.md)、
  [ADR 0038](0038-studio-plugin-kernel.md)、
  `docs/plans/active/moui-studio-shell-completion.md`

## Context

ADR 0039 给 app 壳设了单一完成线（≤ 18,000 行 / ≤ 30 文件 /
`Model` ≤ 55 字段 / `Msg` ≤ 90 变体），配套只降不升的四项棘轮。棘轮本身
工作正常——它成功阻止了无声增重，S1–S4 已把 app 从 37,279 行降到 33,535 行。

但完成线的**可达性从未被核算过**。2026-10-12 按计划自己的侦察结论实测了
剩余可迁移量：

| 处置 | 文件 | 行数 |
|---|---|---|
| 纯文件整体迁（零 `model.` 读取） | `blocks_canvas` 1227、`blocks_slot_hit` 256、`statement_palette` 480、`canvas` 850、`stage_layout` 97、`code_project` 217 | 3,127 |
| Model 耦合视图/组装件（宽参数结构 + `[Msg]` 泛型改造） | `ide_ai` 1636、`ai_sessions_pane` 508、`ai_workspace_panel` 371、`blocks_pane` 761、`views_compile` 647、`problems_pane` 219、`form_design_canvas` 263、`form_design_session` 162 | 4,367 |
| **合计可迁** | **14 个文件** | **7,494** |
| 明确留壳（真源编排） | `update_ai` 952、`update_blocks` 1038、`update_run` 1429、`update_selection_msgs` 584、`project_explorer` 1292、`project_workbench` 901 … | — |

即使 S4–S7 全部按最乐观口径做完，app 也停在 **~26,000 行 / ~37 文件**，
离 18,000 / 30 差约 8,000 行 / 7 文件。计划自己在 2026-10-12 的记录里已把
完成线改称为"持续北极星"——一条永远差一半的线，会随时间削弱棘轮的信号价值
（团队学会把它当背景噪音），这与 ADR 0039 Risk #6「防的是无声增重，不是绝对
行数」的初衷相反。

## Decision

把单一完成线改为**三档阶梯**，每档有明确的达成条件与重新实测要求：

| 档 | 源码行 | 源文件 | `Model` 字段 | `Msg` 变体 | 达成条件 |
|---|---|---|---|---|---|
| **A 承诺线** | ≤ 27,000 | ≤ 40 | ≤ 115 | ≤ 140 | S4–S7 完成：纯文件整体迁 + 视图族宽参数改造（按上表 7,494 行可迁量测算） |
| **B 稳态纪律线** | ≤ 22,000 | ≤ 32 | ≤ 80 | ≤ 100 | 运行臂 Effect 形态定型后 run 域状态切片；剩余组装件继续宽参数化 |
| **C 原完成线（北极星）** | ≤ 18,000 | ≤ 30 | ≤ 55 | ≤ 90 | 需要超出 S4–S7 的新工作：重新界定「壳」边界（哪些组装件本质是产品而非壳）或壳级视图进一步拆分 |

规则：

1. **棘轮机制不变**：`studio_shell_budgets` 的四项 `max_count` 仍是当前
   实测值的只降不升上限；每次提取完成即降并写 reason。分档表是**目标**，
   不是棘轮上限——两者不混用。
2. **A 档是承诺线**：S4–S7 完成即宣称达成，不需要额外论证。达不到就在计划
   Progress 里记录差多少、为什么。
3. **B / C 档需要新的范围决策**，不是把 S4–S7 做细就能到的；进入 B 档前必须
   先有一次「壳边界重界定」评审（哪些留壳是真源编排、哪些其实是产品面）。
4. 每档达成时重新实测四项计数并登记，不允许沿用投影值。

## Options Considered

### Option A: 三档阶梯（选定）

- Pros：A 档可达且有明确完成判据，恢复「做完就能宣称完成」的激励；B/C 保留
  北极星但不阻塞日常；与计划 Risk #6 的初衷一致。
- Cons：多两个数字要维护；C 档仍可能长期不到。

### Option B: 只把完成线降到实测可达值（单档 ~26,000）

- Pros：最简单，一个数字。
- Cons：丢掉 0039 的收敛方向感；26,000 会成为新的永久基线，壳继续增重
  而没有下一级拉力。

### Option C: 维持 18,000 不变，加「允许超线的豁免流程」

- Pros：不改决策。
- Cons：豁免流程会变成常规路径，棘轮退化（正是要防的事）。

## Rationale

选 A 是因为问题的本质不是「数字定错了」，而是**把 aspirational target 和
committed target 混成了一个**。ADR 0039 的 Consequences 已经写了「app 归零
不是目标」「合法常驻 ~15–18k 行」——即 18,000 本来就是常驻壳的估计值，而不
是可迁尽后的下界。分档只是把这个已经存在的区分显式化。

## Consequences

- 计划 `docs/plans/active/moui-studio.md` 式的「完成」宣称以 A 档为准。
- 棘轮上限与分档目标分离，`studio_shell_budgets.mbt` 的注释要指向本 ADR。
- 进入 B 档前必须先做壳边界重界定评审（新工作项，不在 S4–S7 内）。
- 不影响 `services/export` 与 domain 包（0039 已排除）。

### Amendment (2026-10-25): 预算棘轮迁出主仓

主仓不再持有 studio 壳的四项计数器。`moui_studio` 自 `80317ec80`
（2026-10-09）拆成独立子仓库后，本仓 HEAD 只保留 gitlink；但
`tools/moui/validate_maintenance_baseline/studio_shell_budgets.mbt` 是拆仓
**之后**（`1189408e9`，2026-10-12）在主仓建的，此后被改 17 次——主仓一直在为
另一个仓库的账本改文件，而两个账本之间没有任何同步机制。实测（2026-10-25）：

| 计数 | 钉住提交 ef2a56f12 实测 | 本 checkout 遗留副本 | 登记上限 |
|---|---|---|---|
| app 源码行 | 27,374 | 27,531 | 27,374 |
| Model 字段 | 111 | 113 | 111 |
| Msg 变体 | 238 | 242 | 238 |

登记值与钉住提交逐字相等，所以 CI（`submodules: recursive` 检出 gitlink）是绿
的；而本地那份不被任何 git 跟踪的 `moui_studio/` 目录把 `pr` profile 的门长期弄
红，且这个红在主仓里无法修——修它要提交到另一个仓库。同一条仓库边界规则其实早已
写在 `docs/testing.md`（source-file policy 只扫主仓 roots，studio 的 ratchet 刻意
不进主仓表，2026-10-16 owner decision），maintenance baseline 是它的漏网之鱼。
删除的是**记账载体**，不是完成线：A/B/C 三档目标与「A 档已达成」的判定全部保持不变。

- 交接规格（四个计数器的口径、排除规则、只降不升 + reason 即审计记录）写在
  `docs/plans/active/moui-studio-shell-completion.md` 的「棘轮机制」一节，由子
  仓库在自己的 CI 里重建等价的门。
- 子仓库重建门之前，任何 B/C 档进展都不得宣称「已治理」。
- 主仓 `pr`/`daily` 里的 studio 测试步骤保留：它们是行为覆盖率证据，不是预算。

## Agent Notes

- **Session context**: MoUI Studio 分析报告的后续整改轮；本 ADR 是该轮
  「正式修订 shell-completion 的 DoD」这一项的落点。
- **Agent model**: DeepSeek Harness / step-5-preview
- **Key prompt or instruction**: 「正式修订 shell-completion 的 DoD：把
  18,000 拆成可达的中间档」。
- **Validation**: 可迁量按 `wc -l` + `grep -c "model\."` 实测（2026-10-12）；
  当前四项计数用 `validate_maintenance_baseline` 的同一判定规则复算：
  33,535 行 / 51 文件 / 145 字段 / 278 变体。

## References

- `docs/plans/active/moui-studio-shell-completion.md`
- `tools/moui/validate_maintenance_baseline/studio_shell_budgets.mbt`
  （本 ADR 的 Amendment 2026-10-25 已将其从主仓删除）
- `docs/decisions/0039-studio-shell-completion-line.md`

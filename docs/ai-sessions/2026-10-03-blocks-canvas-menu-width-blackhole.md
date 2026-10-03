# 2026-10-03: Blocks canvas — context-menu direction, content-hugging widths, floating black slot hole

- **Agent**: GLM (ZCode)
- **Goal**: 用户报 MoUI Studio 积木视图三个缺陷：① 积木上右键菜单一直向左弹（应主要向右）；② 积木左右撑满画布；③ 积木上出现不明黑块。
- **Outcome**: Success — 三个根因全部修复，`moon test examples/moui_studio/app` 273/273 通过，静态校验全绿，headless 真实渲染验收确认。

## Summary

三个缺陷彼此独立但共享「画布几何单源」这条纪律：菜单方向是 placement 候选顺序问题；积木撑满是 `blocks_item_rects` 按画布预算定宽的问题；黑块是插槽洞（SlotHole）按「左起累加」定位而整行文字按默认 `TextCenter` 绘制——洞孤零零留在标签起点，读成一枚黑洞（洞色恰好是近黑的暗色）。

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `examples/moui_studio/app/ide_root.mbt` | 积木右键菜单候选顺序 `BelowEnd…` → `BelowStart, AboveStart, BelowEnd, AboveEnd` | 锚点是零尺寸指针点，`…End` 把菜单右缘对齐指针（向左弹）；成熟菜单主方向是右下展开 |
| `examples/moui_studio/app/blocks_canvas.mbt` | `blocks_item_rects` 块宽随内容收紧（估宽 ÷ LABEL_WIDTH_SAFETY + 12，下限 64）；标签 `TextStart`；洞先于标签推入 ops；新增 `blocks_row_arrow` / `blocks_row_lead_width`；去「▶ 」聚光灯文字前缀；度量缓存补引导文本与整行 | ②③的修法；洞画在文字之下是叠层顺序要求 |
| `examples/moui_studio/app/blocks_slot_hit.mbt` | `blocks_slot_rects` 增 `lead?`；`blocks_slot_hit` / `blocks_value_hit` 增 `lead_texts?` | 命中层与绘制层读同一份引导几何 |
| `examples/moui_studio/app/blocks_pane.mbt` | 新增 `block_row_texts`（展示 + 引导同源产出）；指示线矩形与画布同参 | 展示/引导/命中三处不吃同一份就会错位 |
| `examples/moui_studio/app/update_blocks.mbt` | 四处命中路径传 `display_texts` | 块宽进了几何后，update 侧矩形必须与绘制同源 |
| `examples/moui_studio/app/views.mbt` | legacy `blocks_panel` 同步 | 同上 |
| 测试：`blocks_edit_test` / `shell_layout_wbtest` / `ai_bar_layout_wbtest` | 新增 4 条回归 + 既有菜单测试加「向右弹」断言 | 钉住三个修复的生产契约 |

## Key Decisions

- **块宽随内容而不是等宽**：Scratch 口径；估宽除以 `LABEL_WIDTH_SAFETY` 抵消 fit_label 的 5% 安全系数，否则「按估宽定宽的块」会被再截一次省略号。
- **删掉「▶ 」聚光灯文字前缀**（保留 BlockStroke 描边）：内容宽下前缀必然把高亮行挤出省略号；且避免为宽度引入 spotlight 参数穿透所有命中路径。
- **`lead_texts` 与 `display_texts` 由一个函数产出**（`block_row_texts`）：洞的游标起点 = 引导宽，两份数据天然同源。

## Discoveries

- `TextRun::new` 默认 `align=TextCenter`——任何「按左起游标定位的附属绘制」（插槽洞、下划线类）配默认对齐都会整体错位。
- MoonBit 字符串插值 `\{…}` **不能跨行**（lexer 报 unterminated string literal）；条件要先提出来。
- MoonBit String 没有 `substring/drop_suffix`（本仓锁定的 core 版本），后缀剥离要用别的结构（这里改为同源产出两份数据）。
- headless runtime（`@runtime.new_program_with_dimensions` + `draw_commands()`）可以精确验收真实文本度量下的绘制几何，比假度量单测更接近实渲。

## Validation

```sh
moon test examples/moui_studio/app --target native          # 273/273
moon test examples/moui_studio/domain/blocks examples/moui_studio/domain/studio_lang --target native  # 68/68
node scripts/validate-maintenance-baseline.mjs && node scripts/validate-api-surface.mjs   # ok
node scripts/validate-release-module-closures.mjs && node scripts/validate-guidance-consistency.mjs  # ok
node scripts/validate-renderer-capability-consistency.mjs && node scripts/validate-doc-references.mjs  # ok
moon info examples/moui_studio/app --target native           # pkg.generated.mbti 已重新生成（此前已过期）
```

## Follow-Up

- [ ] 插槽洞的「空槽」分支（`blocks_slot_empty`）当前实际不可达（槽段文本恒非空）——若未来出现真空槽，需复核空槽色与命中区。
- [ ] `pkg.generated.mbti` 此前就已漂移（本会话重新生成时带出了历史差异）；留意 validate-api-surface 是否需要把它纳入常规预推送。
- [x] （第二轮）运行语义改为装填不执行 + 运行页底栏全宽，见下。

## 第二轮（同日）：运行语义与运行页底栏

用户报：点「运行」后 ① 还没点按钮，标签就显示了内容；② 底部 AI 栏只占左侧、右侧空白。

| 问题 | 根因 | 修法 |
|---|---|---|
| ① 标签预先显示内容 | `start_run` 把**当前选中的子程序**立即跑完一遍（解释轨解析草稿执行；编译轨 `run_handler` 同步跑完）——对事件驱动的程序，「运行」替用户点了一次按钮 | **装填不执行**：`start_run`/`start_compiled_run` 只进入运行页 + 建空计划运行态（舞台=设计初值），事件（`ControlClicked` 等）才经 `run_handler`/`dispatch_compiled_event` 执行。装填态（`plan.instrs==0`）第一个 tick 自然完成，`merge_run_back` 对空计划**不记「运行完成」审计** |
| ② 底栏只占左半 | 全屏页（运行/预览/帮助）没有左右栏，但 `shell_view` 的 `main_col`/`ide_bottom_bar` 仍按 `center_width`（扣除左右栏的宽）定宽 | 全屏时 `main_col` 与底栏用 `side_width`（ide_root.mbt） |

- 新 i18n 键 `app.run.armed`（zh「等待事件 · 点击控件触发」/ en）——装填态的运行页副标题与启动审计 detail。
- 八个锁定旧语义的测试重写为「装填 → 控件事件执行」契约；新增 e2e（真实 runtime）钉住「运行后标签为空、点舞台按钮才出现问候语」与「底栏铺满整行」。
- 顺带发现并绕开：两轨事件派发的审计**行号口径不同源**（解释轨 `run_handler` 走 IR 语句 → line 0；编译轨走草稿 trace → 真实行号）——测试比对 (op, detail)，行号比对留待统一口径时恢复。

## 第二轮验证

```sh
moon test examples/moui_studio/app --target native   # 274/274
node scripts/generate-i18n-catalogs.mjs --check --input examples/moui_studio/app/i18n/catalogs.json --out examples/moui_studio/app/i18n_catalog_generated.mbt  # ok
# 六项静态校验全绿（同上）
```

## Promote (required checklist)

- [x] Short durable facts → `memories/repo/moui-studio-ui-layout-traps.md`（新增「积木画布几何」一节）
- [ ] Architectural choice → ADR（无：均为包内缺陷修复，不涉结构约束）
- [ ] Multi-session work remaining → 无
- [ ] Stale guidance found → 无

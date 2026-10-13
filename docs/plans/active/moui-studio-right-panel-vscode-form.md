# Plan: MoUI Studio 右栏改成 VS Code 侧面板交互形态

- **Status**: active
- **Date**: 2026-10-13
- **Related**: `docs/plans/active/moui-studio.md`（右栏/底栏/AI 落点的历次决策）、
  `docs/plans/done/moui-studio-ai-look.md`（上一轮 AI 面板形态）、
  `memories/repo/moui-studio.md`（右栏头两个 ✕ 的语义分工）、
  `docs/plans/active/moui-studio-shell-completion.md`（app 四项预算棘轮）
- **Goal**: 把 MoUI Studio 右栏的外壳换成 VS Code 侧面板（side panel）的交互
  形式——面板头（标题 + ghost 动作簇）→ 扁平页签行 → 单一滚动区（快速操作 /
  运行时监视改为分区）→ 底部常驻 AI composer；同时把 AI 输入面收敛成**一个
  宿主**（取消底栏「AI 输入」页签与「停靠右栏 / 放到底栏」两个切换钮）。
  信息架构不变：六页签与全部编辑能力保留。
- **Non-goals**: 不改检查器的任何编辑能力；不动 AI 工作台模式（PsAi）中心的
  composer；不加分区折叠状态机与「⋯ More Actions」菜单（Msg 变体预算已封顶）；
  不改 composer 输入盒的扁平视觉（既有实测结论）。

> 触发：用户两图对比——参考图是 VS Code 的右侧 Copilot 侧栏（面板头 + 动作图标簇 +
> 滚动正文 + 底部停靠 composer），MoUI Studio 右栏当时是「对象芯片 + 六页签 + 属性字段
> + 固定底部两块（快速操作 / 运行时监视）」。
>
> 已确认的范围（用户选择）：
> 1. **检查器内容不变，外壳改成 VS Code 侧面板口径**——信息架构不动。
> 2. **AI 输入常驻右栏底部**（VS Code 口径），底栏「AI 输入」页签与「停靠右栏 /
>    放到底栏」两个切换按钮一并取消，AI 输入只有一个家。

## 目标形态

```
┌──────────────────────────────────────────────┐
│ 面板头 30pt   对象名 + 清除✕ │spacer│ 徽标 ⚙ ✕收起 │  ghost 图标簇
├──────────────────────────────────────────────┤
│ 页签行 30pt   属性 状态 数据 动作 依赖 运行时      │  扁平文字 + 活动态下划线
├──────────────────────────────────────────────┤
│ 单一滚动区                                      │
│  ▾ AI 会话                      [徽标 N]       │  仅有内容时出现，整条可点折叠
│    线程卡…                                     │
│  快速操作   对齐×3 复制 删除 AI 优化              │  原固定块 → 分区
│  运行时监视 [N]                                 │  原固定块 → 分区
│  （积木编辑卡：选中积木时常驻，自带标题）           │
├──────────────────────────────────────────────┤  hairline = 钉底边界
│ composer 钉底块                                │
│  [◈ 结果 · 标签]            ← 上下文芯片（新）   │
│  ┌────────────────────────────┐  🎤 ↑          │
│  │ textarea（两行）            │                │
│  │ ＋ Agent⌄   model    历史   │                │
│  └────────────────────────────┘                │
└──────────────────────────────────────────────┘
```

## 硬约束（实施前实测，全部贴上限）

| 预算 | 现值 | 上限 |
|---|---|---|
| `moui_studio/app` 非测试 .mbt 行数 | 32,480 | 32,480 |
| `moui_studio/app` 非测试 .mbt 文件数 | 49 | 49 |
| `Model` 字段数 | 145 | 145 |
| `Msg` 变体数 | 278 | 278 |
| 单文件 logic 行 | `ide_context.mbt` 1810（ratchet） | 1200 + ratchet |

结论：**app 包必须净减行、不新增 app 文件、不新增 Msg 变体**。新通用原子放
`moui_studio/chrome/side_panel.mbt`（chrome 无行数/文件数预算）。删死字段
`Model.ai_context_chips` 把字段数降到 144（本方案不需要那个槽位，只是顺带清理）。

## 高度/宽度预算（单点计算）

| 段 | 来源 |
|---|---|
| 面板头 | `@chrome.PANEL_HEAD_HEIGHT` = 30 |
| 页签行 | `RIGHT_TAB_HEIGHT` = 30（新常量） |
| 钉底块 | `ai_docked_height(model, width)`（新，唯一来源） |
| 滚动正文 | `(height - 30 - 30 - docked_h).max(100)` |
| `docked_h` 夹取 | `.min((height - 60.0 - 100.0).max(0.0))` |

`ai_docked_height = 12(pad×2) + 22(上下文芯片) + 2(间距) + composer_block_height(width)
+ decision_bar_footprint(model)`，总上限 220。
`decision_bar_footprint` 必须记那 12pt——`decision_bar` 的容器高是
`decision_bar_height + 12`（`ide_ai.mbt` 既有实现），预算少算就会裁掉决策条
（本仓反复踩的双算账）。

典型值：默认 272pt 宽 / 736pt 高 → `docked_h` 124，正文 552；最大化 560pt 宽 →
`composer_block_height` 含芯片行 116 → `docked_h` 152，正文 524。

## 决策记录

| 决策 | 理由 |
|---|---|
| AI 会话分区放滚动区**最前**（页签行正下方） | 它只在有内容时存在 → 默认态检查器视觉完全不变；出现时紧贴页签行可见，对应 VS Code「转录在正文顶部、输入在底部」。代价：有 AI 内容时检查器整体下移。 |
| 折叠条与 AI 分区头**合体** | 少一层堆叠的头；复用既有 `ToggleAiCardsFold`，不引入新消息 |
| 分区（除 AI）**不可折叠** | 需要新 Msg 变体，278 已封顶。延后 |
| 不做「⋯ More Actions」菜单 | 需要菜单锚点状态 + 开合消息，两项都贴上限。延后 |
| 不做「⤢ 最大化右栏」 | `@style.IconName` 无合适字形，新增图标枚举属 core/style API 变更，成本远高于收益 |
| 页签行**沿用等宽格子**，只改视觉 | 改内容宽会在 170pt 紧急收缩档溢出（窄窗既有退化不变） |
| composer 输入盒**不加圆角/描边** | 扁平是与面板融为一体的既有实测结论；本方案只改位置与结构 |
| `PsAi` 模式中心的 composer **不动** | 该模式右栏是更改/文件工作区面板，中心即会话面；本方案只取消「底栏」宿主与两个切换钮 |
| `plugins/ai` 的 `thread_area_height` **保留** | 失去唯一 app 调用方，但属插件公开 API 且插件测试覆盖；不在本次范围 |

## 变更清单

### `moui_studio/chrome/side_panel.mbt`（新文件）
- `section_head(label, width, trailing?=[], trailing_widths?=[], lead? : View? = None)`
  —— 22pt、Caption、`ide_text_faint()`、`ide_panel_alt()` 底；`lead` 槽给折叠雪佛龙。
- `side_panel_section(label, content, width, ...)` = `column[section_head, content]`。

### `moui_studio/app/ide_context.mbt`
- `ide_right_panel` 重写：面板头 + 页签行 + 单一滚动区（`context_sections`）+ hairline + 钉底块。
- `context_sections`：AI 会话分区 → 积木编辑卡 → 当前页签内容 → 快速操作 → 运行时监视。
- `context_head`：两枚 `icon_button` → `ghost_icon_button`（去 tile 底块），徽标与关闭 ✕ 之间加 `Gear → ToggleSettings`。**两个 ✕ 的语义分工不动**（`memories/repo/moui-studio.md:1149` 的结论）。
- `context_tabs`：等宽公式不变，视觉改扁平文字 + 2pt 强调色下划线，行底 `ide_panel_alt()` 与面板头连成一条带。
- `quick_actions` / `watch_pane`：`panel_head`(30) → `section_head`(22)，从面板级固定块变为分区。

### `moui_studio/app/ide_ai.mbt`
- 新增 `AI_SUBJECT_CHIP_HEIGHT`、`decision_bar_footprint`、`ai_docked_height`、
  `ai_docked_block`、`ai_subject_chip`、`has_ai_thread`、`ai_thread_section`。
- `composer` 脚注删两枚 ghost 切换钮。
- 删除 `ai_layer`、`ai_docked`、`ai_card_height`、`thread_area_height`(app 包装)、
  `card_chrome_height`、`ai_card_body`、`fold_bar`、`AI_BAR_HEIGHT`、`ai_bar_height`、
  `ai_bar_composer`、`ai_host_hint_key`。

### `moui_studio/app/ide_root.mbt`
右列只留两支：`RvWorkspace` → `ai_workspace_panel`；否则 → `ide_right_panel`。
`shell_view` 的 `bottom_height` 去掉 `BtAi` 分支。

### `moui_studio/app/ide_shell.mbt`
删 `ai_in_bottom` / AI 页签格 / `BtAi` 匹配臂（含 `app.ai.elsewhere` 空态）。

### 状态机
- `model.mbt`：`RightView` 删 `RvAi`；`BottomTab` 删 `BtAi`；`Model` 删死字段
  `ai_context_chips`；初始 `bottom_tab: BtAi` → `BtAudit`。
- `update_shell.mbt`：`set_right_view` 删 `(RvAi, BtAi)` 臂；`apply_perspective_preset`
  的 `PsCode` 改 `RvContext`；`run_studio_command` 删 `studio.ai.dock`/`studio.ai.bar`。
- `ide_dialogs.mbt`：命令表删 `studio.ai.dock`/`studio.ai.pill`/`studio.ai.anchor`（后两条本就无处理器）。
- `ai_sessions_pane.mbt`：删 `ai_host_is_bottom`。

### i18n
- 新增 `app.right.ai_thread`（AI 会话 / AI thread）。
- 删除死键：`app.bottom.ai`、`app.ai.to_dock`、`app.ai.to_bar`、`app.ai.elsewhere`、
  `app.ai.anchor`、`app.ai.anchor.*`(5)、`app.ai.pill`、`app.ai.fold_idle`、
  `app.ai.fold_pending`、`app.command.ai.dock`、`app.command.ai.pill`、
  `app.command.ai.anchor`。
- 重生成 catalog 与 `pkg.generated.mbti`。

## 预算算术

净减 ≈ 400 行（ide_ai −268 / ide_root −41 / ide_shell −35 / update_shell −10 /
ide_dialogs −18 / model −14 / ai_sessions_pane −8 / ide_context −10），
净增 ≈ 140 行（ide_context +70 / ide_ai +70）。
→ **32,480 → ≈ 32,220**。文件数 49 → 49。Model 145 → 144。Msg 278 → 278。

## 测试

改写：`ai_bar_layout_wbtest`（5 例并 1）、`ai_transcript_wbtest`（2 例）、
`pane_lifecycle_wbtest`（1 例）、`shell_layout_wbtest`（3 处 + 2 断言）、
`ui_regression_wbtest`（1 处）、`blocks_slot_test`（键表）。

新增 9 例：composer 恒在右栏/底栏无 AI 页签、单一滚动区含两个分区头、
分区头在 200/170 两档不越界、面板高预算两档、AI 分区按内容出现/消失、
AI 分区头折叠、页签行活动态下划线、面板头 ✕ 关面板不关选中、
AI 插件禁用时无 composer 无 AI 分区。

## 验证

```sh
moon test moui_studio/app --target native
moon test moui_studio/app --target wasm-gc
node scripts/generate-i18n-catalogs.mjs --input moui_studio/app/i18n/catalogs.json --out moui_studio/app/i18n_catalog_generated.mbt   # 然后 --check
node scripts/check-generated-interfaces.mjs
node scripts/validate-maintenance-baseline.mjs
node scripts/validate-dead-messages.mjs
node scripts/validate-guidance-consistency.mjs
node scripts/validate-doc-references.mjs
sh scripts/check.sh --profile pr
```

## 边界

- `plugin_active(model,"ai")` 为假（教学版 / 插件禁用）→ 不出钉底块、不出 AI 分区，正文吃满整高。
- `ai_available=false`（Web）→ `composer` 自身降级为引导文案，高度不变。
- `RvWorkspace`（AI 模式）/ 全屏页（预览/帮助/运行）→ 右栏不渲染检查器，不受影响。
- 布局纪律：带权重 spacer 的行必须显式定宽并走 `@chrome.fill_row`；无背景 container
  会回落到环境 Base 刷子，每个新容器显式给底色；列不钉高会被 ContainerBox 垂直居中；
  scroll_view 子节点无界约束，宽必须由调用方传入。

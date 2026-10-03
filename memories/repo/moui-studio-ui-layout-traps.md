# MoUI Studio UI layout traps (views.mbt)

- **Verify layout via MCP, not pixels**: studio's macos entry serves MCP NDJSON
  on its own stdin (`serve_with_diagnostics`, protocol 2024-11-05): 2 semantic
  tools + 4 diagnostics (runtime counters, paint summary with ALL drawn texts,
  raw pointer/keyboard event injection `{"kind":"Pointer","position":{x,y},
  "phase":"Down|Up"}`, command intents). `read_semantics` frames are numeric
  ground truth; `perform_action` drives the app (target node_id as decimal
  STRING, action `{"kind":"activate"}`, precondition `{"kind":"latest"}`).
  This closed the loop on: empty-canvas hint (paint texts), dirty marker,
  draft restore, canvas zoom hit-testing.
- Known leak (FIXED): text_field values are exposed verbatim in the semantics
  tree. The provider key now uses `password_field` (masked display + reveal
  toggle) and update ignores edits while masked (star-text would corrupt the
  real value).
- Design-canvas auto-fit: the canvas measure fills its constraints
  (`width = min(max_w, max_h/0.75)`), scale = frame.width/640 computed in the
  draw/tap/drag closures — the canvas column is `.flexible()` in the main row,
  so the canvas grows with the window and hit-testing stays consistent without
  model state. Drawing plan ops are pure design coords; transforms happen at
  draw time.
- Draft auto-save: `program()`'s update wrapper recomputes
  `@codec.encode_program(program)` per message; dirty = encoding !=
  `saved_encoding` (set on save/open), draft written to settings key
  `studio.draft` only when the encoding changed since `draft_encoding` (RunTick
  at 30fps doesn't rewrite). Restored drafts boot dirty (● next to the title).

- `@views.text` defaults to `width=160` and the width is a **minimum** (grows with
  measured text). Inside a fixed-width panel it silently inflates the scroll
  content wider than the viewport; sibling buttons stretch to the inflated width
  and get clipped square by the scroll clip. Always pass explicit `width=` for
  texts inside narrow fixed panels (studio left panel headers use 140).
- Scroll indicator geometry (framework): the thumb draws at the **viewport's
  right edge minus 7pt** (`scroll_indicator_thumb`), so "scrollbar at the panel's
  far right" means the scroll viewport itself must reach the panel edge — e.g.
  card `padding=0` + full-bleed `scroll_view(width=card_width)` (studio right
  panel: thumb lands ~4pt from the card border).
- A scroll container's child **frame is the viewport width** (tight on
  re-layout): a bare `column` directly inside `scroll_view` stretches every
  child to the full viewport. To get centered content + a scrollbar lane, wrap
  the column in `@views.container(width=<content>, background=transparent,
  padding=<vertical breathing>)` — ContainerBox centers the child inside the
  stretched frame, and the leftover right strip becomes the indicator lane
  (studio right panel: viewport 300 / content 250 → fields centered at 25pt
  margins, ~18pt clear of the thumb). Cap every child's `width=` to the content
  budget, or one wide text inflates the whole column again.
- Main-row horizontal centering: flex rows pack children at x=0; the top_bar is
  centered (ContainerBox centers its narrow child), so the two rhythms clashed
  and the left card sat flush with the window edge. Fix: `@views.spacer()`
  (weight=1) at both row ends centers the row content and degrades gracefully
  on narrow windows.
- `@views.divider(axis=Vertical)` measures as **full available height** (mirror
  of the horizontal divider's full-width behavior). Inside a flex row it drives
  the row's cross size up to the window height; combine with `ContainerBox`
  centering this pushed the design canvas ~157pt down and pushed the footer
  notice off-window. Fix: bound the row `.frame(height=560.0)` (same as the
  panel cards) and `align=Start` so the 640x480 canvas top-aligns with panels.
- `shortcut_button` chip text is mono 16px: `Ctrl+Z` ≈ 58px, `Ctrl+Shift+Z` ≈
  116px. Chip width must be ≥ label + 12 padding (studio uses 84 / 140); smaller
  values clip the shortcut text on both sides.
- Button variant discipline after the "red wall" feedback: one solid Primary per
  panel (运行 / 生成提案 / 闸门确认); list entries, mode toggles, delete/duplicate
  use Tonal / Outline.

## 设计=运行 治本架构（2026-09）
- 设计舞台不再用 canvas 画"控件效果图"（双渲染器必然漂移：拟真按钮
  13px vs 真按钮 16px semibold 当场翻车）。改为三层：背景画布（窗体框+
  点阵+空态提示）+ 真实控件层（StageLayout 按 IR 矩形分配帧）+ 透明手势
  覆盖层（拦截全部指针，绘制选中描边/名牌/参考线，指针转设计坐标 Msg）。
- `form_widget` 是表单控件唯一构造点：运行舞台传真实回调，设计舞台传
  Noop（文本类回调必填，Noop 兜底防漏网点击）。
- StageLayout/两层画布的缩放都现算 min(帧宽/640, 帧高/480)，三层永不
  失配；导出 runner 模板内嵌同款 StageLayout（自包含副本）。
- 已知代价：zoom 对真控件是"盒子缩放、字号常量"（文字不随 zoom 放大）。

## 积木画布几何（2026-10，用户报「菜单向左/积木撑满/黑块」一轮）

- **块宽随内容**（Scratch 口径）：`blocks_item_rects` 按展示文本估宽收紧，
  不再撑满画布。估宽 = `text_estimate_width` ÷ `LABEL_WIDTH_SAFETY`（否则
  fit_label 的 5% 安全系数会把「按估宽定宽的块」再截一次省略号），下限 64。
  纪律：**凡是算矩形的路径（draw / 命中 / update 的落槽与 PaletteDrop /
  blocks_pane 的指示线）必须传同一份 `display_texts`**——宽度进了几何之后，
  缺了它就是另一组矩形，命中与绘制错开。
- **插槽洞的游标 = label_x + 引导宽**：引导 = 返回箭头 + 本地化标签 + 两
  空格（`block_row_texts` 与展示文本同源产出 `lead_texts`；宽度经
  `blocks_row_lead_width` 用真实度量）。洞游标曾从 label_x 直接累加段宽，
  而整行文字按默认 `TextCenter` 画——洞（近黑胶囊）孤零零留在左边，就是
  用户截图里的「积木上的黑块」。修法：标签 `align=TextStart` + 引导宽计入。
- **洞必须画在文字之下**：绘制按 ops 顺序叠层，`SlotHole` 先于 `BlockLabel`
  推入——反过来洞会把字形盖掉。
- 聚光灯不再加「▶ 」文字前缀（`BlockStroke` 描边已表达）：内容宽下前缀
  会让高亮行被 fit_label 挤出省略号。
- 右键菜单候选顺序 `BelowStart → AboveStart → BelowEnd → AboveEnd`：锚点
  是零尺寸指针点，`…End` 把菜单右缘对齐指针（向左弹）。零尺寸锚点下
  「主方向」完全由候选顺序决定。

## 运行语义与全屏页（2026-10，用户报「没点按钮标签就有内容 / 底栏只占左半」）

- **「运行」= 装填，不执行**：`start_run`/`start_compiled_run` 只进入运行页
  并建**空计划**运行态（舞台 = 设计初值），事件子程序只在真实控件事件
  （`ControlClicked`/`RunToggle`/`ControlChanged`/`ControlInputDone`）时经
  `run_handler` / `dispatch_compiled_event` 派发。此前 RunStart 直接把选中
  子程序跑完——用户「还没点按钮标签就有内容」。装填态判别：`plan.instrs
  == 0`（`merge_run_back` 据此跳过「运行完成」审计）。
- **全屏页（运行/预览/帮助）的底栏必须用 `side_width`**：`shell_chrome_widths`
  按「左右栏都在」算 `center_width`，而全屏页不渲染左右栏——底栏用
  center_width 就只铺左半段，右侧一条空白。
- 已知口径分歧（未修）：两轨事件派发的审计行号不同源——解释轨
  `run_handler` 走 IR 语句（line 0），编译轨走草稿 trace（真实行号）。
  跨轨比对审计时只能比 (op, detail)。

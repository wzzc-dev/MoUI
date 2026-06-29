# 修复 markdown_editor 表格点击光标位置错误

## 总结

点击 markdown_editor 中的表格 cell 时，光标（caret）落点不准。根因是表格分支的「点击→源偏移」映射函数 `rich_text_block_table_source_offset_at_point` 用列宽线性插值 source_range，忽略了 cell_padding、对齐方式和文本实际渲染宽度。本计划在不破坏现有渲染逻辑的前提下，让点击映射函数与渲染逻辑使用同样的几何信息。

## 当前状态分析

### 渲染端（正确）

[`append_rich_text_block_table`](file:///Volumes/Data/Code/moon/MoUI/moui_richtext/rich_text_editor.mbt#L1321-L1396) 渲染时：

- 每个 cell 的列宽 `column_width = frame.size.width / column_count`
- cell_frame = `(cell_x, row_y, column_width, table.row_height)`
- 文本 frame = `cell_frame.inset(table.cell_padding)`（cell_padding 默认 `symmetric(horizontal=8.0, vertical=5.0)`）
- 文本 align = `cell.align.unwrap_or(TextStart)`
- 字体可能根据 header 加重 weight（700 vs 400）

### 点击映射端（错误）

[`rich_text_block_table_source_offset_at_point`](file:///Volumes/Data/Code/moon/MoUI/moui_richtext/rich_text_editor.mbt#L3910-L3966)：

```moonbit
let relative = (x - cell_x) / column_width
Some(range.start + (relative * (range.end - range.start)).round().to_int())
```

- 不接收 `base_font` / `text_system`，无法测量文本宽度
- 不使用 `cell_padding`，把点击 x 当作横跨整个 cell_frame 的均匀插值
- 不考虑 `align`，导致居中/右对齐 cell 偏差更大

### 唯一调用点

[`rich_text_document_source_offset_at_point`](file:///Volumes/Data/Code/moon/MoUI/moui_richtext/rich_text_editor.mbt#L3025-L3027) 已经持有 `base_font` 与 `ctx.text_system`，可直接透传。

### 现有测试（精度不够）

[`editor_snapshot_wbtest.mbt:419`](file:///Volumes/Data/Code/moon/MoUI/examples/markdown_editor/app/editor_snapshot_wbtest.mbt#L419-L446) 断言 `caret >= 38 && caret <= 41`，3 字符 "yes" 的 source_range 是 39..42，线性插值在 0.33..0.67 区间都会得 41，刚好掩盖了偏差。

### 可复用工具

- [`rich_text_block_font(block, base_font)`](file:///Volumes/Data/Code/moon/MoUI/moui_richtext/rich_text_editor.mbt#L2400) — 解析 cell 字体
- [`rich_text_width(text, font, text_system)`](file:///Volumes/Data/Code/moon/MoUI/moui_richtext/rich_text_editor.mbt#L2416) — 测量文本宽度
- [`@core.TextGraphemeBoundaries::new(text)`](file:///Volumes/Data/Code/moon/MoUI/moui_richtext/rich_text_editor.mbt#L3291) + `boundaries.nearest_boundary(index)` — 图形素边界
- 参考实现 [`rich_text_run_visual_offset_at_x`](file:///Volumes/Data/Code/moon/MoUI/moui_richtext/rich_text_editor.mbt#L3282-L3327) 的逐字符中点命中规则

## 拟议变更

### 1. 修改 `moui_richtext/rich_text_editor.mbt`

#### 1.1 扩展 `rich_text_block_table_source_offset_at_point` 签名

把：

```moonbit
fn rich_text_block_table_source_offset_at_point(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
) -> Int?
```

改为：

```moonbit
fn rich_text_block_table_source_offset_at_point(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int?
```

#### 1.2 重写 cell 内的 x→偏移映射

在确定 `row_index` / `column_index` / `row[column_index].source_range = Some(range)` 后：

1. 计算 `cell_x = frame.origin.x + column_width * column_index`
2. 用 `rich_text_block_font(block, base_font)` 取字体；若 cell.header 为 true，按渲染端一致规则加 weight=700
3. 测量 `text_width = rich_text_width(cell.text, font, text_system)`
4. 计算 cell 内容区 x：`inner_x = cell_x + table.cell_padding.left`，`inner_width = column_width - table.cell_padding.left - table.cell_padding.right`
5. 按 `cell.align.unwrap_or(TextStart)` 计算文本渲染起点：
   - `TextStart` → `text_x = inner_x`
   - `TextCenter` → `text_x = inner_x + (inner_width - text_width) / 2`
   - `TextEnd` → `text_x = inner_x + inner_width - text_width`
6. `text_x_end = text_x + text_width`
7. 按渲染文本实际占位映射：
   - 若 `point.x < text_x` → 返回 `range.start`（cell 内文本左侧空白）
   - 若 `point.x > text_x_end` → 返回 `range.end`（文本右侧空白）
   - 否则按逐字符中点命中（参照 `rich_text_run_visual_offset_at_x` 的 `for index in 0..<chars.length()` 分支，但只对 cell.text 自身测量），得到 `local_offset ∈ [0, char_count]`
   - 最终 caret：用 `boundaries.nearest_boundary` 把 `local_offset` 钳到图形素边界，再 `range.start + local_offset`，最后整体 `clamp_int(.., range.start, range.end)`

#### 1.3 更新调用点

`rich_text_document_source_offset_at_point` 第 3025 行：

```moonbit
match rich_text_block_table_source_offset_at_point(
  block, point, frame, base_font, text_system,
) {
```

### 2. 新增/收紧测试：`examples/markdown_editor/app/editor_snapshot_wbtest.mbt`

把现有 "markdown editor click maps table preview cells to markdown source" 测试保留并扩展，或在其后新增：

1. **左对齐 "yes" cell（默认 align=None → TextStart）**
   - 点击文本中心 x → caret 接近 `range.start + char_count` 中点
   - 点击文本右侧空白（仍属 cell）→ caret = range.end
   - 点击文本左侧空白 → caret = range.start
2. **居中对齐 cell**：`| :---: |` 下 "Core" cell，点击 cell 中心 → caret 落在文本实际中点，而非线性插值结果
3. **右对齐 cell**：`| ---: |` 下 cell，点击 cell 中心 → caret = range.end（因文本贴右，中心已落在文本右侧空白）
4. **空 cell**（`|  |`）：source_range 长度为 0，点击任意位置 → caret = range.start

预期具体值示例（基于文档 `| Name | Done |\n| --- | --- |\n| Core | yes |`，"yes" 在 source 偏移 39..42）：
- 点击 "yes" 文本中点 → caret = 41（"y" 与 "e" 之间的图形素边界，参考 `rich_text_run_visual_offset_at_x` 的中点命中规则）
- 点击 "yes" 文本右侧空白（cell_x + text_width 之后）→ caret = 42
- 点击 "yes" 文本左侧空白（cell_padding 区内）→ caret = 39

## 假设与决策

- **不引入新的渲染几何状态**：修复完全在点击映射端，复用 `RichTextTable` 已有的 `cell_padding` / `align` / `cell.text` / `cell.header` 字段。渲染端无改动。
- **字体选择与渲染端一致**：header cell 用 weight=700，body 用 weight=400，与 `append_rich_text_block_table` 第 1379-1383 行保持同步。若未来渲染端字体规则变化，需要同步此函数。
- **图形素边界**：使用 `@core.TextGraphemeBoundaries::nearest_boundary`，避免 caret 落在代理对中间。复用项目已有模式。
- **`TextAlign::TextJustify`**：表格不会产生该值（`markdown_table_alignment_for_separator_cell` 只返回 None / TextCenter / TextEnd），但代码以 `else` 分支兜底处理为 TextStart，保持稳健。
- **不修改普通文本块路径**：仅修复 table 分支，普通 run 路径（`rich_text_block_source_offset_at_point` → `rich_text_block_visual_offset_at_point`）已经是精确测量，无需改动。
- **不修改 `cell.text` 的内容**：渲染用的是 `cell.text`（已是 trimmed 文本），与 source_range 对应的内容文本一致，可直接用 `cell.text` 测量。
- **保留线性插值作为 fallback**：若 `column_width <= 0.0` 或 `text_width <= 0.0`（空 cell），fallback 到原有 range.start ~ range.end 区间行为，避免除零。

## 验证步骤

按以下顺序执行：

1. **编译检查**
   ```sh
   moon check
   ```

2. **moui_richtext 单测**
   ```sh
   moon test -p moui_richtext
   ```

3. **markdown_editor 应用测试**（关键验证）
   ```sh
   moon test -p markdown_editor
   ```
   重点观察 `editor_snapshot_wbtest` 中表格点击相关用例。

4. **API 表面与维护基线**
   ```sh
   node scripts/validate-api-surface.mjs
   node scripts/validate-maintenance-baseline.mjs
   ```

5. **日常验证脚本**
   ```sh
   sh scripts/dev-check.sh
   ```
   该脚本包含 core/view/render/backend 包测试、markdown_editor 测试与 Web wasm-gc 构建。

6. **手动 smoke**（可选，若需要平台验证视觉行为）
   ```sh
   scripts/macos-skia-renderer-smoke.sh --run-markdown-smoke
   ```

## 完成判据

- `moon test -p markdown_editor` 通过，包含新增的精确点击断言。
- 点击 cell 文本左侧空白 → caret = range.start。
- 点击 cell 文本右侧空白 → caret = range.end。
- 点击 cell 文本字符间 → caret 落在最近图形素边界。
- 左/中/右对齐 cell 行为符合渲染实际位置。
- `sh scripts/dev-check.sh` 通过。

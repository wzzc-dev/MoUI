# MoUI 文本与富文本功能优化计划

## Summary

基于对 `moui/core`、`moui/views`、`moui_richtext` 的完整探索与用户的工程判断，本计划落地 5 条优化路线 + 文档修复，目标是把文本/富文本子系统从"主线可用"推进到"长期可维护、可扩展、契约稳定"。

核心动作：
1. 把散落在 `moui_richtext` 与 `moui/views/text_area_control.mbt` 的通用编辑原语下沉到 `moui/core`，消除行为漂移。
2. 把 `moui_richtext` 的 606 项公共面收口为少量 facade，内部 helper 改 private（允许破坏性变更，app 同步迁移）。
3. 让富文本几何走 `TextSystem::layout_paragraph` 的 caret/selection/hit-test 契约，而非自算。
4. 为 `moui_richtext` 补稳定黑盒测试，摆脱"靠 Markdown Editor app 间接覆盖"。
5. 修复 `docs/moui-app-package-boundary.md` 的 rich text ownership 漂移。

执行策略：分 5 个工作流顺序推进（原语下沉 → API 收口 → 几何复用 → 黑盒测试 → 文档修复），每个工作流独立可验证。允许破坏性收口，用 `scripts/dev-check.sh` 与 smoke gate 兜底。

## Current State Analysis

### 已确认的优点（保留不动）
- `moui/core/text_layout.mbt` 的 `TextSystem` 是唯一文本契约，`measure/paragraph_layout/register_font_data` 三函数字段。
- `TextGraphemeBoundaries` 是唯一 UAX #29 簇边界源，core 编辑 fixture 与 Skia white-box 测试共用。
- `moui_richtext` 作为 addon 不进 core/views，`moon.pkg` 只依赖 `wzzc-dev/moui/core` + `mizchi/markdown`。
- `MarkdownDocumentSession` 的 blocks(id/revision/fingerprint) + height_index + layout_cache 三层结构支撑窗口化渲染。

### 已确认的问题（本计划修复）

**问题 A：编辑原语分散，存在重复与漂移风险**
- `moui/core` 已有 `move_text_caret`、`delete_grapheme_range`、`normalize_grapheme_range`、`text_previous_grapheme_caret_boundary`、`text_next_grapheme_caret_boundary`、`TextCommandResult`、`TextCaretDirection`。
- `moui_richtext/rich_text_editor_helpers.mbt` 仍私有保留：`replace_text_range`、`replace_current_selection`、`selected_text`、`surrounding_delete_range`、`restore_text_history`、`apply_text_input`、`apply_text_edit`、`normalize_text_range_to_grapheme`、`text_input_grapheme_selection`、`composition_start_index`、`composition_cursor_offset`、`is_select_all_shortcut`、`is_undo_shortcut`、`is_redo_shortcut`。
- `moui/views/text_area_control.mbt:18-45` 重复定义 `text_area_min_int`/`text_area_max_int`/`text_area_clamp_int`，而 core 已有 `clamp_int`。
- core 的 `text_editing.mbt:36` 与 richtext 的 `rich_text_editor_helpers.mbt:192` 各自私有定义了同名 `active_text_selection`。

**问题 B：moui_richtext 公共面过大（606 项 pub，32 文件）**
- `editor_selection.mbt` 45 项 pub（各种 `*_at_caret`/`*_bounds`/`*_range` 内部 helper）
- `input_paste.mbt` 41 项、`input_table.mbt` 37 项、`commands_blocks.mbt` 41 项
- `editor_source_mapping.mbt` 55 项（源码映射内部实现）
- 真正需要对外暴露的只有：`RichTextDocument`/`RichTextBlock`/`RichTextRun`/`RichTextInputTransform`/`MarkdownDocumentSession`/`MarkdownEditTransaction`/`MarkdownEditorSelection`/`MarkdownEditorCommand` + 4 个 facade 函数 + app 实际使用的几何/查询函数（约 10 个）。
- `examples/markdown_editor/app` 实际直接 import 的 richtext 符号仅 13 处：`RichTextDecoration`、`RichTextDocument`、`RichTextBlock`、`RichTextInputTransform`、`rich_text_editor_content_rect`、`rich_text_document_caret_rect_at_source`、`rich_text_document_height`、`markdown_editor_selected_link_target`、`markdown_editor_selected_image_target`。

**问题 C：富文本几何绕开 TextSystem::layout_paragraph**
- `moui_richtext` 全包 `layout_paragraph` 调用次数为 0。
- `rich_text_document_caret_rect_at_source`、`rich_text_document_height`、`rich_text_editor_content_rect` 等 geometry 自行基于字体度量和行高估算，未复用 core 已有的 `TextParagraphLayoutResult::caret_rect_at`/`selection_rects`/`hit_test` 契约。
- 后果：富文本与 `text_area`/`text_field` 的 caret/selection 几何来源不同，多后端下可能漂移；fallback TextSystem 下富文本几何保真度更差。

**问题 D：moui_richtext 测试覆盖薄弱**
- 仅 `code_highlight_test.mbt`、`editor_session_test.mbt` 两个测试文件。
- 主要靠 `examples/markdown_editor/app/*_wbtest.mbt` 间接覆盖，但 wbtest 是 app 内测试，不属于 addon 稳定契约测试。
- 解析、源码映射、命令、输入变换、表格等核心能力缺黑盒契约测试。

**问题 E：文档漂移**
- `docs/moui-app-package-boundary.md:77-82` 说 rich text 由 `moui/views` 拥有，通过 `@views.RichTextDocument` 等 facade。
- `docs/moui-app-package-boundary.md:290-292` 说 `moui_richtext` 是 addon。
- 代码实际是后者（addon），第 77-82 行过时。

## Proposed Changes

### Workflow 1：编辑原语下沉到 moui/core

**目标**：把 richtext 与 text_area 重复的通用编辑原语统一到 core，消除漂移。

**文件**：`moui/core/text_editing.mbt`（扩展）

**新增 core 公开原语**（基于 rich_text_editor_helpers.mbt 的实现迁移，签名通用化）：
```moonbit
// 文本范围替换（replace_text_range 的通用版）
pub fn replace_text_range(text : String, range : TextRange, insertion : String) -> String

// 取选区文本
pub fn selected_text(text : String, selection : TextRange?) -> String

// 删除范围并返回新文本与建议 caret
pub fn delete_text_range(text : String, range : TextRange) -> String

// 围绕选区包裹前缀/后缀（用于 inline marker 包裹）
pub fn surround_text_range(text : String, range : TextRange, prefix : String, suffix : String) -> { text : String, range : TextRange }

// 快捷键判定（跨平台编辑原语，应在 core）
pub fn is_select_all_shortcut(event : KeyboardEvent) -> Bool
pub fn is_undo_shortcut(event : KeyboardEvent) -> Bool
pub fn is_redo_shortcut(event : KeyboardEvent) -> Bool

// IME composition 几何（core 已有 TextInputState，补齐 composition offset 契约）
pub fn composition_start_index(state : TextInputState) -> Int
pub fn composition_cursor_offset(state : TextInputState) -> Int
```

**core 内部去重**：删除 core 自己的私有 `active_text_selection`（text_editing.mbt:36），统一用新的；或保留 core 版本，richtext 改为引用 core 版本。

**文件**：`moui_richtext/rich_text_editor_helpers.mbt`（改造）
- 删除 `replace_text_range`/`replace_current_selection`/`selected_text`/`surrounding_delete_range`/`is_select_all_shortcut`/`is_undo_shortcut`/`is_redo_shortcut`/`composition_start_index`/`composition_cursor_offset`/`active_text_selection` 的本地实现，改为调用 `@core.*`。
- 保留 richtext 特有的 `restore_text_history`（history 是 richtext session 概念，不下沉）、`apply_text_input`/`apply_text_edit`（richtext 编辑流程编排，调用 core 原语）、`normalize_text_range_to_grapheme`（已有 `@core.normalize_grapheme_range`，直接替换）、`text_input_grapheme_selection`（调用 core grapheme boundary）。

**文件**：`moui/views/text_area_control.mbt`（改造）
- 删除 `text_area_min_int`/`text_area_max_int`/`text_area_clamp_int`，改用 `@core.clamp_int`（core 已有）或 MoonBit 标准库 `@int.min`/`@int.max`（确认标准库可用性后选择）。
- text_area 的快捷键处理改用 `@core.is_*_shortcut`。

**为什么**：原语统一后，未来 text_area/text_field/rich_text_editor 三者的 replace/delete/select/undo 行为由 core 单一来源保证，多后端下不会漂移。

**怎么验证**：`moon check moui/core --target native`、`moon check moui_richtext --target native`、`moon check moui/views --target native`，然后跑 `moui_richtext` 现有测试与 `examples/markdown_editor/app` 测试确认行为不变。

---

### Workflow 2：moui_richtext 公共 API 收口

**目标**：把 606 项 pub 收口为约 30 项稳定 facade，内部 helper 改 private。

**文件**：`moui_richtext/facade.mbt`（扩展为唯一公共入口）

**保留的公共符号**（最终公共面）：
- 文档模型：`RichTextDocument`、`RichTextBlock`、`RichTextRun`、`RichTextDecoration`、`RichTextInputTransform`、`RichTextSourceRange`
- 编辑会话：`MarkdownDocumentSession`、`MarkdownEditTransaction`、`MarkdownEditReason`、`MarkdownEditorSelection`、`MarkdownEditorCommand`、`MarkdownEditorHistoryEntry`
- facade 函数（facade.mbt 已有 4 个，补齐）：
  - `markdown_document(source, base?)`（已有）
  - `markdown_input_transform(source, caret, selection, inserted)`（已有）
  - `markdown_editor(...)`（已有，formatter 模式）
  - `controlled_markdown_editor(...)`（已有）
  - `controlled_markdown_session_editor(...)`（从 rich_text_editor.mbt 迁移到 facade.mbt，作为推荐主路径）
- app 实际使用的几何/查询函数（确认保留，因为这些是 app 渲染必需的契约）：
  - `rich_text_document_caret_rect_at_source`
  - `rich_text_document_height`
  - `rich_text_editor_content_rect`
  - `markdown_editor_selected_link_target`
  - `markdown_editor_selected_image_target`

**改 private 的范围**（按文件）：
- `editor_selection.mbt`：45 项 pub 全部改 `fn`（无 pub）。这些都是内部查询 helper。
- `editor_source_mapping.mbt`：55 项 pub 改 `fn`，仅保留 facade 需要的导出（如有）。
- `input_*.mbt`（input_pairs/input_paste/input_table/input_blocks*/input_delete_merge/input_pairs_*）：所有 `pub fn markdown_editor_*` 改 `fn`，仅 `markdown_editor_transform_input` 通过 `markdown_input_transform` facade 暴露。
- `commands_*.mbt`：所有 `pub fn markdown_editor_*` 改 `fn`，仅通过 `markdown_editor_apply_command_at`（已是内部入口）+ `MarkdownEditorCommand` 枚举对外。
- `markdown_model*.mbt`：内部解析 helper 改 `fn`，仅 `MarkdownBlockKind` 枚举与必要的类型保留 pub。
- `rich_text_editor.mbt`：`controlled_markdown_session_editor` 迁到 facade.mbt，其余 `pub fn rich_text_*` 中只保留上述几何契约函数为 pub，其余改 private。

**app 迁移**（`examples/markdown_editor/app`）：
- 现有 13 处 `@moui_richtext.*` 调用全部是保留的公共符号，无需迁移（已确认）。
- 若 app 内部有直接调用即将改 private 的 helper（需 grep 确认），改为通过 facade 或保留的公共函数。

**为什么**：收口后，未来改解析器、源码映射、表格编辑实现不会触发兼容性约束；公共面从 606 降到约 30，维护成本大幅下降。

**怎么验证**：
1. `moon ide doc '@wzzc-dev/moui_richtext' | wc -l` 应从 960 行显著下降（目标 < 300 行）。
2. `node scripts/validate-api-surface.mjs` 通过（若该脚本检查 richtext，需同步更新白名单）。
3. `sh scripts/dev-check.sh` 全套通过。
4. `examples/markdown_editor/app` 所有 wbtest 通过。

---

### Workflow 3：富文本几何复用 TextSystem::layout_paragraph

**目标**：让 richtext 的 caret/selection/height 几何走 core 的 `TextParagraphLayoutResult` 契约，与 text_area/text_field 统一。

**文件**：`moui_richtext/rich_text_editor.mbt`（改造几何函数）

**现状**：`rich_text_document_caret_rect_at_source`、`rich_text_document_height`、`rich_text_editor_content_rect`、`append_rich_text_block_runs` 相关几何自行基于 `font.size` 与行高估算，未调用 `text_system.layout_paragraph`。

**改造方案**：
1. 在 `rich_text_editor` 的 paint/event context 中获取 `ctx.text_system`（已有，控件通过 `ctx.text_system` 访问）。
2. 对每个 `RichTextBlock`，按 block 的 `frame` 与 `font` 调用 `text_system.layout_paragraph(TextLayoutInput::new(text, font, max_width=block.frame.width))`，得到 `TextParagraphLayoutResult`。
3. `caret_rect_at(offset)` 改为调用 `paragraph_result.caret_rect_at(utf8_offset)`（core 已有该方法，text_layout.mbt:136-220）。
4. `selection_rects` 改为调用 `paragraph_result.selection_rects(range)`。
5. `hit_test(point)` 改为调用 `paragraph_result.hit_test(point)`，回源码 offset。
6. `rich_text_document_height` 改为累加各 block 的 `paragraph_result` 高度。
7. 保留 `visual_text` / `source_range` / `content_range` 三元映射逻辑不变——只是把"offset → 几何"这一步从自算改为查 paragraph_result。

**注意**：
- 富文本是 block 序列，每个 block 内是单段文本，对每 block 调一次 layout_paragraph 是合理的（block = 段落级）。
- 表格 block 的几何仍走自有逻辑（表格不是普通段落），但单元格内文本仍可用 layout_paragraph。
- 保留 fallback 路径：若 `paragraph_layout_available = false`（见 TextParagraphLayoutMetadata），回落到现有估算，保证无原生后端时仍可编辑。

**为什么**：消除富文本与普通文本控件的几何来源分裂，多后端下 caret/selection 行为一致；fallback TextSystem 的几何保真度问题集中到 core 一处解决。

**怎么验证**：
1. `moui_richtext` 现有测试通过（caret/selection offset 不变）。
2. `examples/markdown_editor/app` 的 snapshot wbtest 通过（视觉快照不变）。
3. `scripts/macos-skia-renderer-smoke.sh --run-markdown-smoke` 通过（真实 Skia 渲染几何正确）。
4. `sh scripts/ci-web-runtime-presentation.sh` 通过（Web 后端几何正确）。

---

### Workflow 4：moui_richtext 稳定黑盒测试

**目标**：为 richtext 核心能力补契约级黑盒测试，不依赖 app 间接覆盖。

**新增测试文件**（`moui_richtext/*_test.mbt`）：

1. `rich_text_document_test.mbt`：文档模型契约
   - `RichTextDocument::plain` 切分行为
   - `source_range`/`content_range`/`visual_text` 三元映射的不变量（content_range ⊆ source_range，visual_text 长度 = content_range 长度）
   - Markdown 解析覆盖：heading/paragraph/list/task/quote/code/table/footnote/html/front_matter

2. `editor_source_mapping_test.mbt`：源码映射双向契约
   - 视觉 offset → 源码 offset → 视觉 offset 回环一致性
   - hit test offset 落在 grapheme boundary
   - `reveal_active_inline_run` / `reveal_active_block_marker` 行为

3. `editor_commands_test.mbt`：命令系统契约
   - 每个 `MarkdownEditorCommand` 枚举值的输入输出快照
   - inline toggle（Bold/Italic/Code/Strikethrough）的 wrap/unwrap 对称性
   - block transform（Heading/Paragraph/List/Quote）的 round-trip
   - 表格命令（InsertTable*、SetTableColumnAlignment）

4. `editor_input_transforms_test.mbt`：输入变换管线契约
   - 13 步责任链的每步触发条件与输出
   - 配对定界符输入、选区包裹、Tab 导航、多行粘贴、TSV 转表格
   - composition/IME 文本合并

5. `editor_session_test.mbt`（扩展现有）：session 事务契约
   - `apply(transaction)` 的不可变更新语义
   - `dirty_range` 的最小化（只重算受影响块）
   - `rich_text_window` 的窗口化渲染正确性
   - `fingerprint` 匹配保持 id/revision 稳定

**测试风格**：纯函数黑盒测试，只依赖 facade 暴露的公共符号（依赖 Workflow 2 完成）。不测内部 helper。

**为什么**：当前 richtext 测试仅 2 文件，主要靠 app wbtest 间接覆盖。wbtest 是 app 内测试，不属于 addon 稳定契约。补黑盒测试后，未来重构内部实现有回归保障。

**怎么验证**：`moon test moui_richtext --target native` 全套通过；测试覆盖率显著提升（核心能力每项都有契约测试）。

---

### Workflow 5：文档修复

**目标**：修复 `docs/moui-app-package-boundary.md` 的 rich text ownership 漂移，与代码实际对齐。

**文件**：`docs/moui-app-package-boundary.md`（修订）

**修订点**：
- 第 77-82 行：删除"Rich text ownership 已迁出...由 `moui/views` 拥有，并通过 `@views.RichTextDocument`..."整段过时描述。
- 替换为："`RichTextDocument`、table/image/source range、rich text geometry/paint/selection helper 由 `moui_richtext` addon 拥有，普通 app 通过 `@moui_richtext.RichTextDocument`、`@moui_richtext.markdown_editor`、`@moui_richtext.controlled_markdown_session_editor` 等 facade 使用。`core` 只保留 `TextRange`、grapheme boundary、`TextSystem`、paragraph layout contract、基础 text input state。`moui/views` 只保留 `text`/`text_field`/`text_area` 纯文本控件。"
- 确认第 290-292 行的 addon 描述与修订后的第 77-82 行一致。

**同步检查**：
- `docs/architecture.md` 第 34 行的 `moui_richtext` 描述已正确（"Markdown/rich-text document, editor, command, input, paste, table, and source-mapping logic"），无需改。
- `docs/text-system.md`、`docs/markdown-editor.md` 若有类似 ownership 表述，同步对齐。
- `AGENTS.md` 若有 rich text ownership 表述，同步对齐。
- 运行 `node scripts/sync-website-docs.mjs --check` 确认 website 副本同步。

**为什么**：文档与代码漂移会让新贡献者误以为 rich text 在 views，导致依赖方向错误。

**怎么验证**：`node scripts/validate-api-surface.mjs`、`node scripts/validate-maintenance-baseline.mjs`、guidance consistency guard 通过。

---

## Assumptions & Decisions

1. **允许破坏性收口**：用户确认。Workflow 2 中内部 helper 改 private 不保留 deprecated 过渡期，app 直接迁移（已确认 app 实际使用的公共符号都在保留名单内）。
2. **core 下沉的原语签名通用化**：不下沉 richtext 特有概念（如 `restore_text_history` 是 session 级，留 richtext）。下沉的是纯文本操作（replace/delete/select/surround/快捷键/composition offset）。
3. **几何复用保留 fallback 路径**：`TextParagraphLayoutMetadata.paragraph_layout_available = false` 时回落到现有估算，保证无原生后端环境可编辑。
4. **表格几何不全改**：表格 block 的几何仍走自有逻辑（表格不是普通段落），仅单元格内文本用 layout_paragraph。
5. **测试依赖 Workflow 2**：黑盒测试只测 facade 公共符号，因此 Workflow 4 在 Workflow 2 之后执行。
6. **执行顺序**：Workflow 1 → 2 → 3 → 4 → 5。1 与 2 可部分并行（不同文件），但 2 的 app 迁移依赖 1 的原语下沉完成。3 依赖 2（几何函数已是 facade 公共契约后才改实现）。4 依赖 2。5 独立，可随时做但放最后避免返工。
7. **不引入新包**：原语下沉到现有 `moui/core`，不新建 `moui_text_editing` 包。保持包结构稳定。
8. **formatter 模式暂不弃用**：`rich_text_editor`（formatter 模式）与 `controlled_markdown_session_editor`（session 模式）并存状态本次不打破，仅收口公共面。formatter 弃用路线留作后续 ADR。

## Verification steps

每个 Workflow 完成后执行对应验证；全部完成后执行完整门禁：

```sh
# 单包检查
moon check moui/core --target native
moon check moui_richtext --target native
moon check moui/views --target native

# API 面验证（Workflow 2 后公共面应显著缩小）
moon ide doc '@wzzc-dev/moui_richtext' | wc -l   # 目标 < 300 行

# API surface guard
node scripts/validate-api-surface.mjs
node scripts/validate-maintenance-baseline.mjs

# 全套测试
moon test moui/core --target native
moon test moui_richtext --target native
moon test moui/views --target native

# app 测试（确认迁移无回归）
moon test examples/markdown_editor/app --target native

# 每日验证脚本
sh scripts/dev-check.sh

# 真实渲染几何验证（Workflow 3 后必须）
scripts/macos-skia-renderer-smoke.sh --run-markdown-smoke
sh scripts/ci-web-runtime-presentation.sh

# 文档同步验证（Workflow 5 后）
node scripts/sync-website-docs.mjs --check

# 烟雾门禁预览
node scripts/smoke-gate.mjs --tier release --dry-run --json
```

**完成标准**：
- 所有上述命令通过。
- `moui_richtext` 公共面从 606 项降至约 30 项。
- `moui_richtext` 测试文件从 2 个增至 6+ 个，覆盖文档/映射/命令/输入/session 五大能力。
- 富文本几何与 text_area 共用 `TextParagraphLayoutResult` 契约。
- `docs/moui-app-package-boundary.md` 不再自相矛盾。

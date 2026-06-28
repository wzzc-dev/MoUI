# Plan: 修复 markdown_editor Typora 风格贴边布局

## Summary

修复 Typora 风格贴边布局（左侧文件树紧贴窗口左边缘、右侧大纲紧贴窗口右边缘、editor 水平居中）实施后遗留的 8 个测试失败问题。

## Current State Analysis

### 已完成的修改（前一轮会话）

1. **view_chrome.mbt**：
   - chrome 左右 padding 清零（`right=0.0, left=0.0`）
   - workspace column align 改为 `Stretch`
   - 用 `padded.expanded()` 替代 `markdown_editor_centered_workspace`

2. **view_editor_surface.mbt**：
   - 在 `editor_source_layout` 的 row 中添加了两个等权 `spacer(weight=1.0)` 包裹 editor
   - row align 改为 `Stretch`
   - 外层 column align 改为 `Stretch`

3. **view_inspectors.mbt**：
   - file sidebar `corner_radius=0.0`
   - outline inspector `corner_radius=0.0`

4. **editor_test_helpers_wbtest.mbt**：
   - 重写了 `editor_content_x` 函数，使用新布局数学（无 chrome padding，考虑左右 inspector 宽度）

### 遗留问题：8 个测试失败

失败的测试都调用 `app.editor_content_x(980.0, inner_x=...)`，默认状态下所有 inspector 不可见。

### 根本原因分析

通过 MoUI 布局系统源码分析（`moui/runtime/layout.mbt`、`moui/views/flex_layout_engine.mbt`、`moui/core/view_protocol.mbt`），确认了两个布局缺陷：

#### 缺陷 1：外层 row 阻止 editor_source_layout 填满窗口宽度

`view_chrome.mbt` 第 31-56 行：
```moonbit
children.push(
  row(
    [
      editor_source_layout(...),  // 唯一子组件，无 spacer，无 flex weight
    ],
    spacing=theme.spacing_scale.lg,
    align=@views.CrossAlign::Start,
  ),
)
```

- `row`（axis=Horizontal）只有一个子组件 `editor_source_layout`，没有 spacer，子组件没有 flex weight
- `flex_measured_size`（flex_layout_engine.mbt:45-81）累加子组件 base size；`editor_source_layout` 的 base = intrinsic width
- workspace `column(Stretch)` 在 place 阶段会把外层 row 的 frame 拉伸到 column 宽度（= window width）
- 但 row 内部的 `editor_source_layout` 没有 flex weight，不会被拉伸；slack = window_width - intrinsic_width 被留空
- 结果：`editor_source_layout` 宽度 = intrinsic width（file_sidebar + editor + outline），不是 window width

#### 缺陷 2：无 inspector 时 editor 不进入 row 居中分支

`view_editor_surface.mbt` 第 887-888 行：
```moonbit
if !show_source && !show_outline && !show_files && !show_info {
  editor_with_indicator  // 直接返回，不进入 row + spacer 分支
} else {
  // ... row([spacer(1), editor, spacer(1), ...])
}
```

- 默认状态下所有 inspector 不可见，走提前返回分支
- editor 直接作为 column 子组件，没有 spacer 包裹
- column(Stretch) 会拉伸 editor 的 frame 到 column 宽度，但 editor 有固定宽度（`size=Size(width=editor_width, ...)`，第 831 行）
- editor 不会被居中

#### 与 editor_content_x 的矛盾

`editor_content_x`（editor_test_helpers_wbtest.mbt:538-579）假设 editor 总是居中：
```moonbit
let editor_x = left_width + max(0.0, (available - editor_width) / 2.0)
editor_x + 14.0 + inner_x
```

当没有 inspector 时（默认测试状态）：
- `left_width` = 0, `right_width` = 0
- `available` = 980.0
- `editor_width` = 780.0（page_width）
- `editor_x` = 0 + max(0, (980-780)/2) = 100.0
- 期望 editor 左边缘在 x=100.0

但实际布局中 editor 没有被居中，所以测试失败。

### 布局系统验证

通过搜索 agent 确认（参考 `moui/runtime/flex_weight_test.mbt` 第 29-58 行测试 "weighted spacers center a fixed child horizontally"）：

- `column(Stretch)` 在 place 阶段用 `CrossStretch => { offset: 0.0, size: available }`（flex_layout_engine.mbt:291）把子组件 frame 拉伸到 column 宽度
- 然后用 `Constraints::tight(frame.size)`（layout.mbt:128）重新测量子组件
- row 收到 tight 约束后，`size = constrain(measured, [window_width, ...])` = window_width
- `slack = window_width - base_total`，spacer 按 weight 瓜分 slack
- 结果：row 填满 window width，spacer 让 editor 居中

所以只要修复上述两个缺陷，spacer 就能正确工作，editor 会居中，`editor_content_x` 的计算与实际布局一致。

## Proposed Changes

### 修改 1：view_chrome.mbt — 移除外层 row 包裹

**文件**：`/Volumes/Data/Code/moon/MoUI/examples/markdown_editor/app/view_chrome.mbt`

**位置**：第 31-56 行

**原因**：外层 row 只有一个子组件，没有 spacer，阻止 editor_source_layout 填满窗口宽度。workspace column(Stretch) 会直接把 editor_source_layout 拉伸到 window width。

**修改**：把 `row([editor_source_layout(...)], align=Start)` 改为直接 push `editor_source_layout(...)`。

```moonbit
// 修改前（第 31-56 行）：
children.push(
  row(
    [
      editor_source_layout(
        self, session, editor_font, appearance, theme,
        show_source, show_outline, show_files, show_info,
        target_bar, selection, target_kind, scroll_offset,
        (caret, selection) => SetSelection(caret, selection),
        offset => ToggleTaskAt(offset),
        viewport_height~,
      ),
    ],
    spacing=theme.spacing_scale.lg,
    align=@views.CrossAlign::Start,
  ),
)

// 修改后：
children.push(
  editor_source_layout(
    self, session, editor_font, appearance, theme,
    show_source, show_outline, show_files, show_info,
    target_bar, selection, target_kind, scroll_offset,
    (caret, selection) => SetSelection(caret, selection),
    offset => ToggleTaskAt(offset),
    viewport_height~,
  ),
)
```

### 修改 2：view_editor_surface.mbt — 移除无 inspector 时的提前返回

**文件**：`/Volumes/Data/Code/moon/MoUI/examples/markdown_editor/app/view_editor_surface.mbt`

**位置**：第 887-934 行

**原因**：当没有 inspector 时，提前返回 `editor_with_indicator`，editor 不进入 row + spacer 分支，不会被居中。但 `editor_content_x` 假设 editor 总是居中。Typora 风格也要求 editor 总是居中（即使没有 sidebar）。

**修改**：移除 `if !show_source && !show_outline && !show_files && !show_info` 提前返回，让所有情况都走 row + spacer 分支。

```moonbit
// 修改前（第 887-934 行）：
if !show_source && !show_outline && !show_files && !show_info {
  editor_with_indicator
} else {
  let side_children : Array[@moui.View[MarkdownEditorMsg]] = []
  if show_files { ... }
  side_children.push(spacer(min_length=0.0, weight=1.0))
  side_children.push(editor_with_indicator)
  side_children.push(spacer(min_length=0.0, weight=1.0))
  if show_info { ... }
  if show_outline { ... }
  if show_source { ... }
  let editor_and_sidebars = row(side_children, spacing=0.0, align=Stretch)
  column(...)
}

// 修改后（移除 if 提前返回，总是走 row 分支）：
let side_children : Array[@moui.View[MarkdownEditorMsg]] = []
if show_files {
  side_children.push(
    files_inspector(app, session, theme, height=viewport_height),
  )
}
side_children.push(spacer(min_length=0.0, weight=1.0))
side_children.push(editor_with_indicator)
side_children.push(spacer(min_length=0.0, weight=1.0))
if show_info {
  side_children.push(
    document_info_inspector(session, theme, height=viewport_height),
  )
}
if show_outline {
  side_children.push(
    outline_inspector(app, session, selection, theme, height=viewport_height),
  )
}
if show_source {
  side_children.push(
    source_inspector(session.source, theme, height=viewport_height),
  )
}
let editor_and_sidebars = row(
  side_children,
  spacing=0.0,
  align=@views.CrossAlign::Stretch,
)
column(
  if target_kind == PlainSelection || !show_source {
    [editor_and_sidebars]
  } else {
    [editor_and_sidebars, target_bar]
  },
  spacing=theme.spacing_scale.md,
  align=@views.CrossAlign::Stretch,
)
```

### 验证 editor_content_x 计算正确性

`editor_content_x`（editor_test_helpers_wbtest.mbt:538-579）的计算与实际布局一致（已验证）：

- **无 inspector**（默认）：row=[spacer(1), editor(780), spacer(1)]，window=980
  - slack = 980 - 780 = 200，每个 spacer = 100
  - editor x = 100，`editor_content_x` = 100 + 14 + inner_x = 114 + inner_x ✓

- **show_files only**：row=[files(240), spacer(1), editor(640), spacer(1)]，window=980
  - slack = 980 - 240 - 640 = 100，每个 spacer = 50
  - editor x = 240 + 50 = 290，`editor_content_x` = 290 + 14 + inner_x = 304 + inner_x ✓

- **show_files + show_outline**：row=[files(240), spacer(1), editor(640), spacer(1), outline(240)]，window=980
  - slack = 980 - 240 - 640 - 240 = -120 → 0，每个 spacer = 0
  - editor x = 240，`editor_content_x` = 240 + 14 + inner_x = 254 + inner_x ✓

无需修改 `editor_content_x`。

## Assumptions & Decisions

1. **editor 总是居中**：即使没有 inspector，editor 也通过 row + spacer 居中（Typora 风格）。这与 `editor_content_x` 的假设一致。

2. **保留 `markdown_editor_centered_workspace` 函数定义**：虽然不再使用，但删除它不在本任务范围内，保留不影响功能。

3. **不修改 inspector 宽度**：file_sidebar=240, outline=240, info=240, source=292 保持不变。

4. **不修改 `editor_content_x`**：已验证其计算与实际布局一致。

5. **spacing=0.0**：row 的 spacing 保持 0.0，`editor_content_x` 不考虑 spacing（因为 spacing=0）。

## Verification Steps

1. **编译检查**：
   ```sh
   moon check --target wasm-gc
   ```

2. **运行 markdown_editor 测试**（验证 8 个失败测试通过）：
   ```sh
   moon test --target wasm-gc -p markdown_editor
   ```

3. **验证失败的测试**：
   - `editor_snapshot_wbtest.mbt`: "markdown editor click places caret after hidden heading marker"
   - `editor_snapshot_wbtest.mbt`: "markdown editor selection highlight uses formatted heading range"
   - `editor_snapshot_wbtest.mbt`: "markdown editor drag selection tracks markdown source range"
   - `editor_app_task_runtime_wbtest.mbt`: "markdown editor runtime prefix click toggles task checkbox"
   - `editor_app_clipboard_runtime_wbtest.mbt`: "markdown editor paste command links selected text with url"
   - `editor_app_clipboard_runtime_wbtest.mbt`: "markdown editor paste command links selected text with email"
   - `editor_app_clipboard_runtime_wbtest.mbt`: "markdown editor paste command inserts image from selected alt text"
   - `editor_app_backspace_delete_runtime_wbtest.mbt`: "markdown editor runtime backspace removes hidden heading marker"

4. **运行完整测试套件**（确保无回归）：
   ```sh
   moon test --target wasm-gc
   ```

5. **视觉验证**（可选，手动 smoke）：
   ```sh
   sh scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
   ```
   验证：sidebar 紧贴窗口左边缘，outline 紧贴窗口右边缘，editor 水平居中。

# Plan: 验证并完成 markdown_editor Typora 风格贴边布局

## Summary

上一轮会话已实施 Typora 风格贴边布局的三处修改（sidebar 紧贴窗口左边缘、outline 紧贴窗口右边缘、editor 水平居中），但最后一处修改（用 `expanded()` + `spacer` 替代 `padding_edges`）**尚未通过测试验证**。本计划的目标是：验证现有修改是否正确解决 8 个失败测试，清理遗留的死代码，并确保无回归。

## Current State Analysis

### 已应用的修改（通过 `git diff` 确认）

通过 `git diff` 检查，4 个文件有未提交的修改：

#### 1. `examples/markdown_editor/app/view_chrome.mbt`
- **移除外层 `row` 包裹**：`editor_source_layout(...)` 直接 push 到 `children`，不再用 `row([editor_source_layout(...)], align=Start)` 包裹
- **workspace column align 改为 `Stretch`**（原为 `Start`）
- **移除 `padding_edges` 包裹**：原 `padding_edges(workspace, top=0, right=xl, bottom=xl, left=md)` 已删除
- **移除 `markdown_editor_centered_workspace(padded).expanded()`**
- **新增 `workspace.expanded()` + `spacer(min_length=theme.spacing_scale.xl, weight=0.0)`**：用于底部 padding。原因：`padding_layout`（`moui/views/layout_views.mbt:59-62`）会把子组件 frame 宽度 clamp 到 `min(available.max.width, child_size.width)`，阻止 workspace 填满窗口宽度

#### 2. `examples/markdown_editor/app/view_editor_surface.mbt`
- **移除提前返回**：删除 `if !show_source && !show_outline && !show_files && !show_info { editor_with_indicator } else {` 分支，所有情况都走 row + spacer 分支
- **添加两个等权 spacer 包裹 editor**：`spacer(weight=1.0)` 在 editor 前后各一个，使 editor 居中
- **row spacing 改为 `0.0`**（原为 `theme.spacing_scale.lg`）
- **row align 改为 `Stretch`**（原为 `Start`）
- **外层 column align 改为 `Stretch`**（原为 `Start`）

#### 3. `examples/markdown_editor/app/view_inspectors.mbt`
- **`files_inspector` corner_radius 改为 `0.0`**（原为 `theme.radius_scale.sm`）：sidebar 紧贴窗口左边缘，无需圆角
- **`outline_inspector` corner_radius 改为 `0.0`**（原为 `theme.radius_scale.sm`）：outline 紧贴窗口右边缘，无需圆角

#### 4. `examples/markdown_editor/app/editor_test_helpers_wbtest.mbt`
- **重写 `editor_content_x` 函数**：使用新布局数学
  - 旧：`workspace_width = window_width - 12.0 - 24.0`（考虑 chrome padding），`centered_editor_x = 12.0 + max(0, (workspace_width - editor_width) / 2)`
  - 新：`available = window_width - left_width - right_width`（left_width = file_sidebar 宽度，right_width = info+outline+source 宽度），`editor_x = left_width + max(0, (available - editor_width) / 2)`

### 遗留问题

1. **8 个测试未验证**：上一轮会话中，前两处修改（移除外层 row + 移除提前返回）应用后仍有 8 个测试失败。第三处修改（`padding_edges` → `expanded()` + `spacer`）已应用但**未运行 `moon test` 验证**

2. **死代码**：`markdown_editor_centered_workspace` 函数（`view_chrome.mbt:216-247`）已不再被调用，但仍保留在代码中

### `editor_content_x` 计算验证

新布局下 `editor_content_x` 的计算与实际布局一致（已通过代码分析确认）：

- **无 inspector**（默认，window=980）：row=[spacer(1), editor(780), spacer(1)]
  - slack = 980 - 780 = 200，每个 spacer = 100
  - editor x = 100，`editor_content_x` = 100 + 14 + inner_x = 114 + inner_x ✓

- **show_files only**（window=980）：row=[files(240), spacer(1), editor(640), spacer(1)]
  - slack = 980 - 240 - 640 = 100，每个 spacer = 50
  - editor x = 240 + 50 = 290，`editor_content_x` = 290 + 14 + inner_x = 304 + inner_x ✓

- **show_files + show_outline**（window=980）：row=[files(240), spacer(1), editor(640), spacer(1), outline(240)]
  - slack = 980 - 240 - 640 - 240 = -120 → 0，每个 spacer = 0
  - editor x = 240，`editor_content_x` = 240 + 14 + inner_x = 254 + inner_x ✓

## Proposed Changes

### 修改 1：验证现有实现（无代码改动）

**目的**：确认三处修改已正确解决 8 个失败测试。

**步骤**：
1. `moon check --target wasm-gc` — 编译检查
2. `moon test --target wasm-gc -p markdown_editor` — 运行 markdown_editor 全部测试

**预期结果**：所有测试通过（特别是以下 8 个之前失败的测试）：
- `editor_snapshot_wbtest.mbt`: "markdown editor click places caret after hidden heading marker"
- `editor_snapshot_wbtest.mbt`: "markdown editor selection highlight uses formatted heading range"
- `editor_snapshot_wbtest.mbt`: "markdown editor drag selection tracks markdown source range"
- `editor_app_task_runtime_wbtest.mbt`: "markdown editor runtime prefix click toggles task checkbox"
- `editor_app_clipboard_runtime_wbtest.mbt`: "markdown editor paste command links selected text with url"
- `editor_app_clipboard_runtime_wbtest.mbt`: "markdown editor paste command links selected text with email"
- `editor_app_clipboard_runtime_wbtest.mbt`: "markdown editor paste command inserts image from selected alt text"
- `editor_app_backspace_delete_runtime_wbtest.mbt`: "markdown editor runtime backspace removes hidden heading marker"

### 修改 2：清理死代码 `markdown_editor_centered_workspace`

**文件**：`/Volumes/Data/Code/moon/MoUI/examples/markdown_editor/app/view_chrome.mbt`

**位置**：第 211-247 行（函数定义及其上方的注释）

**原因**：该函数在三处修改后不再被任何代码调用（已通过 `grep` 确认）。保留死代码会增加维护负担。

**修改**：删除 `markdown_editor_centered_workspace` 函数定义及其上方的注释。

```moonbit
// 删除以下代码（第 211-247 行）：
///|
/// Centered-workspace layout. Places its child horizontally centered inside
/// the available frame. Does NOT paint the window background — that is done
/// by a sibling fill view in the enclosing stack so this layout can live
/// inside a column alongside the chrome without needing `constraints.max`.
fn markdown_editor_centered_workspace(
  child : @moui.View[MarkdownEditorMsg],
) -> @moui.View[MarkdownEditorMsg] {
  @views.custom_children_layout(
    // ... 整个函数体
  )
}
```

### 修改 3：如果测试仍失败，调试并修复

**条件**：仅当修改 1 的验证步骤显示测试仍失败时执行。

**调试方向**：
1. 检查 `padding_layout` 的 clamp 行为是否仍影响布局（确认 `workspace.expanded()` 是否真的避免了 clamp）
2. 检查 `flex_measured_size` 是否正确计算 spacer 的 base size 为 0
3. 检查 `CrossAlign::Stretch` 是否在 place 阶段正确拉伸 row 到 window width
4. 使用 `inspect` 打印实际 editor frame 的 x 坐标，与 `editor_content_x` 的返回值对比

## Assumptions & Decisions

1. **三处修改已正确实施**：通过 `git diff` 确认代码与预期一致

2. **第三处修改（`padding_edges` → `expanded()` + `spacer`）是正确的修复**：`padding_layout` 的 clamp 行为（`moui/views/layout_views.mbt:59-62`）会阻止 workspace 填满窗口宽度，用 `expanded()` 替代后 workspace 可以正确拉伸

3. **删除 `markdown_editor_centered_workspace` 是安全的**：已通过 `grep` 确认无任何调用点

4. **不修改 inspector 宽度**：file_sidebar=240, outline=240, info=240, source=292 保持不变

5. **不修改 `editor_content_x`**：已验证其计算与实际布局一致

## Verification Steps

1. **编译检查**：
   ```sh
   moon check --target wasm-gc
   ```

2. **运行 markdown_editor 测试**（验证 8 个失败测试通过）：
   ```sh
   moon test --target wasm-gc -p markdown_editor
   ```

3. **运行完整测试套件**（确保无回归）：
   ```sh
   moon test --target wasm-gc
   ```

4. **视觉验证**（可选，手动 smoke）：
   ```sh
   sh scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke
   ```
   验证：sidebar 紧贴窗口左边缘，outline 紧贴窗口右边缘，editor 水平居中，窗口变宽时 editor 仍在中间，sidebar 与 editor 之间出现空白。

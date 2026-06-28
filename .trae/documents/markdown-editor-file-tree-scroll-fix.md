# 修复 markdown_editor 左侧文件树无法滚动

## 摘要

markdown_editor 左侧文件侧边栏中的目录树（directory tree）在条目过多时无法滚动，列表底部条目不可见。根因是 `tree_view` 调用没有被 `scroll_view` 包裹，而框架的 `tree_view` 本身只是一个无高度上限的 `column`。修复方式参照同函数内 "Recent" 区块已有的 `scroll_view` 模式，为目录树包裹 `scroll_view` 并赋予有界高度，同时相应缩减 "Recent" 区块的高度，使两者在固定容器内共存而不溢出。

## 当前状态分析

### 问题代码位置

- **文件**：`examples/markdown_editor/app/view_inspectors.mbt`
- **函数**：`files_inspector`（第 28-139 行）
- **问题点**：第 100-111 行，`tree_expanded` 分支内直接 `file_rows.push(@views.tree_view(...))`，无 `scroll_view`、无 `height` 约束。

### 框架侧确认

- `moui/views/data_tree.mbt` 第 2-29 行：`tree_view` 签名只有 `width?`，没有 `height?`，内部是 `column(rows, ...)`，高度由内容决定、无上限、无滚动。
- `moui/views/pkg.generated.mbti` 确认 `scroll_view` 接受 `height?` 参数，是标准滚动容器。

### 同函数内已有的正确模式（参照模板）

| 区块 | 行号 | 滚动内容 | 高度公式 |
|---|---|---|---|
| Recent 区块 | 41-49 | `file_sidebar_recent_rows(...)` | `max(0, height - 180.0)` |
| Outline 区块 | 418-422 | `outline_rows(...)` | `max(0, height - 52.0)` |
| Info 区块 | 212-216 | info 行列表 | `max(0, height - 52.0)` |
| **目录树** | **102-110** | **`@views.tree_view(...)`** | **无 scroll_view（BUG）** |

### 高度常量语义

`files_inspector` 收到的 `height` 为视口高度（由 `view_chrome.mbt` 计算 `window_height - 84.0`，再经 `view_editor_surface.mbt:891-895` 传入）。

现有 `recent_content` 的 `height - 180.0` 公式中，`180.0` 代表**除目录树和 recent_content 之外的所有固定头部开销**，包括：
- padding top/bottom（`md` 各一）
- "Files" 文本（24）
- 当前文档标签（30）
- "Pick/Change folder" 按钮（34）
- "Folder" + 折叠按钮行（24）
- "Recent" 文本（24）
- 各项之间的 `xs` 间距

即：`available_for_tree_and_recent = height - 180.0`。当前这段可用空间全部给了 recent_content，目录树则无界溢出，把 recent 及后续内容顶出容器可视区。

### 相关状态

- `file_tree_expanded`（`app.mbt:69,326`）默认 `true`，所以一打开侧边栏并选好工作目录后目录树立即全展开，最容易触发溢出。
- `directory_tree_items`（`app.mbt:68,299`）：目录条目数据源。
- `expanded_tree_paths`：单节点展开状态。
- 测试：`examples/markdown_editor/app/editor_app_file_sidebar_wbtest.mbt` 第 62-115 行验证目录树展开后能渲染 README.md / Journal.md；第 133-147 行验证折叠态切换。

## 提议修改

### 修改 1：为目录树包裹 scroll_view 并分配高度

**文件**：`examples/markdown_editor/app/view_inspectors.mbt`

在 `files_inspector` 中，将第 100-111 行 `tree_expanded` 分支里的 `@views.tree_view(...)` 调用用 `scroll_view` 包裹，并传入有界 `height`。

新增局部变量计算目录树滚动高度。为使目录树获得主要空间、同时给 "Recent" 区块保留约 80px（可显示 2-3 条最近文件），采用如下分配：

- `tree_scroll_height = markdown_editor_max_double(0.0, height - 260.0)`
  - `260.0 = 180.0（固定头部开销）+ 80.0（预留给 recent_content 的最小高度）`
- `recent_scroll_height = markdown_editor_max_double(0.0, height - 180.0 - tree_scroll_height)`
  - 当 `height > 260` 时，`recent_scroll_height` 稳定为约 80px；目录树占用剩余空间。

#### 具体改动

**A. 在 `files_inspector` 内、`recent_content` 计算之前，新增 `tree_scroll_height` 局部变量**

由于 `recent_content`（第 36-50 行）在 `file_rows` 构建之前就计算了，需要把 `tree_scroll_height` 提前到 `recent_content` 计算之前，以便 `recent_content` 的高度能引用它。调整顺序：

1. 在 `let content_width = ...`（第 34 行）之后，新增：
   ```moonbit
   let tree_scroll_height = markdown_editor_max_double(0.0, height - 260.0)
   ```
2. 将 `recent_content` 的 `scroll_view` 高度（第 48 行）从：
   ```moonbit
   height=markdown_editor_max_double(0.0, height - 180.0),
   ```
   改为：
   ```moonbit
   height=markdown_editor_max_double(0.0, height - 180.0 - tree_scroll_height),
   ```

**B. 将第 102-110 行的 `tree_view` 调用用 `scroll_view` 包裹**

把：
```moonbit
@views.tree_view(
  app.directory_tree_items.get(),
  expanded=app.expanded_tree_paths.get(),
  on_select=Some(id => SelectTreePath(id)),
  on_toggle=Some(id => ToggleTreePath(id)),
  theme~,
  width=content_width,
)
```
改为：
```moonbit
scroll_view(
  @views.tree_view(
    app.directory_tree_items.get(),
    expanded=app.expanded_tree_paths.get(),
    on_select=Some(id => SelectTreePath(id)),
    on_toggle=Some(id => ToggleTreePath(id)),
    theme~,
    width=content_width,
  ),
  width=content_width,
  height=tree_scroll_height,
)
```

注意：`tree_view` 的 `width` 参数保留，用于内部行布局；外层 `scroll_view` 的 `width=content_width` 与现有 Recent 区块一致。

### 不修改的部分

- 框架侧 `moui/views/data_tree.mbt` 的 `tree_view` 不变（它本就不负责滚动，应由调用方按需包裹）。
- `file_tree_expanded` 默认值不变。
- 其它 inspector（Outline / Info / source_preview）不变。

## 假设与决策

1. **目录树优先占用空间**：当目录树展开条目多时，它是最需要滚动的区域，因此把 `height - 260` 的大头分给它，Recent 保留固定 ~80px。若 Recent 条目也很多，用户可在其独立滚动区内查看；两者互不挤占。
2. **常量 260 的依据**：`180` 已是本函数现有 recent 高度公式的隐含固定开销常量；额外 `80` 是给 recent_content 的最小预留（约 2-3 行可见）。该值与现有 `xs` 间距和 30px 行高量级一致。
3. **不重构为单一滚动区**：保留目录树与 Recent 各自独立滚动，避免嵌套 scroll_view 的复杂性，且符合本函数已有的分区设计。
4. **`markdown_editor_max_double` 已存在**（`view_editor_surface.mbt:731`），本文件已在第 48 行使用，无需新增 helper。

## 验证步骤

1. **类型检查**：
   ```sh
   moon check --package-markdown-editor
   ```
   或在仓库根目录 `moon check`。

2. **运行既有侧边栏测试**（应继续通过，目录树展开后仍渲染 README.md/Journal.md）：
   ```sh
   moon test --package markdown_editor -f editor_app_file_sidebar_wbtest
   ```
   重点用例：
   - `markdown editor file sidebar renders optional directory tree`
   - `markdown editor tree toggle preserves expansion order`
   - `markdown editor file tree starts expanded`
   - `markdown editor toggle file tree fold hides tree`

3. **运行 markdown_editor 全量测试**确认无回归：
   ```sh
   moon test --package markdown_editor
   ```

4. **手动 smoke（可选但推荐）**：运行 markdown_editor 示例，打开左侧文件侧边栏，选择一个含较多文件/子目录的工作目录，展开目录树节点，验证：
   - 目录树可在自身区域内滚动，底部条目可见。
   - "Recent" 区块仍可见且可独立滚动。
   - 折叠目录树（点 ▾/▸）后布局正常，Recent 区块高度保持稳定。
   - 窗口缩放时两个滚动区高度自适应、不溢出容器。

   示例运行入口参考 `scripts/` 下的 macos/web smoke 脚本或 `moui_devtools`。

5. **如修改了 `moui_theme` 或 `examples/design_systems`** 才需要 `--theme-diagnostics`；本改动不涉及，可跳过。

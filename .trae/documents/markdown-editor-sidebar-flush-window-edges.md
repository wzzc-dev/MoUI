# 让 markdown_editor 左侧文件树和右侧大纲紧贴窗口边框（Typora 风格）

## 摘要

将 markdown_editor 的左侧文件侧边栏和右侧大纲面板改为紧贴窗口左右边框（类似 Typora），中间编辑器保持水平居中。改动集中在三个文件：清零 chrome 外层左右 padding、去掉 workspace 的水平居中逻辑、在 `editor_source_layout` 的 row 中用两个等权 `spacer` 把 editor 夹在中间，并清零贴边 inspector 的圆角。

## 当前状态分析

### 间距来源（三层）

1. **Chrome 外层 padding**（`view_chrome.mbt` 第 62-68 行）：
   ```
   padding_edges(workspace, top=0.0, right=spacing_scale.xl=24.0,
                  bottom=spacing_scale.xl=24.0, left=spacing_scale.md=12.0)
   ```
   - 左侧 12.0、右侧 24.0 直接塞在窗口边缘与 workspace 之间。

2. **workspace 水平居中**（`view_chrome.mbt` 第 225-256 行 `markdown_editor_centered_workspace`）：
   - 当窗口宽度 > workspace 宽度时，左右各加 `(window_width - workspace_width) / 2.0`。
   - 即便清零 chrome padding，居中仍会把 sidebar 推离窗口边缘。

3. **inspector 圆角**（`view_inspectors.mbt` 第 142 行 file sidebar、第 456 行 outline）：
   - `corner_radius=theme.radius_scale.sm = 4.0`。
   - 贴窗口边时圆角会露出窗口背景的"小三角"，不符合 Typora 观感。

### editor_source_layout 当前结构

`view_editor_surface.mbt` 第 890-922 行：
```
side_children = [files_inspector?, editor_with_indicator,
                 document_info_inspector?, outline_inspector?, source_inspector?]
row(side_children, spacing=spacing_scale.lg=16.0, align=CrossAlign::Start)
```
- children 按内容宽度排列，row 宽度 = children 宽度之和 + spacing。
- row 整体被 `markdown_editor_centered_workspace` 居中。

### MoUI flex 能力（已确认）

- `row` 有 `justify?: MainAlign` 参数，但当存在 flex 子项（`spacer(weight>0)` 或 `expanded/flexible`）时 `justify` 失效，位置由 flex 权重决定。
- `spacer(min_length?, weight?)`：`weight>0` 时是 flex spacer，base size=0，按权重吃剩余空间。
- **惯用模式**（`view_chrome.mbt` 第 318-330 行标题栏已用）：`row([spacer(weight=1.0), center_content, spacer(weight=1.0)])` 实现内容居中、两侧贴边。

## 提议修改

### 修改 1：清零 chrome 左右 padding

**文件**：`examples/markdown_editor/app/view_chrome.mbt`
**位置**：第 62-68 行

把：
```moonbit
let padded = padding_edges(
  workspace,
  top=0.0,
  right=theme.spacing_scale.xl,
  bottom=theme.spacing_scale.xl,
  left=theme.spacing_scale.md,
)
```
改为：
```moonbit
let padded = padding_edges(
  workspace,
  top=0.0,
  right=0.0,
  bottom=theme.spacing_scale.xl,
  left=0.0,
)
```

**原因**：消除窗口边缘与 workspace 之间的左右内边距，让 sidebar/outline 有机会贴窗口边。保留 `bottom=xl` 给状态栏呼吸空间；`top=0.0` 维持 chrome 标题栏贴顶。

### 修改 2：去掉 workspace 水平居中，让其占满窗口宽度

**文件**：`examples/markdown_editor/app/view_chrome.mbt`
**位置**：第 79 行

把：
```moonbit
outer_children.push(markdown_editor_centered_workspace(padded).expanded())
```
改为：
```moonbit
outer_children.push(padded.expanded())
```

**原因**：`markdown_editor_centered_workspace` 会在窗口宽于 workspace 时把整体居中，导致 sidebar 离开左边缘。直接 `padded.expanded()` 让 workspace 占满窗口宽度，sidebar/outline 由后续 row 内的 flex 控制贴边。

**注**：`markdown_editor_centered_workspace` 函数（第 225-256 行）不再被调用，可保留不删（避免破坏其它潜在引用），也可一并删除。本计划选择保留以缩小改动面。

### 修改 3：在 row 中用双等权 spacer 把 editor 居中、sidebar/outline 贴边

**文件**：`examples/markdown_editor/app/view_editor_surface.mbt`
**位置**：第 890-922 行（`editor_source_layout` 末尾的 side_children 构建与 row 调用）

把：
```moonbit
let side_children : Array[@moui.View[MarkdownEditorMsg]] = []
if show_files {
  side_children.push(
    files_inspector(app, session, theme, height=viewport_height),
  )
}
side_children.push(editor_with_indicator)
if show_info {
  side_children.push(
    document_info_inspector(session, theme, height=viewport_height),
  )
}
if show_outline {
  side_children.push(
    outline_inspector(
      app,
      session,
      selection,
      theme,
      height=viewport_height,
    ),
  )
}
if show_source {
  side_children.push(
    source_inspector(session.source, theme, height=viewport_height),
  )
}
let editor_and_sidebars = row(
  side_children,
  spacing=theme.spacing_scale.lg,
  align=@views.CrossAlign::Start,
)
```
改为：
```moonbit
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
    outline_inspector(
      app,
      session,
      selection,
      theme,
      height=viewport_height,
    ),
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
```

**原因与行为**：
- `spacer(weight=1.0)` 两个等权 flex 子项平分 `slack`（剩余空间），把 `editor_with_indicator` 居中在 row 内。
- `files_inspector` 在最左（无左侧 spacer），自然贴窗口左边框。
- `outline_inspector`（及紧邻其左的 `info`/`source`）在最右，自然贴窗口右边框。
- 窗口变宽时，两个 spacer 吸收多出的空间，editor 仍居中，sidebar 与 editor 之间出现空白——符合 Typora 观感。
- `spacing=0.0`：因为贴边时 sidebar 与窗口边缘不应有额外间距；sidebar 与 editor 之间的间距由 spacer 自身提供。
- `align=CrossAlign::Stretch`：让 sidebar/editor/outline 都填满 row 高度（与 chrome 视口高度一致），避免顶部对齐时下方留白。
- 当 sidebar 或 outline 隐藏时，对应侧的 inspector 不入栈，但两侧 spacer 仍存在，editor 仍居中。

**关于 editor 宽度**：保留现有 `markdown_editor_primary_editor_width` 逻辑（有 sidebar 时 `side_editor_width`，无 sidebar 时 `page_width=780`）。editor 自身宽度仍由内部测量决定，不主动 flex 增长；剩余空间全部交给两个 spacer 吸收，所以 editor 始终居中且宽度稳定。

**`spacer` 导入**：确认 `app.mbt` 第 10 行已有 `scroll_view` 等 import；需检查 `spacer` 是否在已有 import 列表中。若未导入，需在对应 import 语句添加 `spacer`。

### 修改 4：清零贴边 inspector 的圆角

**文件**：`examples/markdown_editor/app/view_inspectors.mbt`

**A. file sidebar**（第 142 行 `files_inspector` 容器）：
把：
```moonbit
corner_radius=theme.radius_scale.sm,
```
改为：
```moonbit
corner_radius=0.0,
```

**B. outline**（第 456 行 `outline_inspector` 容器）：
把：
```moonbit
corner_radius=theme.radius_scale.sm,
```
改为：
```moonbit
corner_radius=0.0,
```

**原因**：贴窗口边框时圆角会露出窗口背景的小三角，清零后 sidebar/outline 与窗口边无缝衔接，符合 Typora 观感。

**不修改的 inspector**：`document_info_inspector`（第 215 行附近）和 `source_inspector` 不直接贴窗口边框（它们在 outline 左侧），保留 `corner_radius=theme.radius_scale.sm` 不变。

## 不修改的部分

- `markdown_editor_centered_workspace` 函数定义保留不删（避免破坏潜在引用；它只是不再被 `root` 调用）。
- `markdown_editor_workspace_width` 计算（view_chrome.mbt 第 190-218 行）不变——它仍用于状态栏等其它地方的宽度参考。
- 宽度常量（`markdown_editor_file_sidebar_width=240`、`markdown_editor_outline_inspector_width=240`、`markdown_editor_page_width=780` 等）不变。
- inspector 内层 `padding_edges`（top=md, right=sm, bottom=md, left=sm）不变——这是 inspector 内部留白，与贴窗口边无关。
- `editor_with_indicator` 的 `shadow(page_shadow)`（第 886 行）保留——浮动页卡的阴影效果仍有意义。

## 假设与决策

1. **editor 不主动 flex 增长**：保留现有固定宽度逻辑（`side_editor_width` 或 `page_width`）。用户提到的"editor 宽度随窗口变化有最大/最小宽度"通过现有 `markdown_editor_primary_editor_width`（依 sidebar 显隐切换 `side_editor_width` / `page_width`）已部分满足；本计划不引入 `frame(min_width, max_width)` 约束，避免与 editor 内部测量逻辑冲突。若后续需要真正的弹性 editor 宽度，可再用 `frame` 包裹。
2. **右侧 inspector 一起贴右**：`info`/`source` 紧邻 `outline` 左侧排列，整组贴窗口右边框。用户只点名 file tree 和 outline，但 info/source 不应被推到中间，否则布局错乱。
3. **`markdown_editor_centered_workspace` 保留**：不删除函数定义，仅去掉调用，缩小改动面。
4. **`CrossAlign::Stretch`**：让 sidebar/editor/outline 填满 row 高度。原 `CrossAlign::Start` 会让子项顶部对齐、下方留白，贴边时观感不佳。
5. **`spacing=0.0`**：贴边时 sidebar 与窗口边缘不应有额外间距。sidebar 与 editor 之间的间距由 spacer 吸收的空间提供。

## 验证步骤

1. **类型检查**：
   ```sh
   cd examples/markdown_editor && moon check
   ```
   预期 0 errors（原有未使用构造器警告与本次改动无关）。

2. **运行 markdown_editor 全量测试**：
   ```sh
   cd examples/markdown_editor && moon test
   ```
   重点用例：
   - `editor_app_file_sidebar_wbtest.mbt`：侧边栏渲染、目录树展开、折叠切换。
   - 任何与 outline / info / source inspector 显隐相关的测试。
   - chrome 布局相关测试（若有）。

3. **检查 `spacer` 导入**：
   - 若 `moon check` 报错 `spacer` 未定义，在 `app.mbt` 的 import 列表中添加 `spacer`（与 `scroll_view` 同源 `moui/views`，通常已通过 `@views.` 或直接导入）。

4. **手动 smoke（推荐）**：运行 markdown_editor 示例，验证：
   - 左侧文件树紧贴窗口左边框，无缝隙、无圆角小三角。
   - 右侧大纲紧贴窗口右边框。
   - 中间编辑器水平居中。
   - 窗口变宽时，editor 仍居中，sidebar 与 editor 之间出现空白。
   - 切换 sidebar/outline/info/source 显隐时，editor 始终居中。
   - zen 模式（所有 sidebar 隐藏）下 editor 居中且占满可用宽度。
   - chrome 标题栏与状态栏不受影响。

   示例运行入口参考 `scripts/` 下的 macos/web smoke 脚本或 `moui_devtools`。

5. **回归检查**：确认 `markdown_editor_centered_workspace` 不再被调用后，没有其它地方依赖它的居中行为（grep 确认）。

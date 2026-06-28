# Markdown Editor 布局说明

本文档描述 `markdown_editor` 示例应用的完整布局结构，包括窗口层级、各组件尺寸约束和 Typora 风格的贴边布局实现。

## 1. 整体窗口结构（Stack 栈叠）

窗口根视图是一个 `@views.stack`，自下而上叠加四层：

```
┌──────────────────────────────────────────────────────────┐
│ [Layer 1] window_bg       FillRect 填充窗口背景色            │
│ [Layer 2] outer column    垂直 Stretch，填满窗口宽度          │
│ [Layer 3] toast_layer     顶部对齐（x=0.5, y=0.0）           │
│ [Layer 4] confirm_dialog  完全居中（x=0.5, y=0.5）           │
└──────────────────────────────────────────────────────────┘
```

- **window_bg**：`custom_children_layout` 实现，measure 时取 `constraints.max`，place 时返回空数组（只填充背景，不放置子组件）。
- **outer column**：主内容区，包含 chrome、workspace、status_bar。
- **toast_layer**：浮层提示，顶部居中。
- **confirm_dialog**：确认对话框，完全居中。

## 2. outer column（垂直 Stretch，spacing=0）

```
┌──────────────────────────────────────────────────────────┐
│ chrome                       28px 高，Typora 风格标题栏     │
├──────────────────────────────────────────────────────────┤
│ workspace.expanded()         flex weight=1，填满剩余高度    │
├──────────────────────────────────────────────────────────┤
│ spacer                       底部 padding（24px）          │
├──────────────────────────────────────────────────────────┤
│ bottom_status_bar            20px 高，叠加 tree_button      │
└──────────────────────────────────────────────────────────┘
```

**关键设计**：
- chrome 和 status_bar 在 workspace padding **之外**，右侧按钮能直达窗口边缘（Typora 风格）。
- workspace 使用 `.expanded()` 而非 `padding_edges` 包裹，避免 `padding_layout` 将子组件 frame 宽度 clamp 到 intrinsic size，确保 row 能填满窗口宽度。
- 底部 padding 用 `spacer(weight=0)` 实现，而非 `padding_edges`，原因同上。

## 3. chrome 标题栏（28px 高）

```
┌──────────────────────────────────────────────────────────┐
│ ← 78px 空白 →  Title ↓ ·  ← spacer(weight=1) →  [Outline] │
│  (交通灯区域)    (点击切换 doc info)          (右侧按钮组)   │
└──────────────────────────────────────────────────────────┘
```

- 左侧 78px 空白：为 macOS 交通灯预留空间。
- `Title ↓`：点击可切换 document_info_inspector 显示状态。
- 右侧按钮组：Outline、Source、Files、Format、Find、Zen 等切换按钮。

## 4. workspace column（垂直 Stretch，spacing=sm=8px）

按顺序排列（每项之间 8px 间距）：

1. `find_bar`（仅当 `find_visible` 时）— 42px 高
2. `format_palette`（仅当 `format_palette_visible` 时）— 240px 高
3. `editor_source_layout`（核心编辑区）

## 5. editor_source_layout（核心编辑区）

### 5.1 外层 column（spacing=md，align=Stretch）

```
┌──────────────────────────────────────────────────────────┐
│ editor_and_sidebars (row, Stretch)                       │
├──────────────────────────────────────────────────────────┤
│ target_bar (仅当 show_source 且 target_kind != PlainSelection) │
└──────────────────────────────────────────────────────────┘
```

### 5.2 editor_and_sidebars 的 row（水平 Stretch，spacing=0）

这是 Typora 贴边布局的核心。row 使用 `CrossAlign::Stretch`，所有子组件垂直方向拉伸到 row 高度（= viewport_height）。

#### 默认状态（无 inspector，window=980）

```
┌──────────────────────────────────────────────────────────┐
│  spacer(1.0)  │        editor (780px)        │  spacer(1.0)  │
│    100px      │                              │    100px      │
└──────────────────────────────────────────────────────────┘
                          ↑ 居中
```

- editor 宽度 = `page_width = 780px`
- 两个等权 spacer 吸收剩余空间，editor 水平居中

#### show_files only（window=980）

```
┌──────────────────────────────────────────────────────────┐
│ files(240) │ spacer(1) │   editor (640)   │ spacer(1)      │
│            │   50px    │                  │   50px         │
└──────────────────────────────────────────────────────────┘
                                    ↑ 居中于剩余空间
```

- editor 宽度 = `side_editor_width = 640px`
- files_inspector 紧贴窗口左边缘

#### show_files + show_outline（window=980）

```
┌──────────────────────────────────────────────────────────┐
│ files(240) │spacer│ editor (640) │spacer│ outline(240)    │
│            │  0   │              │  0   │                 │
└──────────────────────────────────────────────────────────┘
              ↑ slack=0，spacer 宽度为 0，editor 紧贴两侧 inspector
```

#### 全部 inspector 可见（window=980）

```
┌──────────────────────────────────────────────────────────┐
│files(240)│s│editor(640)│s│info(240)│outline(240)│source(292)│
│          │0│           │0│         │           │           │
└──────────────────────────────────────────────────────────┘
            ↑ 总宽度 240+640+240+240+292=1652 > 980，spacer=0，会溢出
```

### 5.3 editor_with_indicator（Stack）

```moonbit
@views.stack([
  editor_view,
  markdown_editor_scroll_indicator(...),
  markdown_editor_format_bubble_overlay(...),
])
```

- `editor_view`：核心编辑器（或 `floating_target_palette` 包装）
- `scroll_indicator`：滚动指示器（offset_y <= 0 时返回 `empty()`）
- `format_bubble_overlay`：格式气泡浮层（无选区时返回 `empty()`）

stack 让所有子组件 frame 拉伸到 stack size（= editor_view size）。

### 5.4 editor_page 装饰

```moonbit
editor
  .shadow(markdown_editor_page_shadow())   // 页面阴影
  .corner_radius(theme.radius_scale.sm)     // 圆角
  .repaint_boundary()                       // 重绘边界
```

## 6. Inspector 规格

| Inspector | 宽度 | corner_radius | 位置 | 显示条件 |
|---|---|---|---|---|
| files_inspector | 240px | 0.0 | 紧贴窗口左边缘 | `show_files` |
| document_info_inspector | 240px | 默认 | 右侧 | `show_info` |
| outline_inspector | 240px | 0.0 | 紧贴窗口右边缘 | `show_outline` |
| source_inspector | 292px | 默认 | 最右侧 | `show_source` |

**editor 宽度规则**：
- 有任意 inspector 时：`side_editor_width = 640px`
- 无 inspector 时：`page_width = 780px`

## 7. bottom_status_bar（20px 高）

```
┌──────────────────────────────────────────────────────────┐
│ 🌳 ←spacer(1)→  Title / Saved / Block / Word count  ←spacer(1)→ │
│ ↑tree_button    ↑ text (固定宽度)            ↑               │
│ (overlay叠加)                                            │
└──────────────────────────────────────────────────────────┘
```

- `tree_button`（文件树切换）通过 overlay 叠加在左侧 26px 区域
- 状态文字通过两个等权 `spacer(weight=1.0)` 左右居中
- status_bar 在 workspace padding 之外，直达窗口边缘

## 8. viewport_height 计算

```moonbit
let viewport_height = markdown_editor_max_double(320.0, window_height - 84.0)
```

- 84px = chrome(28) + status_bar(20) + bottom_padding(24) + spacing(8) + safety(4)
- 最小 320px，避免窗口过小时编辑区消失

## 9. 布局特性总结

1. **Typora 风格贴边**：sidebar 贴左（`corner_radius=0.0`）、outline 贴右（`corner_radius=0.0`），无圆角，无 chrome padding
2. **editor 水平居中**：通过两个等权 `spacer(weight=1.0)` 包裹，窗口变宽时 editor 始终居中
3. **workspace 填满窗口宽度**：用 `expanded()` 替代 `padding_edges`，避免 `padding_layout` clamp 到 intrinsic 宽度
4. **底部 padding 用 spacer**：`spacer(weight=0, min_length=xl)` 提供 24px 底部间距，避免 `padding_layout` 的 clamp 行为
5. **chrome/status_bar 在 padding 外**：保持按钮直达窗口边缘

## 10. 关键文件

- [view_chrome.mbt](file:///Volumes/Data/Code/moon/MoUI/examples/markdown_editor/app/view_chrome.mbt)：chrome、status_bar、outer column、workspace 组装
- [view_editor_surface.mbt](file:///Volumes/Data/Code/moon/MoUI/examples/markdown_editor/app/view_editor_surface.mbt)：editor_source_layout、editor_page、target_bar、inspectors
- [view_inspectors.mbt](file:///Volumes/Data/Code/moon/MoUI/examples/markdown_editor/app/view_inspectors.mbt)：files/outline/info/source inspector 实现
- [view_toolbar.mbt](file:///Volumes/Data/Code/moon/MoUI/examples/markdown_editor/app/view_toolbar.mbt)：chrome 内的按钮组
- [view_toasts.mbt](file:///Volumes/Data/Code/moon/MoUI/examples/markdown_editor/app/view_toasts.mbt)：toast_layer 和 confirm_dialog

## 11. 布局调试要点

### 11.1 padding_layout 的 clamp 陷阱

`padding_layout`（`moui/views/layout_views.mbt`）在 place 阶段会将 child frame 宽度 clamp 到 `min(available.max.width, child_size.width)`：

```moonbit
width=view_min_double(
  view_max_double(0.0, available.max.width),
  child_size.width,
),
```

当 child 的 intrinsic width（如 editor 的 page_width=780）小于 available width（如 window=980）时，child frame 会被 clamp 到 780，导致 row 无法填满窗口宽度。

**解决方法**：用 `expanded()` + `spacer(weight=0)` 替代 `padding_edges`，让 workspace 通过 `FlexibleModifier` 填满可用空间。

### 11.2 CrossAlign::Stretch 的作用

- **水平 row 的 Stretch**：让所有子组件垂直拉伸到 row 高度（= viewport_height）
- **垂直 column 的 Stretch**：让所有子组件水平拉伸到 column 宽度（= window_width）

### 11.3 spacer 的 weight 语义

- `weight > 0`：base size = 0，吸收 slack 空间（弹性 spacer）
- `weight = 0`：base size = `min_length`，固定尺寸（占位 spacer）

## 12. Appearance 规格

```
PaperAppearance:
  page_width = 780
  side_editor_width = 640
  file_sidebar = 240
  outline = 240
  info = 240
  source = 292
```

所有 appearance（Paper/Warm/Wide）共享相同的尺寸规格，仅颜色和字体不同。

# Plan: MoUI Studio Markdown 插件——.md 预览/编辑（MoMark 引擎接入）

- **Status**: active（v1 已落地：插件包 + .md 路由 + 差分测试;插件 2/2、app 371/371 绿）
- **Goal**: 资源管理器点开 `.md` 文件时进入真正的 Markdown 编辑面（MoMark
  同款引擎），不再是 plain mono 文本;编辑沿用工程文件草稿通道（脏标记/保存
  写盘零新机制）。
- **Non-goals**: WYSIWYG 格式气泡/ folding/大纲（momark 应用层的 chrome）;
  图片/表格高阶渲染增强;插件运行时安装。
- **插件形态（诚实边界）**: 本插件是**无状态视图贡献**——面板状态
  （草稿/脏标记/光标）本来就住在壳的 `open_project_file`，插件不复制状态
  切片;Feature 域留空与 terminal 插件先例一致（状态由壳消息驱动）。
  PluginDescriptor 注册随 G7.3 插件管理页一起接线。

## 已核实事实

| 事实 | 锚点 |
|---|---|
| `moui_richtext.markdown_editor(value~/on_input?/...)` 是 momark 编辑面的引擎（受控、块级格式渲染），native+wasm-gc 兼容 | `moui_richtext/pkg.generated.mbti:23` |
| `markdown_editor_format(source, base?)` + `rich_text_document_height(doc, font, block_width?)` 可算内容全高（外层 scroll_view 需要） | `mbti:35/113` |
| 工程文件面板已具备：草稿 EditProjectFile / 脏 ● / SaveProjectFile 写盘 / web 文件服务不可用显式降级 | `app/code_view.mbt:38`、`update_shell.mbt:87` |
| app 已依赖 moui_richtext;momark 是独立应用形态（native-only），不作依赖 | `app/moon.pkg` |

## 设计

1. **plugins/markdown 包**（native+wasm-gc）：
   - `markdown_file_view[Msg](content~, on_input~, width~, height~, font~,
     foreground~, placeholder_color~, background~, cursor_color~, key?)`：
     受控 `markdown_editor`（MoMark 引擎）+ 内容全高估算
     （`markdown_editor_format` → `rich_text_document_height`，外层滚动由壳
     的 scroll_view 承担——与工程文件编辑器同一滚动方案）。
   - 零 app 依赖：字体/颜色全部参数注入（壳传 studio 主题）。
2. **壳接线**：`code_view` 的 `open_project_file` 分支按 `.md` 后缀分流——
   markdown 面板 vs 既有 mono 编辑器;on_input 接 `EditProjectFile`（草稿/
   脏标记/保存通道原样复用）。
3. **验收**：插件 wbtest 证明渲染管线（内容文本出现在 draw 命令中、高度
   随内容增长）;app wbtest 差分证明 `.md` 走格式渲染（`#` 标记被消费）
   而 `.mbt` 仍原样显示。

## 实施记录（2026-10-07）

- plugins/markdown：markdown_file_view（受控 markdown_editor + 内容全高估算）+ 2 wbtest（渲染消费 `#` 标记 / 高度随内容增长）。
- app：code_view 的 open_project_file 分支按 .md 后缀分流（project_file_body / project_file_body_height），on_input 接 EditProjectFile,保存通道零改动。

## 边界声明

- `markdown_editor` 不支持光标/选区受控回传（与 mono 编辑器不同）——工程
  文件光标状态对 `.md` 不参与;这是引擎现能力边界,如实记录不遮掩。
- 预览/源码双模式、WYSIWYG 格式气泡：后续增强（先跑通「点开即所见即所改」）。

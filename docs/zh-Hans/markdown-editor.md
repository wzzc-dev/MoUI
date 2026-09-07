# Markdown 编辑器

所见即所得的类 Typora Markdown 编辑器（MoMark）已独立成仓库：
[wzzc-dev/MoMark](https://github.com/wzzc-dev/MoMark)。它基于已发布的
`wzzc-dev/moui` 与 `wzzc-dev/moui_richtext` 包构建，编辑模型、会话渲染与各平台
入口均在 MoMark 仓库的 README 与文档中说明。

本仓库保留 MoMark 所消费的框架侧能力：

- `moui_richtext/facade.mbt`：公共富文本编辑器包装器（`markdown_editor`、
  `controlled_markdown_session_editor`）。
- `moui_richtext/rich_text_document.mbt` 加 `moui_richtext/rich_text_editor.mbt`：
  富文本文档模型、绘制、几何、选择和编辑逻辑。
- `moui/core/text_editing.mbt` 加 `moui/core/text_layout.mbt`：平台中立的文本编辑
  原语、`TextSystem`，以及纯文本控件和富文本插件共享的段落布局契约。

历史上的 MoUI Markdown Editor 示例已移除。实际应用、应用层编辑模型与
平台命令请见 MoMark 仓库。

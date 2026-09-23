# Markdown 编辑器

所见即所得的类 Typora Markdown 编辑器（MoMark）位于自有仓库
[wzzc-dev/MoMark](https://github.com/wzzc-dev/MoMark)，并作为 `examples/momark`
Git 子模块挂载到本工作区。它基于已发布的 `wzzc-dev/moui` 与
`wzzc-dev/moui_richtext` 包构建，编辑模型、会话渲染与各平台入口均在 MoMark
仓库的 README 与文档中说明。

`examples/momark` 是 `moon.work` 成员，因此 `moon check examples/momark` 会基于
本仓库检出内容而非已发布包来构建该应用。子模块各自固定上游提交；需要跟进
MoMark 仓库更新时执行 `git submodule update --remote examples/momark`。

本仓库保留 MoMark 所消费的框架侧能力：

- `moui_richtext/facade.mbt`：公共富文本编辑器包装器（`markdown_editor`、
  `controlled_markdown_session_editor`）。
- `moui_richtext/rich_text_document.mbt` 加 `moui_richtext/rich_text_editor.mbt`：
  富文本文档模型、绘制、几何、选择和编辑逻辑。
- `moui/core/text_editing.mbt` 加 `moui/core/text_layout.mbt`：平台中立的文本编辑
  原语、`TextSystem`，以及纯文本控件和富文本插件共享的段落布局契约。

历史上的 MoUI Markdown Editor 示例已在 MoMark 独立成仓库时移除。实际应用、应用层
编辑模型与平台命令现在通过 `examples/momark` 子模块随本工作区一起提供；其独立文档
请见 MoMark 仓库。

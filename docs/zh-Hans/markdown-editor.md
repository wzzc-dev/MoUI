# Markdown 编辑器

所见即所得的类 Typora Markdown 编辑器（MoMark）位于自有仓库
[wzzc-dev/MoMark](https://github.com/wzzc-dev/MoMark)。它基于已发布的
`wzzc-dev/moui` 与 `wzzc-dev/moui_richtext` 包构建，编辑模型、会话渲染与各平台
入口均在 MoMark 仓库的 README 与文档中说明。

MoMark **不再**是本仓库的 submodule 或 `moon.work` 成员。需要修改 MoUI 时使用
[vendor 工作流](vendor-workflow.md)：在 MoMark checkout 里 vendor MoUI，双方验证
后把框架改动作为 MoUI PR 提回。

本仓库保留 MoMark 所消费的框架侧能力：

- `moui_richtext/facade.mbt`：公共富文本编辑器包装器（`markdown_editor`、
  `controlled_markdown_session_editor`）。
- `moui_richtext/rich_text_document.mbt` 加 `moui_richtext/rich_text_editor.mbt`：
  富文本文档模型、绘制、几何、选择和编辑逻辑。
- `moui/core/text_editing_composition.mbt` 加 `moui/core/text_layout.mbt`：平台中立的文本编辑
  原语、`TextSystem`，以及纯文本控件和富文本插件共享的段落布局契约。

## 共享 Markdown chrome（`moui_markdown`）

引擎之上另有宿主中立的 chrome addon：`wzzc-dev/moui_markdown`。它把 MoMark
应用层中不依赖该应用模型与消息类型的部分提取出来，任何 MoUI Markdown 界面
（包括 MoUI Studio 的 `.md` 面板）都能复用同一套行为：

- **查找/替换**：大小写敏感、全词、正则匹配，光标词种子，感知选区的
  previous/next/active index 计算，单处替换与全部替换，以及状态文案。
- **大纲**：折叠过滤、标签、缩进几何、活动标题跟踪和阅读时间标签。
- **格式面板**：quick-format 目录、查询过滤，以及 palette action id 到
  `MarkdownEditorCommand` 的映射。
- **文档信息**：从 source + blocks、session 或 snapshot 派生的字符/标题/
  段落/列表/任务/引用/代码/表格/链接/图片/脚注统计。
- **HTML 导出**：独立静态 HTML 文档，以及块/行内渲染与转义 helper。
- **Msg-generic chrome 视图**：大纲面板、查找替换栏、格式面板、文档信息
  面板。所有视图都通过 theme、文案与回调参数注入，因此 MoMark、Studio 或
  第三方宿主都能实例化，而无需依赖 app package。

分层是刻意的：`moui_richtext` 保持对富文本的通用性，`moui_markdown` 在其上
拥有 Markdown 专有的 chrome 与纯函数 helper。两者都支持 native 与 `wasm-gc`，
消费方一起 pin。

历史上的 MoUI Markdown Editor 示例已在 MoMark 独立成仓库时移除。实际应用、应用层
编辑模型与平台命令现在由外部仓库 `wzzc-dev/MoMark` 提供；其独立文档请见该仓库。

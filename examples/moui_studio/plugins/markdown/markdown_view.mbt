///|
/// Markdown 插件·.md 文件面板（G3）。
///
/// 无状态视图贡献：面板状态（草稿/脏标记/光标）住在壳的
/// `open_project_file`，本插件不复制状态切片（terminal 插件先例——状态由
/// 壳消息驱动）。渲染基于 `wzzc-dev/moui_richtext` 的 `markdown_editor`
/// （MoMark 编辑面同款引擎）：受控、块级格式渲染，`on_input` 把新文本
/// 送回壳的草稿通道（EditProjectFile → 脏 ● → SaveProjectFile 写盘）。
///
/// 零 app 依赖：字体/颜色全部由壳注入;零 app 引用（插件互不 import 纪律）。

///|
/// `.md` 文件的 Markdown 编辑面。高度 = 内容全高（经
/// `markdown_editor_format` + `rich_text_document_height` 估算）与宿主
/// 视口取大——外层滚动由壳的 scroll_view 承担（工程文件编辑器同款方案,
/// 受控编辑器的内部滚轮路径不可靠是既有实测结论）。
pub fn[Msg] markdown_file_view(
  content~ : String,
  on_input~ : (String) -> Msg,
  width~ : Double,
  height~ : Double,
  font~ : @text.FontSpec,
  foreground~ : @graphics.Color,
  placeholder_color~ : @graphics.Color,
  background~ : @graphics.Brush,
  cursor_color~ : @graphics.Color,
  key? : String = "studio-markdown-editor",
) -> @moui.View[Msg] {
  let editor_width = (width - 32.0).max(80.0)
  let content_height = markdown_content_height(
    content~,
    width=editor_width,
    font~,
  ).max(height)
  @richtext.markdown_editor(
    value=content,
    placeholder="",
    size=@geometry.Size::new(width=editor_width, height=content_height),
    font~,
    foreground~,
    placeholder_color~,
    background~,
    cursor_color~,
    on_input=Some(on_input),
    accepts_tab_input=false,
    key=Some(key),
  )
}

///|
/// Markdown 内容的渲染全高估算：整篇源码格式化为富文本文档后量高度
/// （块级边距未计入,以 +24pt 呼吸位兜底）。
pub fn markdown_content_height(
  content~ : String,
  width~ : Double,
  font~ : @text.FontSpec,
) -> Double {
  let document = @richtext.markdown_editor_format(content, base=font)
  @richtext.rich_text_document_height(document, font, block_width=width) + 24.0
}

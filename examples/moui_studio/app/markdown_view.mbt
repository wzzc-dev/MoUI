///|
/// Markdown 块模型 → Studio 视图（M4）：AI 会话卡的 body 用块模型渲染。
///
/// v1 口径（诚实边界，注释即契约）：
/// - 行内片段渲染为**相邻文本视图**（按估宽排一行，超出宿主宽即裁）——
///   不做富文本流式排版；粗体=亮色、斜体=暗色、行内代码=Mono+强调色。
/// - 代码块 = Mono 行列 + 编辑器底色（M6 接高亮服务前先 plain mono）。
/// - 列表项每项一行；标题按级别用字号/角色区分；分隔线 = 发丝线。

///|
pub fn markdown_blocks_view(
  blocks : Array[@markdown.MarkdownBlock],
  width : Double,
) -> @moui.View[Msg] {
  let rows : Array[@moui.View[Msg]] = []
  for block in blocks {
    match block {
      MbHeading(level, text) => {
        let height = match level {
          1 => 28.0
          2 => 24.0
          _ => 20.0
        }
        rows.push(
          @views.text(
            text,
            theme=studio_theme(),
            role=if level == 1 { Title } else { Subtitle },
            width=(width - 16.0).max(60.0),
            height=height,
          )
          .foreground(ide_text()),
        )
      }
      MbParagraph(pieces) =>
        rows.push(markdown_inline_row(pieces, width))
      MbBulletList(items) =>
        for item in items {
          rows.push(
            @views.row(
              [
                markdown_inline_row(item, (width - 20.0).max(60.0)),
              ],
              spacing=0.0,
              align=Center,
            )
            .frame(width~, height=18.0),
          )
        }
      MbOrderedList(items) =>
        for item in items {
          rows.push(
            @views.row(
              [
                markdown_inline_row(item, (width - 20.0).max(60.0)),
              ],
              spacing=0.0,
              align=Center,
            )
            .frame(width~, height=18.0),
          )
        }
      MbCodeBlock(_lang, code) =>
        for line in split_line_texts(code) {
          rows.push(
            @views.container(
              @views.padding_edges(
                @views.text(
                  if line == "" { " " } else { line },
                  theme=studio_theme(),
                  role=Mono,
                  width=(width - 24.0).max(60.0),
                  height=16.0,
                  align=TextStart,
                ).foreground(code_plain_color()),
                left=8.0,
                right=8.0,
              ),
              background=ide_editor_background(),
              width~,
              height=24.0,
              padding=0.0,
            ),
          )
        }
      MbRule => rows.push(hairline())
    }
  }
  @views.column(rows, spacing=4.0)
}

///|
/// 行内片段行：相邻文本视图（估宽），样式用颜色/角色区分。
fn markdown_inline_row(
  pieces : Array[@markdown.MarkdownInline],
  width : Double,
) -> @moui.View[Msg] {
  let cells : Array[@moui.View[Msg]] = []
  for piece in pieces {
    let text = match piece {
      MiText(text) => text
      MiBold(text) => text
      MiItalic(text) => text
      MiCode(text) => text
    }
    let color = match piece {
      MiBold(_) => ide_text()
      MiItalic(_) => ide_text_muted()
      MiCode(_) => ide_accent()
      MiText(_) => ide_text()
    }
    let piece_width = text_estimate_width(text).max(4.0)
    cells.push(
      @views.text(
        text,
        theme=studio_theme(),
        role=if piece is MiCode(_) { Mono } else { Body },
        width=piece_width,
        height=18.0,
        align=TextStart,
      ).foreground(color),
    )
  }
  @views.row(cells, spacing=0.0, align=Center).frame(width~, height=18.0)
}

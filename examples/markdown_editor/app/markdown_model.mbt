///|
pub(all) enum MarkdownInlineKind {
  Plain
  Bold
  Italic
  Code
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownInline {
  text : String
  kind : MarkdownInlineKind
} derive(Eq, Debug, ToJson)

///|
pub(all) enum MarkdownBlockKind {
  Heading(Int)
  Paragraph
  UnorderedListItem
  TaskListItem(Bool)
  OrderedListItem(Int)
  Blockquote
  CodeBlock
  HorizontalRule
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownBlock {
  kind : MarkdownBlockKind
  text : String
  inlines : Array[MarkdownInline]
} derive(Eq, Debug, ToJson)

///|
pub fn parse_markdown(text : String) -> Array[MarkdownBlock] {
  let blocks : Array[MarkdownBlock] = []
  let code_lines : Array[String] = []
  let mut in_code = false
  for line in markdown_split_lines(text) {
    if in_code {
      if line == "```" {
        blocks.push(
          markdown_block(
            MarkdownBlockKind::CodeBlock,
            markdown_join_lines(code_lines).trim().to_owned(),
          ),
        )
        code_lines.clear()
        in_code = false
      } else {
        code_lines.push(line)
      }
    } else if line == "```" {
      in_code = true
    } else if line.trim().to_owned() != "" {
      let parsed = @markdown.parse(line)
      for block in parsed.document.children {
        append_markdown_ast_block(blocks, block)
      }
    }
  }
  if in_code {
    blocks.push(
      markdown_block(
        MarkdownBlockKind::CodeBlock,
        markdown_join_lines(code_lines).trim().to_owned(),
      ),
    )
  }
  blocks
}

///|
fn append_markdown_ast_block(
  blocks : Array[MarkdownBlock],
  block : @markdown.Block,
) -> Unit {
  match block {
    Heading(level~, children~, ..) => {
      let text = markdown_inline_text(children)
      if level >= 1 && level <= 3 {
        blocks.push({
          kind: MarkdownBlockKind::Heading(level),
          text,
          inlines: markdown_inlines_from_ast(children),
        })
      } else {
        let text = markdown_heading_source(level, text)
        blocks.push({
          kind: MarkdownBlockKind::Paragraph,
          text,
          inlines: parse_markdown_inlines(text),
        })
      }
    }
    Paragraph(children~, ..) => {
      let text = markdown_inline_text(children)
      blocks.push({
        kind: MarkdownBlockKind::Paragraph,
        text,
        inlines: markdown_inlines_from_ast(children),
      })
    }
    ThematicBreak(..) =>
      blocks.push(markdown_block(MarkdownBlockKind::HorizontalRule, ""))
    FencedCode(code~, ..) | IndentedCode(code~, ..) =>
      blocks.push(
        markdown_block(MarkdownBlockKind::CodeBlock, code.trim().to_owned()),
      )
    Blockquote(children~, ..) => {
      let text = markdown_blocks_text(children)
      blocks.push({
        kind: MarkdownBlockKind::Blockquote,
        text,
        inlines: parse_markdown_inlines(text),
      })
    }
    BulletList(marker~, items~, ..) =>
      if marker is Plus {
        for item in items {
          let text = markdown_list_item_text(item)
          let plus_text = "+ " + text
          blocks.push({
            kind: MarkdownBlockKind::Paragraph,
            text: plus_text,
            inlines: parse_markdown_inlines(plus_text),
          })
        }
      } else {
        for item in items {
          let text = markdown_list_item_text(item)
          match item.checked {
            Some(checked) =>
              blocks.push({
                kind: MarkdownBlockKind::TaskListItem(checked),
                text,
                inlines: parse_markdown_inlines(text),
              })
            None =>
              blocks.push({
                kind: MarkdownBlockKind::UnorderedListItem,
                text,
                inlines: parse_markdown_inlines(text),
              })
          }
        }
      }
    OrderedList(start~, items~, ..) => {
      let mut number = start
      for item in items {
        let text = markdown_list_item_text(item)
        blocks.push({
          kind: MarkdownBlockKind::OrderedListItem(number),
          text,
          inlines: parse_markdown_inlines(text),
        })
        number = number + 1
      }
    }
    BlankLines(..) => ()
    HtmlBlock(html~, ..) =>
      blocks.push(markdown_block(MarkdownBlockKind::Paragraph, html))
    Table(..) | FootnoteDefinition(..) =>
      blocks.push(
        markdown_block(
          MarkdownBlockKind::Paragraph,
          @markdown.serialize({
            frontmatter: None,
            children: [block],
            span: @markdown.Span::empty(),
          }),
        ),
      )
  }
}

///|
fn markdown_block(kind : MarkdownBlockKind, text : String) -> MarkdownBlock {
  let inlines = match kind {
    CodeBlock | HorizontalRule => []
    _ => parse_markdown_inlines(text)
  }
  { kind, text, inlines }
}

///|
pub fn parse_markdown_inlines(text : String) -> Array[MarkdownInline] {
  markdown_inlines_from_ast(@markdown.parse_inlines(text))
}

///|
fn markdown_inlines_from_ast(
  ast : Array[@markdown.Inline],
) -> Array[MarkdownInline] {
  let spans : Array[MarkdownInline] = []
  for inline in ast {
    append_markdown_inline_ast(spans, inline)
  }
  spans
}

///|
fn append_markdown_inline_ast(
  spans : Array[MarkdownInline],
  inline : @markdown.Inline,
) -> Unit {
  match inline {
    Text(content~, ..) =>
      if content != "" {
        spans.push({ text: content, kind: MarkdownInlineKind::Plain })
      }
    SoftBreak(..) | HardBreak(..) =>
      spans.push({ text: "\n", kind: MarkdownInlineKind::Plain })
    Emphasis(children~, ..) =>
      spans.push({
        text: markdown_inline_text(children),
        kind: MarkdownInlineKind::Italic,
      })
    Strong(children~, ..) =>
      spans.push({
        text: markdown_inline_text(children),
        kind: MarkdownInlineKind::Bold,
      })
    Code(content~, ..) =>
      spans.push({ text: content, kind: MarkdownInlineKind::Code })
    Strikethrough(children~, ..)
    | Link(children~, ..)
    | RefLink(children~, ..) =>
      spans.push({
        text: markdown_inline_text(children),
        kind: MarkdownInlineKind::Plain,
      })
    WikiLink(label~, target~, ..) =>
      spans.push({
        text: if label == "" {
          target
        } else {
          label
        },
        kind: MarkdownInlineKind::Plain,
      })
    Autolink(url~, ..) =>
      spans.push({ text: url, kind: MarkdownInlineKind::Plain })
    Image(alt~, ..) | RefImage(alt~, ..) =>
      spans.push({ text: alt, kind: MarkdownInlineKind::Plain })
    HtmlInline(html~, ..) =>
      spans.push({ text: html, kind: MarkdownInlineKind::Plain })
    FootnoteReference(label~, ..) =>
      spans.push({ text: label, kind: MarkdownInlineKind::Plain })
  }
}

///|
fn markdown_inline_text(ast : Array[@markdown.Inline]) -> String {
  let parts : Array[String] = []
  for inline in ast {
    parts.push(markdown_inline_plain_text(inline))
  }
  markdown_join_lines(parts)
}

///|
fn markdown_inline_plain_text(inline : @markdown.Inline) -> String {
  match inline {
    Text(content~, ..) => content
    SoftBreak(..) | HardBreak(..) => "\n"
    Emphasis(children~, ..)
    | Strong(children~, ..)
    | Strikethrough(children~, ..)
    | Link(children~, ..)
    | RefLink(children~, ..) => markdown_inline_text(children)
    Code(content~, ..) => content
    WikiLink(label~, target~, ..) => if label == "" { target } else { label }
    Autolink(url~, ..) => url
    Image(alt~, ..) | RefImage(alt~, ..) => alt
    HtmlInline(html~, ..) => html
    FootnoteReference(label~, ..) => label
  }
}

///|
fn markdown_blocks_text(blocks : Array[@markdown.Block]) -> String {
  let lines : Array[String] = []
  for block in blocks {
    match block {
      Paragraph(children~, ..) | Heading(children~, ..) =>
        lines.push(markdown_inline_text(children))
      FencedCode(code~, ..) | IndentedCode(code~, ..) => lines.push(code)
      Blockquote(children~, ..) => lines.push(markdown_blocks_text(children))
      BulletList(items~, ..) | OrderedList(items~, ..) =>
        for item in items {
          lines.push(markdown_list_item_text(item))
        }
      ThematicBreak(..) => lines.push("---")
      HtmlBlock(html~, ..) => lines.push(html)
      BlankLines(..) => ()
      Table(..) | FootnoteDefinition(..) => ()
    }
  }
  markdown_join_lines(lines)
}

///|
fn markdown_list_item_text(item : @markdown.ListItem) -> String {
  markdown_blocks_text(item.children)
}

///|
fn markdown_heading_source(level : Int, text : String) -> String {
  let marks : Array[Char] = []
  for _ in 0..<level {
    marks.push('#')
  }
  String::from_array(marks) + " " + text
}

///|
fn markdown_split_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  let current : Array[Char] = []
  for ch in text {
    if ch == '\n' {
      lines.push(String::from_array(current))
      current.clear()
    } else {
      current.push(ch)
    }
  }
  lines.push(String::from_array(current))
  lines
}

///|
fn markdown_join_lines(lines : Array[String]) -> String {
  let chars : Array[Char] = []
  for index, line in lines {
    if index > 0 {
      chars.push('\n')
    }
    chars.append(line.to_array())
  }
  String::from_array(chars)
}

///|
pub fn markdown_to_rich_text(text : String) -> @core.RichTextDocument {
  let blocks : Array[@core.RichTextBlock] = []
  let base = @core.FontSpec::new()
  for block in parse_markdown(text) {
    blocks.push(markdown_block_to_rich_text(block, base))
  }
  @core.RichTextDocument::new(blocks~)
}

///|
fn markdown_block_to_rich_text(
  block : MarkdownBlock,
  base : @core.FontSpec,
) -> @core.RichTextBlock {
  match block.kind {
    Heading(level) => {
      let font = if level == 1 {
        { ..base, size: base.size * 1.45, weight: 700 }
      } else if level == 2 {
        { ..base, size: base.size * 1.22, weight: 700 }
      } else {
        { ..base, size: base.size * 1.08, weight: 700 }
      }
      @core.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, font),
        font=Some(font),
        line_height=Some(
          if level == 1 {
            base.size * 2.0
          } else if level == 2 {
            base.size * 1.65
          } else {
            base.size * 1.45
          },
        ),
      )
    }
    UnorderedListItem =>
      @core.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        prefix="• ",
        line_height=Some(base.size * 1.55),
      )
    TaskListItem(checked) =>
      @core.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        prefix=if checked { "☑ " } else { "☐ " },
        line_height=Some(base.size * 1.55),
      )
    OrderedListItem(number) =>
      @core.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        prefix="\{number}. ",
        line_height=Some(base.size * 1.55),
      )
    Blockquote =>
      @core.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        color=Some(@core.Color::black().multiply_alpha(0.82)),
        border_left=Some(
          @core.BorderStyle::new(
            brush=@core.Brush::solid(@core.Color::black().multiply_alpha(0.32)),
            width=4.0,
          ),
        ),
        inset={ top: 0.0, right: 0.0, bottom: 0.0, left: 14.0 },
        line_height=Some(base.size * 1.55),
      )
    CodeBlock =>
      @core.RichTextBlock::new(
        runs=[
          @core.RichTextRun::new(
            text=block.text,
            font=Some({
              ..base,
              family: "ui-monospace, monospace",
              size: base.size * 0.92,
            }),
          ),
        ],
        background=Some(
          @core.Brush::solid(@core.Color::rgba(r=0.12, g=0.13, b=0.15, a=0.08)),
        ),
        inset={ top: 4.0, right: 10.0, bottom: 4.0, left: 10.0 },
        line_height=Some(base.size * 1.1),
        corner_radius=6.0,
      )
    HorizontalRule =>
      @core.RichTextBlock::new(
        runs=[],
        line_height=Some(base.size * 1.0),
        rule=true,
      )
    Paragraph =>
      @core.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        line_height=Some(base.size * 1.55),
      )
  }
}

///|
fn markdown_inlines_to_rich_text(
  inlines : Array[MarkdownInline],
  base : @core.FontSpec,
) -> Array[@core.RichTextRun] {
  let runs : Array[@core.RichTextRun] = []
  for span in inlines {
    runs.push(
      @core.RichTextRun::new(
        text=span.text,
        font=Some(markdown_inline_font(span.kind, base)),
        background=markdown_inline_background(span.kind),
      ),
    )
  }
  runs
}

///|
fn markdown_inline_font(
  kind : MarkdownInlineKind,
  font : @core.FontSpec,
) -> @core.FontSpec {
  match kind {
    Bold => { ..font, weight: 700 }
    Italic => { ..font, weight: 500 }
    Code =>
      {
        ..font,
        family: "SFMono-Regular, ui-monospace, Menlo, Consolas, monospace",
        size: font.size * 0.92,
      }
    Plain => font
  }
}

///|
fn markdown_inline_background(kind : MarkdownInlineKind) -> @core.Brush? {
  match kind {
    Code => Some(@core.Brush::solid(@core.Color::black().multiply_alpha(0.08)))
    Plain | Bold | Italic => None
  }
}

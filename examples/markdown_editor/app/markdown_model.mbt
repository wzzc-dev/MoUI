///|
pub(all) enum MarkdownInlineKind {
  Plain
  Bold
  Italic
  Code
  Strikethrough
  Link
  Autolink
  Image
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownInline {
  text : String
  kind : MarkdownInlineKind
  target : String?
} derive(Eq, Debug, ToJson)

///|
fn markdown_inline(
  text : String,
  kind : MarkdownInlineKind,
  target? : String? = None,
) -> MarkdownInline {
  { text, kind, target }
}

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
  Table
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
  let lines = markdown_split_lines(text)
  let code_lines : Array[String] = []
  let mut code_fence = ""
  let mut in_code = false
  let mut index = 0
  while index < lines.length() {
    let line = lines[index]
    if in_code {
      if markdown_closing_code_fence(line, code_fence) {
        blocks.push(
          markdown_block(
            MarkdownBlockKind::CodeBlock,
            markdown_join_lines(code_lines).trim().to_owned(),
          ),
        )
        code_lines.clear()
        code_fence = ""
        in_code = false
      } else {
        code_lines.push(line)
      }
    } else {
      match markdown_opening_code_fence(line) {
        Some(fence) => {
          in_code = true
          code_fence = fence
        }
        None =>
          if line.trim().to_owned() != "" {
            match markdown_table_block_at(lines, index) {
              Some(table) => {
                blocks.push(table.block)
                index = table.end_index
              }
              None =>
                match markdown_setext_heading_level_at(lines, index) {
                  Some(level) => {
                    let text = line.trim().to_owned()
                    blocks.push({
                      kind: MarkdownBlockKind::Heading(level),
                      text,
                      inlines: parse_markdown_inlines(text),
                    })
                    index = index + 1
                  }
                  None => {
                    let parsed = @markdown.parse(line)
                    for block in parsed.document.children {
                      append_markdown_ast_block(blocks, block)
                    }
                  }
                }
            }
          }
      }
    }
    index = index + 1
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
struct MarkdownTableParseResult {
  block : MarkdownBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_table_block_at(
  lines : Array[String],
  index : Int,
) -> MarkdownTableParseResult? {
  if index + 1 >= lines.length() ||
    !markdown_table_separator_line(lines[index + 1]) {
    return None
  }
  let segment_lines : Array[String] = [lines[index], lines[index + 1]]
  let mut next = index + 2
  while next < lines.length() && markdown_table_body_line(lines[next]) {
    segment_lines.push(lines[next])
    next = next + 1
  }
  let parsed = @markdown.parse(markdown_join_lines(segment_lines))
  if parsed.document.children.length() != 1 {
    return None
  }
  match parsed.document.children[0] {
    Table(header~, rows~, ..) =>
      Some({
        block: markdown_block(
          MarkdownBlockKind::Table,
          markdown_table_text(header, rows),
        ),
        end_index: next - 1,
      })
    _ => None
  }
}

///|
fn markdown_table_separator_line(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  if !trimmed.contains("|") {
    return false
  }
  let cells = markdown_split_table_cells(trimmed)
  if cells.length() == 0 {
    return false
  }
  for cell in cells {
    if !markdown_table_separator_cell(cell.trim().to_owned()) {
      return false
    }
  }
  true
}

///|
fn markdown_table_separator_cell(cell : String) -> Bool {
  let chars = cell.to_array()
  let mut dash_count = 0
  for ch in chars {
    if ch == '-' {
      dash_count = dash_count + 1
    } else if ch != ':' && ch != ' ' && ch != '\t' {
      return false
    }
  }
  dash_count >= 3
}

///|
fn markdown_table_body_line(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  trimmed != "" && trimmed.contains("|")
}

///|
fn markdown_split_table_cells(line : String) -> Array[String] {
  let cells : Array[String] = []
  let chars = line.to_array()
  let mut start = 0
  let mut end = chars.length()
  if start < end && chars[start] == '|' {
    start = start + 1
  }
  if end > start && chars[end - 1] == '|' {
    end = end - 1
  }
  let current : Array[Char] = []
  let mut index = start
  while index < end {
    if chars[index] == '|' {
      cells.push(String::from_array(current))
      current.clear()
    } else {
      current.push(chars[index])
    }
    index = index + 1
  }
  cells.push(String::from_array(current))
  cells
}

///|
fn markdown_setext_heading_level_at(lines : Array[String], index : Int) -> Int? {
  if index + 1 >= lines.length() {
    return None
  }
  let text = lines[index].trim().to_owned()
  if text == "" ||
    markdown_opening_code_fence(lines[index]) is Some(_) ||
    !markdown_is_setext_paragraph_candidate(lines[index]) {
    return None
  }
  markdown_setext_underline_level(lines[index + 1])
}

///|
fn markdown_is_setext_paragraph_candidate(line : String) -> Bool {
  let parsed = @markdown.parse(line)
  match parsed.document.children {
    [Paragraph(_)] => true
    _ => false
  }
}

///|
fn markdown_setext_underline_level(line : String) -> Int? {
  let text = line.trim().to_owned()
  if text == "" {
    return None
  }
  let chars = text.to_array()
  let marker = chars[0]
  if marker != '=' && marker != '-' {
    return None
  }
  for ch in chars {
    if ch != marker {
      return None
    }
  }
  Some(if marker == '=' { 1 } else { 2 })
}

///|
fn markdown_opening_code_fence(line : String) -> String? {
  let chars = line.to_array()
  let indent = markdown_leading_indent_length(chars)
  if chars.length() < indent + 3 {
    return None
  }
  if chars[indent] != '`' ||
    chars[indent + 1] != '`' ||
    chars[indent + 2] != '`' {
    return None
  }
  let mut fence_end = indent + 3
  while fence_end < chars.length() && chars[fence_end] == '`' {
    fence_end = fence_end + 1
  }
  for index in fence_end..<chars.length() {
    if chars[index] == '`' {
      return None
    }
  }
  Some(String::from_array(chars[indent:fence_end]))
}

///|
fn markdown_closing_code_fence(line : String, fence : String) -> Bool {
  let chars = line.to_array()
  let fence_chars = fence.to_array()
  let indent = markdown_leading_indent_length(chars)
  if fence_chars.length() < 3 || chars.length() < indent + fence_chars.length() {
    return false
  }
  for index in 0..<fence_chars.length() {
    if chars[indent + index] != fence_chars[index] {
      return false
    }
  }
  let mut index = indent + fence_chars.length()
  while index < chars.length() && chars[index] == '`' {
    index = index + 1
  }
  while index < chars.length() {
    if chars[index] != ' ' && chars[index] != '\t' {
      return false
    }
    index = index + 1
  }
  true
}

///|
fn markdown_leading_indent_length(chars : Array[Char]) -> Int {
  let mut index = 0
  while index < chars.length() && (chars[index] == ' ' || chars[index] == '\t') {
    index = index + 1
  }
  index
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
    Table(header~, rows~, ..) => {
      let text = markdown_table_text(header, rows)
      blocks.push(markdown_block(MarkdownBlockKind::Table, text))
    }
    FootnoteDefinition(..) =>
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
    CodeBlock | HorizontalRule | Table => []
    _ => parse_markdown_inlines(text)
  }
  { kind, text, inlines }
}

///|
fn markdown_table_text(
  header : Array[@markdown.TableCell],
  rows : Array[Array[@markdown.TableCell]],
) -> String {
  let lines : Array[String] = []
  lines.push(markdown_table_row_text(header))
  for row in rows {
    lines.push(markdown_table_row_text(row))
  }
  markdown_join_lines(lines)
}

///|
fn markdown_table_row_text(row : Array[@markdown.TableCell]) -> String {
  let cells : Array[String] = []
  for cell in row {
    cells.push(markdown_inline_text(cell.children).trim().to_owned())
  }
  cells.join("  |  ")
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
        spans.push(markdown_inline(content, Plain))
      }
    SoftBreak(..) | HardBreak(..) => spans.push(markdown_inline("\n", Plain))
    Emphasis(children~, ..) =>
      spans.push(markdown_inline(markdown_inline_text(children), Italic))
    Strong(children~, ..) =>
      spans.push(markdown_inline(markdown_inline_text(children), Bold))
    Code(content~, ..) => spans.push(markdown_inline(content, Code))
    Strikethrough(children~, ..) =>
      spans.push(markdown_inline(markdown_inline_text(children), Strikethrough))
    Link(children~, url~, ..) =>
      spans.push(
        markdown_inline(markdown_inline_text(children), Link, target=Some(url)),
      )
    RefLink(children~, label~, ..) =>
      spans.push(
        markdown_inline(
          markdown_inline_text(children),
          Link,
          target=Some(label),
        ),
      )
    WikiLink(label~, target~, ..) =>
      spans.push(
        markdown_inline(
          if label == "" {
            target
          } else {
            label
          },
          Link,
          target=Some(target),
        ),
      )
    Autolink(url~, ..) =>
      spans.push(markdown_inline(url, Autolink, target=Some(url)))
    Image(alt~, url~, ..) =>
      spans.push(markdown_inline(alt, Image, target=Some(url)))
    RefImage(alt~, label~, ..) =>
      spans.push(markdown_inline(alt, Image, target=Some(label)))
    HtmlInline(html~, ..) => spans.push(markdown_inline(html, Plain))
    FootnoteReference(label~, ..) => spans.push(markdown_inline(label, Plain))
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
              families: @core.FontFamilyStack::monospace(),
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
    Table =>
      @core.RichTextBlock::new(
        runs=[
          @core.RichTextRun::new(
            text=block.text,
            font=Some({
              ..base,
              families: @core.FontFamilyStack::monospace(),
              size: base.size * 0.92,
            }),
          ),
        ],
        table=markdown_table_preview(block, base),
        background=Some(
          @core.Brush::solid(@core.Color::rgba(r=0.08, g=0.12, b=0.16, a=0.05)),
        ),
        inset={ top: 6.0, right: 10.0, bottom: 6.0, left: 10.0 },
        line_height=Some(base.size * 1.35),
        corner_radius=6.0,
      )
    Paragraph =>
      @core.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, base),
        line_height=Some(base.size * 1.55),
      )
  }
}

///|
fn markdown_table_preview(
  block : MarkdownBlock,
  base : @core.FontSpec,
) -> @core.RichTextTable? {
  match block.kind {
    Table => {
      let lines = markdown_split_lines(block.text)
      if lines.length() == 0 {
        return None
      }
      let rows : Array[Array[@core.RichTextTableCell]] = []
      let mut line_offset = 0
      for index in 0..<lines.length() {
        let cells : Array[@core.RichTextTableCell] = []
        let source_line = lines[index]
        for cell in markdown_table_cell_ranges_for_line(source_line) {
          cells.push({
            text: cell.text,
            header: index == 0,
            source_range: Some({
              start: line_offset + cell.start,
              end: line_offset + cell.end,
            }),
          })
        }
        rows.push(cells)
        line_offset = line_offset + source_line.to_array().length() + 1
      }
      Some({
        rows,
        row_height: base.size * 1.9,
        cell_padding: @core.Insets::symmetric(horizontal=8.0, vertical=5.0),
        border: @core.Color::black().multiply_alpha(0.16),
        header_background: Some(
          @core.Brush::solid(@core.Color::rgba(r=0.08, g=0.12, b=0.16, a=0.06)),
        ),
      })
    }
    _ => None
  }
}

///|
priv struct MarkdownTableCellPreviewRange {
  text : String
  start : Int
  end : Int
}

///|
fn markdown_table_cell_ranges_for_line(
  line : String,
) -> Array[MarkdownTableCellPreviewRange] {
  let cells : Array[MarkdownTableCellPreviewRange] = []
  let chars = line.to_array()
  let mut start = 0
  let mut end = chars.length()
  if start < end && chars[start] == '|' {
    start = start + 1
  }
  if end > start && chars[end - 1] == '|' {
    end = end - 1
  }
  let mut segment_start = start
  let mut index = start
  while index <= end {
    if index == end || chars[index] == '|' {
      let range = markdown_table_trimmed_range(chars, segment_start, index)
      cells.push({
        text: String::from_array(chars[range.start:range.end]),
        start: range.start,
        end: range.end,
      })
      segment_start = index + 1
    }
    index = index + 1
  }
  cells
}

///|
fn markdown_table_trimmed_range(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> @core.RichTextSourceRange {
  let mut content_start = start
  let mut content_end = end
  while content_start < content_end &&
        (chars[content_start] == ' ' || chars[content_start] == '\t') {
    content_start = content_start + 1
  }
  while content_end > content_start &&
        (chars[content_end - 1] == ' ' || chars[content_end - 1] == '\t') {
    content_end = content_end - 1
  }
  { start: content_start, end: content_end }
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
        text=markdown_inline_source_text(span),
        visual_text=Some(markdown_inline_visual_text(span)),
        image_source=markdown_inline_image_source(span),
        image_size=markdown_inline_image_size(span, base),
        font=Some(markdown_inline_font(span.kind, base)),
        background=markdown_inline_background(span.kind),
        decoration=markdown_inline_decoration(span.kind),
      ),
    )
  }
  runs
}

///|
fn markdown_inline_visual_text(inline : MarkdownInline) -> String {
  match inline.kind {
    Image => markdown_inline_source_text(inline)
    _ => inline.text
  }
}

///|
fn markdown_inline_image_source(inline : MarkdownInline) -> String? {
  match inline.kind {
    Image => inline.target
    _ => None
  }
}

///|
fn markdown_inline_image_size(
  inline : MarkdownInline,
  base : @core.FontSpec,
) -> @core.Size? {
  match inline.kind {
    Image =>
      Some(@core.Size::new(width=base.size * 8.0, height=base.size * 4.5))
    _ => None
  }
}

///|
fn markdown_inline_source_text(inline : MarkdownInline) -> String {
  if inline.text == "" {
    "image"
  } else {
    inline.text
  }
}

///|
fn markdown_inline_font(
  kind : MarkdownInlineKind,
  font : @core.FontSpec,
) -> @core.FontSpec {
  match kind {
    Bold => { ..font, weight: 700 }
    Italic => { ..font, weight: 500 }
    Strikethrough => { ..font, weight: 400 }
    Link | Autolink => { ..font, weight: 500 }
    Image => { ..font, weight: 600 }
    Code =>
      {
        ..font,
        families: @core.FontFamilyStack::named("SFMono-Regular")
        .with_fallback(@core.FontFamily::UiMonospace)
        .with_fallback(@core.FontFamily::Monospace),
        size: font.size * 0.92,
      }
    Plain => font
  }
}

///|
fn markdown_inline_background(kind : MarkdownInlineKind) -> @core.Brush? {
  match kind {
    Code => Some(@core.Brush::solid(@core.Color::black().multiply_alpha(0.08)))
    Image =>
      Some(@core.Brush::solid(@core.Color::rgba(r=0.18, g=0.4, b=0.7, a=0.08)))
    Plain | Bold | Italic | Strikethrough | Link | Autolink => None
  }
}

///|
fn markdown_inline_decoration(
  kind : MarkdownInlineKind,
) -> @core.RichTextDecoration? {
  match kind {
    Strikethrough => Some(@core.RichTextDecoration::Strikethrough)
    Plain | Bold | Italic | Code | Link | Autolink | Image => None
  }
}

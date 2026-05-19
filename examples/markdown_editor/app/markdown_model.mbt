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
  let lines = markdown_split_lines(text)
  let mut in_code = false
  let code_lines : Array[String] = []
  for line in lines {
    if markdown_has_prefix(line, "```") {
      if in_code {
        blocks.push(
          markdown_block(
            MarkdownBlockKind::CodeBlock,
            markdown_join_lines(code_lines),
          ),
        )
        code_lines.clear()
        in_code = false
      } else {
        in_code = true
      }
    } else if in_code {
      code_lines.push(line)
    } else {
      let parsed = parse_markdown_line(line)
      match parsed {
        Some(block) => blocks.push(block)
        None => ()
      }
    }
  }
  if in_code || !code_lines.is_empty() {
    blocks.push(
      markdown_block(
        MarkdownBlockKind::CodeBlock,
        markdown_join_lines(code_lines),
      ),
    )
  }
  blocks
}

///|
fn parse_markdown_line(line : String) -> MarkdownBlock? {
  let trimmed = markdown_trim(line)
  if trimmed == "" {
    None
  } else if markdown_is_horizontal_rule(trimmed) {
    Some(markdown_block(MarkdownBlockKind::HorizontalRule, ""))
  } else if markdown_has_prefix(line, "### ") {
    Some(
      markdown_block(
        MarkdownBlockKind::Heading(3),
        markdown_substring(line, 4, text_length_for_example(line)),
      ),
    )
  } else if markdown_has_prefix(line, "## ") {
    Some(
      markdown_block(
        MarkdownBlockKind::Heading(2),
        markdown_substring(line, 3, text_length_for_example(line)),
      ),
    )
  } else if markdown_has_prefix(line, "# ") {
    Some(
      markdown_block(
        MarkdownBlockKind::Heading(1),
        markdown_substring(line, 2, text_length_for_example(line)),
      ),
    )
  } else if markdown_has_prefix(line, "- [ ] ") ||
    markdown_has_prefix(line, "* [ ] ") {
    Some(
      markdown_block(
        MarkdownBlockKind::TaskListItem(false),
        markdown_substring(line, 6, text_length_for_example(line)),
      ),
    )
  } else if markdown_has_prefix(line, "- [x] ") ||
    markdown_has_prefix(line, "* [x] ") ||
    markdown_has_prefix(line, "- [X] ") ||
    markdown_has_prefix(line, "* [X] ") {
    Some(
      markdown_block(
        MarkdownBlockKind::TaskListItem(true),
        markdown_substring(line, 6, text_length_for_example(line)),
      ),
    )
  } else if markdown_has_prefix(line, "- ") || markdown_has_prefix(line, "* ") {
    Some(
      markdown_block(
        MarkdownBlockKind::UnorderedListItem,
        markdown_substring(line, 2, text_length_for_example(line)),
      ),
    )
  } else if markdown_has_prefix(line, "> ") {
    Some(
      markdown_block(
        MarkdownBlockKind::Blockquote,
        markdown_substring(line, 2, text_length_for_example(line)),
      ),
    )
  } else {
    match markdown_ordered_prefix(line) {
      Some(prefix) =>
        Some(
          markdown_block(
            MarkdownBlockKind::OrderedListItem(prefix.number),
            markdown_substring(
              line,
              prefix.width,
              text_length_for_example(line),
            ),
          ),
        )
      None => Some(markdown_block(MarkdownBlockKind::Paragraph, line))
    }
  }
}

///|
priv struct MarkdownOrderedPrefix {
  number : Int
  width : Int
}

///|
fn markdown_ordered_prefix(line : String) -> MarkdownOrderedPrefix? {
  let chars = line.to_array()
  let mut index = 0
  let mut number = 0
  while index < chars.length() && chars[index].is_ascii_digit() {
    number = number * 10 + chars[index].to_int() - '0'.to_int()
    index = index + 1
  }
  if index > 0 &&
    index + 1 < chars.length() &&
    chars[index] == '.' &&
    chars[index + 1] == ' ' {
    Some({ number, width: index + 2 })
  } else {
    None
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
  let spans : Array[MarkdownInline] = []
  let chars = text.to_array()
  let buffer : Array[Char] = []
  let mut index = 0
  while index < chars.length() {
    if index + 1 < chars.length() &&
      chars[index] == '*' &&
      chars[index + 1] == '*' {
      match markdown_find_marker(chars, index + 2, "**") {
        Some(end) => {
          markdown_push_plain_inline(spans, buffer)
          spans.push({
            text: String::from_array(chars[index + 2:end]),
            kind: MarkdownInlineKind::Bold,
          })
          index = end + 2
        }
        None => {
          buffer.push(chars[index])
          index = index + 1
        }
      }
    } else if index + 1 < chars.length() &&
      chars[index] == '_' &&
      chars[index + 1] == '_' {
      match markdown_find_marker(chars, index + 2, "__") {
        Some(end) => {
          markdown_push_plain_inline(spans, buffer)
          spans.push({
            text: String::from_array(chars[index + 2:end]),
            kind: MarkdownInlineKind::Bold,
          })
          index = end + 2
        }
        None => {
          buffer.push(chars[index])
          index = index + 1
        }
      }
    } else if chars[index] == '*' {
      match markdown_find_char(chars, index + 1, '*') {
        Some(end) => {
          markdown_push_plain_inline(spans, buffer)
          spans.push({
            text: String::from_array(chars[index + 1:end]),
            kind: MarkdownInlineKind::Italic,
          })
          index = end + 1
        }
        None => {
          buffer.push(chars[index])
          index = index + 1
        }
      }
    } else if chars[index] == '_' {
      match markdown_find_char(chars, index + 1, '_') {
        Some(end) => {
          markdown_push_plain_inline(spans, buffer)
          spans.push({
            text: String::from_array(chars[index + 1:end]),
            kind: MarkdownInlineKind::Italic,
          })
          index = end + 1
        }
        None => {
          buffer.push(chars[index])
          index = index + 1
        }
      }
    } else if chars[index] == '`' {
      match markdown_find_char(chars, index + 1, '`') {
        Some(end) => {
          markdown_push_plain_inline(spans, buffer)
          spans.push({
            text: String::from_array(chars[index + 1:end]),
            kind: MarkdownInlineKind::Code,
          })
          index = end + 1
        }
        None => {
          buffer.push(chars[index])
          index = index + 1
        }
      }
    } else {
      buffer.push(chars[index])
      index = index + 1
    }
  }
  markdown_push_plain_inline(spans, buffer)
  spans
}

///|
fn markdown_push_plain_inline(
  spans : Array[MarkdownInline],
  buffer : Array[Char],
) -> Unit {
  if !buffer.is_empty() {
    spans.push({
      text: String::from_array(buffer),
      kind: MarkdownInlineKind::Plain,
    })
    buffer.clear()
  }
}

///|
fn markdown_find_marker(
  chars : Array[Char],
  start : Int,
  marker : String,
) -> Int? {
  let marker_chars = marker.to_array()
  let mut index = start
  while index + marker_chars.length() <= chars.length() {
    let mut matched = true
    for offset in 0..<marker_chars.length() {
      if chars[index + offset] != marker_chars[offset] {
        matched = false
      }
    }
    if matched {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn markdown_find_char(chars : Array[Char], start : Int, target : Char) -> Int? {
  let mut index = start
  while index < chars.length() {
    if chars[index] == target {
      return Some(index)
    }
    index = index + 1
  }
  None
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
fn markdown_has_prefix(text : String, prefix : String) -> Bool {
  let chars = text.to_array()
  let prefix_chars = prefix.to_array()
  chars.length() >= prefix_chars.length() &&
  chars[:prefix_chars.length()] == prefix_chars[:]
}

///|
fn markdown_substring(text : String, start : Int, end : Int) -> String {
  let chars = text.to_array()
  let start = clamp_int_for_example(start, 0, chars.length())
  let end = clamp_int_for_example(end, start, chars.length())
  String::from_array(chars[start:end])
}

///|
fn markdown_trim(text : String) -> String {
  text.trim().to_owned()
}

///|
fn markdown_is_horizontal_rule(text : String) -> Bool {
  text == "---" || text == "***" || text == "___"
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

///|
fn clamp_int_for_example(value : Int, min_value : Int, max_value : Int) -> Int {
  if value < min_value {
    min_value
  } else if value > max_value {
    max_value
  } else {
    value
  }
}

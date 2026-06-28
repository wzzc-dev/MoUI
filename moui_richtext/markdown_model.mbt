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
  FootnoteDefinition(String)
  HtmlBlock
  FrontMatter
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownBlock {
  kind : MarkdownBlockKind
  text : String
  inlines : Array[MarkdownInline]
  table_alignments : Array[@core.TextAlign?]
  code_language : String?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownFrontMatterParseResult {
  block : MarkdownBlock
  next_index : Int
} derive(Eq, Debug)

///|
fn markdown_front_matter_block_at(
  lines : Array[String],
) -> MarkdownFrontMatterParseResult? {
  if lines.length() < 2 || lines[0].trim().to_owned() != "---" {
    return None
  }
  let content : Array[String] = []
  let mut index = 1
  while index < lines.length() {
    if lines[index].trim().to_owned() == "---" {
      return Some({
        block: markdown_block(FrontMatter, markdown_join_lines(content)),
        next_index: index + 1,
      })
    }
    content.push(lines[index])
    index = index + 1
  }
  None
}

///|
pub fn parse_markdown(text : String) -> Array[MarkdownBlock] {
  let blocks : Array[MarkdownBlock] = []
  let definitions = markdown_reference_definitions(text)
  let lines = markdown_split_lines(text)
  match markdown_front_matter_block_at(lines) {
    Some(front_matter) => {
      blocks.push(front_matter.block)
      let remaining_lines : Array[String] = []
      for index in front_matter.next_index..<lines.length() {
        remaining_lines.push(lines[index])
      }
      let remaining = markdown_join_lines(remaining_lines)
      if remaining != "" {
        blocks.append(parse_markdown(remaining))
      }
      return blocks
    }
    None => ()
  }
  let code_lines : Array[String] = []
  let mut code_language : String? = None
  let mut code_fence = ""
  let mut in_code = false
  let mut index = 0
  while index < lines.length() {
    let line = lines[index]
    if in_code {
      if markdown_closing_code_fence(line, code_fence) {
        blocks.push(
          markdown_code_block(markdown_join_lines(code_lines), code_language),
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
          code_fence = fence.marker
          code_language = fence.info
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
                      inlines: parse_markdown_inlines_with_definitions(
                        text, definitions,
                      ),
                      table_alignments: [],
                      code_language: None,
                    })
                    index = index + 1
                  }
                  None => {
                    let parsed = @md.parse(line)
                    for block in parsed.document.children {
                      append_markdown_ast_block(
                        blocks,
                        block,
                        definitions,
                        source_text=Some(line),
                      )
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
      markdown_code_block(markdown_join_lines(code_lines), code_language),
    )
  }
  blocks
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
  let parsed = @md.parse(line)
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
pub(all) struct MarkdownCodeFenceInfo {
  marker : String
  info : String?
} derive(Eq, Debug)

///|
fn markdown_opening_code_fence(line : String) -> MarkdownCodeFenceInfo? {
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
  Some({
    marker: String::from_array(chars[indent:fence_end]),
    info: markdown_code_fence_info(chars, fence_end),
  })
}

///|
fn markdown_code_fence_info(chars : Array[Char], start : Int) -> String? {
  let info = String::from_array(chars[start:]).trim().to_owned()
  if info == "" {
    None
  } else {
    Some(info)
  }
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
  block : @md.Block,
  definitions : Array[MarkdownReferenceDefinition],
  source_text? : String? = None,
) -> Unit {
  match block {
    Heading(level~, children~, ..) => {
      let text = match source_text {
        Some(source_text) => markdown_heading_visible_source_text(source_text)
        None => markdown_inline_text(children)
      }
      // A heading source is only rendered as a heading block when it has `#`
      // markers, a space/tab separator, AND actual content after the separator
      // (e.g. `"# text"`). Bare markers (`"#"`, `"##"`) or markers with a
      // separator but no content yet (`"# "`, `"## "`) are treated as plain
      // text so the user can still see the `#` they typed and the cursor stays
      // at normal size until real heading content is entered.
      let is_real_heading = match source_text {
        Some(source_text) => markdown_heading_source_is_renderable(source_text)
        None => true
      }
      if level >= 1 && level <= 6 && is_real_heading {
        blocks.push({
          kind: MarkdownBlockKind::Heading(level),
          text,
          inlines: parse_markdown_inlines_with_definitions(text, definitions),
          table_alignments: [],
          code_language: None,
        })
      } else {
        let para_text = match source_text {
          Some(source_text) if !is_real_heading => source_text
          _ => markdown_heading_source(level, text)
        }
        blocks.push({
          kind: MarkdownBlockKind::Paragraph,
          text: para_text,
          inlines: parse_markdown_inlines_with_definitions(
            para_text, definitions,
          ),
          table_alignments: [],
          code_language: None,
        })
      }
    }
    Paragraph(children~, ..) => {
      let text = match source_text {
        Some(source_text) => source_text
        None => markdown_inline_text(children)
      }
      blocks.push({
        kind: MarkdownBlockKind::Paragraph,
        text,
        inlines: parse_markdown_inlines_with_definitions(text, definitions),
        table_alignments: [],
        code_language: None,
      })
    }
    ThematicBreak(..) =>
      blocks.push(markdown_block(MarkdownBlockKind::HorizontalRule, ""))
    FencedCode(code~, info~, ..) =>
      blocks.push(
        markdown_code_block(
          markdown_trim_single_trailing_newline(code),
          markdown_normalize_code_info(Some(info)),
        ),
      )
    IndentedCode(code~, ..) =>
      blocks.push(
        markdown_code_block(markdown_trim_single_trailing_newline(code), None),
      )
    Blockquote(children~, ..) => {
      let text = markdown_blocks_text(children)
      blocks.push({
        kind: MarkdownBlockKind::Blockquote,
        text,
        inlines: parse_markdown_inlines_with_definitions(text, definitions),
        table_alignments: [],
        code_language: None,
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
            inlines: parse_markdown_inlines_with_definitions(
              plus_text, definitions,
            ),
            table_alignments: [],
            code_language: None,
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
                inlines: parse_markdown_inlines_with_definitions(
                  text, definitions,
                ),
                table_alignments: [],
                code_language: None,
              })
            None =>
              blocks.push({
                kind: MarkdownBlockKind::UnorderedListItem,
                text,
                inlines: parse_markdown_inlines_with_definitions(
                  text, definitions,
                ),
                table_alignments: [],
                code_language: None,
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
          inlines: parse_markdown_inlines_with_definitions(text, definitions),
          table_alignments: [],
          code_language: None,
        })
        number = number + 1
      }
    }
    BlankLines(..) => ()
    HtmlBlock(html~, ..) =>
      blocks.push(markdown_block(MarkdownBlockKind::HtmlBlock, html))
    Table(header~, rows~, ..) => {
      let text = markdown_table_text(header, rows)
      blocks.push(markdown_table_block(text, []))
    }
    FootnoteDefinition(label~, children~, ..) => {
      let text = markdown_blocks_text(children)
      blocks.push({
        kind: MarkdownBlockKind::FootnoteDefinition(label),
        text,
        inlines: parse_markdown_inlines_with_definitions(text, definitions),
        table_alignments: [],
        code_language: None,
      })
    }
  }
}

///|
fn markdown_trim_single_trailing_newline(text : String) -> String {
  let chars = text.to_array()
  if chars.length() > 0 && chars[chars.length() - 1] == '\n' {
    String::from_array(chars[:chars.length() - 1])
  } else {
    text
  }
}

///|
fn markdown_block(kind : MarkdownBlockKind, text : String) -> MarkdownBlock {
  let inlines = match kind {
    CodeBlock | HorizontalRule | Table | FrontMatter => []
    _ => parse_markdown_inlines(text)
  }
  { kind, text, inlines, table_alignments: [], code_language: None }
}

///|
fn markdown_code_block(text : String, code_language : String?) -> MarkdownBlock {
  {
    kind: MarkdownBlockKind::CodeBlock,
    text,
    inlines: [],
    table_alignments: [],
    code_language,
  }
}

///|
fn markdown_normalize_code_info(info : String?) -> String? {
  match info {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
pub fn markdown_split_lines(text : String) -> Array[String] {
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
pub fn markdown_join_lines(lines : Array[String]) -> String {
  let chars : Array[Char] = []
  for index, line in lines {
    if index > 0 {
      chars.push('\n')
    }
    chars.append(line.to_array())
  }
  String::from_array(chars)
}

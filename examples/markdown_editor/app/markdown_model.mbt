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
  FootnoteReference
  HtmlInline
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
  FootnoteDefinition(String)
  HtmlBlock
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
struct MarkdownReferenceDefinition {
  label : String
  url : String
  title : String
} derive(Eq, Debug)

///|
pub fn parse_markdown(text : String) -> Array[MarkdownBlock] {
  let blocks : Array[MarkdownBlock] = []
  let definitions = markdown_reference_definitions(text)
  let lines = markdown_split_lines(text)
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
          markdown_code_block(
            markdown_join_lines(code_lines).trim().to_owned(),
            code_language,
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
                    let parsed = @markdown.parse(line)
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
      markdown_code_block(
        markdown_join_lines(code_lines).trim().to_owned(),
        code_language,
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
        block: markdown_table_block(
          markdown_table_text(header, rows),
          markdown_table_alignments_for_separator(lines[index + 1]),
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
struct MarkdownCodeFenceInfo {
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
  block : @markdown.Block,
  definitions : Array[MarkdownReferenceDefinition],
  source_text? : String? = None,
) -> Unit {
  match block {
    Heading(level~, children~, ..) => {
      let text = match source_text {
        Some(source_text) => markdown_heading_visible_source_text(source_text)
        None => markdown_inline_text(children)
      }
      if level >= 1 && level <= 6 {
        blocks.push({
          kind: MarkdownBlockKind::Heading(level),
          text,
          inlines: parse_markdown_inlines_with_definitions(text, definitions),
          table_alignments: [],
          code_language: None,
        })
      } else {
        let text = markdown_heading_source(level, text)
        blocks.push({
          kind: MarkdownBlockKind::Paragraph,
          text,
          inlines: parse_markdown_inlines_with_definitions(text, definitions),
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
          code.trim().to_owned(),
          markdown_normalize_code_info(Some(info)),
        ),
      )
    IndentedCode(code~, ..) =>
      blocks.push(markdown_code_block(code.trim().to_owned(), None))
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
fn markdown_block(kind : MarkdownBlockKind, text : String) -> MarkdownBlock {
  let inlines = match kind {
    CodeBlock | HorizontalRule | Table => []
    _ => parse_markdown_inlines(text)
  }
  { kind, text, inlines, table_alignments: [], code_language: None }
}

///|
fn markdown_table_block(
  text : String,
  table_alignments : Array[@core.TextAlign?],
) -> MarkdownBlock {
  {
    kind: MarkdownBlockKind::Table,
    text,
    inlines: [],
    table_alignments,
    code_language: None,
  }
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
  parse_markdown_inlines_with_definitions(text, [])
}

///|
fn parse_markdown_inlines_with_definitions(
  text : String,
  definitions : Array[MarkdownReferenceDefinition],
) -> Array[MarkdownInline] {
  markdown_parse_inlines_preserving_plain_html(text, definitions)
}

///|
fn markdown_parse_inlines_preserving_plain_html(
  text : String,
  definitions : Array[MarkdownReferenceDefinition],
) -> Array[MarkdownInline] {
  let spans : Array[MarkdownInline] = []
  let chars = text.to_array()
  let mut start = 0
  let mut index = 0
  while index < chars.length() {
    match markdown_protected_inline_end(chars, index) {
      Some(end) => {
        markdown_append_parsed_inline_segment(
          spans,
          String::from_array(chars[start:end]),
          definitions,
        )
        index = end
        start = end
      }
      None =>
        if chars[index] == '<' {
          match markdown_html_inline_tag_end(chars, index) {
            Some(end) => {
              markdown_append_parsed_inline_segment(
                spans,
                String::from_array(chars[start:index]),
                definitions,
              )
              spans.push(
                markdown_inline(
                  String::from_array(chars[index:end]),
                  HtmlInline,
                ),
              )
              index = end
              start = end
            }
            None => index = index + 1
          }
        } else {
          index = index + 1
        }
    }
  }
  markdown_append_parsed_inline_segment(
    spans,
    String::from_array(chars[start:]),
    definitions,
  )
  spans
}

///|
fn markdown_append_parsed_inline_segment(
  spans : Array[MarkdownInline],
  text : String,
  definitions : Array[MarkdownReferenceDefinition],
) -> Unit {
  if text == "" {
    return
  }
  spans.append(
    markdown_normalize_html_inlines(
      markdown_inlines_from_ast(@markdown.parse_inlines(text), definitions),
    ),
  )
}

///|
fn markdown_resolve_reference_inlines(
  inlines : Array[MarkdownInline],
  definitions : Array[MarkdownReferenceDefinition],
) -> Array[MarkdownInline] {
  let resolved : Array[MarkdownInline] = []
  for inline in inlines {
    match inline.target {
      Some(target) =>
        match inline.kind {
          Link | Image =>
            resolved.push({
              ..inline,
              target: Some(markdown_reference_target(definitions, target)),
            })
          _ => resolved.push(inline)
        }
      None => resolved.push(inline)
    }
  }
  resolved
}

///|
fn markdown_normalize_html_inlines(
  inlines : Array[MarkdownInline],
) -> Array[MarkdownInline] {
  let normalized : Array[MarkdownInline] = []
  for inline in inlines {
    match inline.kind {
      MarkdownInlineKind::HtmlInline =>
        normalized.push({
          ..inline,
          text: markdown_html_inline_source(inline.text),
        })
      _ => normalized.push(inline)
    }
  }
  normalized
}

///|
fn markdown_protected_inline_end(chars : Array[Char], start : Int) -> Int? {
  if chars[start] == '`' {
    let mut index = start + 1
    while index < chars.length() && chars[index] != '`' && chars[index] != '\n' {
      index = index + 1
    }
    if index < chars.length() && chars[index] == '`' {
      return Some(index + 1)
    }
  }
  if chars[start] == '!' &&
    start + 1 < chars.length() &&
    chars[start + 1] == '[' {
    return markdown_bracketed_inline_end(chars, start + 1)
  }
  if chars[start] == '[' {
    markdown_bracketed_inline_end(chars, start)
  } else {
    None
  }
}

///|
fn markdown_bracketed_inline_end(chars : Array[Char], open : Int) -> Int? {
  let mut close = open + 1
  while close < chars.length() && chars[close] != ']' && chars[close] != '\n' {
    close = close + 1
  }
  if close >= chars.length() ||
    chars[close] != ']' ||
    close + 1 >= chars.length() {
    return None
  }
  if chars[close + 1] == '(' {
    let mut end = close + 2
    while end < chars.length() && chars[end] != ')' && chars[end] != '\n' {
      end = end + 1
    }
    if end < chars.length() && chars[end] == ')' {
      Some(end + 1)
    } else {
      None
    }
  } else if chars[close + 1] == '[' {
    let mut end = close + 2
    while end < chars.length() && chars[end] != ']' && chars[end] != '\n' {
      end = end + 1
    }
    if end < chars.length() && chars[end] == ']' {
      Some(end + 1)
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn markdown_html_inline_source(html : String) -> String {
  if html.has_prefix("<") {
    html
  } else {
    "<" + html + ">"
  }
}

///|
fn markdown_html_inline_tag_end(chars : Array[Char], start : Int) -> Int? {
  if start + 2 >= chars.length() || chars[start] != '<' {
    return None
  }
  let mut name_start = start + 1
  if chars[name_start] == '/' {
    name_start = name_start + 1
  }
  if name_start >= chars.length() ||
    !markdown_html_tag_name_start_char(chars[name_start]) {
    return None
  }
  let mut index = name_start + 1
  while index < chars.length() && markdown_html_tag_name_char(chars[index]) {
    index = index + 1
  }
  if index >= chars.length() ||
    (
      chars[index] != '>' &&
      chars[index] != '/' &&
      chars[index] != ' ' &&
      chars[index] != '\t'
    ) {
    return None
  }
  while index < chars.length() && chars[index] != '>' && chars[index] != '\n' {
    index = index + 1
  }
  if index >= chars.length() || chars[index] != '>' {
    None
  } else {
    Some(index + 1)
  }
}

///|
fn markdown_html_tag_name_start_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn markdown_html_tag_name_char(ch : Char) -> Bool {
  markdown_html_tag_name_start_char(ch) || (ch >= '0' && ch <= '9') || ch == '-'
}

///|
fn markdown_inlines_from_ast(
  ast : Array[@markdown.Inline],
  definitions : Array[MarkdownReferenceDefinition],
) -> Array[MarkdownInline] {
  let spans : Array[MarkdownInline] = []
  for inline in ast {
    append_markdown_inline_ast(spans, inline, definitions)
  }
  spans
}

///|
fn append_markdown_inline_ast(
  spans : Array[MarkdownInline],
  inline : @markdown.Inline,
  definitions : Array[MarkdownReferenceDefinition],
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
          target=Some(markdown_reference_target(definitions, label)),
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
      spans.push(
        markdown_inline(
          alt,
          Image,
          target=Some(markdown_reference_target(definitions, label)),
        ),
      )
    HtmlInline(html~, ..) =>
      spans.push(markdown_inline(markdown_html_inline_source(html), HtmlInline))
    FootnoteReference(label~, ..) =>
      spans.push(markdown_inline(label, FootnoteReference))
  }
}

///|
fn markdown_reference_definitions(
  source : String,
) -> Array[MarkdownReferenceDefinition] {
  let definitions : Array[MarkdownReferenceDefinition] = []
  for definition in @markdown.parse(source).definitions {
    definitions.push({
      label: markdown_reference_label_key(definition.label),
      url: definition.url,
      title: definition.title,
    })
  }
  for definition in markdown_scan_reference_definitions(source) {
    definitions.push(definition)
  }
  definitions
}

///|
fn markdown_scan_reference_definitions(
  source : String,
) -> Array[MarkdownReferenceDefinition] {
  let definitions : Array[MarkdownReferenceDefinition] = []
  let lines = markdown_split_lines(source)
  for line in lines {
    match markdown_scan_reference_definition_line(line) {
      Some(definition) => definitions.push(definition)
      None => ()
    }
  }
  definitions
}

///|
fn markdown_scan_reference_definition_line(
  line : String,
) -> MarkdownReferenceDefinition? {
  let trimmed = line.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() < 4 || chars[0] != '[' {
    return None
  }
  let mut close = 1
  while close < chars.length() && chars[close] != ']' {
    close = close + 1
  }
  if close <= 1 || close + 1 >= chars.length() || chars[close + 1] != ':' {
    return None
  }
  let label = String::from_array(chars[1:close])
  let rest = String::from_array(chars[close + 2:]).trim().to_owned()
  if rest == "" {
    return None
  }
  let rest_chars = rest.to_array()
  let mut url = ""
  let mut title = ""
  if rest_chars[0] == '<' {
    let mut end = 1
    while end < rest_chars.length() && rest_chars[end] != '>' {
      end = end + 1
    }
    if end >= rest_chars.length() {
      return None
    }
    url = String::from_array(rest_chars[1:end])
    title = String::from_array(rest_chars[end + 1:]).trim().to_owned()
  } else {
    let mut end = 0
    while end < rest_chars.length() &&
          rest_chars[end] != ' ' &&
          rest_chars[end] != '\t' {
      end = end + 1
    }
    url = String::from_array(rest_chars[:end])
    title = String::from_array(rest_chars[end:]).trim().to_owned()
  }
  if url == "" {
    return None
  }
  Some({
    label: markdown_reference_label_key(label),
    url,
    title: markdown_trim_reference_title(title),
  })
}

///|
fn markdown_trim_reference_title(title : String) -> String {
  let chars = title.to_array()
  if chars.length() >= 2 &&
    (
      (chars[0] == '"' && chars[chars.length() - 1] == '"') ||
      (chars[0] == '\'' && chars[chars.length() - 1] == '\'')
    ) {
    String::from_array(chars[1:chars.length() - 1])
  } else {
    title
  }
}

///|
fn markdown_reference_target(
  definitions : Array[MarkdownReferenceDefinition],
  label : String,
) -> String {
  let normalized = markdown_reference_label_key(label)
  for definition in definitions {
    if markdown_reference_label_key(definition.label) == normalized {
      return definition.url
    }
  }
  label
}

///|
fn markdown_reference_label_key(label : String) -> String {
  label.trim().to_owned().to_lower()
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
    HtmlInline(html~, ..) => markdown_html_inline_source(html)
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
      Table(..) => ()
      FootnoteDefinition(label~, children~, ..) =>
        lines.push("[^" + label + "]: " + markdown_blocks_text(children))
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
fn markdown_heading_visible_source_text(source : String) -> String {
  let chars = source.trim().to_owned().to_array()
  let mut start = 0
  while start < chars.length() && chars[start] == '#' {
    start = start + 1
  }
  if start < chars.length() && chars[start] == ' ' {
    start = start + 1
  }
  let mut end = chars.length()
  while end > start && chars[end - 1] == '#' {
    end = end - 1
  }
  while end > start && chars[end - 1] == ' ' {
    end = end - 1
  }
  String::from_array(chars[start:end])
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
      let font = {
        ..base,
        size: base.size * markdown_heading_size_scale(level),
        weight: 700,
      }
      @core.RichTextBlock::new(
        runs=markdown_inlines_to_rich_text(block.inlines, font),
        font=Some(font),
        line_height=Some(base.size * markdown_heading_line_height_scale(level)),
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
        runs=markdown_code_block_runs(block, base),
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
    FootnoteDefinition(label) =>
      @core.RichTextBlock::new(
        runs=[
          @core.RichTextRun::new(
            text="[^" + label + "]: ",
            visual_text=Some(label),
            font=Some({ ..base, size: base.size * 0.78, weight: 700 }),
            color=Some(@core.Color::black().multiply_alpha(0.58)),
            background=Some(
              @core.Brush::solid(
                @core.Color::rgba(r=0.18, g=0.4, b=0.7, a=0.08),
              ),
            ),
            background_radius=4.0,
          ),
          ..markdown_inlines_to_rich_text(block.inlines, base),
        ],
        color=Some(@core.Color::black().multiply_alpha(0.82)),
        border_left=Some(
          @core.BorderStyle::new(
            brush=@core.Brush::solid(@core.Color::black().multiply_alpha(0.22)),
            width=3.0,
          ),
        ),
        inset={ top: 2.0, right: 0.0, bottom: 2.0, left: 12.0 },
        line_height=Some(base.size * 1.45),
      )
    HtmlBlock =>
      @core.RichTextBlock::new(
        runs=[
          @core.RichTextRun::new(
            text=block.text,
            font=Some({
              ..base,
              families: @core.FontFamilyStack::monospace(),
              size: base.size * 0.9,
            }),
            color=Some(@core.Color::black().multiply_alpha(0.7)),
          ),
        ],
        background=Some(
          @core.Brush::solid(@core.Color::rgba(r=0.12, g=0.12, b=0.12, a=0.06)),
        ),
        inset={ top: 4.0, right: 10.0, bottom: 4.0, left: 10.0 },
        line_height=Some(base.size * 1.25),
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
fn markdown_code_block_runs(
  block : MarkdownBlock,
  base : @core.FontSpec,
) -> Array[@core.RichTextRun] {
  let font = {
    ..base,
    families: @core.FontFamilyStack::monospace(),
    size: base.size * 0.92,
  }
  match block.code_language {
    Some(language) =>
      [
        @core.RichTextRun::new(
          text=language,
          font=Some({ ..font, size: base.size * 0.78, weight: 700 }),
          visual_text=Some(language),
          color=Some(@core.Color::black().multiply_alpha(0.56)),
        ),
        @core.RichTextRun::new(text="\n" + block.text, font=Some(font)),
      ]
    None => [@core.RichTextRun::new(text=block.text, font=Some(font))]
  }
}

///|
fn markdown_heading_size_scale(level : Int) -> Double {
  if level <= 1 {
    1.45
  } else if level == 2 {
    1.22
  } else if level == 3 {
    1.08
  } else if level == 4 {
    1.0
  } else if level == 5 {
    0.94
  } else {
    0.9
  }
}

///|
fn markdown_heading_line_height_scale(level : Int) -> Double {
  if level <= 1 {
    2.0
  } else if level == 2 {
    1.65
  } else if level == 3 {
    1.45
  } else {
    1.35
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
      let aligns = block.table_alignments
      let mut line_offset = 0
      for index in 0..<lines.length() {
        let cells : Array[@core.RichTextTableCell] = []
        let source_line = lines[index]
        for cell in markdown_table_cell_ranges_for_line(source_line) {
          cells.push({
            text: cell.text,
            header: index == 0,
            align: markdown_table_alignment_at(aligns, cells.length()),
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
fn markdown_table_alignments_for_separator(
  line : String,
) -> Array[@core.TextAlign?] {
  let aligns : Array[@core.TextAlign?] = []
  for cell in markdown_split_table_cells(line) {
    aligns.push(markdown_table_alignment_for_separator_cell(cell))
  }
  aligns
}

///|
fn markdown_table_alignment_for_separator_cell(
  cell : String,
) -> @core.TextAlign? {
  let trimmed = cell.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() == 0 {
    return None
  }
  let leading = chars[0] == ':'
  let trailing = chars[chars.length() - 1] == ':'
  if leading && trailing {
    Some(@core.TextAlign::TextCenter)
  } else if trailing {
    Some(@core.TextAlign::TextEnd)
  } else {
    None
  }
}

///|
fn markdown_table_alignment_at(
  aligns : Array[@core.TextAlign?],
  index : Int,
) -> @core.TextAlign? {
  if index >= 0 && index < aligns.length() {
    aligns[index]
  } else {
    None
  }
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
    FootnoteReference => inline.text
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
  if inline.kind is HtmlInline {
    return markdown_html_inline_source(inline.text)
  }
  if inline.kind is FootnoteReference {
    return "[^" + inline.text + "]"
  }
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
    FootnoteReference => { ..font, size: font.size * 0.76, weight: 700 }
    HtmlInline =>
      {
        ..font,
        families: @core.FontFamilyStack::named("SFMono-Regular")
        .with_fallback(@core.FontFamily::UiMonospace)
        .with_fallback(@core.FontFamily::Monospace),
        size: font.size * 0.9,
      }
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
    FootnoteReference =>
      Some(@core.Brush::solid(@core.Color::rgba(r=0.18, g=0.4, b=0.7, a=0.08)))
    HtmlInline =>
      Some(@core.Brush::solid(@core.Color::black().multiply_alpha(0.06)))
    Plain | Bold | Italic | Strikethrough | Link | Autolink => None
  }
}

///|
fn markdown_inline_decoration(
  kind : MarkdownInlineKind,
) -> @core.RichTextDecoration? {
  match kind {
    Strikethrough => Some(@core.RichTextDecoration::Strikethrough)
    Plain
    | Bold
    | Italic
    | Code
    | Link
    | Autolink
    | Image
    | FootnoteReference
    | HtmlInline => None
  }
}

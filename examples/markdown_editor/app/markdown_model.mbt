///|
enum MarkdownInlineKind {
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
struct MarkdownInline {
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
enum MarkdownBlockKind {
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
struct MarkdownBlock {
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
struct MarkdownFrontMatterParseResult {
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
fn parse_markdown(text : String) -> Array[MarkdownBlock] {
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
fn parse_markdown_inlines(text : String) -> Array[MarkdownInline] {
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

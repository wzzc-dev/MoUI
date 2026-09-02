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
priv struct MarkdownFrontMatterParseResult {
  block : MarkdownBlock
  next_index : Int
}

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
            match markdown_html_block_at(lines, index) {
              Some(html) => {
                blocks.push(html.block)
                index = html.end_index
              }
              None =>
                match markdown_table_block_at(lines, index) {
                  Some(table) => {
                    blocks.push(table.block)
                    index = table.end_index
                  }
                  None =>
                    match
                      markdown_setext_heading_block_at(
                        lines, index, definitions,
                      ) {
                      Some(heading) => {
                        blocks.push(heading.block)
                        index = heading.end_index
                      }
                      None =>
                        match markdown_indented_code_block_at(lines, index) {
                          Some(code) => {
                            blocks.push(code.block)
                            index = code.end_index
                          }
                          None =>
                            match
                              markdown_soft_wrapped_paragraph_block_at(
                                lines, index, definitions,
                              ) {
                              Some(paragraph) => {
                                blocks.push(paragraph.block)
                                index = paragraph.end_index
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
struct MarkdownHtmlBlockParseResult {
  block : MarkdownBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_html_block_at(
  lines : Array[String],
  index : Int,
) -> MarkdownHtmlBlockParseResult? {
  if index < 0 || index >= lines.length() {
    return None
  }
  if markdown_html_block_comment_start(lines[index]) {
    return markdown_html_comment_block_at(lines, index)
  }
  if markdown_html_block_processing_instruction_start(lines[index]) {
    return markdown_html_processing_instruction_block_at(lines, index)
  }
  if markdown_html_block_cdata_start(lines[index]) {
    return markdown_html_cdata_block_at(lines, index)
  }
  match markdown_html_block_start_tag(lines[index]) {
    Some(tag) => Some(markdown_html_tag_block_at(lines, index, tag))
    None => None
  }
}

///|
fn markdown_html_comment_block_at(
  lines : Array[String],
  index : Int,
) -> MarkdownHtmlBlockParseResult? {
  let html_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    html_lines.push(lines[next])
    if markdown_html_block_comment_end(lines[next]) {
      return Some(markdown_html_block_result(html_lines, next))
    }
    next = next + 1
  }
  Some(markdown_html_block_result(html_lines, next - 1))
}

///|
fn markdown_html_processing_instruction_block_at(
  lines : Array[String],
  index : Int,
) -> MarkdownHtmlBlockParseResult? {
  let html_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    html_lines.push(lines[next])
    if markdown_html_block_processing_instruction_end(lines[next]) {
      return Some(markdown_html_block_result(html_lines, next))
    }
    next = next + 1
  }
  Some(markdown_html_block_result(html_lines, next - 1))
}

///|
fn markdown_html_cdata_block_at(
  lines : Array[String],
  index : Int,
) -> MarkdownHtmlBlockParseResult? {
  let html_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    html_lines.push(lines[next])
    if markdown_html_block_cdata_end(lines[next]) {
      return Some(markdown_html_block_result(html_lines, next))
    }
    next = next + 1
  }
  Some(markdown_html_block_result(html_lines, next - 1))
}

///|
fn markdown_html_tag_block_at(
  lines : Array[String],
  index : Int,
  tag : String,
) -> MarkdownHtmlBlockParseResult {
  let html_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    if next > index &&
      markdown_blank_line(lines[next]) &&
      !markdown_html_block_tag_keeps_blank_lines(tag) {
      break
    }
    html_lines.push(lines[next])
    if markdown_html_block_line_closes_tag(lines[next], tag) ||
      (next == index && markdown_html_block_line_self_closes(lines[next])) {
      return markdown_html_block_result(html_lines, next)
    }
    next = next + 1
  }
  markdown_html_block_result(html_lines, next - 1)
}

///|
fn markdown_html_block_result(
  html_lines : Array[String],
  end_index : Int,
) -> MarkdownHtmlBlockParseResult {
  {
    block: markdown_block(HtmlBlock, markdown_join_lines(html_lines)),
    end_index,
  }
}

///|
fn markdown_html_block_comment_start(line : String) -> Bool {
  markdown_html_block_trimmed_start(line).has_prefix("<!--")
}

///|
fn markdown_html_block_comment_end(line : String) -> Bool {
  line.contains("-->")
}

///|
fn markdown_html_block_processing_instruction_start(line : String) -> Bool {
  markdown_html_block_trimmed_start(line).has_prefix("<?")
}

///|
fn markdown_html_block_processing_instruction_end(line : String) -> Bool {
  line.contains("?>")
}

///|
fn markdown_html_block_cdata_start(line : String) -> Bool {
  markdown_html_block_trimmed_start(line).has_prefix("<![CDATA[")
}

///|
fn markdown_html_block_cdata_end(line : String) -> Bool {
  line.contains("]]>")
}

///|
fn markdown_html_block_start_tag(line : String) -> String? {
  let chars = line.to_array()
  let indent = markdown_html_block_indent(chars)
  if indent < 0 || indent >= chars.length() || chars[indent] != '<' {
    return None
  }
  let name_start = indent + 1
  if name_start >= chars.length() ||
    chars[name_start] == '/' ||
    !markdown_html_tag_name_start_char(chars[name_start]) {
    return None
  }
  let mut name_end = name_start + 1
  while name_end < chars.length() &&
        markdown_html_tag_name_char(chars[name_end]) {
    name_end = name_end + 1
  }
  let tag = String::from_array(chars[name_start:name_end]).to_lower()
  if markdown_html_block_tag_name_allowed(tag) {
    Some(tag)
  } else {
    None
  }
}

///|
fn markdown_html_block_indent(chars : Array[Char]) -> Int {
  let mut index = 0
  while index < chars.length() && chars[index] == ' ' {
    index = index + 1
  }
  if index > 3 || (index < chars.length() && chars[index] == '\t') {
    -1
  } else {
    index
  }
}

///|
fn markdown_html_block_trimmed_start(line : String) -> String {
  let chars = line.to_array()
  let indent = markdown_html_block_indent(chars)
  if indent < 0 {
    ""
  } else {
    String::from_array(chars[indent:])
  }
}

///|
fn markdown_html_block_tag_name_allowed(tag : String) -> Bool {
  match tag {
    "address"
    | "article"
    | "aside"
    | "base"
    | "basefont"
    | "blockquote"
    | "body"
    | "caption"
    | "center"
    | "col"
    | "colgroup"
    | "dd"
    | "details"
    | "dialog"
    | "dir"
    | "div"
    | "dl"
    | "dt"
    | "fieldset"
    | "figcaption"
    | "figure"
    | "footer"
    | "form"
    | "frame"
    | "frameset"
    | "h1"
    | "h2"
    | "h3"
    | "h4"
    | "h5"
    | "h6"
    | "head"
    | "header"
    | "hr"
    | "html"
    | "iframe"
    | "legend"
    | "li"
    | "link"
    | "main"
    | "menu"
    | "menuitem"
    | "nav"
    | "noframes"
    | "ol"
    | "optgroup"
    | "option"
    | "p"
    | "param"
    | "search"
    | "section"
    | "summary"
    | "table"
    | "tbody"
    | "td"
    | "tfoot"
    | "th"
    | "thead"
    | "title"
    | "tr"
    | "track"
    | "ul" => true
    _ => false
  }
}

///|
fn markdown_html_block_line_closes_tag(line : String, tag : String) -> Bool {
  line.to_lower().contains("</" + tag + ">")
}

///|
fn markdown_html_block_line_self_closes(line : String) -> Bool {
  markdown_html_block_trimmed_start(line).trim().to_owned().has_suffix("/>")
}

///|
/// Gallery containers commonly use blank lines to separate image rows. Keep
/// scanning these containers until their own closing tag instead of treating a
/// formatting blank as the end of the HTML block.
fn markdown_html_block_tag_keeps_blank_lines(tag : String) -> Bool {
  tag == "div" || tag == "center"
}

///|
struct MarkdownSetextHeadingParseResult {
  block : MarkdownBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_setext_heading_block_at(
  lines : Array[String],
  index : Int,
  definitions : Array[MarkdownReferenceDefinition],
) -> MarkdownSetextHeadingParseResult? {
  let heading_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    if heading_lines.length() > 0 {
      match markdown_setext_underline_level(lines[next]) {
        Some(level) => {
          let text = markdown_join_lines(heading_lines)
          return Some({
            block: {
              kind: MarkdownBlockKind::Heading(level),
              text,
              inlines: parse_markdown_inlines_with_definitions(
                text, definitions,
              ),
              table_alignments: [],
              code_language: None,
            },
            end_index: next,
          })
        }
        None => ()
      }
    }
    if markdown_setext_heading_content_line(lines, next) {
      heading_lines.push(lines[next].trim().to_owned())
      next = next + 1
    } else {
      return None
    }
  }
  None
}

///|
fn markdown_setext_heading_content_line(
  lines : Array[String],
  index : Int,
) -> Bool {
  if index < 0 || index >= lines.length() {
    return false
  }
  let line = lines[index]
  if line.trim().to_owned() == "" ||
    markdown_opening_code_fence(line) is Some(_) {
    return false
  }
  markdown_is_setext_paragraph_candidate(line)
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
struct MarkdownIndentedCodeParseResult {
  block : MarkdownBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_indented_code_block_at(
  lines : Array[String],
  index : Int,
) -> MarkdownIndentedCodeParseResult? {
  if !markdown_indented_code_line(lines, index) {
    return None
  }
  let code_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    if markdown_indented_code_line(lines, next) {
      code_lines.push(markdown_indented_code_line_content(lines[next]))
      next = next + 1
    } else if markdown_blank_line(lines[next]) {
      match markdown_next_indented_code_line_index(lines, next + 1) {
        Some(code_index) =>
          while next < code_index {
            code_lines.push("")
            next = next + 1
          }
        None => break
      }
    } else {
      break
    }
  }
  Some({
    block: markdown_code_block(markdown_join_lines(code_lines), None),
    end_index: next - 1,
  })
}

///|
fn markdown_next_indented_code_line_index(
  lines : Array[String],
  start : Int,
) -> Int? {
  let mut index = start
  while index < lines.length() && markdown_blank_line(lines[index]) {
    index = index + 1
  }
  if index < lines.length() && markdown_indented_code_line(lines, index) {
    Some(index)
  } else {
    None
  }
}

///|
fn markdown_blank_line(line : String) -> Bool {
  line.trim().to_owned() == ""
}

///|
fn markdown_indented_code_line(lines : Array[String], index : Int) -> Bool {
  if index < 0 || index >= lines.length() {
    return false
  }
  markdown_indented_code_content_offset(lines[index]) > 0
}

///|
fn markdown_indented_code_line_content(line : String) -> String {
  let chars = line.to_array()
  let offset = markdown_indented_code_content_offset(line)
  String::from_array(chars[markdown_min_int(offset, chars.length()):])
}

///|
fn markdown_indented_code_content_offset(line : String) -> Int {
  let chars = line.to_array()
  let mut index = 0
  let mut column = 0
  while index < chars.length() && column < 4 {
    if chars[index] == ' ' {
      column = column + 1
      index = index + 1
    } else if chars[index] == '\t' {
      column = markdown_next_tab_stop(column)
      index = index + 1
    } else {
      break
    }
  }
  if column >= 4 {
    index
  } else {
    0
  }
}

///|
fn markdown_next_tab_stop(column : Int) -> Int {
  (column / 4 + 1) * 4
}

///|
fn markdown_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
struct MarkdownParagraphParseResult {
  block : MarkdownBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_soft_wrapped_paragraph_block_at(
  lines : Array[String],
  index : Int,
  definitions : Array[MarkdownReferenceDefinition],
) -> MarkdownParagraphParseResult? {
  if !markdown_soft_wrapped_paragraph_line(lines, index) {
    return None
  }
  let paragraph_lines : Array[String] = [lines[index]]
  let mut next = index + 1
  while next < lines.length() &&
        markdown_setext_heading_level_at(lines, next) is None &&
        markdown_soft_wrapped_paragraph_line(lines, next) {
    paragraph_lines.push(lines[next])
    next = next + 1
  }
  if paragraph_lines.length() < 2 {
    return None
  }
  let text = markdown_join_lines(paragraph_lines)
  Some({
    block: {
      kind: MarkdownBlockKind::Paragraph,
      text,
      inlines: parse_markdown_inlines_with_definitions(text, definitions),
      table_alignments: [],
      code_language: None,
    },
    end_index: next - 1,
  })
}

///|
fn markdown_soft_wrapped_paragraph_line(
  lines : Array[String],
  index : Int,
) -> Bool {
  if index < 0 || index >= lines.length() {
    return false
  }
  let line = lines[index]
  if line.trim().to_owned() == "" ||
    markdown_opening_code_fence(line) is Some(_) ||
    markdown_table_block_at(lines, index) is Some(_) ||
    markdown_setext_heading_level_at(lines, index) is Some(_) {
    return false
  }
  match @md.parse(line).document.children {
    [Paragraph(_)] => true
    _ => false
  }
}

///|
priv struct MarkdownCodeFenceInfo {
  marker : String
  info : String?
}

///|
fn markdown_opening_code_fence(line : String) -> MarkdownCodeFenceInfo? {
  let chars = line.to_array()
  let indent = markdown_leading_indent_length(chars)
  if !markdown_code_fence_indent_allowed(chars, indent) ||
    chars.length() < indent + 3 {
    return None
  }
  let fence_char = chars[indent]
  if (fence_char != '`' && fence_char != '~') ||
    chars[indent + 1] != fence_char ||
    chars[indent + 2] != fence_char {
    return None
  }
  let mut fence_end = indent + 3
  while fence_end < chars.length() && chars[fence_end] == fence_char {
    fence_end = fence_end + 1
  }
  for index in fence_end..<chars.length() {
    if fence_char == '`' && chars[index] == fence_char {
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
  if !markdown_code_fence_indent_allowed(chars, indent) ||
    fence_chars.length() < 3 ||
    chars.length() < indent + fence_chars.length() {
    return false
  }
  for index in 0..<fence_chars.length() {
    if chars[indent + index] != fence_chars[index] {
      return false
    }
  }
  let mut index = indent + fence_chars.length()
  let fence_char = fence_chars[0]
  while index < chars.length() && chars[index] == fence_char {
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
fn markdown_code_fence_indent_allowed(
  chars : Array[Char],
  indent : Int,
) -> Bool {
  if indent > 3 {
    return false
  }
  for index in 0..<indent {
    if chars[index] == '\t' {
      return false
    }
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
      let text = markdown_quote_block_text(children, source_text)
      blocks.push({
        kind: MarkdownBlockKind::Blockquote,
        text,
        inlines: parse_markdown_inlines_with_definitions(text, definitions),
        table_alignments: [],
        code_language: None,
      })
    }
    BulletList(items~, ..) =>
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
/// Quote lines are parsed per source line, so a fenced code block inside
/// a blockquote flattens its fence-marker lines (`> ```lang` / `> ``` `)
/// to an empty quote block, rendering two blank quote rows around the
/// quoted code. Keep the fence text visible so those rows carry their
/// source content instead of blank space.
fn markdown_quote_block_text(
  children : Array[@md.Block],
  source_text : String?,
) -> String {
  let text = markdown_blocks_text(children)
  if text != "" {
    return text
  }
  match source_text {
    None => text
    Some(source_text) => {
      let content = markdown_editor_strip_block_marker(source_text)
      if content.trim_start().has_prefix("```") ||
        content.trim_start().has_prefix("~~~") {
        content
      } else {
        text
      }
    }
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

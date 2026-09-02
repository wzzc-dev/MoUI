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
priv struct MarkdownReferenceDefinition {
  label : String
  url : String
}

///|
fn markdown_inline(
  text : String,
  kind : MarkdownInlineKind,
  target? : String? = None,
) -> MarkdownInline {
  { text, kind, target }
}

///|
struct MarkdownHtmlEntityDecodeResult {
  ch : Char
  end : Int
} derive(Eq, Debug)

///|
fn markdown_decode_html_entities(text : String) -> String {
  let chars = text.to_array()
  let decoded : Array[Char] = []
  let mut index = 0
  while index < chars.length() {
    match markdown_html_entity_decode_at(chars, index) {
      Some(entity) => {
        decoded.push(entity.ch)
        index = entity.end
      }
      None => {
        decoded.push(chars[index])
        index = index + 1
      }
    }
  }
  String::from_array(decoded)
}

///|
fn markdown_html_entity_decode_at(
  chars : Array[Char],
  start : Int,
) -> MarkdownHtmlEntityDecodeResult? {
  if start < 0 || start >= chars.length() || chars[start] != '&' {
    return None
  }
  let mut end = start + 1
  while end < chars.length() && chars[end] != ';' && end - start <= 8 {
    end = end + 1
  }
  if end >= chars.length() || chars[end] != ';' {
    return None
  }
  match
    markdown_html_entity_char(
      String::from_array(chars[start + 1:end]).to_lower(),
    ) {
    Some(ch) => Some({ ch, end: end + 1 })
    None => None
  }
}

///|
fn markdown_html_entity_char(name : String) -> Char? {
  match markdown_named_html_entity_char(name) {
    Some(ch) => Some(ch)
    None => markdown_numeric_html_entity_char(name)
  }
}

///|
fn markdown_named_html_entity_char(name : String) -> Char? {
  match name {
    "amp" => Some('&')
    "lt" => Some('<')
    "gt" => Some('>')
    "quot" => Some('"')
    "apos" => Some('\'')
    "nbsp" => Some(' ')
    _ => None
  }
}

///|
fn markdown_numeric_html_entity_char(name : String) -> Char? {
  let chars = name.to_array()
  if chars.length() < 2 || chars[0] != '#' {
    return None
  }
  let (start, radix) = if chars.length() >= 3 &&
    (chars[1] == 'x' || chars[1] == 'X') {
    (2, 16)
  } else {
    (1, 10)
  }
  match markdown_parse_html_entity_number(chars, start, radix) {
    Some(value) => value.to_char()
    None => None
  }
}

///|
fn markdown_parse_html_entity_number(
  chars : Array[Char],
  start : Int,
  radix : Int,
) -> Int? {
  if start >= chars.length() {
    return None
  }
  let mut value = 0
  for index in start..<chars.length() {
    match markdown_html_entity_digit_value(chars[index], radix) {
      Some(digit) => {
        value = value * radix + digit
        if value > 1114111 {
          return None
        }
      }
      None => return None
    }
  }
  Some(value)
}

///|
fn markdown_html_entity_digit_value(ch : Char, radix : Int) -> Int? {
  let value = if ch >= '0' && ch <= '9' {
    ch.to_int() - '0'.to_int()
  } else if ch >= 'a' && ch <= 'f' {
    ch.to_int() - 'a'.to_int() + 10
  } else if ch >= 'A' && ch <= 'F' {
    ch.to_int() - 'A'.to_int() + 10
  } else {
    return None
  }
  if value < radix {
    Some(value)
  } else {
    None
  }
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
      markdown_inlines_from_ast(@md.parse_inlines(text), definitions),
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
  ast : Array[@md.Inline],
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
  inline : @md.Inline,
  definitions : Array[MarkdownReferenceDefinition],
) -> Unit {
  match inline {
    Text(content~, ..) =>
      if content != "" {
        spans.push(
          markdown_inline(markdown_decode_html_entities(content), Plain),
        )
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
      spans.push(
        markdown_inline(
          markdown_decode_html_entities(alt),
          Image,
          target=Some(url),
        ),
      )
    RefImage(alt~, label~, ..) =>
      spans.push(
        markdown_inline(
          markdown_decode_html_entities(alt),
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
  for definition in @md.parse(source).definitions {
    definitions.push({
      label: markdown_reference_label_key(definition.label),
      url: definition.url,
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
  if rest_chars[0] == '<' {
    let mut end = 1
    while end < rest_chars.length() && rest_chars[end] != '>' {
      end = end + 1
    }
    if end >= rest_chars.length() {
      return None
    }
    url = String::from_array(rest_chars[1:end])
  } else {
    let mut end = 0
    while end < rest_chars.length() &&
          rest_chars[end] != ' ' &&
          rest_chars[end] != '\t' {
      end = end + 1
    }
    url = String::from_array(rest_chars[:end])
  }
  if url == "" {
    return None
  }
  Some({ label: markdown_reference_label_key(label), url })
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
  let normalized : Array[Char] = []
  let chars = label.trim().to_owned().to_array()
  let mut in_space = false
  for ch in chars {
    if ch == ' ' || ch == '\t' || ch == '\n' {
      if normalized.length() > 0 && !in_space {
        normalized.push(' ')
      }
      in_space = true
    } else {
      normalized.push(ch)
      in_space = false
    }
  }
  String::from_array(normalized).to_lower()
}

///|
fn markdown_inline_text(ast : Array[@md.Inline]) -> String {
  let parts : Array[String] = []
  for inline in ast {
    parts.push(markdown_inline_plain_text(inline))
  }
  markdown_join_lines(parts)
}

///|
fn markdown_inline_plain_text(inline : @md.Inline) -> String {
  match inline {
    Text(content~, ..) => markdown_decode_html_entities(content)
    SoftBreak(..) | HardBreak(..) => "\n"
    Emphasis(children~, ..)
    | Strong(children~, ..)
    | Strikethrough(children~, ..)
    | Link(children~, ..)
    | RefLink(children~, ..) => markdown_inline_text(children)
    Code(content~, ..) => content
    WikiLink(label~, target~, ..) => if label == "" { target } else { label }
    Autolink(url~, ..) => url
    Image(alt~, ..) | RefImage(alt~, ..) => markdown_decode_html_entities(alt)
    HtmlInline(html~, ..) => markdown_html_inline_source(html)
    FootnoteReference(label~, ..) => label
  }
}

///|
fn markdown_blocks_text(blocks : Array[@md.Block]) -> String {
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
fn markdown_list_item_text(item : @md.ListItem) -> String {
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
  let chars = source.to_array()
  let start = markdown_heading_source_content_start_offset(source)
  let end = markdown_heading_source_content_end_offset(source, start)
  String::from_array(chars[start:end])
}

///|
fn markdown_heading_source_content_start_offset(source : String) -> Int {
  let chars = source.to_array()
  let mut index = 0
  while index < chars.length() && (chars[index] == ' ' || chars[index] == '\t') {
    index = index + 1
  }
  while index < chars.length() && chars[index] == '#' {
    index = index + 1
  }
  while index < chars.length() && (chars[index] == ' ' || chars[index] == '\t') {
    index = index + 1
  }
  index
}

///|
fn markdown_heading_source_content_end_offset(
  source : String,
  content_start : Int,
) -> Int {
  let chars = source.to_array()
  let mut end = chars.length()
  while end > content_start && (chars[end - 1] == ' ' || chars[end - 1] == '\t') {
    end = end - 1
  }
  let mut hash_start = end
  while hash_start > content_start && chars[hash_start - 1] == '#' {
    hash_start = hash_start - 1
  }
  if hash_start < end &&
    hash_start > content_start &&
    (chars[hash_start - 1] == ' ' || chars[hash_start - 1] == '\t') {
    let mut content_end = hash_start - 1
    while content_end > content_start &&
          (chars[content_end - 1] == ' ' || chars[content_end - 1] == '\t') {
      content_end = content_end - 1
    }
    content_end
  } else {
    end
  }
}

///|
/// Returns true if the heading source should be rendered as a heading block:
/// it must have leading `#` markers, a space/tab separator, AND non-empty
/// content after the separator (e.g., `"# text"`, `"## content"`).
/// Returns false for bare markers with no separator (`"#"`, `"##"`) or markers
/// with a separator but no content yet (`"# "`, `"## "`), which are treated as
/// plain text so the user can still see the `#` they typed.
fn markdown_heading_source_is_renderable(source : String) -> Bool {
  let chars = source.to_array()
  let mut index = 0
  // Skip leading whitespace (indent) before the # markers.
  while index < chars.length() && (chars[index] == ' ' || chars[index] == '\t') {
    index = index + 1
  }
  let marker_start = index
  while index < chars.length() && chars[index] == '#' {
    index = index + 1
  }
  if index == marker_start {
    return false
  }
  // After the # markers, require a space/tab separator.
  if index >= chars.length() || (chars[index] != ' ' && chars[index] != '\t') {
    return false
  }
  // Skip the separator and any trailing whitespace; there must be actual
  // content after the marker for this to be a rendered heading. A bare "# "
  // (marker + separator + no content) is treated as plain text so the user
  // can still see the # they typed.
  while index < chars.length() && (chars[index] == ' ' || chars[index] == '\t') {
    index = index + 1
  }
  index < chars.length()
}

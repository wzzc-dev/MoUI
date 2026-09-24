///|
pub(all) enum MarkdownInlineKind {
  Plain
  Bold
  Italic
  Code
  Strikethrough
  Highlight
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
  { text, kind, target, }
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
    Some(ch) => Some({ ch, end: end + 1, })
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
        } else if chars[index] == '`' {
          // A backtick run must close on its own source line, otherwise it is
          // literal text. CommonMark instead lets it run to the next matching
          // run anywhere in the paragraph, and a paragraph here can be an
          // entire document: one stray backtick in a novel-sized block closed
          // 32k lines later and produced a single multi-megabyte code span,
          // which the layout then tried to measure in one piece. Emitting the
          // run as plain text keeps the rest of the line parseable.
          let run_end = markdown_backtick_run_end(chars, index)
          match markdown_backtick_run_closer(chars, run_end, run_end - index) {
            // A matched run opens a span that closes on this line. Skip the
            // whole span so a backtick *inside* it (``a`b``) is never examined
            // on its own and mistaken for an unclosed one; the segment handed
            // to the parser still contains it verbatim.
            Some(closer_end) => index = closer_end
            None => {
              markdown_append_parsed_inline_segment(
                spans,
                String::from_array(chars[start:index]),
                definitions,
              )
              spans.push(
                markdown_inline(String::from_array(chars[index:run_end]), Plain),
              )
              index = run_end
              start = run_end
            }
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
  // DISABLED: merging adjacent plain spans aborts the momark zen-mode editing
  // test. The backtick rule above is what fixes the runaway code span; the
  // merge only tidied the inline array, and something downstream depends on
  // the split shape. Re-enable once that dependency is understood.
  spans
}

///|
/// End of the backtick run starting at `start` (exclusive).
fn markdown_backtick_run_end(chars : Array[Char], start : Int) -> Int {
  let mut index = start
  while index < chars.length() && chars[index] == '`' {
    index = index + 1
  }
  index
}

///|
/// End of the next run of exactly `length` backticks, searching only up to the
/// end of the current source line. `None` means the run never closes on this
/// line and is therefore literal text.
fn markdown_backtick_run_closer(
  chars : Array[Char],
  from : Int,
  length : Int,
) -> Int? {
  let mut index = from
  while index < chars.length() && chars[index] != '\n' {
    if chars[index] == '`' {
      let end = markdown_backtick_run_end(chars, index)
      if end - index == length {
        return Some(end)
      }
      index = end
    } else {
      index = index + 1
    }
  }
  None
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
  let before = spans.length()
  spans.append(
    markdown_normalize_html_inlines(
      markdown_inlines_from_ast(
        @md.parse_inlines(markdown_expand_reference_links(text, definitions)),
        definitions,
      ),
    ),
  )
  markdown_restore_trailing_whitespace(spans, before, text)
}

///|
/// mizchi/markdown 0.8 trims trailing blanks from the plain text it emits —
/// its marker-free fast path trims the whole segment — but the editor maps
/// runs back to source offsets by matching run text, so a dropped space
/// shifts every later mapping one character left. Re-attach whatever part of
/// the segment's trailing blank run the parse dropped.
fn markdown_restore_trailing_whitespace(
  spans : Array[MarkdownInline],
  from : Int,
  text : String,
) -> Unit {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && (chars[end - 1] == ' ' || chars[end - 1] == '\t') {
    end = end - 1
  }
  if end == chars.length() {
    return
  }
  if spans.length() == from {
    // The segment was blank only and the parse dropped it entirely.
    spans.push(markdown_inline(String::from_array(chars), Plain))
    return
  }
  let last_index = spans.length() - 1
  let last = spans[last_index]
  let missing = match last.kind {
    Plain => {
      let produced = last.text.to_array()
      let mut kept = 0
      while kept < produced.length() &&
            (produced[produced.length() - 1 - kept] == ' ' ||
            produced[produced.length() - 1 - kept] == '\t') {
        kept = kept + 1
      }
      let segment_blanks = chars.length() - end
      if kept < segment_blanks {
        Some(String::from_array(chars[end : end + segment_blanks - kept]))
      } else {
        None
      }
    }
    _ => Some(String::from_array(chars[end:]))
  }
  match missing {
    Some(restored) =>
      spans[last_index] = { ..last, text: last.text + restored }
    None => ()
  }
}

///|
fn markdown_resolve_reference_inlines(
  inlines : Array[MarkdownInline],
  definitions : Array[MarkdownReferenceDefinition],
) -> Array[MarkdownInline] {
  let resolved : Array[MarkdownInline] = []
  for inline in inlines {
    match inline.kind {
      // The editor's per-line fallback parses with line-local definitions,
      // and mizchi/markdown 0.8 keeps reference syntax as literal text when
      // no definition is in scope at parse time. Re-parse plain spans that
      // still carry brackets against the document-wide set.
      Plain if inline.text.contains("[") =>
        resolved.append(
          parse_markdown_inlines_with_definitions(inline.text, definitions),
        )
      _ =>
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
      HtmlInline =>
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
/// Plain-text projection of an inline html tag: the bracket syntax is
/// stripped so html inside flattened children (link text, preview text)
/// reads as the tag's content — `[<kbd>](url)` flattens to `kbd` — while
/// top-level spans keep the raw tag for the rich text view.
fn markdown_html_inline_plain_text(html : String) -> String {
  let chars = html.to_array()
  let mut start = 0
  let mut end = chars.length()
  if start < end && chars[start] == '<' {
    start = start + 1
  }
  if start < end && chars[start] == '/' {
    start = start + 1
  }
  if end > start && chars[end - 1] == '>' {
    end = end - 1
  }
  if end > start && chars[end - 1] == '/' {
    end = end - 1
  }
  String::from_array(chars[start:end])
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
        markdown_split_plain_highlights(spans, content)
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
    // `mizchi/markdown` 0.8.x 新增的内联指令变体：编辑器暂按普通文本
    // 呈现，取指令 label（为空时回退到指令名）。
    Directive(name~, label~, ..) =>
      spans.push(markdown_inline(if label == "" { name } else { label }, Plain))
  }
}

///|
/// Split a plain text segment on `==mark==` spans so highlighted runs render
/// with their own inline kind. The `@md` parser has no mark node and emits
/// `==...==` as plain text, so highlight spans are recovered here from the
/// plain content: an opening `==` pairs with the next `==` that leaves
/// non-empty inner text, and entity decoding still runs per segment.
fn markdown_split_plain_highlights(
  spans : Array[MarkdownInline],
  content : String,
) -> Unit {
  let chars = content.to_array()
  let length = chars.length()
  let mut segment_start = 0
  let mut index = 0
  while index + 1 < length {
    if chars[index] != '=' || chars[index + 1] != '=' {
      index = index + 1
      continue
    }
    let inner_start = index + 2
    let mut close = inner_start
    let mut found = -1
    while close + 1 < length {
      if chars[close] == '=' && chars[close + 1] == '=' {
        found = close
        break
      }
      close = close + 1
    }
    if found > inner_start {
      if index > segment_start {
        spans.push(
          markdown_inline(
            markdown_decode_html_entities(
              String::from_array(chars[segment_start:index]),
            ),
            Plain,
          ),
        )
      }
      spans.push(
        markdown_inline(
          markdown_decode_html_entities(
            String::from_array(chars[inner_start:found]),
          ),
          Highlight,
        ),
      )
      index = found + 2
      segment_start = index
    } else {
      index = index + 1
    }
  }
  if segment_start < length {
    spans.push(
      markdown_inline(
        markdown_decode_html_entities(String::from_array(chars[segment_start:])),
        Plain,
      ),
    )
  }
}

///|

///|
/// Definition set from the single-line scanner only. The full-parser union
/// below costs a whole-document markdown parse (~700 ms on a 5 MB fixture),
/// which a definition-cache miss would otherwise charge to an interactive
/// keystroke. The scanner catches every single-line definition, including
/// the indented ones inside containers, and the session's incremental apply
/// carries the set forward per edit; multi-line definitions (label and URL
/// on separate lines) are only found by the full-parse paths.
fn markdown_reference_definitions_scan_only(
  source : String,
) -> Array[MarkdownReferenceDefinition] {
  markdown_scan_reference_definitions_fast(source)
}

///|
fn markdown_source_char_is_ascii_or_nbsp_whitespace(c : Char) -> Bool {
  c == ' ' ||
  c == '\t' ||
  c == '\r' ||
  c == '\n' ||
  c == '\u{000B}' ||
  c == '\u{000C}' ||
  c == '\u{00A0}'
}

///|
/// Single-line-scan definition extraction without materializing every
/// line. One pass over the source locates candidate lines by their first
/// non-whitespace character; only candidates are handed to the allocating
/// per-line scanner, so the matching semantics live in exactly one place.
/// On multi-megabyte documents the split-into-lines version spent
/// hundreds of milliseconds per call on line-string and char-array
/// allocations alone.
fn markdown_scan_reference_definitions_fast(
  source : String,
) -> Array[MarkdownReferenceDefinition] {
  let definitions : Array[MarkdownReferenceDefinition] = []
  // One flat char array: a single large allocation beats the per-line
  // string and char-array allocations of the split-into-lines version.
  let chars = source.to_array()
  let n = chars.length()
  let mut index = 0
  while index < n {
    let line_start = index
    while index < n && chars[index] != '\n' {
      index = index + 1
    }
    let line_end = index
    index = index + 1
    // Quick reject on the unmaterialized line: a definition line's
    // trimmed content starts with '['.
    let mut scan = line_start
    while scan < line_end &&
          markdown_source_char_is_ascii_or_nbsp_whitespace(chars[scan]) {
      scan = scan + 1
    }
    if scan >= line_end || chars[scan] != '[' {
      continue
    }
    let line = String::from_array(chars[line_start:line_end])
    match markdown_scan_reference_definition_line(line) {
      Some(definition) => definitions.push(definition)
      None => ()
    }
  }
  definitions
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
  Some({ label: markdown_reference_label_key(label), url, })
}

///|
fn markdown_reference_target(
  definitions : Array[MarkdownReferenceDefinition],
  label : String,
) -> String {
  match markdown_reference_definition_lookup(definitions, label) {
    Some(url) => url
    None => label
  }
}

///|
/// Case-insensitive lookup with collapsed internal whitespace, the matching
/// rule CommonMark applies to link reference labels. Labels stored in
/// `definitions` are already keyed through `markdown_reference_label_key`,
/// which is idempotent, so normalizing both sides here stays correct.
fn markdown_reference_definition_lookup(
  definitions : Array[MarkdownReferenceDefinition],
  label : String,
) -> String? {
  let normalized = markdown_reference_label_key(label)
  for definition in definitions {
    if markdown_reference_label_key(definition.label) == normalized {
      return Some(definition.url)
    }
  }
  None
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
/// `mizchi/markdown` 0.8 resolves reference links while it parses and emits
/// literal text for any label it cannot see, and its inline entry point
/// always parses with an empty definition set. The editor owns the
/// document-wide definition set (with CommonMark label matching), so this
/// pass rewrites every reference form that resolves against it into the
/// equivalent inline link before the segment reaches `@md.parse_inlines`.
/// Unresolvable constructs are copied verbatim, keeping their literal-text
/// rendering. Segments reaching the inline parser never contain complete
/// code spans or HTML tags, so the scan only has to honor backslash escapes
/// and bracket nesting.
fn markdown_expand_reference_links(
  text : String,
  definitions : Array[MarkdownReferenceDefinition],
) -> String {
  if definitions.is_empty() || !text.contains("[") {
    return text
  }
  let chars = text.to_array()
  let output : Array[Char] = []
  let append = chars => output.append(chars)
  let mut index = 0
  let length = chars.length()
  while index < length {
    let ch = chars[index]
    if ch == '\\' && index + 1 < length {
      append([ch, chars[index + 1]])
      index = index + 2
      continue
    }
    let image = ch == '!' &&
      index + 1 < length &&
      chars[index + 1] == '['
    if !image && ch != '[' {
      append([ch])
      index = index + 1
      continue
    }
    let bracket = if image { index + 1 } else { index }
    guard markdown_scan_balanced_bracket(chars, bracket) is Some(close) else {
      append([ch])
      index = index + 1
      continue
    }
    let inner = String::from_array(chars[bracket + 1:close])
    let after = close + 1
    // `](...)` is an inline destination or a failed one — either way the
    // markdown parser owns it and the text must stay verbatim.
    if after < length && chars[after] == '(' {
      append(chars[index:after])
      index = after
      continue
    }
    // Full form `[text][label]` / `![alt][label]`, then collapsed `[]`
    // reusing the link text as label.
    if after < length && chars[after] == '[' {
      if markdown_scan_balanced_bracket(chars, after) is Some(label_close) {
        let label = String::from_array(chars[after + 1:label_close])
        let resolved = if label == "" {
          markdown_reference_definition_lookup(definitions, inner)
        } else {
          markdown_reference_definition_lookup(definitions, label)
        }
        append(
          match resolved {
            Some(url) if markdown_inline_destination_is_expansible(url) =>
              markdown_reference_expansion(image, inner, url).to_array()
            _ => chars[index:label_close + 1]
          },
        )
        index = label_close + 1
        continue
      }
    }
    // Shortcut form `[label]` — only when a definition actually matches.
    match markdown_reference_definition_lookup(definitions, inner) {
      Some(url) if markdown_inline_destination_is_expansible(url) => {
        append(markdown_reference_expansion(image, inner, url).to_array())
        index = after
      }
      _ => {
        append(chars[index:after])
        index = after
      }
    }
  }
  String::from_array(output)
}

///|
/// Index of the `]` matching the `[` at `start`, honoring backslash escapes
/// and nested bracket pairs. `None` when the bracket never closes.
fn markdown_scan_balanced_bracket(
  chars : Array[Char],
  start : Int,
) -> Int? {
  let mut depth = 0
  let mut index = start
  while index < chars.length() {
    match chars[index] {
      '\\' => index = index + 1
      '[' => depth = depth + 1
      ']' => {
        depth = depth - 1
        if depth == 0 {
          return Some(index)
        }
      }
      _ => ()
    }
    index = index + 1
  }
  None
}

///|
/// Whether a definition URL can be re-emitted as an inline destination in
/// angle-bracket form. `<`, `>` and newlines cannot appear unescaped there
/// and a trailing backslash would escape the closing bracket, so those URLs
/// keep their reference form instead.
fn markdown_inline_destination_is_expansible(url : String) -> Bool {
  let mut expansible = true
  for ch in url {
    if ch == '<' || ch == '>' || ch == '\n' || ch == '\\' {
      expansible = false
      break
    }
  }
  expansible
}

///|
fn markdown_reference_expansion(
  image : Bool,
  link_text : String,
  url : String,
) -> String {
  (if image { "![" } else { "[" }) + link_text + "](<" + url + ">)"
}

///|
/// Flattens inline AST nodes into their plain text. Nodes are siblings on
/// one visual line — backslash escapes split `Text` nodes without any
/// source break — so they must concatenate directly. Real breaks only
/// come from SoftBreak/HardBreak node payloads, never from the join.
fn markdown_inline_text(ast : Array[@md.Inline]) -> String {
  let mut text = ""
  for inline in ast {
    text = text + markdown_inline_plain_text(inline)
  }
  text
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
    HtmlInline(html~, ..) => markdown_html_inline_plain_text(html)
    FootnoteReference(label~, ..) => label
    Directive(name~, label~, ..) => if label == "" { name } else { label }
  }
}

///|
fn markdown_blocks_text(blocks : Array[@md.Block]) -> String {
  let lines : Array[String] = []
  for block in blocks {
    append_markdown_block_text(lines, block)
  }
  markdown_join_lines(lines)
}

///|
/// 把单个块压平成纯文本行，追加到 `lines`。供 `markdown_blocks_text`
/// 及嵌套块（引用/脚注/指令/属性注解）递归复用。
fn append_markdown_block_text(lines : Array[String], block : @md.Block) -> Unit {
  match block {
    Paragraph(children~, ..) | Heading(children~, ..) =>
      lines.push(markdown_inline_text(children))
    FencedCode(code~, ..) | IndentedCode(code~, ..) => lines.push(code)
    Blockquote(children~, ..) =>
      for child in children {
        append_markdown_block_text(lines, child)
      }
    BulletList(items~, ..) | OrderedList(items~, ..) =>
      for item in items {
        lines.push(markdown_list_item_text(item))
      }
    ThematicBreak(..) => lines.push("---")
    HtmlBlock(html~, ..) => lines.push(html)
    BlankLines(..) => ()
    Table(..) => ()
    FootnoteDefinition(label~, children~, ..) => {
      lines.push("[^" + label + "]:")
      for child in children {
        append_markdown_block_text(lines, child)
      }
    }
    MathBlock(value~, ..) => lines.push(value)
    Directive(children~, ..) =>
      for child in children {
        append_markdown_block_text(lines, child)
      }
    DefinitionList(items~, ..) =>
      lines.push(markdown_definition_list_text(items))
    Alert(children~, ..) =>
      for child in children {
        append_markdown_block_text(lines, child)
      }
    Attributed(block~, ..) => append_markdown_block_text(lines, block)
  }
}

///|
/// 把定义列表条目压平成纯文本行：每条目的术语一行，其后各条描述各占一行。
fn markdown_definition_list_text(items : Array[@md.DefinitionItem]) -> String {
  let lines : Array[String] = []
  for item in items {
    lines.push(markdown_inline_text(item.term))
    for definition in item.definitions {
      lines.push(markdown_inline_text(definition))
    }
  }
  markdown_join_lines(lines)
}

///|
/// The item's rendered text. When the raw source line is available, the
/// item's content slice comes straight from it with the list marker
/// (`- `/`- [x] `/`1. `/`+ `/`3) `...) stripped: inline markers (`` ` ``/
/// `**`/...) stay in the text, so the item's inlines parse styled exactly
/// like a paragraph's. The AST-flattened fallback loses the markers (and
/// would strip them from the source on edit round-trips), so it stays only
/// for callers without source context (nested lists inside quotes).
fn markdown_list_item_text(
  item : @md.ListItem,
  source_text? : String? = None,
) -> String {
  match source_text {
    Some(source) =>
      match item.children.get(0) {
        Some(Paragraph(span~, ..)) => {
          let chars = source.to_array()
          let start = @core.clamp_int(span.from, 0, chars.length())
          let end = @core.clamp_int(
            @core.min_int(@core.min_int(span.to, item.span.to), chars.length()),
            start,
            chars.length(),
          )
          let slice = String::from_array(chars[start:end])
          let marker_length = markdown_editor_marker_prefix_length(slice)
          if marker_length > 0 {
            String::from_array(slice.to_array()[marker_length:].to_owned())
          } else {
            slice
          }
        }
        _ => markdown_list_item_text_flattened(item)
      }
    None => markdown_list_item_text_flattened(item)
  }
}

///|
fn markdown_list_item_text_flattened(item : @md.ListItem) -> String {
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
fn markdown_heading_visible_source_text(source : StringView) -> String {
  let chars = source.to_array()
  let start = markdown_heading_source_content_start_offset(source)
  let end = markdown_heading_source_content_end_offset(source, start)
  String::from_array(chars[start:end])
}

///|
fn markdown_heading_source_content_start_offset(source : StringView) -> Int {
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
  source : StringView,
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

///|
pub(all) struct MarkdownSourceRange {
  // Mutable so hot-path suffix shifts (the incremental apply moving the
  // ranges of up to every block after an edit) can update the two ints in
  // place instead of allocating a fresh record per block per keystroke.
  mut start : Int
  mut end : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditorBlock {
  block : MarkdownBlock
  // Absolute source offsets are shifted in place by the incremental apply;
  // every session value derived from an edit shares these records (same
  // contract as the text store). Callers must not cache the ranges across
  // an apply — read them at use time.
  mut source_range : MarkdownSourceRange
  mut content_range : MarkdownSourceRange
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditorSnapshot {
  source : String
  blocks : Array[MarkdownEditorBlock]
  rich_text : RichTextDocument
  line_count : Int
  word_count : Int
  reading_minutes : Int
  active_heading : String
  metadata_title : String
  metadata_tags : Array[String]
  outline : Array[MarkdownEditorOutlineItem]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditorOutlineItem {
  level : Int
  title : String
  // Absolute source offset, shifted in place by the incremental apply's
  // fast path (same shared-mutable contract as the block ranges).
  mut source_start : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditorSelection {
  caret : Int
  selection : @core.TextRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditorEditResult {
  source : String
  caret : Int
  selection : @core.TextRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) enum MarkdownEditorCommand {
  Bold
  Italic
  Code
  Strikethrough
  Link
  Image
  SetLinkTarget(String)
  SetImageTarget(String)
  SetCodeLanguage(String)
  SetFootnoteText(String)
  SetHtmlBlockText(String)
  Paragraph
  Heading(Int)
  BulletList
  TaskList
  OrderedList
  Quote
  CodeBlock
  HorizontalRule
  Table
  InsertTableOfContents
  InsertFrontMatter
  DuplicateBlock
  MoveBlockUp
  MoveBlockDown
  InsertTableRow
  InsertTableColumn
  DeleteTableRow
  DeleteTableColumn
  SetTableColumnAlignment(@core.TextAlign?)
} derive(Eq, Debug, ToJson)

///|
priv struct MarkdownLine {
  // A view into the source, not a copy: the shell parse inspects every
  // line of a document and only a fraction of line texts ever become
  // block text; copying all of them was the single largest open cost.
  text : StringView
  start : Int
  end : Int
}

///|
/// Word/line counts, the content digest, and the line views produced by
/// the last `markdown_editor_lines` scan. The line scan already decodes
/// the whole source, so the session builder gets the counts, the
/// digest (mixed into the same pass), and the line views for free at
/// open — no second full-source pass for any of them. The runtime is
/// single-threaded; same memo pattern as
/// `markdown_editor_text_length_cache`.
let markdown_editor_line_scan_cache : Ref[(String, Int, Int, UInt64, Array[MarkdownLine])] = Ref(
  ("", -1, -1, 0UL, []),
)

///|
/// Content digest accumulated by the last `markdown_editor_lines` scan,
/// bit-identical to `rich_text_digest_string(seed, source)` seeded from
/// the document length.
fn markdown_editor_line_scan_cached_digest(
  source : String,
) -> UInt64? {
  let cached = markdown_editor_line_scan_cache.val
  if physical_equal(cached.0, source) {
    Some(cached.3)
  } else {
    ignore(markdown_editor_lines(source))
    let refreshed = markdown_editor_line_scan_cache.val
    if physical_equal(refreshed.0, source) {
      Some(refreshed.3)
    } else {
      None
    }
  }
}

///|
/// The line views of the last scan for `source`, scanning only when the
/// cache holds a different document.
fn markdown_editor_line_scan_cached_lines(source : String) -> Array[MarkdownLine] {
  let cached = markdown_editor_line_scan_cache.val
  if physical_equal(cached.0, source) {
    cached.4
  } else {
    ignore(markdown_editor_lines(source))
    markdown_editor_line_scan_cache.val.4
  }
}

///|
fn markdown_editor_line_count(source : String) -> Int {
  let cached = markdown_editor_line_scan_cache.val
  if cached.1 >= 0 && physical_equal(cached.0, source) {
    cached.2
  } else if source == "" {
    0
  } else {
    let mut count = 1
    for ch in source {
      if ch == '\n' {
        count = count + 1
      }
    }
    count
  }
}

///|
fn markdown_editor_word_count(source : String) -> Int {
  let cached = markdown_editor_line_scan_cache.val
  if cached.1 >= 0 && physical_equal(cached.0, source) {
    cached.1
  } else {
    let mut count = 0
    let mut in_word = false
    for ch in source {
      if ch.is_ascii_whitespace() {
        if in_word {
          count = count + 1
        }
        in_word = false
      } else {
        in_word = true
      }
    }
    if in_word {
      count = count + 1
    }
    count
  }
}

///|
fn markdown_editor_lines(source : String) -> Array[MarkdownLine] {
  // One `StringView` per line: a 3-word view into the source, never a
  // copy. The old version materialized every line as an owned String (or
  // before that an Array[Char]) — on large documents that allocation
  // churn dominated the open cost. `start`/`end` stay in char space
  // (iterator indices, matching the source ranges the parser produces);
  // the view bounds are the matching UTF-16 offsets tracked alongside.
  // The same pass accumulates the document word count, and the line
  // count drops out of the result, so session construction does not
  // rescan the source for either.
  let lines : Array[MarkdownLine] = []
  let mut char_start = 0
  let mut char_index = 0
  let mut unit_start = 0
  let mut unit_offset = 0
  let mut words = 0
  let mut in_word = false
  // The document content digest rides the same scan: seeded from the
  // UTF-16 length exactly like `rich_text_digest_string`, mixed per char.
  let mut digest = rich_text_digest_mix(
    0xcbf29ce484222325UL,
    source.length().to_uint64(),
  )
  for ch in source {
    digest = rich_text_digest_mix(digest, ch.to_int().to_uint64())
    if ch == '\n' {
      if in_word {
        words = words + 1
        in_word = false
      }
      lines.push({
        text: source.sub(start=unit_start, end=unit_offset),
        start: char_start,
        end: char_index,
      })
      unit_offset = unit_offset + ch.utf16_len()
      char_index = char_index + 1
      char_start = char_index
      unit_start = unit_offset
    } else {
      if ch.is_ascii_whitespace() {
        if in_word {
          words = words + 1
        }
        in_word = false
      } else {
        in_word = true
      }
      unit_offset = unit_offset + ch.utf16_len()
      char_index = char_index + 1
    }
  }
  if in_word {
    words = words + 1
  }
  lines.push({
    text: source.sub(start=unit_start, end=unit_offset),
    start: char_start,
    end: char_index,
  })
  let line_count = if source == "" { 0 } else { lines.length() }
  markdown_editor_line_scan_cache.val = (source, words, line_count, digest, lines)
  lines
}

///|
/// `char_length` decodes the whole UTF-8 buffer, and the editor helpers
/// call it on the same source document for every block conversion, caret
/// clamp, and substring. Memoize the last two (source, length) pairs so
/// one keystroke pays the scan at most once even though the control's
/// new source and the session's previous source alternate; the runtime
/// is single-threaded. Comparisons are pointer-identity (`phys_equal`):
/// the sources are long-lived objects per revision, and a content
/// comparison would itself scan megabytes on every miss.
let markdown_editor_text_length_cache : Ref[(String, Int)] = Ref(("", -1))
let markdown_editor_text_length_cache_prev : Ref[(String, Int)] = Ref((
  "",
  -1,
))

///|
pub fn markdown_editor_text_length(source : String) -> Int {
  let cached = markdown_editor_text_length_cache.val
  if cached.1 >= 0 && physical_equal(cached.0, source) {
    cached.1
  } else {
    let previous = markdown_editor_text_length_cache_prev.val
    if previous.1 >= 0 && physical_equal(previous.0, source) {
      // Swap the slots so an A/B/A/B alternation keeps both entries hot.
      markdown_editor_text_length_cache_prev.val = cached
      markdown_editor_text_length_cache.val = previous
      previous.1
    } else {
      let length = source.char_length()
      markdown_editor_text_length_cache_prev.val = cached
      markdown_editor_text_length_cache.val = (source, length)
      length
    }
  }
}

///|
pub fn markdown_editor_substring(
  source : String,
  start : Int,
  end : Int,
) -> String {
  let char_length = markdown_editor_text_length(source)
  let start = markdown_editor_clamp_int(start, 0, char_length)
  let end = markdown_editor_clamp_int(end, start, char_length)
  let source_length = source.length()
  let start_offset = if start == 0 {
    0
  } else if start == char_length {
    source_length
  } else {
    source.offset_of_nth_char(start).unwrap_or(source_length)
  }
  let end_offset = if end == char_length {
    source_length
  } else {
    source.offset_of_nth_char(end).unwrap_or(source_length)
  }
  source.sub(start=start_offset, end=end_offset).to_owned()
}

///|
fn markdown_editor_digit_count(number : Int) -> Int {
  let mut value = number
  let mut count = 1
  while value >= 10 {
    value = value / 10
    count = count + 1
  }
  count
}

///|
fn markdown_editor_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn markdown_editor_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
pub fn markdown_editor_clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

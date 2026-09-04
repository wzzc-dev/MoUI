///|
pub(all) struct MarkdownSourceRange {
  start : Int
  end : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditorBlock {
  block : MarkdownBlock
  source_range : MarkdownSourceRange
  content_range : MarkdownSourceRange
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
  source_start : Int
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
  text : String
  start : Int
  end : Int
}

///|
fn markdown_editor_line_count(source : String) -> Int {
  if source == "" {
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

///|
fn markdown_editor_lines(source : String) -> Array[MarkdownLine] {
  let lines : Array[MarkdownLine] = []
  let current : Array[Char] = []
  let mut start = 0
  let mut offset = 0
  for ch in source {
    if ch == '\n' {
      lines.push({ text: String::from_array(current), start, end: offset })
      current.clear()
      offset = offset + 1
      start = offset
    } else {
      current.push(ch)
      offset = offset + 1
    }
  }
  lines.push({ text: String::from_array(current), start, end: offset })
  lines
}

///|
/// `char_length` decodes the whole UTF-8 buffer, and the editor helpers
/// call it on the same source document for every block conversion, caret
/// clamp, and substring. Memoize the last (source, length) pair so one
/// keystroke pays the scan at most once; the runtime is single-threaded.
let markdown_editor_text_length_cache : Ref[(String, Int)] = Ref(("", -1))

///|
pub fn markdown_editor_text_length(source : String) -> Int {
  let cached = markdown_editor_text_length_cache.val
  if cached.1 >= 0 && cached.0 == source {
    cached.1
  } else {
    let length = source.char_length()
    markdown_editor_text_length_cache.val = (source, length)
    length
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

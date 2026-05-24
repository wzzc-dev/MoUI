///|
struct MarkdownSourceRange {
  start : Int
  end : Int
} derive(Eq, Debug, ToJson)

///|
struct MarkdownEditorBlock {
  block : MarkdownBlock
  source_range : MarkdownSourceRange
  content_range : MarkdownSourceRange
} derive(Eq, Debug, ToJson)

///|
struct MarkdownEditorSnapshot {
  source : String
  blocks : Array[MarkdownEditorBlock]
  rich_text : @core.RichTextDocument
  line_count : Int
  word_count : Int
  active_heading : String
} derive(Eq, Debug, ToJson)

///|
struct MarkdownEditorSelection {
  caret : Int
  selection : @core.TextRange?
} derive(Eq, Debug, ToJson)

///|
struct MarkdownEditorEditResult {
  source : String
  caret : Int
  selection : @core.TextRange?
} derive(Eq, Debug, ToJson)

///|
enum MarkdownEditorCommand {
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
  InsertTableRow
  InsertTableColumn
  DeleteTableRow
  DeleteTableColumn
  SetTableColumnAlignment(@core.TextAlign?)
  Clear
} derive(Eq, Debug, ToJson)

///|
struct MarkdownLine {
  text : String
  start : Int
  end : Int
} derive(Eq, Debug)

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
fn markdown_editor_text_length(source : String) -> Int {
  source.to_array().length()
}

///|
fn markdown_editor_substring(source : String, start : Int, end : Int) -> String {
  let chars = source.to_array()
  let start = clamp_example_int(start, 0, chars.length())
  let end = clamp_example_int(end, start, chars.length())
  String::from_array(chars[start:end])
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
fn markdown_editor_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn markdown_editor_clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

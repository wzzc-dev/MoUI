///|
fn MarkdownEditorSnapshot::parse(source : String) -> MarkdownEditorSnapshot {
  let blocks = parse_markdown_editor_blocks(source)
  {
    source,
    blocks,
    rich_text: markdown_editor_blocks_to_rich_text(source, blocks),
    line_count: markdown_editor_line_count(source),
    word_count: markdown_editor_word_count(source),
    active_heading: markdown_editor_active_heading(blocks),
  }
}

///|
fn markdown_editor_format(source : String) -> @core.RichTextDocument {
  MarkdownEditorSnapshot::parse(source).rich_text
}

///|
fn parse_markdown_editor_blocks(source : String) -> Array[MarkdownEditorBlock] {
  let blocks : Array[MarkdownEditorBlock] = []
  let definitions = markdown_reference_definitions(source)
  let lines = markdown_editor_lines(source)
  let code_lines : Array[String] = []
  let mut code_start = 0
  let mut code_content_start = 0
  let mut code_fence = ""
  let mut code_language : String? = None
  let mut in_code = false
  let mut index = 0
  while index < lines.length() {
    let line = lines[index]
    if in_code {
      if markdown_editor_closing_code_fence(line.text, code_fence) {
        let text = markdown_join_lines(code_lines).trim().to_owned()
        blocks.push({
          block: markdown_editor_code_block(text, code_language),
          source_range: { start: code_start, end: line.end },
          content_range: { start: code_content_start, end: line.start },
        })
        code_lines.clear()
        code_fence = ""
        code_language = None
        in_code = false
      } else {
        code_lines.push(line.text)
      }
    } else if line.text.trim().to_owned() != "" {
      match markdown_editor_opening_code_fence_marker(line.text) {
        Some(fence) => {
          in_code = true
          code_fence = fence.marker
          code_language = fence.info
          code_start = line.start
          code_content_start = line.end + 1
        }
        None =>
          match markdown_editor_table_block_at(lines, index) {
            Some(table) => {
              blocks.push(table.block)
              index = table.end_index
            }
            None =>
              match markdown_editor_setext_heading_level_at(lines, index) {
                Some(level) => {
                  let text = line.text.trim().to_owned()
                  blocks.push({
                    block: {
                      kind: MarkdownBlockKind::Heading(level),
                      text,
                      inlines: parse_markdown_inlines_with_definitions(
                        text, definitions,
                      ),
                      table_alignments: [],
                      code_language: None,
                    },
                    source_range: {
                      start: line.start,
                      end: lines[index + 1].end,
                    },
                    content_range: { start: line.start, end: line.end },
                  })
                  index = index + 1
                }
                None => {
                  let parsed = parse_markdown(line.text)
                  for block in parsed {
                    let block = markdown_editor_block_with_references(
                      block, definitions,
                    )
                    blocks.push({
                      block,
                      source_range: { start: line.start, end: line.end },
                      content_range: markdown_editor_content_range(
                        line,
                        block.kind,
                      ),
                    })
                  }
                }
              }
          }
      }
    }
    index = index + 1
  }
  if in_code {
    let text = markdown_join_lines(code_lines).trim().to_owned()
    let end = markdown_editor_text_length(source)
    blocks.push({
      block: markdown_editor_code_block(text, code_language),
      source_range: { start: code_start, end },
      content_range: { start: code_content_start, end },
    })
  }
  blocks
}

///|
fn markdown_editor_block_with_references(
  block : MarkdownBlock,
  definitions : Array[MarkdownReferenceDefinition],
) -> MarkdownBlock {
  match block.kind {
    CodeBlock | HorizontalRule | Table | HtmlBlock => block
    _ =>
      {
        ..block,
        inlines: markdown_resolve_reference_inlines(block.inlines, definitions),
      }
  }
}

///|
struct MarkdownEditorTableParseResult {
  block : MarkdownEditorBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_editor_table_block_at(
  lines : Array[MarkdownLine],
  index : Int,
) -> MarkdownEditorTableParseResult? {
  if index + 1 >= lines.length() ||
    !markdown_editor_table_separator_line(lines[index + 1].text) {
    return None
  }
  let table_lines : Array[MarkdownLine] = [lines[index], lines[index + 1]]
  let mut next = index + 2
  while next < lines.length() &&
        markdown_editor_table_body_line(lines[next].text) {
    table_lines.push(lines[next])
    next = next + 1
  }
  let segment_lines : Array[String] = []
  for line in table_lines {
    segment_lines.push(line.text)
  }
  let segment = markdown_join_lines(segment_lines)
  match parse_markdown(segment) {
    [{ kind: MarkdownBlockKind::Table, .. } as block] => {
      let source_start = table_lines[0].start
      let source_end = table_lines[table_lines.length() - 1].end
      Some({
        block: {
          block,
          source_range: { start: source_start, end: source_end },
          content_range: { start: source_start, end: source_end },
        },
        end_index: next - 1,
      })
    }
    _ => None
  }
}

///|
fn markdown_editor_table_separator_line(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  if !trimmed.contains("|") {
    return false
  }
  let cells = markdown_editor_split_table_cells(trimmed)
  if cells.length() == 0 {
    return false
  }
  for cell in cells {
    if !markdown_editor_table_separator_cell(cell.trim().to_owned()) {
      return false
    }
  }
  true
}

///|
fn markdown_editor_table_separator_cell(cell : String) -> Bool {
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
fn markdown_editor_table_body_line(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  trimmed != "" && trimmed.contains("|")
}

///|
fn markdown_editor_split_table_cells(line : String) -> Array[String] {
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
fn markdown_editor_setext_heading_level_at(
  lines : Array[MarkdownLine],
  index : Int,
) -> Int? {
  if index + 1 >= lines.length() {
    return None
  }
  let text = lines[index].text.trim().to_owned()
  if text == "" ||
    markdown_editor_opening_code_fence_marker(lines[index].text) is Some(_) ||
    !markdown_editor_is_setext_paragraph_candidate(lines[index].text) {
    return None
  }
  markdown_editor_setext_underline_level(lines[index + 1].text)
}

///|
fn markdown_editor_is_setext_paragraph_candidate(line : String) -> Bool {
  match parse_markdown(line) {
    [{ kind: MarkdownBlockKind::Paragraph, .. }] => true
    _ => false
  }
}

///|
fn markdown_editor_setext_underline_level(line : String) -> Int? {
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
fn markdown_editor_closing_code_fence(line : String, fence : String) -> Bool {
  let chars = line.to_array()
  let fence_chars = fence.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
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
fn markdown_editor_blocks_to_rich_text(
  source : String,
  blocks : Array[MarkdownEditorBlock],
) -> @core.RichTextDocument {
  let rich_blocks : Array[@core.RichTextBlock] = []
  let base = @core.FontSpec::new()
  for block in blocks {
    rich_blocks.push(markdown_editor_block_to_rich_text(source, block, base))
  }
  @core.RichTextDocument::new(blocks=rich_blocks)
}

///|
fn markdown_editor_block_to_rich_text(
  source : String,
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
) -> @core.RichTextBlock {
  let block = markdown_block_to_rich_text(editor_block.block, base)
  {
    ..block,
    runs: markdown_editor_runs_with_source_ranges(block.runs, editor_block),
    table: markdown_editor_table_with_source_ranges(
      block.table,
      source,
      editor_block,
    ),
    source_range: Some(markdown_core_range(editor_block.source_range)),
    content_range: Some(markdown_core_range(editor_block.content_range)),
  }
}

///|
fn markdown_editor_table_with_source_ranges(
  table : @core.RichTextTable?,
  source : String,
  editor_block : MarkdownEditorBlock,
) -> @core.RichTextTable? {
  match table {
    Some(table) => {
      let block_source_text = markdown_editor_substring(
        source,
        editor_block.source_range.start,
        editor_block.source_range.end,
      )
      let source_cells = markdown_editor_table_cells_for_block(
        block_source_text,
        {
          block: editor_block.block,
          source_range: {
            start: 0,
            end: markdown_editor_text_length(block_source_text),
          },
          content_range: {
            start: 0,
            end: markdown_editor_text_length(block_source_text),
          },
        },
      )
      let rows : Array[Array[@core.RichTextTableCell]] = []
      for row_index in 0..<table.rows.length() {
        let row : Array[@core.RichTextTableCell] = []
        for column_index in 0..<table.rows[row_index].length() {
          let cell = table.rows[row_index][column_index]
          let mapped = markdown_editor_find_table_cell(
            source_cells, row_index, column_index,
          )
          row.push({
            ..cell,
            source_range: match mapped {
              Some(range) =>
                Some({
                  start: editor_block.source_range.start + range.content_start,
                  end: editor_block.source_range.start + range.content_end,
                })
              None => cell.source_range
            },
          })
        }
        rows.push(row)
      }
      Some({ ..table, rows, })
    }
    None => None
  }
}

///|
fn markdown_editor_find_table_cell(
  cells : Array[MarkdownEditorTableCellRange],
  row : Int,
  column : Int,
) -> MarkdownEditorTableCellRange? {
  for cell in cells {
    if cell.row == row && cell.column == column {
      return Some(cell)
    }
  }
  None
}

///|
fn markdown_editor_runs_with_source_ranges(
  runs : Array[@core.RichTextRun],
  editor_block : MarkdownEditorBlock,
) -> Array[@core.RichTextRun] {
  let mapped : Array[@core.RichTextRun] = []
  let mut search = 0
  let mut index = 0
  let content = markdown_editor_block_source_content(editor_block)
  for run in runs {
    if index == 0 && editor_block.block.kind is FootnoteDefinition(_) {
      mapped.push({
        ..run,
        source_range: Some({
          start: editor_block.source_range.start,
          end: editor_block.content_range.start,
        }),
      })
    } else {
      let length = markdown_editor_text_length(run.text)
      let start = markdown_editor_find_run_source_offset(
        content,
        run.text,
        search,
      )
      let end = start + length
      mapped.push({
        ..run,
        source_range: Some({
          start: editor_block.content_range.start + start,
          end: editor_block.content_range.start + end,
        }),
      })
      search = end
    }
    index = index + 1
  }
  mapped
}

///|
fn markdown_editor_block_source_content(
  editor_block : MarkdownEditorBlock,
) -> String {
  let source = editor_block.source_range
  let content = editor_block.content_range
  let chars = markdown_editor_block_source_text(editor_block).to_array()
  let start = markdown_editor_clamp_int(
    content.start - source.start,
    0,
    chars.length(),
  )
  let end = markdown_editor_clamp_int(
    content.end - source.start,
    start,
    chars.length(),
  )
  String::from_array(chars[start:end])
}

///|
fn markdown_editor_block_source_text(
  editor_block : MarkdownEditorBlock,
) -> String {
  let prefix_padding = markdown_editor_block_source_prefix_padding(editor_block)
  match editor_block.block.kind {
    Heading(level) =>
      prefix_padding +
      markdown_editor_heading_source(level, editor_block.block.text)
    UnorderedListItem =>
      prefix_padding +
      "- " +
      markdown_editor_inline_source(editor_block.block.inlines)
    TaskListItem(checked) =>
      if checked {
        prefix_padding +
        "- [x] " +
        markdown_editor_inline_source(editor_block.block.inlines)
      } else {
        prefix_padding +
        "- [ ] " +
        markdown_editor_inline_source(editor_block.block.inlines)
      }
    OrderedListItem(number) =>
      prefix_padding +
      number.to_string() +
      ". " +
      markdown_editor_inline_source(editor_block.block.inlines)
    Blockquote =>
      prefix_padding +
      "> " +
      markdown_editor_inline_source(editor_block.block.inlines)
    Paragraph =>
      prefix_padding + markdown_editor_inline_source(editor_block.block.inlines)
    FootnoteDefinition(label) =>
      prefix_padding +
      "[^" +
      label +
      "]: " +
      markdown_editor_inline_source(editor_block.block.inlines)
    CodeBlock | HorizontalRule | Table | HtmlBlock => editor_block.block.text
  }
}

///|
fn markdown_editor_block_source_prefix_padding(
  editor_block : MarkdownEditorBlock,
) -> String {
  let marker_length = match editor_block.block.kind {
    Heading(level) => level + 1
    UnorderedListItem => 2
    TaskListItem(_) => 6
    OrderedListItem(number) => markdown_editor_digit_count(number) + 2
    Blockquote => 2
    FootnoteDefinition(label) =>
      markdown_editor_text_length("[^" + label + "]: ")
    Paragraph | CodeBlock | HorizontalRule | Table | HtmlBlock => 0
  }
  let padding_length = markdown_editor_max_int(
    0,
    editor_block.content_range.start -
    editor_block.source_range.start -
    marker_length,
  )
  let chars : Array[Char] = []
  for _ in 0..<padding_length {
    chars.push(' ')
  }
  String::from_array(chars)
}

///|
fn markdown_editor_inline_source(inlines : Array[MarkdownInline]) -> String {
  let text = ""
  let parts : Array[String] = []
  for inline in inlines {
    match inline.kind {
      Plain => parts.push(inline.text)
      Bold => parts.push("**" + inline.text + "**")
      Italic => parts.push("*" + inline.text + "*")
      Code => parts.push("`" + inline.text + "`")
      Strikethrough => parts.push("~~" + inline.text + "~~")
      Link =>
        parts.push(
          "[" + inline.text + "](" + markdown_editor_inline_target(inline) + ")",
        )
      Autolink => parts.push("<" + markdown_editor_inline_target(inline) + ">")
      Image =>
        parts.push(
          "![" +
          inline.text +
          "](" +
          markdown_editor_inline_target(inline) +
          ")",
        )
      FootnoteReference => parts.push("[^" + inline.text + "]")
      HtmlInline => parts.push(inline.text)
    }
  }
  ignore(text)
  markdown_join_lines([markdown_join_strings(parts)])
}

///|
fn markdown_editor_inline_target(inline : MarkdownInline) -> String {
  match inline.target {
    Some(target) => target
    None => inline.text
  }
}

///|
fn markdown_join_strings(parts : Array[String]) -> String {
  let chars : Array[Char] = []
  for part in parts {
    chars.append(part.to_array())
  }
  String::from_array(chars)
}

///|
fn markdown_editor_heading_source(level : Int, text : String) -> String {
  let marks : Array[Char] = []
  for _ in 0..<level {
    marks.push('#')
  }
  String::from_array(marks) + " " + text
}

///|
fn markdown_editor_find_run_source_offset(
  content : String,
  run_text : String,
  start : Int,
) -> Int {
  let content_chars = content.to_array()
  let run_chars = run_text.to_array()
  if run_chars.length() == 0 {
    return markdown_editor_clamp_int(start, 0, content_chars.length())
  }
  let mut index = markdown_editor_clamp_int(start, 0, content_chars.length())
  while index + run_chars.length() <= content_chars.length() {
    if markdown_editor_chars_match(content_chars, index, run_chars) {
      return index
    }
    index = index + 1
  }
  markdown_editor_clamp_int(start, 0, content_chars.length())
}

///|
fn markdown_editor_chars_match(
  content : Array[Char],
  start : Int,
  target : Array[Char],
) -> Bool {
  if start + target.length() > content.length() {
    return false
  }
  for index in 0..<target.length() {
    if content[start + index] != target[index] {
      return false
    }
  }
  true
}

///|
fn markdown_core_range(
  range : MarkdownSourceRange,
) -> @core.RichTextSourceRange {
  { start: range.start, end: range.end }
}

///|
fn markdown_editor_active_heading(
  blocks : Array[MarkdownEditorBlock],
) -> String {
  for block in blocks {
    match block.block.kind {
      Heading(_) => return block.block.text
      _ => ()
    }
  }
  "Untitled"
}

///|
fn markdown_editor_block_kind_label(kind : MarkdownBlockKind) -> String {
  match kind {
    Heading(level) => "Heading " + level.to_string()
    UnorderedListItem => "Bullet list"
    TaskListItem(_) => "Task list"
    OrderedListItem(_) => "Ordered list"
    Blockquote => "Quote"
    CodeBlock => "Code block"
    HorizontalRule => "Rule"
    Table => "Table"
    FootnoteDefinition(label) => "Footnote " + label
    HtmlBlock => "HTML"
    Paragraph => "Paragraph"
  }
}

///|
fn markdown_editor_content_range(
  line : MarkdownLine,
  kind : MarkdownBlockKind,
) -> MarkdownSourceRange {
  let offset = match kind {
    Heading(_)
    | UnorderedListItem
    | TaskListItem(_)
    | OrderedListItem(_)
    | Blockquote => markdown_editor_marker_prefix_length(line.text)
    FootnoteDefinition(_) =>
      markdown_editor_footnote_marker_prefix_length(line.text)
    Paragraph | CodeBlock | HorizontalRule | Table | HtmlBlock => 0
  }
  {
    start: markdown_editor_min_int(line.start + offset, line.end),
    end: line.end,
  }
}

///|
fn markdown_editor_footnote_marker_prefix_length(line : String) -> Int {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() < indent + 5 ||
    chars[indent] != '[' ||
    chars[indent + 1] != '^' {
    return 0
  }
  let mut close = indent + 2
  while close < chars.length() && chars[close] != ']' {
    close = close + 1
  }
  if close <= indent + 2 ||
    close + 2 >= chars.length() ||
    chars[close + 1] != ':' ||
    chars[close + 2] != ' ' {
    return 0
  }
  close + 3
}

///|

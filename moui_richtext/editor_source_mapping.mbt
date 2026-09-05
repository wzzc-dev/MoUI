///|
pub fn MarkdownEditorSnapshot::parse(source : String) -> MarkdownEditorSnapshot {
  MarkdownEditorSnapshot::parse_with_font(source, @core.FontSpec::new())
}

///|
pub fn MarkdownEditorSnapshot::parse_with_font(
  source : String,
  base : @core.FontSpec,
  base_dir? : String? = None,
) -> MarkdownEditorSnapshot {
  let blocks = parse_markdown_editor_blocks(source)
  let word_count = markdown_editor_word_count(source)
  let metadata = markdown_editor_front_matter_metadata(blocks)
  {
    source,
    blocks,
    rich_text: markdown_editor_blocks_to_rich_text(
      source,
      blocks,
      base,
      base_dir~,
    ),
    line_count: markdown_editor_line_count(source),
    word_count,
    reading_minutes: markdown_editor_reading_minutes(word_count),
    active_heading: markdown_editor_active_heading(blocks),
    metadata_title: metadata.title,
    metadata_tags: metadata.tags,
    outline: markdown_editor_outline(blocks),
  }
}

///|
pub fn markdown_editor_format(
  source : String,
  base? : @core.FontSpec = @core.FontSpec::new(),
  base_dir? : String? = None,
) -> RichTextDocument {
  MarkdownEditorSnapshot::parse_with_font(source, base, base_dir~).rich_text
}

///|
pub fn markdown_editor_format_for_selection(
  source : String,
  selection : MarkdownEditorSelection,
  base? : @core.FontSpec = @core.FontSpec::new(),
  base_dir? : String? = None,
) -> RichTextDocument {
  let document = markdown_editor_format(source, base~, base_dir~)
  let blocks : Array[RichTextBlock] = []
  for block in document.blocks {
    let block_source_end = match block.source_range {
      Some(source_range) => source_range.end
      None => 0
    }
    let runs : Array[RichTextRun] = []
    for run in block.runs {
      runs.push(
        markdown_editor_reveal_active_inline_run(
          source,
          block_source_end~,
          selection,
          run,
        ),
      )
    }
    blocks.push(
      markdown_editor_reveal_active_block_marker(source, selection, {
        ..block,
        runs,
      }),
    )
  }
  RichTextDocument::new(blocks~)
}

///|
pub fn markdown_editor_format_for_writing_mode(
  source : String,
  selection : MarkdownEditorSelection,
  base? : @core.FontSpec = @core.FontSpec::new(),
  focus_mode~ : Bool,
  base_dir? : String? = None,
) -> RichTextDocument {
  let document = markdown_editor_format_for_selection(
    source,
    selection,
    base~,
    base_dir~,
  )
  if focus_mode {
    markdown_editor_dim_inactive_blocks(document, selection)
  } else {
    document
  }
}

///|
fn markdown_editor_format_source_mode(
  source : String,
  base : @core.FontSpec,
) -> RichTextDocument {
  let length = markdown_editor_text_length(source)
  let font = {
    ..base,
    families: @core.FontFamilyStack::monospace(),
    size: base.size * 0.92,
  }
  RichTextDocument::new(blocks=[
    RichTextBlock::new(
      runs=[
        RichTextRun::new(
          text=source,
          font=Some(font),
          source_range=Some({ start: 0, end: length }),
        ),
      ],
      font=Some(font),
      source_range=Some({ start: 0, end: length }),
      content_range=Some({ start: 0, end: length }),
      line_height=Some(base.size * 1.42),
    ),
  ])
}

///|
fn markdown_editor_dim_inactive_blocks(
  document : RichTextDocument,
  selection : MarkdownEditorSelection,
) -> RichTextDocument {
  let blocks : Array[RichTextBlock] = []
  for block in document.blocks {
    if markdown_editor_focus_block_active(block, selection) {
      blocks.push(block)
    } else {
      blocks.push(markdown_editor_dim_rich_text_block(block))
    }
  }
  RichTextDocument::new(blocks~)
}

///|
fn markdown_editor_focus_block_active(
  block : RichTextBlock,
  selection : MarkdownEditorSelection,
) -> Bool {
  match block.source_range {
    Some(range) => markdown_editor_selection_touches_range(selection, range)
    None => true
  }
}

///|
fn markdown_editor_dim_rich_text_block(block : RichTextBlock) -> RichTextBlock {
  let runs : Array[RichTextRun] = []
  for run in block.runs {
    runs.push(markdown_editor_dim_rich_text_run(run))
  }
  {
    ..block,
    runs,
    color: Some(
      block.color
      .unwrap_or(markdown_editor_default_text_color())
      .multiply_alpha(0.38),
    ),
    border_left: markdown_editor_dim_border(block.border_left),
  }
}

///|
fn markdown_editor_dim_rich_text_run(run : RichTextRun) -> RichTextRun {
  {
    ..run,
    color: match run.color {
      Some(color) => Some(color.multiply_alpha(0.38))
      None => None
    },
  }
}

///|
fn markdown_editor_dim_border(
  border : @core.BorderStyle?,
) -> @core.BorderStyle? {
  match border {
    Some(border) => Some({ ..border, brush: border.brush.multiply_alpha(0.38) })
    None => None
  }
}

///|
fn markdown_editor_default_text_color() -> @core.Color {
  @core.Color::rgba(r=0.12, g=0.12, b=0.12)
}

///|
fn markdown_editor_reveal_active_block_marker(
  source : String,
  selection : MarkdownEditorSelection,
  block : RichTextBlock,
) -> RichTextBlock {
  match (block.source_range, block.content_range) {
    (Some(source_range), Some(content_range)) => {
      if markdown_editor_active_code_block(source, selection, block) {
        return markdown_editor_reveal_active_code_block(source, block)
      }
      if source_range.start >= content_range.start ||
        block.runs.length() == 0 ||
        block.runs[0].source_range is None ||
        !markdown_editor_selection_touches_range(selection, content_range) {
        return block
      }
      let prefix = markdown_editor_substring(
        source,
        source_range.start,
        content_range.start,
      )
      if block.prefix != "" {
        return { ..block, prefix, }
      }
      let runs = block.runs.copy()
      let first = runs[0]
      runs[0] = {
        ..first,
        text: prefix + first.text,
        visual_text: None,
        source_range: match first.source_range {
          Some(run_range) =>
            Some({ start: source_range.start, end: run_range.end })
          None => Some({ start: source_range.start, end: content_range.start })
        },
      }
      { ..block, prefix: "", runs }
    }
    _ => block
  }
}

///|
fn markdown_editor_active_code_block(
  source : String,
  selection : MarkdownEditorSelection,
  block : RichTextBlock,
) -> Bool {
  match (block.source_range, block.content_range) {
    (Some(source_range), Some(_content_range)) => {
      let block_source = markdown_editor_substring(
        source,
        source_range.start,
        source_range.end,
      )
      markdown_editor_source_starts_with_code_fence(block_source) &&
      markdown_editor_selection_touches_range(selection, source_range)
    }
    _ => false
  }
}

///|
fn markdown_editor_reveal_active_code_block(
  source : String,
  block : RichTextBlock,
) -> RichTextBlock {
  match block.source_range {
    Some(source_range) => {
      let source_text = markdown_editor_substring(
        source,
        source_range.start,
        source_range.end,
      )
      let font = markdown_editor_first_run_font(block)
      {
        ..block,
        runs: [
          RichTextRun::new(
            text=source_text,
            font~,
            source_range=Some(source_range),
          ),
        ],
        content_range: Some(source_range),
      }
    }
    None => block
  }
}

///|
fn markdown_editor_first_run_font(block : RichTextBlock) -> @core.FontSpec? {
  if block.runs.length() == 0 {
    None
  } else {
    block.runs[0].font
  }
}

///|
fn markdown_editor_source_starts_with_code_fence(source : String) -> Bool {
  let chars = source.trim().to_owned().to_array()
  if chars.length() < 3 {
    return false
  }
  (chars[0] == '`' && chars[1] == '`' && chars[2] == '`') ||
  (chars[0] == '~' && chars[1] == '~' && chars[2] == '~')
}

///|
/// A char-indexed window over the source for the inline marker probes.
/// The probes only ever read a handful of characters around one inline
/// span, so the reveal path builds a block-sized window; materializing the
/// whole document as a char array per touched run (the old
/// `source.to_array()`) cost O(document) per run per frame. Reads outside
/// the window return None, which fails marker detection exactly like the
/// block-adjacent newlines and blank lines the whole-source scan used to
/// find there.
priv struct MarkdownSourceChars {
  chars : Array[Char]
  offset : Int
}

///|
fn MarkdownSourceChars::get(self : MarkdownSourceChars, index : Int) -> Char? {
  let offset = index - self.offset
  if offset < 0 || offset >= self.chars.length() {
    None
  } else {
    Some(self.chars[offset])
  }
}

///|
fn MarkdownSourceChars::length(self : MarkdownSourceChars) -> Int {
  self.offset + self.chars.length()
}

///|
/// Slice `[start, end)` (absolute char indices) inside the window; None
/// when either edge falls outside it.
fn MarkdownSourceChars::slice(
  self : MarkdownSourceChars,
  start : Int,
  end : Int,
) -> Array[Char]? {
  let lo = start - self.offset
  let hi = end - self.offset
  if start < self.offset || hi > self.chars.length() || lo > hi {
    None
  } else {
    Some(self.chars[lo:hi].to_owned())
  }
}

///|
fn markdown_editor_source_chars_all(source : String) -> MarkdownSourceChars {
  { chars: source.to_array(), offset: 0 }
}

///|
/// A window covering one inline span's neighborhood: two characters of
/// lookback (the `**`/`[`/`!` markers) plus the rest of the owning block
/// and a small tail for the `]`/`)`/label reads and end-of-line scans.
fn markdown_editor_source_chars_near(
  source : String,
  range : RichTextSourceRange,
  block_source_end~ : Int,
) -> MarkdownSourceChars {
  let doc_length = markdown_editor_text_length(source)
  let start = markdown_editor_clamp_int(range.start - 2, 0, doc_length)
  let end = markdown_editor_clamp_int(block_source_end + 8, start, doc_length)
  {
    chars: markdown_editor_substring(source, start, end).to_array(),
    offset: start,
  }
}

///|
fn markdown_editor_window_has_marker(
  chars : MarkdownSourceChars,
  start : Int,
  marker : String,
) -> Bool {
  if start < chars.offset {
    return false
  }
  let mut offset = start - chars.offset
  for ch in marker {
    match chars.chars.get(offset) {
      Some(window_char) => if window_char != ch { return false }
      None => return false
    }
    offset = offset + 1
  }
  true
}

///|
fn markdown_editor_single_inline_marker_at_window(
  chars : MarkdownSourceChars,
  index : Int,
  marker : Char,
) -> Bool {
  let ch = match chars.get(index) {
    Some(ch) => ch
    None => return false
  }
  if ch != marker {
    return false
  }
  let previous_differs = match chars.get(index - 1) {
    Some(previous) => previous != marker
    // The near window always covers `range.start - 2`, so an out-of-window
    // read here only happens at the document start (index 0).
    None => true
  }
  let next_differs = match chars.get(index + 1) {
    Some(next) => next != marker
    None => true
  }
  previous_differs && next_differs
}

///|
fn markdown_editor_reveal_active_inline_run(
  source : String,
  block_source_end~ : Int,
  selection : MarkdownEditorSelection,
  run : RichTextRun,
) -> RichTextRun {
  match run.source_range {
    Some(range) =>
      if markdown_editor_selection_touches_range(selection, range) {
        match
          markdown_editor_inline_marker_source_range(
            source,
            chars=markdown_editor_source_chars_near(
              source,
              range,
              block_source_end~,
            ),
            range,
          ) {
          Some(full_range) =>
            {
              ..run,
              text: markdown_editor_substring(
                source,
                full_range.start,
                full_range.end,
              ),
              visual_text: None,
              source_range: Some(full_range),
            }
          None => run
        }
      } else {
        run
      }
    None => run
  }
}

///|
fn markdown_editor_selection_touches_range(
  selection : MarkdownEditorSelection,
  range : RichTextSourceRange,
) -> Bool {
  match markdown_editor_active_selection(selection.selection) {
    Some(active) => {
      let active = active.normalized()
      active.start < range.end && active.end > range.start
    }
    None => selection.caret >= range.start && selection.caret <= range.end
  }
}

///|
fn markdown_editor_inline_marker_source_range(
  source : String,
  chars~ : MarkdownSourceChars,
  range : RichTextSourceRange,
) -> RichTextSourceRange? {
  if range.start < 0 || range.end < range.start || range.end > chars.length() {
    return None
  }
  if markdown_editor_window_has_marker(chars, range.start - 2, "**") &&
    markdown_editor_window_has_marker(chars, range.end, "**") {
    return Some({ start: range.start - 2, end: range.end + 2 })
  }
  if markdown_editor_window_has_marker(chars, range.start - 2, "__") &&
    markdown_editor_window_has_marker(chars, range.end, "__") {
    return Some({ start: range.start - 2, end: range.end + 2 })
  }
  if markdown_editor_window_has_marker(chars, range.start - 2, "~~") &&
    markdown_editor_window_has_marker(chars, range.end, "~~") {
    return Some({ start: range.start - 2, end: range.end + 2 })
  }
  if markdown_editor_window_has_marker(chars, range.start - 1, "`") &&
    markdown_editor_window_has_marker(chars, range.end, "`") {
    return Some({ start: range.start - 1, end: range.end + 1 })
  }
  if markdown_editor_single_inline_marker_at_window(chars, range.start - 1, '*') &&
    markdown_editor_single_inline_marker_at_window(chars, range.end, '*') {
    return Some({ start: range.start - 1, end: range.end + 1 })
  }
  if markdown_editor_single_inline_marker_at_window(chars, range.start - 1, '_') &&
    markdown_editor_single_inline_marker_at_window(chars, range.end, '_') {
    return Some({ start: range.start - 1, end: range.end + 1 })
  }
  match markdown_editor_reference_source_range(source, chars~, range) {
    Some(reference_range) => return Some(reference_range)
    None => ()
  }
  None
}

///|
fn markdown_editor_reference_source_range(
  source : String,
  chars~ : MarkdownSourceChars,
  range : RichTextSourceRange,
) -> RichTextSourceRange? {
  let text_range = @core.TextRange::new(start=range.start, end=range.end)
  match markdown_editor_range_link_bounds_in(source, chars~, text_range) {
    Some(bounds) =>
      return Some({ start: bounds.open_start, end: bounds.target_end + 1 })
    None => ()
  }
  match markdown_editor_range_image_bounds_in(source, chars~, text_range) {
    Some(bounds) =>
      Some({ start: bounds.open_start, end: bounds.target_end + 1 })
    None => None
  }
}

///|
fn parse_markdown_editor_blocks(source : String) -> Array[MarkdownEditorBlock] {
  parse_markdown_editor_blocks_cached(source)
}

///|
fn parse_markdown_editor_blocks_uncached(
  source : String,
) -> Array[MarkdownEditorBlock] {
  parse_markdown_editor_blocks_with_definitions(source, definitions=None)
}

///|
/// Shell parse: the same line scan and block boundaries as the full parse,
/// but content blocks (paragraphs, headings, list items, quotes) carry no
/// inline runs and best-effort marker-stripped text. Used for session
/// construction so opening a document costs one linear scan instead of one
/// markdown parse per block; blocks are re-parsed on demand by
/// `markdown_editor_block_materialized` the first time their inline runs
/// are actually needed (rendering, caret geometry, export).
fn parse_markdown_editor_blocks_shell(
  source : String,
) -> Array[MarkdownEditorBlock] {
  parse_markdown_editor_blocks_with_definitions(
    source,
    // Shell blocks never consult reference definitions, so passing an empty
    // set also skips the whole-document definition parse.
    definitions=Some([]),
    parse_inlines=false,
  )
}

///|
/// Parse with a precomputed whole-source reference-definition set. The
/// session's incremental apply path passes definitions from the previous
/// source (edits that could change the definition set fall back to the
/// full parse), which skips the second whole-document markdown parse
/// that only exists to collect `[label]: url` entries.
fn parse_markdown_editor_blocks_with_definitions(
  source : String,
  definitions~ : Array[MarkdownReferenceDefinition]?,
  parse_inlines? : Bool = true,
) -> Array[MarkdownEditorBlock] {
  let blocks : Array[MarkdownEditorBlock] = []
  if source == "" {
    return blocks
  }
  let definitions = match definitions {
    Some(definitions) => definitions
    None => markdown_reference_definitions_cached(source)
  }
  let lines = markdown_editor_lines(source)
  match markdown_editor_front_matter_block_at(lines) {
    Some(front_matter) => {
      blocks.push(front_matter.block)
      let mut index = front_matter.next_index
      while index < lines.length() {
        let line = lines[index]
        if markdown_editor_line_text_is_blank(line.text) {
          blocks.push(markdown_editor_blank_line_block(line))
          index = index + 1
        } else {
          break
        }
      }
      if index < lines.length() {
        let rest_start = lines[index].start
        let rest = markdown_editor_substring(
          source,
          rest_start,
          markdown_editor_text_length(source),
        )
        for
          block in parse_markdown_editor_blocks_with_definitions(
            rest,
            definitions=Some(definitions),
            parse_inlines~,
          ) {
          blocks.push({
            ..block,
            source_range: {
              start: block.source_range.start + rest_start,
              end: block.source_range.end + rest_start,
            },
            content_range: {
              start: block.content_range.start + rest_start,
              end: block.content_range.end + rest_start,
            },
          })
        }
      }
      return blocks
    }
    None => ()
  }
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
        let text = markdown_join_lines(code_lines)
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
    } else if markdown_editor_line_text_is_blank(line.text) {
      blocks.push(markdown_editor_blank_line_block(line))
    } else {
      let fence_info = if parse_inlines ||
        markdown_editor_shell_line_may_open_fence(line.text) {
        markdown_editor_opening_code_fence_marker(line.text)
      } else {
        None
      }
      match fence_info {
        Some(fence) => {
          in_code = true
          code_fence = fence.marker
          code_language = fence.info
          code_start = line.start
          code_content_start = line.end + 1
        }
        None => {
          let html_hit = if parse_inlines ||
            markdown_editor_shell_line_may_open_html(line.text) {
            markdown_editor_html_block_at(lines, index)
          } else {
            None
          }
          match html_hit {
            Some(html) => {
              blocks.push(html.block)
              index = html.end_index
            }
            None =>
              match markdown_editor_table_block_at(lines, index) {
                Some(table) => {
                  blocks.push(table.block)
                  index = table.end_index
                }
                None =>
                  match
                    markdown_editor_setext_heading_block_at(
                      lines, index, definitions,
                      parse_inlines~,
                    ) {
                    Some(heading) => {
                      blocks.push(heading.block)
                      index = heading.end_index
                    }
                    None => {
                      let code_hit = if parse_inlines ||
                        markdown_editor_shell_line_is_indented(line.text) {
                        markdown_editor_indented_code_block_at(lines, index)
                      } else {
                        None
                      }
                      match code_hit {
                        Some(code) => {
                          blocks.push(code.block)
                          index = code.end_index
                        }
                        None =>
                          match
                            markdown_editor_soft_wrapped_paragraph_block_at(
                              lines, index, definitions,
                              parse_inlines~,
                            ) {
                            Some(paragraph) => {
                              blocks.push(paragraph.block)
                              index = paragraph.end_index
                            }
                            None =>
                              if parse_inlines {
                                let parsed = parse_markdown(line.text)
                                for block in parsed {
                                  let block = markdown_editor_block_with_references(
                                    block, definitions,
                                  )
                                  blocks.push({
                                    block,
                                    source_range: {
                                      start: line.start,
                                      end: line.end,
                                    },
                                    content_range: markdown_editor_content_range(
                                      line,
                                      block.kind,
                                    ),
                                  })
                                }
                              } else {
                                // Shell mode: classify the line with cheap
                                // prefix rules instead of running the
                                // markdown parser per line. Shell kinds are
                                // exact for common lines and the real parse
                                // replaces the shell the first time its
                                // inline runs are needed.
                                blocks.push(
                                  markdown_editor_shell_line_block(line),
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
    let text = markdown_join_lines(code_lines)
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
fn markdown_editor_blank_line_block(line : MarkdownLine) -> MarkdownEditorBlock {
  {
    block: {
      kind: MarkdownBlockKind::Paragraph,
      text: "",
      inlines: [],
      table_alignments: [],
      code_language: None,
    },
    source_range: { start: line.start, end: line.end },
    content_range: { start: line.start, end: line.end },
  }
}

///|
priv struct MarkdownEditorFrontMatterParseResult {
  block : MarkdownEditorBlock
  next_index : Int
}

///|
fn markdown_editor_front_matter_block_at(
  lines : Array[MarkdownLine],
) -> MarkdownEditorFrontMatterParseResult? {
  if lines.length() < 2 || lines[0].text.trim().to_owned() != "---" {
    return None
  }
  let content : Array[String] = []
  let mut index = 1
  while index < lines.length() {
    if lines[index].text.trim().to_owned() == "---" {
      return Some({
        block: {
          block: markdown_block(FrontMatter, markdown_join_lines(content)),
          source_range: { start: lines[0].start, end: lines[index].end },
          content_range: { start: lines[0].end + 1, end: lines[index].start },
        },
        next_index: index + 1,
      })
    }
    content.push(lines[index].text)
    index = index + 1
  }
  None
}

///|
struct MarkdownEditorHtmlBlockParseResult {
  block : MarkdownEditorBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_editor_html_block_at(
  lines : Array[MarkdownLine],
  index : Int,
) -> MarkdownEditorHtmlBlockParseResult? {
  if index < 0 || index >= lines.length() {
    return None
  }
  if markdown_html_block_comment_start(lines[index].text) {
    return markdown_editor_html_comment_block_at(lines, index)
  }
  if markdown_html_block_processing_instruction_start(lines[index].text) {
    return markdown_editor_html_processing_instruction_block_at(lines, index)
  }
  if markdown_html_block_cdata_start(lines[index].text) {
    return markdown_editor_html_cdata_block_at(lines, index)
  }
  match markdown_html_block_start_tag(lines[index].text) {
    Some(tag) => Some(markdown_editor_html_tag_block_at(lines, index, tag))
    None => None
  }
}

///|
fn markdown_editor_html_comment_block_at(
  lines : Array[MarkdownLine],
  index : Int,
) -> MarkdownEditorHtmlBlockParseResult? {
  let html_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    html_lines.push(lines[next].text)
    if markdown_html_block_comment_end(lines[next].text) {
      return Some(
        markdown_editor_html_block_result(lines, html_lines, index, next),
      )
    }
    next = next + 1
  }
  Some(markdown_editor_html_block_result(lines, html_lines, index, next - 1))
}

///|
fn markdown_editor_html_processing_instruction_block_at(
  lines : Array[MarkdownLine],
  index : Int,
) -> MarkdownEditorHtmlBlockParseResult? {
  let html_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    html_lines.push(lines[next].text)
    if markdown_html_block_processing_instruction_end(lines[next].text) {
      return Some(
        markdown_editor_html_block_result(lines, html_lines, index, next),
      )
    }
    next = next + 1
  }
  Some(markdown_editor_html_block_result(lines, html_lines, index, next - 1))
}

///|
fn markdown_editor_html_cdata_block_at(
  lines : Array[MarkdownLine],
  index : Int,
) -> MarkdownEditorHtmlBlockParseResult? {
  let html_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    html_lines.push(lines[next].text)
    if markdown_html_block_cdata_end(lines[next].text) {
      return Some(
        markdown_editor_html_block_result(lines, html_lines, index, next),
      )
    }
    next = next + 1
  }
  Some(markdown_editor_html_block_result(lines, html_lines, index, next - 1))
}

///|
fn markdown_editor_html_tag_block_at(
  lines : Array[MarkdownLine],
  index : Int,
  tag : String,
) -> MarkdownEditorHtmlBlockParseResult {
  let html_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    if next > index &&
      markdown_editor_blank_line(lines[next]) &&
      !markdown_html_block_tag_keeps_blank_lines(tag) {
      break
    }
    html_lines.push(lines[next].text)
    if markdown_html_block_line_closes_tag(lines[next].text, tag) ||
      (next == index && markdown_html_block_line_self_closes(lines[next].text)) {
      return markdown_editor_html_block_result(lines, html_lines, index, next)
    }
    next = next + 1
  }
  markdown_editor_html_block_result(lines, html_lines, index, next - 1)
}

///|
fn markdown_editor_html_block_result(
  lines : Array[MarkdownLine],
  html_lines : Array[String],
  start_index : Int,
  end_index : Int,
) -> MarkdownEditorHtmlBlockParseResult {
  let first = lines[start_index]
  let last = lines[end_index]
  {
    block: {
      block: markdown_block(HtmlBlock, markdown_join_lines(html_lines)),
      source_range: { start: first.start, end: last.end },
      content_range: { start: first.start, end: last.end },
    },
    end_index,
  }
}

///|
struct MarkdownEditorSetextHeadingParseResult {
  block : MarkdownEditorBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_editor_setext_heading_block_at(
  lines : Array[MarkdownLine],
  index : Int,
  definitions : Array[MarkdownReferenceDefinition],
  parse_inlines? : Bool = true,
) -> MarkdownEditorSetextHeadingParseResult? {
  let heading_lines : Array[MarkdownLine] = []
  let text_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    if heading_lines.length() > 0 {
      match markdown_editor_setext_underline_level(lines[next].text) {
        Some(level) => {
          for heading_line in heading_lines {
            text_lines.push(heading_line.text.trim().to_owned())
          }
          let text = markdown_join_lines(text_lines)
          let first = heading_lines[0]
          let last_content = heading_lines[heading_lines.length() - 1]
          return Some({
            block: {
              block: {
                kind: MarkdownBlockKind::Heading(level),
                text,
                inlines: if parse_inlines {
                  parse_markdown_inlines_with_definitions(
                    text, definitions,
                  )
                } else {
                  []
                },
                table_alignments: [],
                code_language: None,
              },
              source_range: { start: first.start, end: lines[next].end },
              content_range: { start: first.start, end: last_content.end },
            },
            end_index: next,
          })
        }
        None => ()
      }
    }
    if markdown_editor_setext_heading_content_line(lines, next, parse_inlines~) {
      heading_lines.push(lines[next])
      next = next + 1
    } else {
      return None
    }
  }
  None
}

///|
fn markdown_editor_setext_heading_content_line(
  lines : Array[MarkdownLine],
  index : Int,
  parse_inlines? : Bool = true,
) -> Bool {
  if index < 0 || index >= lines.length() {
    return false
  }
  let line = lines[index]
  if markdown_editor_line_text_is_blank(line.text) {
    return false
  }
  if !parse_inlines && !markdown_editor_shell_line_may_open_fence(line.text) {
    // Shell mode: the per-line markdown parse and char-array fence scan
    // here would dominate the open cost; the cheap marker rules agree with
    // them on every common line.
    if markdown_editor_shell_line_opens_html(lines, index) {
      return false
    }
    return markdown_editor_shell_structural_kind(line.text) is None
  }
  if markdown_editor_opening_code_fence_marker(line.text) is Some(_) {
    return false
  }
  if parse_inlines {
    markdown_editor_is_setext_paragraph_candidate(line.text)
  } else {
    markdown_editor_shell_structural_kind(line.text) is None
  }
}

///|
/// Cheap pre-filter for the fence-marker check: a line can only open a
/// code fence when, within the allowed three-space indent (no tabs), its
/// first character is a backtick or tilde run. Lets the shell parse skip
/// the char-array fence scan for every plain line.
fn markdown_editor_shell_line_may_open_fence(text : String) -> Bool {
  let length = text.length()
  let mut cursor = 0
  let mut spaces = 0
  while cursor < length && spaces <= 3 {
    let ch = text.get_char(cursor).unwrap_or(' ')
    if ch == ' ' {
      cursor = cursor + 1
      spaces = spaces + 1
    } else if ch == '\t' {
      return false
    } else {
      break
    }
  }
  if cursor + 2 >= length {
    return false
  }
  let fence = text.get_char(cursor).unwrap_or(' ')
  (fence == '`' || fence == '~') &&
  text.get_char(cursor + 1).unwrap_or(' ') == fence &&
  text.get_char(cursor + 2).unwrap_or(' ') == fence
}

///|
/// Cheap pre-filter for the HTML-block check: a line can only start an
/// HTML block when its first non-space character (within a small indent)
/// is `<`.
fn markdown_editor_shell_line_may_open_html(text : String) -> Bool {
  let length = text.length()
  let mut cursor = 0
  let mut spaces = 0
  while cursor < length && spaces <= 3 {
    let ch = text.get_char(cursor).unwrap_or(' ')
    if ch == ' ' {
      cursor = cursor + 1
      spaces = spaces + 1
    } else if ch == '\t' {
      return true
    } else {
      break
    }
  }
  cursor < length && text.get_char(cursor).unwrap_or(' ') == '<'
}

///|
/// Cheap pre-filter for the indented-code check: the line must begin with
/// a space or tab.
fn markdown_editor_shell_line_is_indented(text : String) -> Bool {
  text.length() > 0 &&
  (text.get_char(0).unwrap_or(' ') == ' ' || text.get_char(0).unwrap_or(' ') == '\t')
}

///|
/// Full HTML-block check behind the cheap `<` gate, shared by the shell
/// classifiers: a line that opens an HTML block is never paragraph
/// content, even though the marker rules cannot see it.
fn markdown_editor_shell_line_opens_html(
  lines : Array[MarkdownLine],
  index : Int,
) -> Bool {
  let line = lines[index]
  markdown_editor_shell_line_may_open_html(line.text) &&
  markdown_editor_html_block_at(lines, index) is Some(_)
}

///|
/// Cheap structural-line classification for shell parses: the block kind a
/// line's marker prefix implies (heading, list item, quote, rule, footnote
/// definition), or None when the line is plain paragraph text.
/// Allocation-free single pass with O(1) UTF-16 char access — the shell
/// parse runs this once per line, and a char-array materialization per line
/// dominated the open cost on large documents. The full markdown parser
/// agrees with these rules on every common line; a shell block's text is
/// exact for headings and rules, best-effort for marker-stripped
/// list/quote content, and is always replaced by the real parse the first
/// time its inline runs are needed.
fn markdown_editor_shell_structural_kind(text : String) -> MarkdownBlockKind? {
  let length = text.length()
  let mut cursor = 0
  while cursor < length {
    let ch = text.get_char(cursor).unwrap_or(' ')
    if ch == ' ' || ch == '\t' {
      cursor = cursor + 1
    } else {
      break
    }
  }
  if cursor >= length {
    return None
  }
  let first = text.get_char(cursor).unwrap_or(' ')
  // ATX heading: 1-6 `#` markers, a space/tab separator, and content after
  // (bare `#` / `# ` stay paragraphs, matching the real parser).
  if first == '#' {
    let mut index = cursor
    let mut level = 0
    while index < length {
      let ch = text.get_char(index).unwrap_or(' ')
      if ch == '#' {
        level = level + 1
        index = index + 1
      } else {
        break
      }
    }
    if level >= 1 && level <= 6 && index < length {
      let ch = text.get_char(index).unwrap_or(' ')
      if ch == ' ' || ch == '\t' {
        let mut content = index
        while content < length {
          let c = text.get_char(content).unwrap_or(' ')
          if c == ' ' || c == '\t' {
            content = content + 1
          } else {
            break
          }
        }
        if content < length {
          return Some(MarkdownBlockKind::Heading(level))
        }
      }
    }
    return None
  }
  // Footnote definition: `[^label]:`
  if first == '[' &&
    cursor + 1 < length &&
    text.get_char(cursor + 1).unwrap_or(' ') == '^' {
    let mut close = cursor + 2
    while close < length {
      let ch = text.get_char(close).unwrap_or(' ')
      if ch == ']' {
        break
      }
      close = close + ch.utf16_len()
    }
    if close > cursor + 2 &&
      close < length &&
      close + 1 < length &&
      text.get_char(close).unwrap_or(' ') == ']' &&
      text.get_char(close + 1).unwrap_or(' ') == ':' {
      let label = markdown_editor_shell_slice(text, start=cursor + 2, end=close)
      return Some(MarkdownBlockKind::FootnoteDefinition(label))
    }
    return None
  }
  // Task list item: `- [ ] ` / `- [x] ` / `- [X] `
  if first == '-' &&
    cursor + 5 < length &&
    text.get_char(cursor + 1).unwrap_or(' ') == ' ' &&
    text.get_char(cursor + 2).unwrap_or(' ') == '[' &&
    (text.get_char(cursor + 3).unwrap_or(' ') == ' ' ||
    text.get_char(cursor + 3).unwrap_or(' ') == 'x' ||
    text.get_char(cursor + 3).unwrap_or(' ') == 'X') &&
    text.get_char(cursor + 4).unwrap_or(' ') == ']' &&
    text.get_char(cursor + 5).unwrap_or(' ') == ' ' {
    let checked = text.get_char(cursor + 3).unwrap_or(' ') != ' '
    return Some(MarkdownBlockKind::TaskListItem(checked))
  }
  // Unordered list item
  if (first == '-' || first == '*' || first == '+') &&
    cursor + 1 < length &&
    text.get_char(cursor + 1).unwrap_or(' ') == ' ' {
    return Some(MarkdownBlockKind::UnorderedListItem)
  }
  // Quote
  if first == '>' &&
    cursor + 1 < length &&
    text.get_char(cursor + 1).unwrap_or(' ') == ' ' {
    return Some(MarkdownBlockKind::Blockquote)
  }
  // Thematic break: three or more of the same marker, spaces allowed
  // between them, nothing else on the line. `-` falls through to nothing
  // else (the `- item` case returned above), so a lone `-` is paragraph
  // text, matching the real parser.
  if first == '-' || first == '*' || first == '_' {
    let mut index = cursor
    let mut count = 0
    let mut structural = true
    while index < length {
      let ch = text.get_char(index).unwrap_or(' ')
      if ch == first {
        count = count + 1
        index = index + 1
      } else if ch == ' ' || ch == '\t' {
        index = index + 1
      } else {
        structural = false
        break
      }
    }
    if structural && count >= 3 {
      return Some(MarkdownBlockKind::HorizontalRule)
    }
    return None
  }
  // Ordered list item: digits + `.`/`)` + space.
  if first.is_ascii_digit() {
    let mut index = cursor
    let mut number = 0
    while index < length {
      let ch = text.get_char(index).unwrap_or(' ')
      if ch.is_ascii_digit() {
        number = number * 10 + ch.to_int() - 0x30
        index = index + 1
      } else {
        break
      }
    }
    if index > cursor &&
      index + 1 < length &&
      (text.get_char(index).unwrap_or(' ') == '.' ||
      text.get_char(index).unwrap_or(' ') == ')') &&
      text.get_char(index + 1).unwrap_or(' ') == ' ' {
      return Some(MarkdownBlockKind::OrderedListItem(number))
    }
  }
  None
}

///|
/// Slice `[start, end)` (UTF-16 offsets) via char access; used for the
/// rare footnote label on the shell path.
fn markdown_editor_shell_slice(
  text : String,
  start~ : Int,
  end~ : Int,
) -> String {
  let builder = StringBuilder()
  let mut index = start
  while index < end {
    let ch = text.get_char(index).unwrap_or(' ')
    builder.write_char(ch)
    index = index + ch.utf16_len()
  }
  builder.to_string()
}

///|
/// Marker-stripped content text for a shell list/quote/footnote line
/// (best-effort; the real parse replaces it on materialization).
fn markdown_editor_shell_content_text(
  text : String,
  skip_marker_length~ : Int,
) -> String {
  let chars = text.to_array()
  let mut offset = skip_marker_length
  while offset < chars.length() && (chars[offset] == ' ' || chars[offset] == '\t') {
    offset = offset + 1
  }
  String::from_array(chars[offset:])
}

///|
fn markdown_editor_shell_line_block(line : MarkdownLine) -> MarkdownEditorBlock {
  let kind = match markdown_editor_shell_structural_kind(line.text) {
    Some(kind) => kind
    None => MarkdownBlockKind::Paragraph
  }
  let text = match kind {
    MarkdownBlockKind::Heading(_) => markdown_heading_visible_source_text(
      line.text,
    )
    MarkdownBlockKind::HorizontalRule => ""
    MarkdownBlockKind::FootnoteDefinition(_) =>
      markdown_editor_shell_content_text(
        line.text,
        skip_marker_length=markdown_editor_footnote_marker_prefix_length(
          line.text,
        ),
      )
    MarkdownBlockKind::Paragraph => line.text
    _ =>
      markdown_editor_shell_content_text(
        line.text,
        skip_marker_length=markdown_editor_marker_prefix_length(line.text),
      )
  }
  {
    block: {
      kind,
      text,
      inlines: [],
      table_alignments: [],
      code_language: None,
    },
    source_range: { start: line.start, end: line.end },
    content_range: markdown_editor_content_range(line, kind),
  }
}

///|
/// A shell block: a content block produced by the shell parse — no inline
/// runs yet, non-empty text. Structural blocks (code, rule, table, html,
/// front matter) and genuinely empty blocks never qualify, and a real
/// content parse of non-empty text always yields at least one inline.
fn markdown_editor_block_is_shell(editor_block : MarkdownEditorBlock) -> Bool {
  let block = editor_block.block
  if !block.inlines.is_empty() || block.text == "" {
    return false
  }
  match block.kind {
    Paragraph
    | Heading(_)
    | UnorderedListItem
    | TaskListItem(_)
    | OrderedListItem(_)
    | Blockquote
    | FootnoteDefinition(_) => true
    CodeBlock | HorizontalRule | Table | HtmlBlock | FrontMatter => false
  }
}

///|
/// Replace a shell block with the real parse of its source slice. Pure:
/// nothing is mutated, and `parse_markdown` memoizes per text, so repeated
/// calls for the same visible block are cache hits. Blocks the real parser
/// splits differently keep their shell form (rendered as plain source text)
/// instead of corrupting block positions.
fn markdown_editor_block_materialized(
  source : String,
  source_length~ : Int,
  source_digest~ : UInt64,
  editor_block : MarkdownEditorBlock,
) -> MarkdownEditorBlock {
  if !markdown_editor_block_is_shell(editor_block) {
    return editor_block
  }
  let range = editor_block.source_range
  let slice = markdown_editor_substring(source, range.start, range.end)
  match parse_markdown(slice) {
    [real] => {
      // Reference-style links and footnotes need the whole-source
      // definition set; inline syntax does not, so most documents never
      // pay for it here.
      let needs_definitions = real.inlines.any(inline =>
        match inline.kind {
          Link => inline.target is None
          FootnoteReference(_) => true
          _ => false
        })
      let definitions = if needs_definitions {
        markdown_reference_definitions_cached_keyed(
          source,
          source_length~,
          source_digest~,
        )
      } else {
        []
      }
      let real = markdown_editor_block_with_references(real, definitions)
      // The shell's ranges are exact (the shell scan and the real parse
      // agree on block boundaries and the content-range formula), so they
      // carry over unchanged.
      {
        block: real,
        source_range: range,
        content_range: editor_block.content_range,
      }
    }
    _ => editor_block
  }
}

///|
fn markdown_editor_block_with_references(
  block : MarkdownBlock,
  definitions : Array[MarkdownReferenceDefinition],
) -> MarkdownBlock {
  match block.kind {
    CodeBlock | HorizontalRule | Table | HtmlBlock | FrontMatter => block
    _ =>
      {
        ..block,
        inlines: markdown_resolve_reference_inlines(block.inlines, definitions),
      }
  }
}

///|
struct MarkdownEditorIndentedCodeParseResult {
  block : MarkdownEditorBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_editor_indented_code_block_at(
  lines : Array[MarkdownLine],
  index : Int,
) -> MarkdownEditorIndentedCodeParseResult? {
  if !markdown_editor_indented_code_line(lines, index) {
    return None
  }
  let code_lines : Array[String] = []
  let mut next = index
  while next < lines.length() {
    if markdown_editor_indented_code_line(lines, next) {
      code_lines.push(markdown_indented_code_line_content(lines[next].text))
      next = next + 1
    } else if markdown_editor_blank_line(lines[next]) {
      match markdown_editor_next_indented_code_line_index(lines, next + 1) {
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
  let first = lines[index]
  let last = lines[next - 1]
  let content_start = first.start +
    markdown_indented_code_content_offset(first.text)
  Some({
    block: {
      block: markdown_editor_code_block(markdown_join_lines(code_lines), None),
      source_range: { start: first.start, end: last.end },
      content_range: {
        start: markdown_editor_min_int(content_start, last.end),
        end: last.end,
      },
    },
    end_index: next - 1,
  })
}

///|
fn markdown_editor_next_indented_code_line_index(
  lines : Array[MarkdownLine],
  start : Int,
) -> Int? {
  let mut index = start
  while index < lines.length() && markdown_editor_blank_line(lines[index]) {
    index = index + 1
  }
  if index < lines.length() && markdown_editor_indented_code_line(lines, index) {
    Some(index)
  } else {
    None
  }
}

///|
fn markdown_editor_blank_line(line : MarkdownLine) -> Bool {
  markdown_editor_line_text_is_blank(line.text)
}

///|
/// Whitespace-only check without the trimmed copy the string comparison
/// used to allocate once per line per parse.
fn markdown_editor_line_text_is_blank(text : String) -> Bool {
  for ch in text {
    if ch != ' ' && ch != '\t' && ch != '\r' {
      return false
    }
  }
  true
}

///|
fn markdown_editor_indented_code_line(
  lines : Array[MarkdownLine],
  index : Int,
) -> Bool {
  if index < 0 || index >= lines.length() {
    return false
  }
  markdown_indented_code_content_offset(lines[index].text) > 0
}

///|
struct MarkdownEditorParagraphParseResult {
  block : MarkdownEditorBlock
  end_index : Int
} derive(Eq, Debug)

///|
fn markdown_editor_soft_wrapped_paragraph_block_at(
  lines : Array[MarkdownLine],
  index : Int,
  definitions : Array[MarkdownReferenceDefinition],
  parse_inlines? : Bool = true,
) -> MarkdownEditorParagraphParseResult? {
  if !markdown_editor_soft_wrapped_paragraph_line(lines, index, parse_inlines~) {
    return None
  }
  let paragraph_lines : Array[MarkdownLine] = [lines[index]]
  let mut next = index + 1
  while next < lines.length() &&
        markdown_editor_setext_heading_level_at(lines, next) is None &&
        markdown_editor_soft_wrapped_paragraph_line(lines, next, parse_inlines~) {
    paragraph_lines.push(lines[next])
    next = next + 1
  }
  if paragraph_lines.length() < 2 {
    return None
  }
  let text_lines : Array[String] = []
  for line in paragraph_lines {
    text_lines.push(line.text)
  }
  let text = markdown_join_lines(text_lines)
  Some({
    block: {
      block: {
        kind: MarkdownBlockKind::Paragraph,
        text,
        inlines: if parse_inlines {
          parse_markdown_inlines_with_definitions(text, definitions)
        } else {
          []
        },
        table_alignments: [],
        code_language: None,
      },
      source_range: {
        start: paragraph_lines[0].start,
        end: paragraph_lines[paragraph_lines.length() - 1].end,
      },
      content_range: {
        start: paragraph_lines[0].start,
        end: paragraph_lines[paragraph_lines.length() - 1].end,
      },
    },
    end_index: next - 1,
  })
}

///|
/// Shell-mode paragraph classification: same shape as
/// `markdown_editor_soft_wrapped_paragraph_line` but the per-line
/// "is this plain paragraph text" question is answered by the cheap prefix
/// rules instead of running the markdown parser on every line.
fn markdown_editor_soft_wrapped_paragraph_line(
  lines : Array[MarkdownLine],
  index : Int,
  parse_inlines? : Bool = true,
) -> Bool {
  if index < 0 || index >= lines.length() {
    return false
  }
  let line = lines[index]
  if markdown_editor_line_text_is_blank(line.text) {
    return false
  }
  if !parse_inlines {
    // Shell mode: skip the char-array fence scan, the trimmed separator
    // scan and the per-line markdown parse — the cheap marker rules agree
    // with them on every common line.
    if markdown_editor_shell_line_may_open_fence(line.text) &&
      markdown_editor_opening_code_fence_marker(line.text) is Some(_) {
      return false
    }
    if markdown_editor_shell_line_opens_html(lines, index) {
      return false
    }
    if index + 1 < lines.length() {
      if lines[index + 1].text.contains("|") &&
        markdown_editor_table_block_at(lines, index) is Some(_) {
        return false
      }
      if markdown_editor_setext_underline_level(lines[index + 1].text)
        is Some(_) {
        return false
      }
    }
    return markdown_editor_shell_structural_kind(line.text) is None
  }
  if markdown_editor_opening_code_fence_marker(line.text) is Some(_) ||
    markdown_editor_table_block_at(lines, index) is Some(_) ||
    markdown_editor_setext_heading_level_at(lines, index) is Some(_) {
    return false
  }
  match parse_markdown(line.text) {
    [{ kind: MarkdownBlockKind::Paragraph, .. }] => true
    _ => false
  }
}

///|
priv struct MarkdownEditorTableParseResult {
  block : MarkdownEditorBlock
  end_index : Int
}

///|
fn markdown_editor_table_block_at(
  lines : Array[MarkdownLine],
  index : Int,
) -> MarkdownEditorTableParseResult? {
  // A separator row must contain `|`; lines whose next line has none skip
  // the trimmed cell scan entirely (this check runs once per line).
  if index + 1 >= lines.length() ||
    !lines[index + 1].text.contains("|") ||
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
  if end > start &&
    chars[end - 1] == '|' &&
    markdown_editor_table_pipe_is_separator(chars, end - 1) {
    end = end - 1
  }
  let current : Array[Char] = []
  let mut index = start
  while index < end {
    if chars[index] == '|' &&
      markdown_editor_table_pipe_is_separator(chars, index) {
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
    markdown_editor_opening_code_fence_marker(lines[index].text) is Some(_) {
    return None
  }
  // Underline first: it is a trivial character scan, and the paragraph
  // candidate mini-parse below is only worth running on the rare line
  // that actually sits above a `---`/`===` underline.
  match markdown_editor_setext_underline_level(lines[index + 1].text) {
    None => None
    Some(level) =>
      if markdown_editor_is_setext_paragraph_candidate(lines[index].text) {
        Some(level)
      } else {
        None
      }
  }
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
  // Allocation-free scan: skip leading whitespace, then require a run of
  // `=` (level 1) or `-` (level 2) covering the rest of the line.
  let length = line.length()
  let mut cursor = 0
  while cursor < length {
    let ch = line.get_char(cursor).unwrap_or(' ')
    if ch == ' ' || ch == '\t' {
      cursor = cursor + 1
    } else {
      break
    }
  }
  if cursor >= length {
    return None
  }
  let marker = line.get_char(cursor).unwrap_or(' ')
  if marker != '=' && marker != '-' {
    return None
  }
  let mut index = cursor + 1
  while index < length {
    let ch = line.get_char(index).unwrap_or(' ')
    if ch == marker {
      index = index + 1
    } else if ch == ' ' || ch == '\t' {
      // Trailing whitespace is allowed; nothing else may follow.
      index = index + 1
      while index < length {
        let tail = line.get_char(index).unwrap_or(' ')
        if tail == ' ' || tail == '\t' {
          index = index + 1
        } else {
          return None
        }
      }
      break
    } else {
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
  if !markdown_editor_code_fence_indent_allowed(chars, indent) ||
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
fn markdown_editor_blocks_to_rich_text(
  source : String,
  blocks : Array[MarkdownEditorBlock],
  base : @core.FontSpec,
  base_dir? : String? = None,
) -> RichTextDocument {
  let rich_blocks : Array[RichTextBlock] = []
  for block in blocks {
    rich_blocks.push(
      markdown_editor_block_to_rich_text(source, block, base, base_dir~),
    )
  }
  RichTextDocument::new(blocks=rich_blocks)
}

///|
fn markdown_editor_block_to_rich_text(
  source : String,
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
  base_dir? : String? = None,
) -> RichTextBlock {
  markdown_editor_block_to_rich_text_with_cache(
    source,
    editor_block,
    base,
    base_dir~,
    build=(source, editor_block, base, base_dir) => {
      markdown_editor_block_to_rich_text_uncached(
        source,
        editor_block,
        base,
        base_dir~,
      )
    },
  )
}

///|
fn markdown_editor_block_to_rich_text_uncached(
  source : String,
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
  base_dir~ : String?,
) -> RichTextBlock {
  let block = markdown_block_to_rich_text(editor_block.block, base, base_dir~)
  {
    ..block,
    runs: markdown_editor_runs_with_source_ranges(
      block.runs,
      source,
      editor_block,
    ),
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
  table : RichTextTable?,
  source : String,
  editor_block : MarkdownEditorBlock,
) -> RichTextTable? {
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
      let rows : Array[Array[RichTextTableCell]] = []
      for row_index in 0..<table.rows.length() {
        let row : Array[RichTextTableCell] = []
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
  runs : Array[RichTextRun],
  source : String,
  editor_block : MarkdownEditorBlock,
) -> Array[RichTextRun] {
  let mapped : Array[RichTextRun] = []
  let mut search = 0
  let mut index = 0
  let content = markdown_editor_run_source_content(source, editor_block)
  for run in runs {
    if editor_block.block.kind is CodeBlock &&
      editor_block.block.code_language is Some(_) &&
      index < 2 {
      mapped.push(run)
    } else if index == 0 && editor_block.block.kind is FootnoteDefinition(_) {
      mapped.push({
        ..run,
        source_range: Some({
          start: editor_block.source_range.start,
          end: editor_block.content_range.start,
        }),
      })
    } else {
      let range = markdown_editor_find_run_source_range(
        content,
        run.text,
        search,
      )
      mapped.push({
        ..run,
        source_range: Some({
          start: editor_block.content_range.start + range.start,
          end: editor_block.content_range.start + range.end,
        }),
      })
      search = range.end
    }
    index = index + 1
  }
  mapped
}

///|
fn markdown_editor_run_source_content(
  source : String,
  editor_block : MarkdownEditorBlock,
) -> String {
  match editor_block.block.kind {
    Heading(_)
    | UnorderedListItem
    | TaskListItem(_)
    | OrderedListItem(_)
    | Blockquote
    | Paragraph
    | FootnoteDefinition(_) =>
      markdown_editor_substring(
        source,
        editor_block.content_range.start,
        editor_block.content_range.end,
      )
    CodeBlock | HorizontalRule | Table | HtmlBlock | FrontMatter =>
      markdown_editor_block_source_content(editor_block)
  }
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
    FrontMatter => "---\n" + editor_block.block.text + "\n---"
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
    Paragraph | CodeBlock | HorizontalRule | Table | HtmlBlock | FrontMatter =>
      0
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
struct MarkdownEditorRunSourceRange {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
fn markdown_editor_find_run_source_range(
  content : String,
  run_text : String,
  start : Int,
) -> MarkdownEditorRunSourceRange {
  let content_chars = content.to_array()
  let run_chars = run_text.to_array()
  if run_chars.length() == 0 {
    let offset = markdown_editor_clamp_int(start, 0, content_chars.length())
    return { start: offset, end: offset }
  }
  let mut index = markdown_editor_clamp_int(start, 0, content_chars.length())
  while index < content_chars.length() {
    match
      markdown_editor_match_run_source_end(content_chars, index, run_chars) {
      Some(end) => return { start: index, end }
      None => index = index + 1
    }
  }
  let offset = markdown_editor_clamp_int(start, 0, content_chars.length())
  { start: offset, end: offset + run_chars.length() }
}

///|
fn markdown_editor_match_run_source_end(
  content : Array[Char],
  start : Int,
  target : Array[Char],
) -> Int? {
  let mut source_index = start
  let mut target_index = 0
  while target_index < target.length() {
    if source_index >= content.length() {
      return None
    }
    match markdown_html_entity_decode_at(content, source_index) {
      Some(entity) if entity.ch == target[target_index] => {
        source_index = entity.end
        target_index = target_index + 1
        continue
      }
      _ => ()
    }
    if content[source_index] == target[target_index] {
      source_index = source_index + 1
      target_index = target_index + 1
    } else if content[source_index] == '\\' &&
      source_index + 1 < content.length() &&
      content[source_index + 1] == target[target_index] {
      source_index = source_index + 2
      target_index = target_index + 1
    } else {
      return None
    }
  }
  Some(source_index)
}

///|
fn markdown_core_range(range : MarkdownSourceRange) -> RichTextSourceRange {
  { start: range.start, end: range.end }
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
    FrontMatter => "Front matter"
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
    Paragraph | CodeBlock | HorizontalRule | Table | HtmlBlock | FrontMatter =>
      0
  }
  let start = markdown_editor_min_int(line.start + offset, line.end)
  let end = match kind {
    Heading(_) =>
      markdown_editor_min_int(
        line.start +
        markdown_heading_source_content_end_offset(line.text, offset),
        line.end,
      )
    _ => line.end
  }
  { start, end: markdown_editor_max_int(start, end) }
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

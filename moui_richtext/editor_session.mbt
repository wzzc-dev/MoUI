///|
pub(all) enum MarkdownEditReason {
  LoadDocument
  TextInput
  CommandEdit
  ReplaceEdit
  ToggleTaskEdit
  MediaEdit
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownEditTransaction {
  previous_source : String
  source : String
  edit_range : MarkdownSourceRange
  replacement : String
  caret : Int
  selection : @core.TextRange?
  reason : MarkdownEditReason
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownDocumentDirtyRange {
  start_block : Int
  end_block : Int
  source_start : Int
  source_end : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownDocumentBlock {
  id : Int
  revision : Int
  source_range : MarkdownSourceRange
  content_range : MarkdownSourceRange
  kind : MarkdownBlockKind
  text : String
  fingerprint : String
  inline_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownDocumentLayoutBlock {
  block_id : Int
  block_index : Int
  revision : Int
  top : Double
  height : Double
  source_range : MarkdownSourceRange
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownDocumentBlockHeightMetric {
  block_id : Int
  block_index : Int
  revision : Int
  source_range : MarkdownSourceRange
  visual_top_units : Double
  visual_height_units : Double
  source_top_units : Double
  source_height_units : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownDocumentHeightIndex {
  visual_content_units : Double
  source_content_units : Double
  blocks : Array[MarkdownDocumentBlockHeightMetric]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownDocumentLayoutCache {
  revision : Int
  width : Double
  scroll_y : Double
  viewport_height : Double
  overscan : Double
  content_height : Double
  visible_start : Int
  visible_end : Int
  blocks : Array[MarkdownDocumentLayoutBlock]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownDocumentRichTextWindow {
  document : RichTextDocument
  content_height : Double
  top_padding : Double
  scroll_y : Double
  viewport_height : Double
  overscan : Double
  visible_start : Int
  visible_end : Int
  block_count : Int
  rendered_block_count : Int
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownDocumentSession {
  source : String
  source_length : Int
  blocks : Array[MarkdownDocumentBlock]
  editor_blocks : Array[MarkdownEditorBlock]
  line_count : Int
  word_count : Int
  reading_minutes : Int
  active_heading : String
  metadata_title : String
  metadata_tags : Array[String]
  outline : Array[MarkdownEditorOutlineItem]
  revision : Int
  parse_count : Int
  next_block_id : Int
  dirty_range : MarkdownDocumentDirtyRange?
  height_index : MarkdownDocumentHeightIndex
  layout_cache : MarkdownDocumentLayoutCache?
} derive(Eq, Debug, ToJson)

///|
pub fn MarkdownEditTransaction::replace_all(
  previous_source : String,
  source : String,
  caret? : Int = markdown_editor_text_length(source),
  selection? : @core.TextRange? = None,
  reason? : MarkdownEditReason = ReplaceEdit,
) -> MarkdownEditTransaction {
  MarkdownEditTransaction::from_sources(
    previous_source,
    source,
    caret~,
    selection~,
    reason~,
  )
}

///|
pub fn MarkdownEditTransaction::from_sources(
  previous_source : String,
  source : String,
  caret? : Int = markdown_editor_text_length(source),
  selection? : @core.TextRange? = None,
  reason? : MarkdownEditReason = TextInput,
) -> MarkdownEditTransaction {
  let previous_chars = previous_source.to_array()
  let next_chars = source.to_array()
  let mut prefix = 0
  let min_length = markdown_editor_min_int(
    previous_chars.length(),
    next_chars.length(),
  )
  while prefix < min_length && previous_chars[prefix] == next_chars[prefix] {
    prefix = prefix + 1
  }
  let mut previous_suffix = previous_chars.length()
  let mut next_suffix = next_chars.length()
  while previous_suffix > prefix &&
        next_suffix > prefix &&
        previous_chars[previous_suffix - 1] == next_chars[next_suffix - 1] {
    previous_suffix = previous_suffix - 1
    next_suffix = next_suffix - 1
  }
  {
    previous_source,
    source,
    edit_range: { start: prefix, end: previous_suffix },
    replacement: String::from_array(next_chars[prefix:next_suffix]),
    caret,
    selection,
    reason,
  }
}

///|
pub fn MarkdownEditTransaction::from_edit_result(
  previous_source : String,
  result : MarkdownEditorEditResult,
  reason? : MarkdownEditReason = CommandEdit,
) -> MarkdownEditTransaction {
  MarkdownEditTransaction::from_sources(
    previous_source,
    result.source,
    caret=result.caret,
    selection=result.selection,
    reason~,
  )
}

///|
pub fn MarkdownEditTransaction::from_input_transform(
  previous_source : String,
  transform : RichTextInputTransform,
  reason? : MarkdownEditReason = TextInput,
) -> MarkdownEditTransaction {
  MarkdownEditTransaction::from_sources(
    previous_source,
    transform.text,
    caret=transform.caret,
    selection=transform.selection,
    reason~,
  )
}

///|
pub fn MarkdownDocumentSession::new(source : String) -> MarkdownDocumentSession {
  markdown_document_session_from_blocks(
    source,
    parse_markdown_editor_blocks(source),
    previous=None,
    revision=0,
    parse_count=1,
    dirty_range=None,
  )
}

///|
pub fn MarkdownDocumentSession::source(
  self : MarkdownDocumentSession,
) -> String {
  self.source
}

///|
pub fn MarkdownDocumentSession::snapshot(
  self : MarkdownDocumentSession,
  base? : @core.FontSpec = @core.FontSpec::new(),
  base_dir? : String? = None,
) -> MarkdownEditorSnapshot {
  {
    source: self.source,
    blocks: self.editor_blocks,
    rich_text: markdown_editor_blocks_to_rich_text(
      self.source,
      self.editor_blocks,
      base,
      base_dir~,
    ),
    line_count: self.line_count,
    word_count: self.word_count,
    reading_minutes: self.reading_minutes,
    active_heading: self.active_heading,
    metadata_title: self.metadata_title,
    metadata_tags: self.metadata_tags,
    outline: self.outline,
  }
}

///|
pub fn MarkdownDocumentSession::rich_text(
  self : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  base? : @core.FontSpec = @core.FontSpec::new(),
  source_mode? : Bool = false,
  focus_mode? : Bool = false,
  base_dir? : String? = None,
) -> RichTextDocument {
  if source_mode {
    markdown_editor_format_source_mode(self.source, base)
  } else {
    let document = markdown_editor_blocks_to_rich_text(
      self.source,
      self.editor_blocks,
      base,
      base_dir~,
    )
    let revealed = markdown_document_session_reveal_selection(
      self.source,
      document,
      selection,
    )
    if focus_mode {
      markdown_editor_dim_inactive_blocks(revealed, selection)
    } else {
      revealed
    }
  }
}

///|
pub fn MarkdownDocumentSession::rich_text_window(
  self : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  base? : @core.FontSpec = @core.FontSpec::new(),
  source_mode? : Bool = false,
  focus_mode? : Bool = false,
  base_dir? : String? = None,
  scroll_y? : Double = 0.0,
  viewport_height? : Double = 0.0,
  overscan? : Double = 320.0,
) -> MarkdownDocumentRichTextWindow {
  let source_chars = if source_mode { self.source.to_array() } else { [] }
  let range = markdown_document_window_range(
    self,
    base,
    source_mode~,
    scroll_y~,
    viewport_height~,
    overscan~,
  )
  let rich_blocks : Array[RichTextBlock] = []
  if range.visible_start >= 0 && range.visible_end >= range.visible_start {
    for index in range.visible_start..<=range.visible_end {
      let editor_block = self.editor_blocks[index]
      rich_blocks.push(
        if source_mode {
          markdown_document_source_mode_block_to_rich_text(
            source_chars, editor_block, base,
          )
        } else {
          markdown_editor_block_to_rich_text(
            self.source,
            editor_block,
            base,
            base_dir~,
          )
        },
      )
    }
  }
  let document = RichTextDocument::new(blocks=rich_blocks)
  let document = if source_mode {
    document
  } else {
    let revealed = markdown_document_session_reveal_selection(
      self.source,
      document,
      selection,
    )
    if focus_mode {
      markdown_editor_dim_inactive_blocks(revealed, selection)
    } else {
      revealed
    }
  }
  {
    document,
    content_height: range.content_height,
    top_padding: range.top_padding,
    scroll_y,
    viewport_height,
    overscan,
    visible_start: range.visible_start,
    visible_end: range.visible_end,
    block_count: self.editor_blocks.length(),
    rendered_block_count: rich_blocks.length(),
  }
}

///|
pub fn MarkdownDocumentSession::estimated_content_height(
  self : MarkdownDocumentSession,
  base? : @core.FontSpec = @core.FontSpec::new(),
  source_mode? : Bool = false,
) -> Double {
  if source_mode {
    self.height_index.source_content_units * base.size
  } else {
    self.height_index.visual_content_units * base.size
  }
}

///|
pub fn MarkdownDocumentSession::source_offset_y(
  self : MarkdownDocumentSession,
  source_offset : Int,
  base? : @core.FontSpec = @core.FontSpec::new(),
  source_mode? : Bool = false,
) -> Double {
  if self.editor_blocks.length() == 0 {
    return 0.0
  }
  markdown_document_height_index_source_offset_y(
    self.height_index,
    source_offset,
    base,
    source_mode~,
  )
}

///|
pub fn MarkdownDocumentRichTextWindow::content_rect(
  self : MarkdownDocumentRichTextWindow,
  content : @core.Rect,
) -> @core.Rect {
  content.offset(dx=0.0, dy=self.top_padding - self.scroll_y)
}

///|
pub fn MarkdownDocumentRichTextWindow::caret_rect_at_source(
  self : MarkdownDocumentRichTextWindow,
  source_caret : Int,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system? : @core.TextSystem = @core.TextSystem::fallback(),
) -> @core.Rect? {
  rich_text_document_caret_rect_at_source(
    self.document,
    source_caret,
    self.content_rect(content),
    base_font,
    text_system~,
  )
}

///|
pub fn MarkdownDocumentSession::apply(
  self : MarkdownDocumentSession,
  transaction : MarkdownEditTransaction,
) -> MarkdownDocumentSession {
  if transaction.source == self.source {
    return self
  }
  let blocks = parse_markdown_editor_blocks(transaction.source)
  let dirty = markdown_document_dirty_range(transaction, blocks)
  markdown_document_session_from_blocks(
    transaction.source,
    blocks,
    previous=Some(self),
    revision=self.revision + 1,
    parse_count=self.parse_count + 1,
    dirty_range=dirty,
  )
}

///|
pub fn MarkdownDocumentSession::replace_source(
  self : MarkdownDocumentSession,
  source : String,
  reason? : MarkdownEditReason = ReplaceEdit,
) -> MarkdownDocumentSession {
  self.apply(MarkdownEditTransaction::replace_all(self.source, source, reason~))
}

///|
pub fn MarkdownDocumentSession::with_layout_cache(
  self : MarkdownDocumentSession,
  document : RichTextDocument,
  base : @core.FontSpec,
  width~ : Double,
  scroll_y~ : Double,
  viewport_height~ : Double,
  overscan? : Double = 320.0,
  text_system? : @core.TextSystem = @core.TextSystem::fallback(),
) -> MarkdownDocumentSession {
  {
    ..self,
    layout_cache: Some(
      MarkdownDocumentLayoutCache::new(
        self,
        document,
        base,
        text_system~,
        width~,
        scroll_y~,
        viewport_height~,
        overscan~,
      ),
    ),
  }
}

///|
pub fn MarkdownDocumentLayoutCache::new(
  session : MarkdownDocumentSession,
  document : RichTextDocument,
  base : @core.FontSpec,
  width~ : Double,
  scroll_y~ : Double,
  viewport_height~ : Double,
  overscan? : Double = 320.0,
  text_system? : @core.TextSystem = @core.TextSystem::fallback(),
) -> MarkdownDocumentLayoutCache {
  let layout_blocks : Array[MarkdownDocumentLayoutBlock] = []
  let mut top = 0.0
  let visible_min = scroll_y - overscan
  let visible_max = scroll_y + viewport_height + overscan
  let mut visible_start = -1
  let mut visible_end = -1
  for index, block in document.blocks {
    let height = rich_text_block_total_height(block, base, text_system)
    let bottom = top + height
    let session_block = if index < session.blocks.length() {
      session.blocks[index]
    } else {
      {
        id: index,
        revision: 0,
        source_range: { start: 0, end: 0 },
        content_range: { start: 0, end: 0 },
        kind: Paragraph,
        text: "",
        fingerprint: "",
        inline_count: 0,
      }
    }
    if bottom >= visible_min && top <= visible_max {
      if visible_start < 0 {
        visible_start = index
      }
      visible_end = index
    }
    layout_blocks.push({
      block_id: session_block.id,
      block_index: index,
      revision: session_block.revision,
      top,
      height,
      source_range: session_block.source_range,
    })
    top = bottom
  }
  {
    revision: session.revision,
    width,
    scroll_y,
    viewport_height,
    overscan,
    content_height: top,
    visible_start,
    visible_end,
    blocks: layout_blocks,
  }
}

///|
pub fn MarkdownDocumentLayoutCache::visible_block_count(
  self : MarkdownDocumentLayoutCache,
) -> Int {
  if self.visible_start < 0 || self.visible_end < self.visible_start {
    0
  } else {
    self.visible_end - self.visible_start + 1
  }
}

///|
pub fn MarkdownDocumentLayoutCache::source_offset_y(
  self : MarkdownDocumentLayoutCache,
  source_offset : Int,
) -> Double? {
  for block in self.blocks {
    if source_offset >= block.source_range.start &&
      source_offset <= block.source_range.end {
      return Some(block.top)
    }
  }
  None
}

///|
priv struct MarkdownDocumentWindowRange {
  visible_start : Int
  visible_end : Int
  top_padding : Double
  content_height : Double
}

///|
fn markdown_document_window_range(
  session : MarkdownDocumentSession,
  base : @core.FontSpec,
  source_mode~ : Bool,
  scroll_y~ : Double,
  viewport_height~ : Double,
  overscan~ : Double,
) -> MarkdownDocumentWindowRange {
  let index = session.height_index
  if index.blocks.length() == 0 {
    return {
      visible_start: -1,
      visible_end: -1,
      top_padding: 0.0,
      content_height: 0.0,
    }
  }
  let content_units = markdown_document_height_index_content_units(
    index,
    source_mode~,
  )
  let content_height = content_units * base.size
  if viewport_height <= 0.0 {
    return {
      visible_start: 0,
      visible_end: index.blocks.length() - 1,
      top_padding: 0.0,
      content_height,
    }
  }
  let visible_min_units = max_double(0.0, (scroll_y - overscan) / base.size)
  let visible_max_units = min_double(
    content_units,
    (scroll_y + viewport_height + overscan) / base.size,
  )
  let visible_start = markdown_document_height_index_block_at_units(
    index,
    visible_min_units,
    source_mode~,
  )
  let visible_end = markdown_document_height_index_block_at_units(
    index,
    visible_max_units,
    source_mode~,
  )
  let top_padding = markdown_document_height_metric_top_units(
      index.blocks[visible_start],
      source_mode~,
    ) *
    base.size
  { visible_start, visible_end, top_padding, content_height }
}

///|
fn markdown_document_height_index_content_units(
  index : MarkdownDocumentHeightIndex,
  source_mode~ : Bool,
) -> Double {
  if source_mode {
    index.source_content_units
  } else {
    index.visual_content_units
  }
}

///|
fn markdown_document_height_index(
  source : String,
  editor_blocks : Array[MarkdownEditorBlock],
  blocks : Array[MarkdownDocumentBlock],
) -> MarkdownDocumentHeightIndex {
  let source_chars = source.to_array()
  let metrics : Array[MarkdownDocumentBlockHeightMetric] = []
  let mut visual_top_units = 0.0
  let mut source_top_units = 0.0
  for index, editor_block in editor_blocks {
    let session_block = blocks[index]
    let visual_height_units = markdown_document_estimated_editor_block_height_units(
      editor_block,
    )
    let source_height_units = markdown_document_source_range_line_count(
        source_chars,
        editor_block.source_range,
      ).to_double() *
      1.42
    metrics.push({
      block_id: session_block.id,
      block_index: index,
      revision: session_block.revision,
      source_range: editor_block.source_range,
      visual_top_units,
      visual_height_units,
      source_top_units,
      source_height_units,
    })
    visual_top_units = visual_top_units + visual_height_units
    source_top_units = source_top_units + source_height_units
  }
  {
    visual_content_units: visual_top_units,
    source_content_units: source_top_units,
    blocks: metrics,
  }
}

///|
fn markdown_document_height_index_block_at_units(
  index : MarkdownDocumentHeightIndex,
  y_units : Double,
  source_mode~ : Bool,
) -> Int {
  let count = index.blocks.length()
  if count == 0 {
    return -1
  }
  if y_units <= 0.0 {
    return 0
  }
  let mut low = 0
  let mut high = count - 1
  let mut answer = count - 1
  while low <= high {
    let mid = (low + high) / 2
    let metric = index.blocks[mid]
    let bottom = markdown_document_height_metric_top_units(metric, source_mode~) +
      markdown_document_height_metric_height_units(metric, source_mode~)
    if bottom >= y_units {
      answer = mid
      high = mid - 1
    } else {
      low = mid + 1
    }
  }
  answer
}

///|
fn markdown_document_height_index_source_offset_y(
  index : MarkdownDocumentHeightIndex,
  source_offset : Int,
  base : @core.FontSpec,
  source_mode~ : Bool,
) -> Double {
  let count = index.blocks.length()
  if count == 0 {
    return 0.0
  }
  let mut low = 0
  let mut high = count - 1
  let mut answer = count
  while low <= high {
    let mid = (low + high) / 2
    let range = index.blocks[mid].source_range
    if source_offset <= range.end {
      answer = mid
      high = mid - 1
    } else {
      low = mid + 1
    }
  }
  if answer >= count {
    markdown_document_height_index_content_units(index, source_mode~) *
    base.size
  } else {
    markdown_document_height_metric_top_units(
      index.blocks[answer],
      source_mode~,
    ) *
    base.size
  }
}

///|
fn markdown_document_height_metric_top_units(
  metric : MarkdownDocumentBlockHeightMetric,
  source_mode~ : Bool,
) -> Double {
  if source_mode {
    metric.source_top_units
  } else {
    metric.visual_top_units
  }
}

///|
fn markdown_document_height_metric_height_units(
  metric : MarkdownDocumentBlockHeightMetric,
  source_mode~ : Bool,
) -> Double {
  if source_mode {
    metric.source_height_units
  } else {
    metric.visual_height_units
  }
}

///|
fn markdown_document_estimated_editor_block_height_units(
  editor_block : MarkdownEditorBlock,
) -> Double {
  let line_count = markdown_document_estimated_visual_line_count(editor_block)
  let line_height = markdown_document_estimated_line_height_units(
    editor_block.block.kind,
  )
  let inset_units = markdown_document_estimated_inset_units(
    editor_block.block.kind,
  )
  let mut height_units = line_height * line_count.to_double()
  if editor_block.block.kind is Table {
    height_units = max_double(height_units, 1.9 * line_count.to_double())
  }
  if markdown_document_block_has_image(editor_block.block) {
    height_units = max_double(height_units, 4.5)
  }
  height_units + inset_units.top + inset_units.bottom
}

///|
fn markdown_document_estimated_visual_line_count(
  editor_block : MarkdownEditorBlock,
) -> Int {
  let text_lines = markdown_editor_max_int(
    1,
    1 + markdown_document_newline_count(editor_block.block.text),
  )
  match editor_block.block.kind {
    CodeBlock =>
      match editor_block.block.code_language {
        Some(_) => text_lines + 1
        None => text_lines
      }
    _ => text_lines
  }
}

///|
fn markdown_document_estimated_line_height_units(
  kind : MarkdownBlockKind,
) -> Double {
  match kind {
    Heading(level) => markdown_heading_line_height_scale(level)
    CodeBlock => 1.1
    HorizontalRule => 1.0
    Table => 1.35
    FootnoteDefinition(_) => 1.45
    HtmlBlock | FrontMatter => 1.25
    Paragraph
    | UnorderedListItem
    | TaskListItem(_)
    | OrderedListItem(_)
    | Blockquote => 1.55
  }
}

///|
fn markdown_document_estimated_inset_units(
  kind : MarkdownBlockKind,
) -> @core.Insets {
  match kind {
    Heading(_) => { top: 0.6, right: 0.0, bottom: 0.3, left: 0.0 }
    Blockquote => { top: 0.43, right: 0.0, bottom: 0.86, left: 1.0 }
    CodeBlock => { top: 0.86, right: 1.0, bottom: 0.86, left: 1.0 }
    Table => { top: 0.43, right: 0.71, bottom: 0.43, left: 0.71 }
    FootnoteDefinition(_) => { top: 0.14, right: 0.0, bottom: 0.14, left: 0.86 }
    HtmlBlock => { top: 0.29, right: 0.71, bottom: 0.29, left: 0.71 }
    FrontMatter => { top: 0.43, right: 0.71, bottom: 0.43, left: 0.71 }
    Paragraph => { top: 0.0, right: 0.0, bottom: 0.4, left: 0.0 }
    UnorderedListItem | TaskListItem(_) | OrderedListItem(_) | HorizontalRule =>
      @core.Insets::symmetric()
  }
}

///|
fn markdown_document_block_has_image(block : MarkdownBlock) -> Bool {
  block.inlines.any(inline => inline.kind is Image)
}

///|
fn markdown_document_newline_count(text : String) -> Int {
  let mut count = 0
  for ch in text {
    if ch == '\n' {
      count = count + 1
    }
  }
  count
}

///|
fn markdown_document_source_range_line_count(
  source_chars : Array[Char],
  range : MarkdownSourceRange,
) -> Int {
  if source_chars.length() == 0 {
    return 1
  }
  let start = markdown_editor_clamp_int(range.start, 0, source_chars.length())
  let end = markdown_editor_clamp_int(range.end, start, source_chars.length())
  let mut lines = 1
  for index in start..<end {
    if source_chars[index] == '\n' {
      lines = lines + 1
    }
  }
  lines
}

///|
fn markdown_document_source_mode_block_to_rich_text(
  source_chars : Array[Char],
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
) -> RichTextBlock {
  let start = markdown_editor_clamp_int(
    editor_block.source_range.start,
    0,
    source_chars.length(),
  )
  let end = markdown_editor_clamp_int(
    editor_block.source_range.end,
    start,
    source_chars.length(),
  )
  let text = String::from_array(source_chars[start:end])
  let range = markdown_core_range(editor_block.source_range)
  let font = {
    ..base,
    families: @core.FontFamilyStack::monospace(),
    size: base.size * 0.92,
  }
  RichTextBlock::new(
    runs=[RichTextRun::new(text~, font=Some(font), source_range=Some(range))],
    font=Some(font),
    source_range=Some(range),
    content_range=Some(range),
    line_height=Some(base.size * 1.42),
  )
}

///|
fn markdown_document_session_from_blocks(
  source : String,
  editor_blocks : Array[MarkdownEditorBlock],
  previous~ : MarkdownDocumentSession?,
  revision~ : Int,
  parse_count~ : Int,
  dirty_range~ : MarkdownDocumentDirtyRange?,
) -> MarkdownDocumentSession {
  let word_count = markdown_editor_word_count(source)
  let metadata = markdown_editor_front_matter_metadata(editor_blocks)
  let next_block_id_seed = match previous {
    Some(prev) => prev.next_block_id
    None => 1
  }
  let assigned = markdown_document_assign_blocks(
    editor_blocks,
    previous~,
    next_id=next_block_id_seed,
    dirty_range~,
  )
  let height_index = markdown_document_height_index(
    source,
    editor_blocks,
    assigned.blocks,
  )
  {
    source,
    source_length: markdown_editor_text_length(source),
    blocks: assigned.blocks,
    editor_blocks,
    line_count: markdown_editor_line_count(source),
    word_count,
    reading_minutes: markdown_editor_reading_minutes(word_count),
    active_heading: markdown_editor_active_heading(editor_blocks),
    metadata_title: metadata.title,
    metadata_tags: metadata.tags,
    outline: markdown_editor_outline(editor_blocks),
    revision,
    parse_count,
    next_block_id: assigned.next_id,
    dirty_range,
    height_index,
    layout_cache: None,
  }
}

///|
priv struct MarkdownDocumentBlockAssignment {
  blocks : Array[MarkdownDocumentBlock]
  next_id : Int
}

///|
fn markdown_document_assign_blocks(
  editor_blocks : Array[MarkdownEditorBlock],
  previous~ : MarkdownDocumentSession?,
  next_id~ : Int,
  dirty_range~ : MarkdownDocumentDirtyRange?,
) -> MarkdownDocumentBlockAssignment {
  let blocks : Array[MarkdownDocumentBlock] = []
  let used_previous : Array[Bool] = []
  match previous {
    Some(prev) =>
      for _ in prev.blocks {
        used_previous.push(false)
      }
    None => ()
  }
  let mut next_id = next_id
  for index, editor_block in editor_blocks {
    let fingerprint = markdown_document_block_fingerprint(editor_block)
    let matched = markdown_document_match_previous_block(
      previous, used_previous, index, fingerprint,
    )
    let dirty = markdown_document_block_index_dirty(dirty_range, index)
    let (id, block_revision) = match matched {
      Some(match_index) => {
        guard previous is Some(prev) else { (next_id, 0) }
        used_previous[match_index] = true
        let previous_block = prev.blocks[match_index]
        (
          previous_block.id,
          if dirty || previous_block.fingerprint != fingerprint {
            previous_block.revision + 1
          } else {
            previous_block.revision
          },
        )
      }
      None => {
        let id = next_id
        next_id = next_id + 1
        (id, 0)
      }
    }
    blocks.push({
      id,
      revision: block_revision,
      source_range: editor_block.source_range,
      content_range: editor_block.content_range,
      kind: editor_block.block.kind,
      text: editor_block.block.text,
      fingerprint,
      inline_count: editor_block.block.inlines.length(),
    })
  }
  { blocks, next_id }
}

///|
fn markdown_document_match_previous_block(
  previous : MarkdownDocumentSession?,
  used_previous : Array[Bool],
  index : Int,
  fingerprint : String,
) -> Int? {
  match previous {
    Some(prev) => {
      if index < prev.blocks.length() &&
        !used_previous[index] &&
        prev.blocks[index].fingerprint == fingerprint {
        return Some(index)
      }
      for previous_index, block in prev.blocks {
        if !used_previous[previous_index] && block.fingerprint == fingerprint {
          return Some(previous_index)
        }
      }
      if index < prev.blocks.length() && !used_previous[index] {
        Some(index)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn markdown_document_block_index_dirty(
  dirty_range : MarkdownDocumentDirtyRange?,
  index : Int,
) -> Bool {
  match dirty_range {
    Some(range) => index >= range.start_block && index <= range.end_block
    None => false
  }
}

///|
fn markdown_document_block_fingerprint(block : MarkdownEditorBlock) -> String {
  markdown_document_block_kind_key(block.block.kind) + ":" + block.block.text
}

///|
fn markdown_document_block_kind_key(kind : MarkdownBlockKind) -> String {
  match kind {
    Heading(level) => "heading:\{level}"
    Paragraph => "paragraph"
    UnorderedListItem => "ul"
    TaskListItem(checked) => if checked { "task:checked" } else { "task" }
    OrderedListItem(number) => "ol:\{number}"
    Blockquote => "quote"
    CodeBlock => "code"
    HorizontalRule => "rule"
    Table => "table"
    FootnoteDefinition(label) => "footnote:\{label}"
    HtmlBlock => "html"
    FrontMatter => "front-matter"
  }
}

///|
fn markdown_document_dirty_range(
  transaction : MarkdownEditTransaction,
  blocks : Array[MarkdownEditorBlock],
) -> MarkdownDocumentDirtyRange? {
  if blocks.length() == 0 {
    return None
  }
  let source_start = transaction.edit_range.start
  let inserted_length = markdown_editor_text_length(transaction.replacement)
  let source_end = source_start + inserted_length
  let context_all = markdown_document_transaction_needs_global_context(
    transaction,
  )
  if context_all {
    return Some({
      start_block: 0,
      end_block: blocks.length() - 1,
      source_start: 0,
      source_end: markdown_editor_text_length(transaction.source),
    })
  }
  let mut start_block = -1
  let mut end_block = -1
  for index, block in blocks {
    if markdown_document_ranges_touch(
        block.source_range.start,
        block.source_range.end,
        source_start,
        source_end,
      ) {
      if start_block < 0 {
        start_block = index
      }
      end_block = index
    }
  }
  if start_block < 0 {
    start_block = markdown_document_block_index_after_source(
      blocks, source_start,
    )
    end_block = start_block
  }
  start_block = markdown_editor_clamp_int(
    start_block - 1,
    0,
    blocks.length() - 1,
  )
  end_block = markdown_editor_clamp_int(
    end_block + 1,
    start_block,
    blocks.length() - 1,
  )
  Some({ start_block, end_block, source_start, source_end })
}

///|
fn markdown_document_transaction_needs_global_context(
  transaction : MarkdownEditTransaction,
) -> Bool {
  let text = transaction.replacement +
    markdown_editor_substring(
      transaction.previous_source,
      transaction.edit_range.start,
      transaction.edit_range.end,
    )
  text.contains("```") ||
  text.contains("~~~") ||
  text.contains("]:") ||
  text.has_prefix("---")
}

///|
fn markdown_document_ranges_touch(
  start_a : Int,
  end_a : Int,
  start_b : Int,
  end_b : Int,
) -> Bool {
  if start_b == end_b {
    start_b >= start_a && start_b <= end_a
  } else {
    start_a <= end_b && end_a >= start_b
  }
}

///|
fn markdown_document_block_index_after_source(
  blocks : Array[MarkdownEditorBlock],
  source_offset : Int,
) -> Int {
  for index, block in blocks {
    if source_offset <= block.source_range.end {
      return index
    }
  }
  blocks.length() - 1
}

///|
fn markdown_document_session_reveal_selection(
  source : String,
  document : RichTextDocument,
  selection : MarkdownEditorSelection,
) -> RichTextDocument {
  let blocks : Array[RichTextBlock] = []
  for block in document.blocks {
    let runs : Array[RichTextRun] = []
    for run in block.runs {
      runs.push(
        markdown_editor_reveal_active_inline_run(source, selection, run),
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
fn rich_text_block_total_height(
  block : RichTextBlock,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Double {
  rich_text_block_line_height(block, base_font, text_system) +
  block.inset.top +
  block.inset.bottom
}

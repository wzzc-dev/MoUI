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
  source_digest : UInt64
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
  let previous_length = markdown_editor_text_length(previous_source)
  let source_length = markdown_editor_text_length(source)
  let (prefix, _, source_prefix_offset) = markdown_document_common_prefix(
    previous_source, source, previous_length, source_length,
  )
  let suffix = markdown_document_common_suffix_length(
    previous_source, source, previous_length, source_length, prefix,
  )
  let previous_suffix = previous_length - suffix
  let next_suffix = source_length - suffix
  {
    previous_source,
    source,
    edit_range: { start: prefix, end: previous_suffix },
    replacement: markdown_document_source_substring_after_prefix(
      source, source_length, prefix, next_suffix, source_prefix_offset,
    ),
    caret,
    selection,
    reason,
  }
}

///|
fn markdown_document_common_prefix(
  previous_source : String,
  source : String,
  previous_length : Int,
  source_length : Int,
) -> (Int, Int, Int) {
  let previous_utf16_length = previous_source.length()
  let source_utf16_length = source.length()
  let limit = markdown_editor_min_int(previous_length, source_length)
  let mut index = 0
  let mut previous_offset = 0
  let mut source_offset = 0
  while index < limit &&
        previous_offset < previous_utf16_length &&
        source_offset < source_utf16_length {
    match
      (
        previous_source.get_char(previous_offset),
        source.get_char(source_offset),
      ) {
      (Some(previous_char), Some(source_char)) =>
        if previous_char == source_char {
          previous_offset = previous_offset + previous_char.utf16_len()
          source_offset = source_offset + source_char.utf16_len()
          index = index + 1
        } else {
          return (index, previous_offset, source_offset)
        }
      _ => return (index, previous_offset, source_offset)
    }
  }
  (index, previous_offset, source_offset)
}

///|
fn markdown_document_common_suffix_length(
  previous_source : String,
  source : String,
  previous_length : Int,
  source_length : Int,
  prefix : Int,
) -> Int {
  let limit = markdown_editor_min_int(
    previous_length - prefix,
    source_length - prefix,
  )
  let previous_iter = previous_source.rev_iter()
  let source_iter = source.rev_iter()
  let mut suffix = 0
  while suffix < limit {
    match (previous_iter.next(), source_iter.next()) {
      (Some(previous_char), Some(source_char)) =>
        if previous_char == source_char {
          suffix = suffix + 1
        } else {
          return suffix
        }
      _ => return suffix
    }
  }
  suffix
}

///|
fn markdown_document_source_substring_after_prefix(
  source : String,
  source_length : Int,
  start : Int,
  end : Int,
  start_offset : Int,
) -> String {
  let source_utf16_length = source.length()
  let end_offset = if end == source_length {
    source_utf16_length
  } else {
    source
    .offset_of_nth_char(
      end - start,
      start_offset~,
      end_offset=source_utf16_length,
    )
    .unwrap_or(source_utf16_length)
  }
  source.sub(start=start_offset, end=end_offset).to_owned()
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
  hot_path_full_parse_count.val = hot_path_full_parse_count.val + 1
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
  content_width? : Double = 0.0,
) -> MarkdownDocumentRichTextWindow {
  let range = markdown_document_window_range(
    self,
    base,
    source_mode~,
    scroll_y~,
    viewport_height~,
    overscan~,
    content_width~,
  )
  let (source_chars, source_char_offset) = if source_mode &&
    range.visible_start >= 0 &&
    range.visible_end >= range.visible_start {
    let source_start = self.editor_blocks[range.visible_start].source_range.start
    let source_end = self.editor_blocks[range.visible_end].source_range.end
    (
      markdown_document_source_chars_in_range(
        self.source,
        self.source_length,
        source_start,
        source_end,
      ),
      source_start,
    )
  } else {
    ([], 0)
  }
  let rich_blocks : Array[RichTextBlock] = []
  if range.visible_start >= 0 && range.visible_end >= range.visible_start {
    for index in range.visible_start..<=range.visible_end {
      let editor_block = self.editor_blocks[index]
      rich_blocks.push(
        if source_mode {
          markdown_document_source_mode_block_to_rich_text(
            source_chars, source_char_offset, editor_block, base,
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
  content_width? : Double = 0.0,
) -> Double {
  if source_mode {
    self.height_index.source_content_units * base.size
  } else {
    match markdown_document_block_geometry(self, base, content_width~) {
      Some(geometry) =>
        markdown_document_scroll_geometry_prefix_at(
          geometry,
          count=geometry.heights.length(),
        )
      None => self.height_index.visual_content_units * base.size
    }
  }
}

///|
pub fn MarkdownDocumentSession::source_offset_y(
  self : MarkdownDocumentSession,
  source_offset : Int,
  base? : @core.FontSpec = @core.FontSpec::new(),
  source_mode? : Bool = false,
  content_width? : Double = 0.0,
) -> Double {
  if self.editor_blocks.length() == 0 {
    return 0.0
  }
  if !source_mode {
    match markdown_document_block_heights(self, base, content_width~) {
      Some(heights) =>
        return markdown_document_gallery_source_offset_y(
          self, source_offset, heights,
        )
      None => ()
    }
  }
  markdown_document_height_index_source_offset_y(
    self.height_index,
    source_offset,
    base,
    source_mode~,
  )
}

///|
fn MarkdownDocumentRichTextWindow::content_rect(
  self : MarkdownDocumentRichTextWindow,
  content : @core.Rect,
) -> @core.Rect {
  content.offset(dx=0.0, dy=self.top_padding - self.scroll_y)
}

///|
pub fn MarkdownDocumentSession::apply(
  self : MarkdownDocumentSession,
  transaction : MarkdownEditTransaction,
) -> MarkdownDocumentSession {
  if transaction.source == self.source {
    return self
  }
  match markdown_document_session_apply_incremental(self, transaction) {
    Some(next) => next
    None => {
      hot_path_full_parse_count.val = hot_path_full_parse_count.val + 1
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
  }
}

///|
/// Incremental `apply`: re-parse only the blank-line-delimited block
/// cluster containing the edit, rebase the re-parsed region into new
/// source offsets, and shift the untouched suffix blocks by the edit
/// delta. Returns None when the full-document parse is required:
/// structural context markers (fences, `]:`, leading `---`), edits
/// carrying reference-definition characters (the definition set is a
/// whole-source property), and edits inside front matter. Edits that
/// touch newlines also force the full parse (they can merge or split
/// clusters) — with one fence-aware exception: a keystroke that stays
/// strictly inside a fenced code block (never touching its opener or
/// closer line, never typing fence characters) keeps the fence exactly
/// as bounded as it was, newlines included, so typing code re-parses
/// just the one fenced block.
fn markdown_document_session_apply_incremental(
  session : MarkdownDocumentSession,
  transaction : MarkdownEditTransaction,
) -> MarkdownDocumentSession? {
  let deleted = markdown_editor_substring(
    transaction.previous_source,
    transaction.edit_range.start,
    transaction.edit_range.end,
  )
  let blocks = session.editor_blocks
  let edit_in_front_matter = blocks.length() > 0 &&
    blocks[0].block.kind is FrontMatter &&
    transaction.edit_range.start <= blocks[0].source_range.end
  if blocks.length() == 0 ||
    edit_in_front_matter ||
    !markdown_document_transaction_incremental_safe(transaction, deleted) {
    hot_path_incremental_fallback_count.val = hot_path_incremental_fallback_count.val +
      1
    return None
  }
  match markdown_document_edit_cluster(session.editor_blocks, transaction) {
    Some(cluster) => {
      // The cluster is re-parseable on its own only when its swallowable
      // blocks (currently code fences) are entered strictly from the
      // inside; that single decision also licenses newline edits, which
      // a fence swallows.
      let interior_fence_edit = cluster_interior_fence_edit(
        session.editor_blocks,
        cluster,
        transaction,
        deleted,
      )
      guard markdown_document_newlines_safe(
          transaction,
          deleted,
          interior_fence_edit~,
        ) &&
        markdown_document_region_can_stitch(
          session.editor_blocks,
          cluster,
          interior_fence_edit~,
        ) else {
        hot_path_incremental_fallback_count.val = hot_path_incremental_fallback_count.val +
          1
        return None
      }
      let delta = markdown_editor_text_length(transaction.replacement) -
        markdown_editor_text_length(deleted)
      let region_end = if cluster.end_index >=
        session.editor_blocks.length() - 1 {
        markdown_editor_text_length(transaction.previous_source)
      } else {
        cluster.end_block_end
      }
      let region_slice = markdown_editor_substring(
        transaction.source,
        cluster.start_block_start,
        markdown_editor_min_int(
          region_end + delta,
          markdown_editor_text_length(transaction.source),
        ),
      )
      // Definitions keyed by the previous session's (length, digest) pair:
      // no multi-megabyte map-key hashing on the hot path.
      let definitions = markdown_reference_definitions_cached_keyed(
        transaction.previous_source,
        source_length=transaction.previous_source.length(),
        source_digest=session.source_digest,
      )
      let reparsed = parse_markdown_editor_blocks_with_definitions(
        region_slice,
        definitions=Some(definitions),
      )
      let stitched : Array[MarkdownEditorBlock] = []
      for index, block in session.editor_blocks {
        if index < cluster.start_index {
          stitched.push(block)
        }
      }
      for block in reparsed {
        stitched.push({
          ..block,
          source_range: {
            start: block.source_range.start + cluster.start_block_start,
            end: block.source_range.end + cluster.start_block_start,
          },
          content_range: {
            start: block.content_range.start + cluster.start_block_start,
            end: block.content_range.end + cluster.start_block_start,
          },
        })
      }
      for index, block in session.editor_blocks {
        if index > cluster.end_index {
          stitched.push({
            ..block,
            source_range: {
              start: block.source_range.start + delta,
              end: block.source_range.end + delta,
            },
            content_range: {
              start: block.content_range.start + delta,
              end: block.content_range.end + delta,
            },
          })
        }
      }
      hot_path_region_reparse_count.val = hot_path_region_reparse_count.val + 1
      // The guard above proved this edit cannot change the whole-source
      // definition set, so publish the previous set under the edited
      // source's (length, digest) key; the next keystroke's lookup then
      // hits instead of re-running the whole-document definition parse.
      // The edited source's digest is computed once here and reused by the
      // session construction below.
      let next_source_digest = markdown_document_source_digest(
        transaction.source,
      )
      markdown_reference_definitions_cache_store_keyed(
        source_length=transaction.source.length(),
        source_digest=next_source_digest,
        definitions,
      )
      let dirty = markdown_document_dirty_range(transaction, stitched)
      let reindex : MarkdownDocumentReindexWindow = {
        prefix_count: cluster.start_index,
        suffix_new_start: cluster.start_index + reparsed.length(),
        suffix_shift: cluster.end_index +
        1 -
        (cluster.start_index + reparsed.length()),
        old_region_start: cluster.start_block_start,
        old_region_end: region_end,
        edit_start: transaction.edit_range.start,
        deleted,
        replacement: transaction.replacement,
        char_delta: delta,
      }
      markdown_document_session_from_blocks(
        transaction.source,
        stitched,
        previous=Some(session),
        revision=session.revision + 1,
        parse_count=session.parse_count + 1,
        dirty_range=dirty,
        reindex=Some(reindex),
        source_digest=Some(next_source_digest),
      )
      |> Some
    }
    None => {
      hot_path_incremental_fallback_count.val = hot_path_incremental_fallback_count.val +
        1
      None
    }
  }
}

///|
/// True when a transaction can be handled incrementally: no structural
/// context markers and no reference-definition characters (`[`, `]`, `:`)
/// that could change the whole-source definition set or a link span
/// inside a block. Newline safety is decided once the edit cluster is
/// known (`markdown_document_newlines_safe`), because a newline inside a
/// fenced block is structurally inert.
fn markdown_document_transaction_incremental_safe(
  transaction : MarkdownEditTransaction,
  deleted : String,
) -> Bool {
  !markdown_document_transaction_needs_global_context(transaction) &&
  !markdown_document_text_may_touch_reference_definition(
    transaction.replacement,
  ) &&
  !markdown_document_text_may_touch_reference_definition(deleted)
}

///|
/// The fence edit keeps the block's span iff it (a) types or deletes no
/// fence character, (b) starts strictly after the opener line — a change
/// on the opener can stop it opening a fence — and (c) stays strictly
/// before the closer line — typing on the closer stops it closing, which
/// would make the fence swallow the rest of the document. An unclosed
/// fence running to the end of the source has no closer line to protect,
/// so its last (interior) line is editable.
fn markdown_document_fence_edit_is_interior(
  editor_block : MarkdownEditorBlock,
  transaction : MarkdownEditTransaction,
  deleted : String,
) -> Bool {
  editor_block.block.kind is CodeBlock &&
  !markdown_document_edit_text_has_fence_char(transaction.replacement) &&
  !markdown_document_edit_text_has_fence_char(deleted) &&
  markdown_document_fence_interior_bounds(editor_block, transaction)
}

///|
/// One forward pass over the fence block's source: remember the end of
/// the opener line (first newline at or after the block start) and the
/// start of the last line together with whether that last line is
/// fence-character-only. The edit range must live in
/// `[opener_end, closer_start)`; an unclosed fence that runs to the end
/// of the source (and whose last line is not fence-only) has no closer
/// line, so its bound is the block end itself.
fn markdown_document_fence_interior_bounds(
  editor_block : MarkdownEditorBlock,
  transaction : MarkdownEditTransaction,
) -> Bool {
  let previous = transaction.previous_source
  let previous_length = markdown_editor_text_length(previous)
  let range = editor_block.source_range
  let iterator = previous.iter()
  let mut index = 0
  let mut opener_end = -1
  let mut last_line_start = range.start
  let mut last_line_fence_only = true
  let mut scanning = true
  while scanning {
    match iterator.next() {
      Some(ch) => {
        // A trailing newline may or may not belong to the block range;
        // treat it as line terminator, never as line content, so the
        // closer-line logic works for either parser convention.
        if index == range.end - 1 && ch == '\n' {

        } else if ch == '\n' {
          if index >= range.start && opener_end < 0 {
            opener_end = index + 1
          }
          if index >= range.start && index < range.end {
            last_line_start = index + 1
            last_line_fence_only = true
          }
        } else if index >= range.start &&
          index < range.end &&
          !(ch == ' ' || ch == '\t' || ch == '`' || ch == '~') {
          last_line_fence_only = false
        }
        index = index + 1
        if index >= range.end && opener_end >= 0 {
          scanning = false
        }
      }
      None => scanning = false
    }
  }
  if opener_end < 0 {
    opener_end = range.end
  }
  let closed_fence = range.end < previous_length || last_line_fence_only
  let closer_start = if closed_fence { last_line_start } else { range.end }
  let end_ok = if closed_fence {
    transaction.edit_range.end < closer_start
  } else {
    // Unclosed fence: the document tail is still interior code, so an
    // edit ending exactly at the block end is fine too.
    transaction.edit_range.end <= closer_start
  }
  transaction.edit_range.start >= opener_end && end_ok
}

///|
fn markdown_document_edit_text_has_fence_char(text : String) -> Bool {
  text.contains("`") || text.contains("~")
}

///|
/// Edits touching newlines can merge or split blank-line clusters and
/// are only safe inside a fenced code block, which swallows them.
fn markdown_document_newlines_safe(
  transaction : MarkdownEditTransaction,
  deleted : String,
  interior_fence_edit~ : Bool,
) -> Bool {
  interior_fence_edit ||
  !(transaction.replacement.contains("\n") || deleted.contains("\n"))
}

///|
/// True when every swallowable block in the cluster (fences, HTML,
/// tables, footnote definitions) keeps its span across the edit: re-
/// parsing the cluster then reproduces the suffix boundary exactly. Only
/// code fences admit this, and only for strictly-interior edits (already
/// decided once as `interior_fence_edit`); HTML blocks, tables, and
/// footnote definitions always force the full-parse fallback.
fn markdown_document_region_can_stitch(
  blocks : Array[MarkdownEditorBlock],
  cluster : MarkdownDocumentEditCluster,
  interior_fence_edit~ : Bool,
) -> Bool {
  for index in cluster.start_index..<=cluster.end_index {
    match blocks[index].block.kind {
      CodeBlock if interior_fence_edit => ()
      CodeBlock | HtmlBlock | Table | FootnoteDefinition(_) => return false
      _ => ()
    }
  }
  true
}

///|
/// True when the whole cluster is a single code fence and the edit stays
/// strictly in its interior (never on the opener or closer line, no
/// fence characters typed or deleted). The fence then keeps exactly the
/// span it had, newlines included.
fn cluster_interior_fence_edit(
  blocks : Array[MarkdownEditorBlock],
  cluster : MarkdownDocumentEditCluster,
  transaction : MarkdownEditTransaction,
  deleted : String,
) -> Bool {
  cluster.start_index == cluster.end_index &&
  markdown_document_fence_edit_is_interior(
    blocks[cluster.start_index],
    transaction,
    deleted,
  )
}

///|
fn markdown_document_text_may_touch_reference_definition(text : String) -> Bool {
  text.contains("[") || text.contains("]") || text.contains(":")
}

///|
priv struct MarkdownDocumentEditCluster {
  start_index : Int
  end_index : Int
  start_block_start : Int
  end_block_end : Int
}

///|
/// The exact block reindexing an incremental apply produced: new blocks
/// `[0, prefix_count)` are content-identical to the previous blocks at the
/// same index, new blocks `[suffix_new_start, n)` are content-identical to
/// previous blocks at `index + suffix_shift`, and the window between them
/// is the re-parsed region (previous-source coordinates
/// `[old_region_start, old_region_end)`). Derived bookkeeping — block
/// fingerprints, height metrics, outline, word/line counts — may reuse the
/// previous session's results outside the window and recompute only inside
/// it. `edit_start`/`deleted`/`replacement`/`char_delta` describe the
/// character edit itself, which the count deltas need.
priv struct MarkdownDocumentReindexWindow {
  prefix_count : Int
  suffix_new_start : Int
  suffix_shift : Int
  old_region_start : Int
  old_region_end : Int
  edit_start : Int
  deleted : String
  replacement : String
  char_delta : Int
}

///|
/// Validate a reindex window against the sessions it claims to describe.
/// Bookkeeping reuse falls back to full computation whenever this fails.
fn markdown_document_reindex_window_fits(
  window : MarkdownDocumentReindexWindow,
  previous : MarkdownDocumentSession,
  new_block_count : Int,
) -> Bool {
  let suffix_old_start = window.suffix_new_start + window.suffix_shift
  let old_window_count = suffix_old_start - window.prefix_count
  window.prefix_count >= 0 &&
  window.prefix_count <= window.suffix_new_start &&
  window.suffix_new_start <= new_block_count &&
  old_window_count >= 1 &&
  suffix_old_start <= previous.blocks.length() &&
  suffix_old_start + (new_block_count - window.suffix_new_start) ==
  previous.blocks.length() &&
  previous.height_index.blocks.length() == previous.blocks.length() &&
  window.old_region_start <= window.old_region_end
}

///|
/// The blank-line-delimited block cluster containing the edit. Blank-line
/// blocks are hard parser boundaries — no setext underline, table, list,
/// indented code block, or soft-wrapped paragraph continues across one,
/// and fences/definitions that could span them are excluded earlier — so
/// re-parsing just this cluster reproduces exactly what the full parse
/// produces for the same source range. A blank block is its own cluster.
fn markdown_document_edit_cluster(
  blocks : Array[MarkdownEditorBlock],
  transaction : MarkdownEditTransaction,
) -> MarkdownDocumentEditCluster? {
  let edit_start = transaction.edit_range.start
  let edit_end = markdown_editor_max_int(transaction.edit_range.end, edit_start)
  let mut start_index = blocks.length() - 1
  for index, block in blocks {
    if block.source_range.end >= edit_start {
      start_index = index
      break
    }
  }
  let mut end_index = start_index
  for index in start_index..<blocks.length() {
    end_index = index
    if blocks[index].source_range.end >= edit_end {
      break
    }
  }
  // Editing inside a blank block can turn the empty line into paragraph
  // content (or a marker line), which lazily joins the clusters on both
  // sides of it. Grow through this blank block so the region always
  // covers the fused result; for edits inside a non-blank block the
  // blank neighbors are hard boundaries and stop the growth.
  let mut grow_start = start_index
  while grow_start > 0 &&
        !markdown_document_editor_block_is_blank(blocks[grow_start - 1]) {
    grow_start = grow_start - 1
  }
  if markdown_document_editor_block_is_blank(blocks[start_index]) {
    if grow_start > 0 {
      grow_start = grow_start - 1
    }
    while grow_start > 0 &&
          !markdown_document_editor_block_is_blank(blocks[grow_start - 1]) {
      grow_start = grow_start - 1
    }
  }
  let mut grow_end = end_index
  while grow_end + 1 < blocks.length() &&
        !markdown_document_editor_block_is_blank(blocks[grow_end + 1]) {
    grow_end = grow_end + 1
  }
  if markdown_document_editor_block_is_blank(blocks[start_index]) {
    if grow_end + 1 < blocks.length() {
      grow_end = grow_end + 1
    }
    while grow_end + 1 < blocks.length() &&
          !markdown_document_editor_block_is_blank(blocks[grow_end + 1]) {
      grow_end = grow_end + 1
    }
  }
  Some({
    start_index: grow_start,
    end_index: grow_end,
    start_block_start: blocks[grow_start].source_range.start,
    end_block_end: blocks[grow_end].source_range.end,
  })
}

///|
/// A blank-line block: the empty paragraph the parser produces for each
/// whitespace-only source line. Its range is zero-width at the line
/// start and its cluster role is always a boundary.
fn markdown_document_editor_block_is_blank(block : MarkdownEditorBlock) -> Bool {
  block.block.text == "" &&
  block.block.inlines.is_empty() &&
  block.block.kind is Paragraph &&
  block.source_range.start == block.source_range.end
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
fn MarkdownDocumentLayoutCache::new(
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
    let height = rich_text_block_total_height(
      block,
      base,
      text_system,
      block_width=width,
    )
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
  content_width~ : Double,
) -> MarkdownDocumentWindowRange {
  if !source_mode {
    match markdown_document_block_geometry(session, base, content_width~) {
      Some(geometry) =>
        return markdown_document_window_range_for_geometry(
          geometry,
          scroll_y~,
          viewport_height~,
          overscan~,
        )
      None => ()
    }
  }
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
/// The height index is intentionally source-only for cheap scrolling. A
/// responsive HTML gallery is the narrow exception: its height depends on the
/// current content width, so calculate just those blocks from the rich-text
/// model and retain indexed estimates for every other block.
fn markdown_document_gallery_block_heights(
  session : MarkdownDocumentSession,
  base : @core.FontSpec,
  content_width : Double,
) -> Array[Double]? {
  if content_width <= 0.0 {
    return None
  }
  let heights : Array[Double] = []
  let mut found_gallery = false
  for index, editor_block in session.editor_blocks {
    let estimated = if index < session.height_index.blocks.length() {
      session.height_index.blocks[index].visual_height_units * base.size
    } else {
      base.size * 1.55
    }
    if editor_block.block.kind is HtmlBlock &&
      markdown_html_image_gallery(editor_block.block.text, base, None)
      is Some(_) {
      let rich_block = markdown_block_to_rich_text(
        editor_block.block,
        base,
        base_dir=None,
      )
      heights.push(
        rich_text_block_total_height(
          rich_block,
          base,
          @core.TextSystem::fallback(),
          block_width=content_width,
        ),
      )
      found_gallery = true
    } else {
      heights.push(estimated)
    }
  }
  if found_gallery {
    Some(heights)
  } else {
    None
  }
}

///|
/// Per-block pixel heights for scroll geometry. Prefers measured paint
/// geometry (recorded by the session editor once a block has been
/// rendered at this width and font), falls back to the gallery
/// rich-text computation, then to the parse-time estimate. Returns None
/// only when no block carries geometry better than the unit estimates,
/// which keeps the pure unit-index path for unrendered documents.
fn markdown_document_block_heights(
  session : MarkdownDocumentSession,
  base : @core.FontSpec,
  content_width~ : Double,
) -> Array[Double]? {
  match markdown_document_block_geometry(session, base, content_width~) {
    Some(geometry) => Some(geometry.heights)
    None => None
  }
}

///|
/// Persisted scroll geometry for the session at a laid out content width.
/// Cache hits (the same source digest, font, and width) perform no block
/// walk at all; a miss walks every block once, builds the Fenwick tree,
/// and stores the entry. Measured heights landing afterwards are applied
/// through the O(log n) point update, so scrolling stays walk-free.
/// Zero content width never has measured or gallery geometry, so it skips
/// the walk entirely and lets callers fall back to the parse-time index.
fn markdown_document_block_geometry(
  session : MarkdownDocumentSession,
  base : @core.FontSpec,
  content_width~ : Double,
) -> MarkdownDocumentScrollGeometry? {
  if content_width <= 0.0 {
    return None
  }
  match
    markdown_document_scroll_geometry_get(
      base,
      width=content_width,
      source_digest=session.source_digest,
      source_length=session.source_length,
    ) {
    Some(geometry) => {
      hot_path_scroll_geometry_cache_hits.val = hot_path_scroll_geometry_cache_hits.val +
        1
      if geometry.heights.is_empty() {
        return None
      }
      return Some(geometry)
    }
    None => ()
  }
  let gallery = markdown_document_gallery_block_heights(
    session, base, content_width,
  )
  let height_seed = rich_text_block_height_digest_seed(
    base,
    width=content_width,
  )
  let heights : Array[Double] = []
  let mut has_measured = false
  for index, _editor_block in session.editor_blocks {
    hot_path_block_height_walk_blocks.val = hot_path_block_height_walk_blocks.val +
      1
    // The measured-height table keys on block identity (id, revision),
    // which the session's block assignment keeps in lockstep with content.
    // session.blocks is parallel to session.editor_blocks.
    let identity = session.blocks.get(index)
    match
      rich_text_block_measured_height(
        base,
        width=content_width,
        seed=height_seed,
        block_id=match identity {
          Some(session_block) => session_block.id
          None => index
        },
        block_revision=match identity {
          Some(session_block) => session_block.revision
          None => 0
        },
      ) {
      Some(height) => {
        has_measured = true
        heights.push(height)
      }
      None =>
        match gallery {
          Some(gallery) => heights.push(gallery[index])
          None =>
            heights.push(
              session.height_index.blocks
              .get(index)
              .map(metric => metric.visual_height_units * base.size)
              .unwrap_or(base.size * 1.55),
            )
        }
    }
  }
  let epoch = rich_text_block_heights_epoch.val
  if !has_measured && gallery is None {
    // Cache the “no measured geometry yet” verdict too, so wheels before
    // the first measured paint stay O(1) until a height actually lands.
    markdown_document_scroll_geometry_put(
      base,
      markdown_document_scroll_geometry_from_heights([], epoch~),
      width=content_width,
      source_digest=session.source_digest,
      source_length=session.source_length,
    )
    return None
  }
  let geometry = markdown_document_scroll_geometry_from_heights(heights, epoch~)
  markdown_document_scroll_geometry_put(
    base,
    geometry,
    width=content_width,
    source_digest=session.source_digest,
    source_length=session.source_length,
  )
  Some(geometry)
}

///|
/// Feed one freshly measured block height into the live scroll geometry
/// with an O(log n) Fenwick point update, replacing the previous
/// epoch-invalidate-and-rebuild-everything path. Falls back to dropping
/// the cached entry (so the next query rebuilds once) when the entry is
/// missing, stale against the epoch, or the “no measured geometry yet”
/// verdict.
fn markdown_document_apply_measured_height(
  session : MarkdownDocumentSession,
  base : @core.FontSpec,
  block_index~ : Int,
  width~ : Double,
  height~ : Double,
) -> Unit {
  if width <= 0.0 || height <= 0.0 {
    return
  }
  let key = markdown_document_scroll_geometry_key(
    base,
    width~,
    source_digest=session.source_digest,
    source_length=session.source_length,
  )
  match markdown_document_scroll_geometry_cache.get(key) {
    Some(geometry) =>
      if geometry.epoch == rich_text_block_heights_epoch.val &&
        geometry.heights.length() == session.editor_blocks.length() {
        hot_path_scroll_geometry_point_updates.val = hot_path_scroll_geometry_point_updates.val +
          1
        markdown_document_scroll_geometry_set_height(
          geometry,
          index=block_index,
          height~,
        )
      } else {
        markdown_document_scroll_geometry_cache.remove(key)
      }
    None => ()
  }
}

///|
/// Window lookup over persisted prefix sums: the total is `prefix[n]` and
/// both edges are binary searches, so a wheel step is O(log n) in blocks.
fn markdown_document_window_range_for_geometry(
  geometry : MarkdownDocumentScrollGeometry,
  scroll_y~ : Double,
  viewport_height~ : Double,
  overscan~ : Double,
) -> MarkdownDocumentWindowRange {
  let count = geometry.heights.length()
  if count == 0 {
    return {
      visible_start: -1,
      visible_end: -1,
      top_padding: 0.0,
      content_height: 0.0,
    }
  }
  let content_height = markdown_document_scroll_geometry_prefix_at(
    geometry,
    count~,
  )
  if viewport_height <= 0.0 {
    return {
      visible_start: 0,
      visible_end: count - 1,
      top_padding: 0.0,
      content_height,
    }
  }
  let visible_min = max_double(0.0, scroll_y - overscan)
  let visible_max = min_double(
    content_height,
    scroll_y + viewport_height + overscan,
  )
  // First block whose bottom edge (prefix at `index + 1`) reaches the
  // visible band; heights are non-negative, so prefix is monotone.
  let mut low = 0
  let mut high = count
  while low < high {
    let mid = low + (high - low) / 2
    let bottom = markdown_document_scroll_geometry_prefix_at(
      geometry,
      count=mid + 1,
    )
    if bottom >= visible_min {
      high = mid
    } else {
      low = mid + 1
    }
  }
  let visible_start = if low >= count { count - 1 } else { low }
  // Last block whose top edge (prefix at `index`) is still inside the band.
  let mut low = 0
  let mut high = count
  while low < high {
    let mid = low + (high - low) / 2
    let top = markdown_document_scroll_geometry_prefix_at(geometry, count=mid)
    if top <= visible_max {
      low = mid + 1
    } else {
      high = mid
    }
  }
  let visible_end = if low - 1 < visible_start {
    visible_start
  } else {
    low - 1
  }
  {
    visible_start,
    visible_end,
    top_padding: markdown_document_scroll_geometry_prefix_at(
      geometry,
      count=visible_start,
    ),
    content_height,
  }
}

///|
fn markdown_document_gallery_source_offset_y(
  session : MarkdownDocumentSession,
  source_offset : Int,
  heights : Array[Double],
) -> Double {
  let mut top = 0.0
  for index, block in session.editor_blocks {
    if source_offset <= block.source_range.end {
      return top
    }
    match heights.get(index) {
      Some(height) => top = top + height
      None => ()
    }
  }
  top
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
  previous? : MarkdownDocumentSession? = None,
  reuse? : MarkdownDocumentReindexWindow? = None,
) -> MarkdownDocumentHeightIndex {
  match (previous, reuse) {
    (Some(prev), Some(window)) if prev.height_index.blocks.length() ==
      prev.blocks.length() =>
      markdown_document_height_index_reuse(
        source, editor_blocks, blocks, prev, window,
      )
    _ => markdown_document_height_index_full(source, editor_blocks, blocks)
  }
}

///|
/// Full height index: decodes the whole source and measures every block —
/// the session-creation and full-parse cost.
fn markdown_document_height_index_full(
  source : String,
  editor_blocks : Array[MarkdownEditorBlock],
  blocks : Array[MarkdownDocumentBlock],
) -> MarkdownDocumentHeightIndex {
  let line_counts = markdown_document_block_source_line_counts(
    source, editor_blocks,
  )
  let metrics : Array[MarkdownDocumentBlockHeightMetric] = []
  let mut visual_top_units = 0.0
  let mut source_top_units = 0.0
  for index, editor_block in editor_blocks {
    let session_block = blocks[index]
    let visual_height_units = markdown_document_estimated_editor_block_height_units(
      editor_block,
    )
    let source_height_units = line_counts[index].to_double() * 1.42
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
/// Newline count per block source range, in one forward pass over the
/// source (line count = newlines + 1, matching
/// `markdown_document_source_range_line_count`). The old path materialized
/// the whole document as a char array just to count newlines per range.
/// Block ranges tile the source in parse order; zero-width blank blocks
/// own no characters and keep the base count of 1.
fn markdown_document_block_source_line_counts(
  source : String,
  editor_blocks : Array[MarkdownEditorBlock],
) -> Array[Int] {
  let counts : Array[Int] = []
  if markdown_editor_text_length(source) == 0 {
    for _ in editor_blocks {
      counts.push(1)
    }
    return counts
  }
  for _ in editor_blocks {
    counts.push(1)
  }
  let mut block_index = 0
  let mut char_index = 0
  for ch in source {
    while block_index < editor_blocks.length() &&
          char_index >= editor_blocks[block_index].source_range.end {
      block_index = block_index + 1
    }
    if block_index >= editor_blocks.length() {
      break
    }
    if ch == '\n' && char_index >= editor_blocks[block_index].source_range.start {
      counts[block_index] = counts[block_index] + 1
    }
    char_index = char_index + 1
  }
  counts
}

///|
/// Height index for an incremental apply: block heights depend only on
/// block content, so the unchanged prefix and suffix keep their previous
/// per-block height units and only the re-parse window is measured (its
/// source is decoded as a slice instead of the whole document). The tops
/// are re-accumulated over all blocks in one double-addition pass, so the
/// result is numerically identical to a full rebuild.
fn markdown_document_height_index_reuse(
  source : String,
  editor_blocks : Array[MarkdownEditorBlock],
  blocks : Array[MarkdownDocumentBlock],
  previous : MarkdownDocumentSession,
  window : MarkdownDocumentReindexWindow,
) -> MarkdownDocumentHeightIndex {
  let metrics : Array[MarkdownDocumentBlockHeightMetric] = []
  let mut visual_top_units = 0.0
  let mut source_top_units = 0.0
  let window_open = window.suffix_new_start > window.prefix_count
  let span_start = if window_open {
    editor_blocks[window.prefix_count].source_range.start
  } else {
    0
  }
  let span_end = if window_open {
    editor_blocks[window.suffix_new_start - 1].source_range.end
  } else {
    0
  }
  let window_chars = markdown_document_source_chars_in_range(
    source,
    markdown_editor_text_length(source),
    span_start,
    span_end,
  )
  for index, editor_block in editor_blocks {
    let session_block = blocks[index]
    let visual_height_units = if index < window.prefix_count {
      previous.height_index.blocks[index].visual_height_units
    } else if index >= window.suffix_new_start {
      previous.height_index.blocks[index + window.suffix_shift].visual_height_units
    } else {
      hot_path_height_metrics_recomputed.val = hot_path_height_metrics_recomputed.val +
        1
      markdown_document_estimated_editor_block_height_units(editor_block)
    }
    let source_height_units = if index < window.prefix_count {
      previous.height_index.blocks[index].source_height_units
    } else if index >= window.suffix_new_start {
      previous.height_index.blocks[index + window.suffix_shift].source_height_units
    } else {
      markdown_document_source_range_line_count(window_chars, {
        start: editor_block.source_range.start - span_start,
        end: editor_block.source_range.end - span_start,
      }).to_double() *
      1.42
    }
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
fn markdown_document_source_chars_in_range(
  source : String,
  char_length : Int,
  start : Int,
  end : Int,
) -> Array[Char] {
  let start = markdown_editor_clamp_int(start, 0, char_length)
  let end = markdown_editor_clamp_int(end, start, char_length)
  let source_length = source.length()
  let start_offset = if start == char_length {
    source_length
  } else {
    source.offset_of_nth_char(start).unwrap_or(source_length)
  }
  let end_offset = if end == char_length {
    source_length
  } else {
    source.offset_of_nth_char(end).unwrap_or(source_length)
  }
  source.sub(start=start_offset, end=end_offset).to_array()
}

///|
fn markdown_document_source_mode_block_to_rich_text(
  source_chars : Array[Char],
  source_char_offset : Int,
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
) -> RichTextBlock {
  let source_length = source_chars.length()
  let start = markdown_editor_clamp_int(
    editor_block.source_range.start - source_char_offset,
    0,
    source_length,
  )
  let end = markdown_editor_clamp_int(
    editor_block.source_range.end - source_char_offset,
    start,
    source_length,
  )
  markdown_document_source_mode_block_to_rich_text_with_cache(
    String::from_array(source_chars[start:end]),
    editor_block,
    base,
    build=(editor_block, base) => {
      markdown_document_source_mode_block_to_rich_text_uncached(
        source_chars, source_char_offset, editor_block, base,
      )
    },
  )
}

///|
fn markdown_document_source_mode_block_to_rich_text_uncached(
  source_chars : Array[Char],
  source_char_offset : Int,
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
) -> RichTextBlock {
  let source_length = source_chars.length()
  let start = markdown_editor_clamp_int(
    editor_block.source_range.start - source_char_offset,
    0,
    source_length,
  )
  let end = markdown_editor_clamp_int(
    editor_block.source_range.end - source_char_offset,
    start,
    source_length,
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
  reindex? : MarkdownDocumentReindexWindow? = None,
  // Precomputed content digest for this source; callers that already hold
  // one (the incremental apply) skip the second whole-source hash.
  source_digest? : UInt64? = None,
) -> MarkdownDocumentSession {
  // Only trust the reindex window when it describes the sessions exactly;
  // every derived bookkeeping step falls back to its full computation
  // otherwise.
  let reuse = match (previous, reindex) {
    (Some(prev), Some(window)) if markdown_document_reindex_window_fits(
        window,
        prev,
        editor_blocks.length(),
      ) => Some(window)
    _ => None
  }
  markdown_editor_blocks_cache_put(source, editor_blocks)
  let word_count = match (previous, reuse) {
    (Some(prev), Some(window)) =>
      markdown_document_word_count_after_edit(prev, window)
    _ => markdown_editor_word_count(source)
  }
  let line_count = match (previous, reuse) {
    (Some(prev), Some(window)) =>
      markdown_document_line_count_after_edit(prev, source, window)
    _ => markdown_editor_line_count(source)
  }
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
    reuse~,
  )
  let height_index = markdown_document_height_index(
    source,
    editor_blocks,
    assigned.blocks,
    previous~,
    reuse~,
  )
  let outline = match (previous, reuse) {
    (Some(prev), Some(window)) =>
      markdown_document_outline_after_edit(editor_blocks, prev, window)
    _ => markdown_editor_outline(editor_blocks)
  }
  {
    source,
    source_length: markdown_editor_text_length(source),
    source_digest: match source_digest {
      Some(digest) => digest
      None => markdown_document_source_digest(source)
    },
    blocks: assigned.blocks,
    editor_blocks,
    line_count,
    word_count,
    reading_minutes: markdown_editor_reading_minutes(word_count),
    active_heading: markdown_editor_active_heading(editor_blocks),
    metadata_title: metadata.title,
    metadata_tags: metadata.tags,
    outline,
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
  reuse? : MarkdownDocumentReindexWindow? = None,
) -> MarkdownDocumentBlockAssignment {
  match (previous, reuse) {
    (Some(prev), Some(window)) =>
      markdown_document_assign_blocks_reuse(
        editor_blocks,
        prev,
        window,
        next_id~,
        dirty_range~,
      )
    _ =>
      markdown_document_assign_blocks_full(
        editor_blocks,
        previous~,
        next_id~,
        dirty_range~,
      )
  }
}

///|
/// Id/revision assignment when the incremental apply proved that every
/// block outside the re-parse window is content-identical to a previous
/// block: the prefix and suffix are copied (only the dirty ±1 edge re-
/// stamps its revision), and window blocks match fingerprints only among
/// the previous window blocks — outside ones are already accounted for,
/// so ids follow content through the window instead of drifting to
/// unrelated positions. Fingerprint construction (kind key + full block
/// text) is paid only for window blocks.
fn markdown_document_assign_blocks_reuse(
  editor_blocks : Array[MarkdownEditorBlock],
  previous : MarkdownDocumentSession,
  window : MarkdownDocumentReindexWindow,
  next_id~ : Int,
  dirty_range~ : MarkdownDocumentDirtyRange?,
) -> MarkdownDocumentBlockAssignment {
  let suffix_old_start = window.suffix_new_start + window.suffix_shift
  let blocks : Array[MarkdownDocumentBlock] = []
  let used_window : Array[Bool] = []
  for _ in window.prefix_count..<suffix_old_start {
    used_window.push(false)
  }
  let mut next_id = next_id
  for index, editor_block in editor_blocks {
    let dirty = markdown_document_block_index_dirty(dirty_range, index)
    if index < window.prefix_count {
      let previous_block = previous.blocks[index]
      if !dirty {
        blocks.push(previous_block)
      } else {
        // Dirty edge outside the window: content is unchanged, so the
        // previous fingerprint string is still exact — only the revision
        // re-stamps.
        blocks.push({
          ..previous_block,
          source_range: editor_block.source_range,
          content_range: editor_block.content_range,
          kind: editor_block.block.kind,
          text: editor_block.block.text,
          inline_count: editor_block.block.inlines.length(),
          revision: previous_block.revision + 1,
        })
      }
    } else if index >= window.suffix_new_start {
      let previous_block = previous.blocks[index + window.suffix_shift]
      blocks.push({
        id: previous_block.id,
        revision: if dirty {
          previous_block.revision + 1
        } else {
          previous_block.revision
        },
        source_range: editor_block.source_range,
        content_range: editor_block.content_range,
        kind: editor_block.block.kind,
        text: editor_block.block.text,
        fingerprint: previous_block.fingerprint,
        inline_count: editor_block.block.inlines.length(),
      })
    } else {
      let fingerprint = markdown_document_block_fingerprint(editor_block)
      hot_path_block_fingerprints_built.val = hot_path_block_fingerprints_built.val +
        1
      let position = index - window.prefix_count
      let mut matched = -1
      if position < used_window.length() &&
        !used_window[position] &&
        previous.blocks[index].fingerprint == fingerprint {
        matched = position
      } else {
        for window_offset in 0..<used_window.length() {
          let previous_block = previous.blocks[window.prefix_count +
            window_offset]
          if !used_window[window_offset] &&
            previous_block.fingerprint == fingerprint {
            matched = window_offset
            break
          }
        }
        if matched < 0 &&
          position < used_window.length() &&
          !used_window[position] {
          matched = position
        }
      }
      if matched < 0 {
        let id = next_id
        next_id = next_id + 1
        blocks.push(
          markdown_document_assigned_block(
            editor_block,
            id~,
            revision=0,
            fingerprint~,
          ),
        )
      } else {
        used_window[matched] = true
        let previous_block = previous.blocks[window.prefix_count + matched]
        blocks.push(
          markdown_document_assigned_block(
            editor_block,
            id=previous_block.id,
            revision=if dirty || previous_block.fingerprint != fingerprint {
              previous_block.revision + 1
            } else {
              previous_block.revision
            },
            fingerprint~,
          ),
        )
      }
    }
  }
  { blocks, next_id }
}

///|
fn markdown_document_assigned_block(
  editor_block : MarkdownEditorBlock,
  id~ : Int,
  revision~ : Int,
  fingerprint~ : String,
) -> MarkdownDocumentBlock {
  {
    id,
    revision,
    source_range: editor_block.source_range,
    content_range: editor_block.content_range,
    kind: editor_block.block.kind,
    text: editor_block.block.text,
    fingerprint,
    inline_count: editor_block.block.inlines.length(),
  }
}

///|
fn markdown_document_assign_blocks_full(
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
    hot_path_block_fingerprints_built.val = hot_path_block_fingerprints_built.val +
      1
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
    blocks.push(
      markdown_document_assigned_block(
        editor_block,
        id~,
        revision=block_revision,
        fingerprint~,
      ),
    )
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
/// Outline for an incremental apply: heading items before the re-parse
/// region are unchanged; items after it only shift by the character
/// delta; the region itself is rescanned. Blocks outside the window keep
/// their content, so their heading items survive untouched.
fn markdown_document_outline_after_edit(
  editor_blocks : Array[MarkdownEditorBlock],
  previous : MarkdownDocumentSession,
  window : MarkdownDocumentReindexWindow,
) -> Array[MarkdownEditorOutlineItem] {
  let items : Array[MarkdownEditorOutlineItem] = []
  for item in previous.outline {
    if item.source_start < window.old_region_start {
      items.push(item)
    }
  }
  for index in window.prefix_count..<window.suffix_new_start {
    let editor_block = editor_blocks[index]
    match editor_block.block.kind {
      Heading(level) =>
        items.push({
          level,
          title: editor_block.block.text,
          source_start: editor_block.content_range.start,
        })
      _ => ()
    }
  }
  for item in previous.outline {
    if item.source_start >= window.old_region_end {
      items.push({
        level: item.level,
        title: item.title,
        source_start: item.source_start + window.char_delta,
      })
    }
  }
  items
}

///|
/// Char at the given char-space index, used for the one-character context
/// probes around an edit. Probes at the document edges are O(1); an
/// interior probe (mid-document edit) falls back to the offset scan.
fn markdown_document_char_at(source : String, index~ : Int) -> Char? {
  let char_length = markdown_editor_text_length(source)
  if index < 0 || index >= char_length {
    None
  } else if index == 0 {
    source.get_char(0)
  } else if index == char_length - 1 {
    source.rev_iter().next()
  } else {
    let offset = source.offset_of_nth_char(index).unwrap_or(source.length())
    source.get_char(offset)
  }
}

///|
/// Word-start count inside `text`, given whether the character before it
/// is whitespace. Returns the count and whether the span ends in (or
/// starts in, if empty) whitespace — enough to stitch neighbouring spans.
fn markdown_document_word_starts_in(
  text : String,
  after_whitespace~ : Bool,
) -> (Int, Bool) {
  let mut count = 0
  let mut whitespace = after_whitespace
  for ch in text {
    if ch.is_ascii_whitespace() {
      whitespace = true
    } else {
      if whitespace {
        count = count + 1
      }
      whitespace = false
    }
  }
  (count, whitespace)
}

///|
/// Word count after an incremental edit. A word starts at each
/// non-whitespace char preceded by whitespace (or at the document start),
/// and an edit only changes the start predicate inside the edited span
/// and at the first character after it — so the delta is exact: subtract
/// the starts counted for the deleted span (with the same left context),
/// add the ones for the replacement, and reconcile the boundary char that
/// follows.
fn markdown_document_word_count_after_edit(
  previous : MarkdownDocumentSession,
  window : MarkdownDocumentReindexWindow,
) -> Int {
  let before = markdown_document_char_at(
    previous.source,
    index=window.edit_start - 1,
  )
  let before_whitespace = match before {
    None => true
    Some(ch) => ch.is_ascii_whitespace()
  }
  let (old_starts, old_ends_whitespace) = markdown_document_word_starts_in(
    window.deleted,
    after_whitespace=before_whitespace,
  )
  let (new_starts, new_ends_whitespace) = markdown_document_word_starts_in(
    window.replacement,
    after_whitespace=before_whitespace,
  )
  let deleted_length = markdown_editor_text_length(window.deleted)
  let after = markdown_document_char_at(
    previous.source,
    index=window.edit_start + deleted_length,
  )
  let boundary = match after {
    Some(ch) if !ch.is_ascii_whitespace() =>
      (
        if old_ends_whitespace {
          1
        } else {
          0
        },
        if new_ends_whitespace {
          1
        } else {
          0
        },
      )
    Some(_) | None => (0, 0)
  }
  previous.word_count - old_starts - boundary.0 + new_starts + boundary.1
}

///|
/// Line count after an incremental edit: lines equal newline count plus
/// one (zero for the empty document), and the newline count only changes
/// by what the edit deleted and inserted.
fn markdown_document_line_count_after_edit(
  previous : MarkdownDocumentSession,
  source : String,
  window : MarkdownDocumentReindexWindow,
) -> Int {
  let previous_newlines = if previous.line_count == 0 {
    0
  } else {
    previous.line_count - 1
  }
  if source == "" {
    0
  } else {
    previous_newlines -
    markdown_document_newline_count(window.deleted) +
    markdown_document_newline_count(window.replacement) +
    1
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
    // The inline marker probes read only around one run, so each touched
    // run gets a block-sized char window instead of a whole-document array.
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
fn rich_text_block_total_height(
  block : RichTextBlock,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  block_width? : Double = 0.0,
) -> Double {
  rich_text_block_line_height(block, base_font, text_system, block_width~) +
  block.inset.top +
  block.inset.bottom
}

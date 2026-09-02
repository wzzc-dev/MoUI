///|
/// Package-private memoization for the markdown editor hot paths.
///
/// The editor rebuilds rich text documents on every keystroke, scroll
/// frame, pointer hit test, and IME poll. These caches make that
/// rebuilding cheap by keying on *content identity* instead of position:
///
/// - Block conversions are keyed by block content plus font (never by
///   absolute source offsets), so edits upstream of a block shift the
///   block's ranges without invalidating it. A hit rebases the cached
///   ranges by the start-offset delta.
/// - Run widths are keyed by text system id + font + text, mirroring the
///   inputs of a host measurement.
/// - Measured block heights are keyed by block content + font + width,
///   so an edit that changes a block's text is self-invalidating and no
///   explicit eviction hook is needed. Heights are written by the
///   session editor paint and read by the scroll geometry, which turns
///   the parse-time height estimates into measured geometry for
///   already-rendered blocks.
/// - Display sessions (source + composition text) memoize the full parse
///   for the short window where an IME polls paints while the candidate
///   text is unchanged.
/// - Scroll geometry (block heights + prefix sums) is keyed by font,
///   content width, and source, and stays valid until a measured height
///   actually changes, so wheel events and repaints read O(1) totals and
///   binary-searched windows instead of walking every block.
///
/// All maps are bounded; over-cap they clear wholesale. The runtime is
/// single-threaded, so no synchronization is needed.
priv struct RichTextBlockCacheEntry {
  source_start : Int
  block : RichTextBlock
}

///|
let rich_text_block_conversions : Map[String, RichTextBlockCacheEntry] = Map([])

///|
let rich_text_run_widths : Map[String, Double] = Map([])

///|
let rich_text_block_heights : Map[String, Double] = Map([])

///|
let rich_text_display_sessions : Map[String, MarkdownDocumentSession] = Map([])

///|
let markdown_reference_definitions_cache : Map[
  String,
  Array[MarkdownReferenceDefinition],
] = Map([])

///|
/// Bumped whenever a block's *measured* height changes (including when the
/// height map is evicted wholesale). Scroll geometry entries record the
/// epoch they were built at, so a wheel event rebuilds the height array
/// only when geometry actually changed — steady-state scrolling performs
/// zero block walks.
let rich_text_block_heights_epoch : Ref[Int] = Ref(0)

///|

///|
/// Persisted scroll geometry for one (font, content width, source): the
/// per-block pixel heights plus their prefix sums (`prefix[i]` is the
/// total height of the first `i` blocks), so content height is O(1) and
/// the visible window is a binary search. An entry with an empty
/// `heights` caches the “no measured geometry yet” verdict; the epoch
/// check revives it once paints record measured heights.
priv struct MarkdownDocumentScrollGeometry {
  heights : Array[Double]
  prefix : Array[Double]
  epoch : Int
}

///|
let markdown_document_scroll_geometry_cache : Map[
  String,
  MarkdownDocumentScrollGeometry,
] = Map([])

///|
fn rich_text_cache_join_key(parts : Array[String]) -> String {
  let mut key = ""
  for part in parts {
    key = key + part + "\u0001"
  }
  key
}

///|
/// Fonts repeat constantly within a frame, so keep the last encoded key
/// instead of re-serializing the FontSpec for every block conversion.
let rich_text_cache_last_font : Ref[(@core.FontSpec, String)] = Ref(
  (@core.FontSpec::new(), ""),
)

///|
fn rich_text_cache_font_key(font : @core.FontSpec) -> String {
  let last = rich_text_cache_last_font.val
  if last.0 == font {
    last.1
  } else {
    let key = @json.to_json(font).stringify()
    rich_text_cache_last_font.val = (font, key)
    key
  }
}

///|
fn markdown_editor_block_key(block : MarkdownBlock) -> String {
  @json.to_json(block).stringify()
}

///|
fn rich_text_source_range_shift(
  range : RichTextSourceRange?,
  delta : Int,
) -> RichTextSourceRange? {
  match range {
    Some(range) => Some({ start: range.start + delta, end: range.end + delta })
    None => None
  }
}

///|
/// Shift every absolute source offset inside a cached rich block by the
/// same delta. Content identity (text, runs, table shape) is unchanged;
/// only the mapping back into canonical source moves.
fn markdown_editor_rich_block_shift(
  block : RichTextBlock,
  delta : Int,
) -> RichTextBlock {
  if delta == 0 {
    return block
  }
  let runs : Array[RichTextRun] = []
  for run in block.runs {
    runs.push({
      ..run,
      source_range: rich_text_source_range_shift(run.source_range, delta),
    })
  }
  let table = match block.table {
    Some(table) =>
      Some({
        ..table,
        rows: table.rows.map(row => {
          row.map(cell => {
            ..cell,
            source_range: rich_text_source_range_shift(cell.source_range, delta),
          })
        }),
      })
    None => None
  }
  {
    ..block,
    runs,
    table,
    source_range: rich_text_source_range_shift(block.source_range, delta),
    content_range: rich_text_source_range_shift(block.content_range, delta),
  }
}

///|
/// Content-identity key for a block conversion. Deliberately excludes
/// absolute source offsets; the relative content offset is kept because
/// marker prefix widths (indent, quote layers) shift it independently of
/// the block text.
fn markdown_editor_block_conversion_key(
  editor_block : MarkdownEditorBlock,
  content : String,
  source_slice : String,
  base : @core.FontSpec,
  base_dir~ : String?,
) -> String {
  rich_text_cache_join_key([
    rich_text_cache_font_key(base),
    base_dir.unwrap_or(""),
    markdown_editor_block_key(editor_block.block),
    source_slice,
    content,
    (editor_block.content_range.start - editor_block.source_range.start).to_string(),
  ])
}

///|

///|
/// Memoize the whole-source reference-definition set. The incremental
/// apply path reuses definitions from the previous source for edits that
/// cannot change them, skipping the second whole-document markdown parse
/// that `markdown_reference_definitions` performs.
fn markdown_reference_definitions_cached(
  source : String,
) -> Array[MarkdownReferenceDefinition] {
  match markdown_reference_definitions_cache.get(source) {
    Some(definitions) => definitions
    None => {
      let definitions = markdown_reference_definitions(source)
      if markdown_reference_definitions_cache.length() >= 16 {
        markdown_reference_definitions_cache.clear()
      }
      markdown_reference_definitions_cache.set(source, definitions)
      definitions
    }
  }
}

///|
fn markdown_editor_block_to_rich_text_with_cache(
  source : String,
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
  base_dir~ : String?,
  build~ : (String, MarkdownEditorBlock, @core.FontSpec, String?) -> RichTextBlock,
) -> RichTextBlock {
  let content = markdown_editor_run_source_content(source, editor_block)
  let source_slice = markdown_editor_substring(
    source,
    editor_block.source_range.start,
    editor_block.source_range.end,
  )
  let key = markdown_editor_block_conversion_key(
    editor_block,
    content,
    source_slice,
    base,
    base_dir~,
  )
  match rich_text_block_conversions.get(key) {
    Some(entry) =>
      markdown_editor_rich_block_shift(
        entry.block,
        editor_block.source_range.start - entry.source_start,
      )
    None => {
      hot_path_block_conversion_builds.val = hot_path_block_conversion_builds.val +
        1
      let block = build(source, editor_block, base, base_dir)
      if rich_text_block_conversions.length() >= 4096 {
        rich_text_block_conversions.clear()
      }
      rich_text_block_conversions.set(key, {
        source_start: editor_block.source_range.start,
        block,
      })
      block
    }
  }
}

///|
/// Content-identity key for a source-mode block. The rendered text is
/// the whole input (monospace, no inline parsing), so the visible slice
/// plus font fully determines the block up to a source rebase.
fn markdown_document_source_mode_block_to_rich_text_with_cache(
  text : String,
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
  build~ : (MarkdownEditorBlock, @core.FontSpec) -> RichTextBlock,
) -> RichTextBlock {
  let key = rich_text_cache_join_key([
    "source-mode",
    rich_text_cache_font_key(base),
    text,
  ])
  match rich_text_block_conversions.get(key) {
    Some(entry) =>
      markdown_editor_rich_block_shift(
        entry.block,
        editor_block.source_range.start - entry.source_start,
      )
    None => {
      let block = build(editor_block, base)
      if rich_text_block_conversions.length() >= 4096 {
        rich_text_block_conversions.clear()
      }
      rich_text_block_conversions.set(key, {
        source_start: editor_block.source_range.start,
        block,
      })
      block
    }
  }
}

///|
fn rich_text_run_width_with_cache(
  text : String,
  font : @core.FontSpec,
  text_system~ : @core.TextSystem,
  measure~ : (String, @core.FontSpec) -> Double,
) -> Double {
  let key = rich_text_cache_join_key([
    text_system.id(),
    rich_text_cache_font_key(font),
    text,
  ])
  match rich_text_run_widths.get(key) {
    Some(width) => width
    None => {
      let width = measure(text, font)
      if rich_text_run_widths.length() >= 65536 {
        rich_text_run_widths.clear()
      }
      rich_text_run_widths.set(key, width)
      width
    }
  }
}

///|
/// Measured-height keys cover the inputs that determine a block's laid
/// out pixel height: content (kind, text, inlines, images), base font,
/// and the laid out block width. Like block conversions, offsets are
/// excluded so upstream edits keep the entry valid.
fn rich_text_block_measured_height_key(
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
  width~ : Double,
) -> String {
  rich_text_cache_join_key([
    "height",
    rich_text_cache_font_key(base),
    width.to_string(),
    markdown_editor_block_key(editor_block.block),
  ])
}

///|
fn rich_text_record_block_measured_height(
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
  width~ : Double,
  height~ : Double,
) -> Unit {
  if width <= 0.0 || height <= 0.0 {
    return
  }
  let key = rich_text_block_measured_height_key(editor_block, base, width~)
  if rich_text_block_heights.get(key) == Some(height) {
    return
  }
  if rich_text_block_heights.length() >= 32768 {
    rich_text_block_heights.clear()
    rich_text_block_heights_epoch.val = rich_text_block_heights_epoch.val + 1
  }
  rich_text_block_heights.set(key, height)
  rich_text_block_heights_epoch.val = rich_text_block_heights_epoch.val + 1
}

///|
/// Read the persisted scroll geometry for a (font, content width, source)
/// triple. Returns `None` on miss or when the entry predates the current
/// measured-height epoch; an entry with empty `heights` is a cached
/// “no measured geometry” verdict and is returned like any other hit.
fn markdown_document_scroll_geometry_get(
  source : String,
  base : @core.FontSpec,
  width~ : Double,
) -> MarkdownDocumentScrollGeometry? {
  let key = rich_text_cache_join_key([
    "scroll-geometry",
    rich_text_cache_font_key(base),
    width.to_string(),
    source,
  ])
  match markdown_document_scroll_geometry_cache.get(key) {
    Some(entry) =>
      if entry.epoch == rich_text_block_heights_epoch.val {
        Some(entry)
      } else {
        None
      }
    None => None
  }
}

///|
fn markdown_document_scroll_geometry_put(
  source : String,
  base : @core.FontSpec,
  width : Double,
  geometry : MarkdownDocumentScrollGeometry,
) -> Unit {
  let key = rich_text_cache_join_key([
    "scroll-geometry",
    rich_text_cache_font_key(base),
    width.to_string(),
    source,
  ])
  if markdown_document_scroll_geometry_cache.length() >= 4 {
    markdown_document_scroll_geometry_cache.clear()
  }
  markdown_document_scroll_geometry_cache.set(key, geometry)
}

///|
fn rich_text_block_measured_height(
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
  width~ : Double,
) -> Double? {
  if width <= 0.0 {
    return None
  }
  rich_text_block_heights.get(
    rich_text_block_measured_height_key(editor_block, base, width~),
  )
}

///|
/// Memoize the full-document parse behind `MarkdownDocumentSession::new`
/// for the IME composition path, where paints and host IME polls repeat
/// with the same display text while the candidate is open. The session
/// is a pure function of its source text, so the memo is content-keyed
/// across documents as well.
fn markdown_document_session_parse_cached(
  source : String,
) -> MarkdownDocumentSession {
  match rich_text_display_sessions.get(source) {
    Some(session) => session
    None => {
      let session = MarkdownDocumentSession::new(source)
      if rich_text_display_sessions.length() >= 4 {
        rich_text_display_sessions.clear()
      }
      rich_text_display_sessions.set(source, session)
      session
    }
  }
}

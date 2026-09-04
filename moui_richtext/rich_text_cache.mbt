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
/// - The editor block parse is keyed by source, so the many block-context
///   questions a single keystroke or command asks (pair/autolink/HTML
///   guards, caret kind and containment queries) share one whole-document
///   parse instead of re-parsing per question.
/// - The markdown mini-parse is keyed by text, because the block pass
///   consults the same lines several times and each mini-parse runs a
///   mizchi parse of its input to collect reference definitions.
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
/// Measured heights live in digest buckets: the full-document scroll
/// geometry walk queries every block, so it hashes a cheap 64-bit digest
/// per block instead of allocating and re-hashing a content-length key
/// string. Each bucket still validates its hits against the exact
/// content-identity key, so lookups remain exact.
let rich_text_block_heights : Map[UInt64, Array[(String, Double)]] = Map([])

///|
/// Number of exact (key, height) pairs across all digest buckets; the
/// bounded clear and the empty-map short circuit read this instead of
/// walking the bucket map.
let rich_text_block_heights_count : Ref[Int] = Ref(0)

///|
let rich_text_display_sessions : Map[String, MarkdownDocumentSession] = Map([])

///|
let markdown_reference_definitions_cache : Map[
  String,
  Array[MarkdownReferenceDefinition],
] = Map([])

///|
let markdown_editor_blocks_cache : Map[String, Array[MarkdownEditorBlock]] = Map([],
)

///|
let markdown_parse_cache : Map[String, Array[MarkdownBlock]] = Map([])

///|
/// Bumped whenever a block's *measured* height changes (including when the
/// height map is evicted wholesale). Scroll geometry entries record the
/// epoch they were built at, so a wheel event rebuilds the height array
/// only when geometry actually changed — steady-state scrolling performs
/// zero block walks.
let rich_text_block_heights_epoch : Ref[Int] = Ref(0)

///|
/// Persisted scroll geometry for one (font, content width, source digest):
/// the per-block pixel heights plus a Fenwick tree over them, so content
/// height and any block prefix are O(log n), the visible window is a
/// prefix descent, and a freshly measured height for one block is an
/// O(log n) point update instead of a full rebuild. An entry with an
/// empty `heights` caches the “no measured geometry yet” verdict; the
/// epoch check revives it once paints record measured heights.
priv struct MarkdownDocumentScrollGeometry {
  heights : Array[Double]
  /// 1-based Fenwick tree over `heights`, length `heights.length() + 1`.
  tree : Array[Double]
  epoch : Int
}

///|
/// Build the geometry (and its Fenwick tree) from a full height array in
/// O(n).
fn markdown_document_scroll_geometry_from_heights(
  heights : Array[Double],
  epoch~ : Int,
) -> MarkdownDocumentScrollGeometry {
  let count = heights.length()
  let limit = count + 1
  let tree : Array[Double] = []
  for _ in 0..<limit {
    tree.push(0.0)
  }
  for index, height in heights {
    let i = index + 1
    tree[i] = tree[i] + height
    let parent = i + (i & (-i))
    if parent <= count {
      tree[parent] = tree[parent] + tree[i]
    }
  }
  { heights, tree, epoch }
}

///|
/// Total height of the first `count` blocks (prefix sums are not stored;
/// this is the O(log n) Fenwick descent, clamped like an array read).
fn markdown_document_scroll_geometry_prefix_at(
  geometry : MarkdownDocumentScrollGeometry,
  count~ : Int,
) -> Double {
  let mut i = count
  if i > geometry.heights.length() {
    i = geometry.heights.length()
  }
  if i < 0 {
    i = 0
  }
  let mut sum = 0.0
  while i > 0 {
    sum = sum + geometry.tree[i]
    i = i - (i & (-i))
  }
  sum
}

///|
/// Apply a new pixel height for one block in O(log n). Heights are
/// mutable in place: every holder of this geometry sees the update.
fn markdown_document_scroll_geometry_set_height(
  geometry : MarkdownDocumentScrollGeometry,
  index~ : Int,
  height~ : Double,
) -> Unit {
  if index < 0 || index >= geometry.heights.length() {
    return
  }
  let delta = height - geometry.heights[index]
  if delta == 0.0 {
    return
  }
  geometry.heights[index] = height
  let count = geometry.heights.length()
  let mut i = index + 1
  while i <= count {
    geometry.tree[i] = geometry.tree[i] + delta
    i = i + (i & (-i))
  }
}

///|
/// Cheap content identity for the session source, computed once per
/// session construction so cache keys never concatenate the document.
fn markdown_document_source_digest(source : String) -> UInt64 {
  rich_text_digest_string(0xcbf29ce484222325UL, source)
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
/// Content-identity key for a parsed block. Hand-rolled to keep the
/// measured-height walk cheap over large documents, it must stay
/// injective on the exact fields that determine layout, so every payload
/// carries its length and every field a fixed tag; changing a field or
/// adding one to `MarkdownBlock` requires mirroring it here.
fn markdown_editor_block_key(block : MarkdownBlock) -> String {
  let key = StringBuilder()
  key.write_string("b")
  match block.kind {
    Heading(level) => key.write_string("h\{level};")
    Paragraph => key.write_string("p;")
    UnorderedListItem => key.write_string("u;")
    TaskListItem(checked) =>
      key.write_string("t\{if checked { 1 } else { 0 }};")
    OrderedListItem(start) => key.write_string("o\{start};")
    Blockquote => key.write_string("q;")
    CodeBlock => key.write_string("c;")
    HorizontalRule => key.write_string("r;")
    Table => key.write_string("a;")
    FootnoteDefinition(label) => {
      key.write_string("f")
      markdown_editor_block_key_string(key, Some(label))
    }
    HtmlBlock => key.write_string("x;")
    FrontMatter => key.write_string("m;")
  }
  markdown_editor_block_key_string(key, Some(block.text))
  key.write_string("i\{block.inlines.length()};")
  for inline in block.inlines {
    let inline_tag = match inline.kind {
      Plain => '0'
      Bold => '1'
      Italic => '2'
      Code => '3'
      Strikethrough => '4'
      Link => '5'
      Autolink => '6'
      Image => '7'
      FootnoteReference => '8'
      HtmlInline => '9'
    }
    key.write_char(inline_tag)
    markdown_editor_block_key_string(key, Some(inline.text))
    markdown_editor_block_key_string(key, inline.target)
  }
  key.write_string("a\{block.table_alignments.length()};")
  for align in block.table_alignments {
    let align_tag = match align {
      None => 'n'
      Some(@core.TextStart) => 's'
      Some(@core.TextCenter) => 'e'
      Some(@core.TextEnd) => 'd'
    }
    key.write_char(align_tag)
  }
  markdown_editor_block_key_string(key, block.code_language)
  key.to_string()
}

///|
fn markdown_editor_block_key_string(
  key : StringBuilder,
  part : String?,
) -> Unit {
  match part {
    None => key.write_char('n')
    Some(text) => key.write_string("s\{text.length()}:\{text}")
  }
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
/// Memoize the editor block parse for one source. Block-context queries
/// are pure functions of the parse, and a single keystroke or command
/// asks several of them, so one parse per source serves them all. The
/// entry duplicates the document's block text plus inline arrays, so the
/// cap stays at 2; callers get a shallow copy to keep the cached array's
/// identity private (the model itself is never mutated in place).
fn parse_markdown_editor_blocks_cached(
  source : String,
) -> Array[MarkdownEditorBlock] {
  match markdown_editor_blocks_cache.get(source) {
    Some(blocks) => blocks.copy()
    None => {
      let blocks = parse_markdown_editor_blocks_uncached(source)
      markdown_editor_blocks_cache_put(source, blocks)
      blocks.copy()
    }
  }
}

///|
/// Publish a parse result produced elsewhere (the session's incremental
/// apply stitches blocks without re-parsing the whole source) so the
/// next keystroke's block-context queries resolve from the cache.
fn markdown_editor_blocks_cache_put(
  source : String,
  blocks : Array[MarkdownEditorBlock],
) -> Unit {
  if markdown_editor_blocks_cache.length() >= 2 {
    markdown_editor_blocks_cache.clear()
  }
  markdown_editor_blocks_cache.set(source, blocks)
}

///|
/// Memoize `parse_markdown` per text. The block pass consults the same
/// lines repeatedly (setext candidate, soft-wrap line, paragraph
/// fallback) and `parse_markdown` runs a full mizchi parse to collect
/// definitions per call, so without this each keystroke parses every
/// line 2–3 times. The cap is sized to keep the ±few-line reuse window
/// of the block pass hot while bounding memory to sub-line payloads.
fn parse_markdown_cached(text : String) -> Array[MarkdownBlock] {
  match markdown_parse_cache.get(text) {
    Some(blocks) => blocks.copy()
    None => {
      let blocks = parse_markdown_uncached(text)
      if markdown_parse_cache.length() >= 1024 {
        markdown_parse_cache.clear()
      }
      markdown_parse_cache.set(text, blocks)
      blocks.copy()
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

///|
/// Exact (key, height) lookup inside a digest bucket. Buckets hold only
/// the handful of distinct blocks sharing a digest, so a linear scan is
/// the cheapest verification step.
fn rich_text_bucket_lookup(
  bucket : Array[(String, Double)],
  key~ : String,
) -> Double? {
  let mut found : Double? = None
  for pair in bucket {
    if pair.0 == key {
      found = Some(pair.1)
      break
    }
  }
  found
}

///|
/// FNV-1a mixing over the same identity inputs as the exact key, but
/// without materializing any string: the geometry walk hashes 100k+
/// blocks per revision, so the digest must stay allocation-light.
fn rich_text_digest_mix(hash : UInt64, value : UInt64) -> UInt64 {
  let mut hash = hash ^ value
  hash = hash * 0x100000001b3UL
  hash
}

///|
fn rich_text_digest_string(hash : UInt64, text : String) -> UInt64 {
  let mut hash = rich_text_digest_mix(hash, text.length().to_uint64())
  for ch in text {
    hash = rich_text_digest_mix(hash, ch.to_int().to_uint64())
  }
  hash
}

///|
fn rich_text_block_measured_height_digest(
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
  width~ : Double,
) -> UInt64 {
  let block = editor_block.block
  let mut hash = 0xcbf29ce484222325UL
  hash = rich_text_digest_string(hash, rich_text_cache_font_key(base))
  hash = rich_text_digest_string(hash, width.to_string())
  hash = match block.kind {
    Heading(level) =>
      rich_text_digest_mix(rich_text_digest_mix(hash, 1UL), level.to_uint64())
    Paragraph => rich_text_digest_mix(hash, 2UL)
    UnorderedListItem => rich_text_digest_mix(hash, 3UL)
    TaskListItem(checked) =>
      rich_text_digest_mix(hash, if checked { 4UL } else { 5UL })
    OrderedListItem(start) =>
      rich_text_digest_mix(rich_text_digest_mix(hash, 6UL), start.to_uint64())
    Blockquote => rich_text_digest_mix(hash, 7UL)
    CodeBlock => rich_text_digest_mix(hash, 8UL)
    HorizontalRule => rich_text_digest_mix(hash, 9UL)
    Table => rich_text_digest_mix(hash, 10UL)
    FootnoteDefinition(label) =>
      rich_text_digest_string(rich_text_digest_mix(hash, 11UL), label)
    HtmlBlock => rich_text_digest_mix(hash, 12UL)
    FrontMatter => rich_text_digest_mix(hash, 13UL)
  }
  hash = rich_text_digest_string(hash, block.text)
  hash = rich_text_digest_mix(hash, block.inlines.length().to_uint64())
  for inline in block.inlines {
    hash = rich_text_digest_mix(
      hash,
      match inline.kind {
        Plain => 20UL
        Bold => 21UL
        Italic => 22UL
        Code => 23UL
        Strikethrough => 24UL
        Link => 25UL
        Autolink => 26UL
        Image => 27UL
        FootnoteReference => 28UL
        HtmlInline => 29UL
      },
    )
    hash = rich_text_digest_string(hash, inline.text)
    match inline.target {
      None => hash = rich_text_digest_mix(hash, 30UL)
      Some(target) =>
        hash = rich_text_digest_string(rich_text_digest_mix(hash, 31UL), target)
    }
  }
  hash = rich_text_digest_mix(hash, block.table_alignments.length().to_uint64())
  for align in block.table_alignments {
    hash = rich_text_digest_mix(
      hash,
      match align {
        None => 40UL
        Some(@core.TextStart) => 41UL
        Some(@core.TextCenter) => 42UL
        Some(@core.TextEnd) => 43UL
      },
    )
  }
  match block.code_language {
    None => rich_text_digest_mix(hash, 50UL)
    Some(language) =>
      rich_text_digest_string(rich_text_digest_mix(hash, 51UL), language)
  }
}

///|
/// Record a measured pixel height for a block. Returns `true` when the
/// table actually gained or changed an entry (the caller then applies the
/// same height to the live scroll geometry through the point-update
/// path); a repeated identical measurement returns `false`. Only the
/// wholesale eviction bumps the epoch — per-block changes no longer
/// invalidate cached scroll geometry.
fn rich_text_record_block_measured_height(
  editor_block : MarkdownEditorBlock,
  base : @core.FontSpec,
  width~ : Double,
  height~ : Double,
) -> Bool {
  if width <= 0.0 || height <= 0.0 {
    return false
  }
  let key = rich_text_block_measured_height_key(editor_block, base, width~)
  let digest = rich_text_block_measured_height_digest(
    editor_block,
    base,
    width~,
  )
  let old_bucket = rich_text_block_heights.get(digest)
  match old_bucket {
    Some(bucket) =>
      match rich_text_bucket_lookup(bucket, key~) {
        Some(recorded) => if recorded == height { return false }
        None => ()
      }
    None => ()
  }
  if rich_text_block_heights_count.val >= 32768 {
    rich_text_block_heights.clear()
    rich_text_block_heights_count.val = 0
    rich_text_block_heights_epoch.val = rich_text_block_heights_epoch.val + 1
  }
  let next_bucket = match old_bucket {
    Some(bucket) => {
      let filtered = bucket.filter(pair => pair.0 != key)
      filtered.push((key, height))
      filtered
    }
    None => [(key, height)]
  }
  let old_length = match old_bucket {
    Some(bucket) => bucket.length()
    None => 0
  }
  rich_text_block_heights_count.val = rich_text_block_heights_count.val -
    old_length +
    next_bucket.length()
  rich_text_block_heights.set(digest, next_bucket)
  true
}

///|
/// Read the persisted scroll geometry for a (font, content width,
/// source-digest) triple. Returns `None` on miss or when the entry
/// predates the current measured-height epoch (the epoch only bumps on a
/// wholesale measured-height eviction; single-block height changes are
/// applied in place through the Fenwick point update).
fn markdown_document_scroll_geometry_get(
  base : @core.FontSpec,
  width~ : Double,
  source_digest~ : UInt64,
  source_length~ : Int,
) -> MarkdownDocumentScrollGeometry? {
  let key = markdown_document_scroll_geometry_key(
    base,
    width~,
    source_digest~,
    source_length~,
  )
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
fn markdown_document_scroll_geometry_key(
  base : @core.FontSpec,
  width~ : Double,
  source_digest~ : UInt64,
  source_length~ : Int,
) -> String {
  rich_text_cache_join_key([
    "scroll-geometry",
    rich_text_cache_font_key(base),
    width.to_string(),
    source_length.to_string(),
    source_digest.to_string(),
  ])
}

///|
fn markdown_document_scroll_geometry_put(
  base : @core.FontSpec,
  geometry : MarkdownDocumentScrollGeometry,
  width~ : Double,
  source_digest~ : UInt64,
  source_length~ : Int,
) -> Unit {
  let key = markdown_document_scroll_geometry_key(
    base,
    width~,
    source_digest~,
    source_length~,
  )
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
  // Before the first measured height lands (a fresh process opening a
  // document) every lookup would miss, so skip the digest entirely
  // instead of computing it once per block.
  if rich_text_block_heights_count.val == 0 {
    return None
  }
  let digest = rich_text_block_measured_height_digest(
    editor_block,
    base,
    width~,
  )
  match rich_text_block_heights.get(digest) {
    None => None
    Some(bucket) => {
      // A digest hit is the only case that pays for the exact key, so
      // misses stay allocation-free while hits remain content-verified.
      let key = rich_text_block_measured_height_key(editor_block, base, width~)
      rich_text_bucket_lookup(bucket, key~)
    }
  }
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

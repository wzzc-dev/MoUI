///|
/// High-level text state for GUI/editor code: a keyed font registry plus
/// layout and caret helpers built on the stable FontFace/TextLayout facades.
struct TextSystem {
  loader : MemoryFontLoader
  face_cache : FontFaceCache
  mut font_keys : Array[String]
} derive(Debug)

///|
/// Caret geometry in layout-local coordinates for one text insertion point.
struct TextCaret {
  index : Int
  line : Int
  x : Double
  y : Double
  height : Double
  baseline_y : Double
} derive(Eq, Debug)

///|
/// Highlight geometry for one visual line of a text selection.
struct TextSelectionRect {
  start_index : Int
  end_index : Int
  line : Int
  x : Double
  y : Double
  width : Double
  height : Double
  baseline_y : Double
} derive(Eq, Debug)

///|
/// Result of registering checked font data in a TextSystem.
struct TextSystemFontRegistration {
  key : String
  face : FontFace
  font_data : FontData
  did_replace : Bool
  did_replace_cached_face : Bool
  font_count : Int
} derive(Debug)

///|
/// Prepared text layout for GUI/editor code that needs several geometry
/// queries from the same registered font, text, and layout config.
struct TextSystemLayout {
  key : String
  text : String
  config : LayoutConfig
  face : FontFace
  layout : TextLayout
} derive(Debug)

///|
priv struct TextLineSourceSpan {
  start_index : Int
  end_index : Int
}

///|
/// Create an empty text system with an unbounded parsed-face cache.
pub fn TextSystem::new() -> TextSystem {
  {
    loader: MemoryFontLoader::new(),
    face_cache: FontFaceCache::new(),
    font_keys: [],
  }
}

///|
/// Create an empty text system with an LRU parsed-face cache capacity.
pub fn TextSystem::with_font_cache_capacity(capacity : Int) -> TextSystem {
  {
    loader: MemoryFontLoader::new(),
    face_cache: FontFaceCache::with_capacity(capacity),
    font_keys: [],
  }
}

///|
/// Register checked font bytes under a caller-provided key.
pub fn TextSystem::register_font_bytes(
  self : TextSystem,
  key : String,
  data : Bytes,
  font_index? : Int = 0,
) -> Result[FontFace, FontParseError] {
  match self.register_font_bytes_result(key, data, font_index~) {
    Ok(result) => Ok(result.get_face())
    Err(error) => Err(error)
  }
}

///|
/// Register checked font bytes and return registration telemetry.
pub fn TextSystem::register_font_bytes_result(
  self : TextSystem,
  key : String,
  data : Bytes,
  font_index? : Int = 0,
) -> Result[TextSystemFontRegistration, FontParseError] {
  self.register_font_data_result(key, FontData::new(data, font_index~))
}

///|
/// Register checked font data under a caller-provided key.
pub fn TextSystem::register_font_data(
  self : TextSystem,
  key : String,
  font_data : FontData,
) -> Result[FontFace, FontParseError] {
  match self.register_font_data_result(key, font_data) {
    Ok(result) => Ok(result.get_face())
    Err(error) => Err(error)
  }
}

///|
/// Register checked font data and return registration telemetry.
pub fn TextSystem::register_font_data_result(
  self : TextSystem,
  key : String,
  font_data : FontData,
) -> Result[TextSystemFontRegistration, FontParseError] {
  match FontFace::from_data(font_data) {
    Ok(face) => {
      let did_replace = self.loader.contains(key)
      let did_replace_cached_face = self.face_cache.contains(key)
      ignore(self.loader.insert(key, font_data))
      if !did_replace {
        self.font_keys.push(key)
      }
      Ok({
        key,
        face: self.face_cache.insert(key, face),
        font_data,
        did_replace,
        did_replace_cached_face,
        font_count: self.font_count(),
      })
    }
    Err(error) => Err(error)
  }
}

///|
/// Read checked font bytes from a file and register them under a
/// caller-provided key, caching the loaded data in this TextSystem.
pub fn TextSystem::register_font_file(
  self : TextSystem,
  key : String,
  path : String,
  font_index? : Int = 0,
) -> Result[FontFace, FontLoadError] {
  match self.register_font_file_result(key, path, font_index~) {
    Ok(result) => Ok(result.get_face())
    Err(error) => Err(error)
  }
}

///|
/// Read checked font bytes from a file, register them as in-memory font data,
/// and return registration telemetry.
pub fn TextSystem::register_font_file_result(
  self : TextSystem,
  key : String,
  path : String,
  font_index? : Int = 0,
) -> Result[TextSystemFontRegistration, FontLoadError] {
  let loaded : Bytes? = Some(read_file(path)) catch { _ => None }
  match loaded {
    Some(data) =>
      match
        self.register_font_data_result(key, FontData::new(data, font_index~)) {
        Ok(result) => Ok(result)
        Err(error) => Err(FontLoadError::FontParseFailed(key, error))
      }
    None => Err(FontLoadError::FontFileReadFailed(key, path))
  }
}

///|
/// Return the font registry key that was registered.
pub fn TextSystemFontRegistration::get_key(
  self : TextSystemFontRegistration,
) -> String {
  self.key
}

///|
/// Return the checked face that was registered.
pub fn TextSystemFontRegistration::get_face(
  self : TextSystemFontRegistration,
) -> FontFace {
  self.face
}

///|
/// Return the checked font data that was registered.
pub fn TextSystemFontRegistration::get_font_data(
  self : TextSystemFontRegistration,
) -> FontData {
  self.font_data
}

///|
/// Return whether registration replaced existing font data for the key.
pub fn TextSystemFontRegistration::did_replace(
  self : TextSystemFontRegistration,
) -> Bool {
  self.did_replace
}

///|
/// Return whether registration replaced an already-cached parsed face.
pub fn TextSystemFontRegistration::did_replace_cached_face(
  self : TextSystemFontRegistration,
) -> Bool {
  self.did_replace_cached_face
}

///|
/// Return the registered font-data entry count after this registration.
pub fn TextSystemFontRegistration::get_font_count(
  self : TextSystemFontRegistration,
) -> Int {
  self.font_count
}

///|
/// Return the number of registered font-data entries.
pub fn TextSystem::font_count(self : TextSystem) -> Int {
  self.loader.len()
}

///|
/// Return registered font keys in registration order.
pub fn TextSystem::get_font_keys(self : TextSystem) -> Array[String] {
  copy_text_system_font_keys(self.font_keys)
}

///|
/// Return a registered font key by registration-order index.
pub fn TextSystem::get_font_key(self : TextSystem, index : Int) -> String? {
  guard index >= 0 && index < self.font_keys.length() else { return None }
  Some(self.font_keys[index])
}

///|
/// Return whether font data has been registered for a key.
pub fn TextSystem::contains_font(self : TextSystem, key : String) -> Bool {
  self.loader.contains(key)
}

///|
/// Return registered font data for a key.
pub fn TextSystem::get_font_data(
  self : TextSystem,
  key : String,
) -> Result[FontData, FontLoadError] {
  FontLoader::load_font_data(self.loader, key)
}

///|
pub impl FontLoader for TextSystem with fn load_font_data(self, key) {
  self.get_font_data(key)
}

///|
/// Drop one registered font-data entry and any parsed face cached for the key.
///
/// Returns whether font data was registered before removal.
pub fn TextSystem::remove_font(self : TextSystem, key : String) -> Bool {
  let had_font = self.loader.contains(key)
  self.loader.remove(key)
  self.face_cache.remove(key)
  if had_font {
    self.remove_font_key(key)
  }
  had_font
}

///|
/// Drop registered font data and parsed face cache entries.
pub fn TextSystem::clear_fonts(self : TextSystem) -> Unit {
  self.loader.clear()
  self.face_cache.clear()
  self.font_keys = []
}

///|
fn copy_text_system_font_keys(keys : Array[String]) -> Array[String] {
  let copied = []
  for key in keys {
    copied.push(key)
  }
  copied
}

///|
fn TextSystem::remove_font_key(self : TextSystem, key : String) -> Unit {
  let mut index = 0
  while index < self.font_keys.length() {
    if self.font_keys[index] == key {
      ignore(self.font_keys.remove(index))
    } else {
      index += 1
    }
  }
}

///|
/// Return the number of parsed font faces currently cached.
pub fn TextSystem::font_face_cache_len(self : TextSystem) -> Int {
  self.face_cache.len()
}

///|
/// Return the parsed face cache capacity, or 0 for unbounded caches.
pub fn TextSystem::font_face_cache_capacity(self : TextSystem) -> Int {
  self.face_cache.capacity()
}

///|
/// Return whether the parsed face cache has an entry capacity.
pub fn TextSystem::is_font_face_cache_capacity_bounded(
  self : TextSystem,
) -> Bool {
  self.face_cache.is_capacity_bounded()
}

///|
/// Return whether a parsed face is cached for a registered font key.
pub fn TextSystem::contains_cached_font_face(
  self : TextSystem,
  key : String,
) -> Bool {
  self.face_cache.contains(key)
}

///|
/// Clear parsed face cache entries while preserving registered font data.
pub fn TextSystem::clear_font_face_cache(self : TextSystem) -> Unit {
  self.face_cache.clear()
}

///|
/// Return a checked face for a registered font key.
pub fn TextSystem::get_font_face(
  self : TextSystem,
  key : String,
) -> Result[FontFace, FontLoadError] {
  match self.get_font_face_result(key) {
    Ok(result) => Ok(result.get_face())
    Err(error) => Err(error)
  }
}

///|
/// Return a checked face for a registered font key with cache telemetry.
pub fn TextSystem::get_font_face_result(
  self : TextSystem,
  key : String,
) -> Result[FontFaceCacheParseResult, FontLoadError] {
  self.face_cache.get_or_load_result(key, self.loader)
}

///|
/// Layout text using a registered font key.
pub fn TextSystem::layout_text(
  self : TextSystem,
  key : String,
  text : String,
  config : LayoutConfig,
) -> Result[TextLayout, FontLoadError] {
  match self.prepare_layout(key, text, config) {
    Ok(prepared) => Ok(prepared.get_layout())
    Err(error) => Err(error)
  }
}

///|
/// Prepare a reusable layout snapshot for caret, hit-test, and selection
/// geometry queries.
pub fn TextSystem::prepare_layout(
  self : TextSystem,
  key : String,
  text : String,
  config : LayoutConfig,
) -> Result[TextSystemLayout, FontLoadError] {
  match self.get_font_face(key) {
    Err(error) => Err(error)
    Ok(face) =>
      Ok({
        key,
        text,
        config,
        face,
        layout: TextLayout::layout(face, text, config),
      })
  }
}

///|
/// Return the registered font key used by this prepared layout.
pub fn TextSystemLayout::get_key(self : TextSystemLayout) -> String {
  self.key
}

///|
/// Return the source text used by this prepared layout.
pub fn TextSystemLayout::get_text(self : TextSystemLayout) -> String {
  self.text
}

///|
/// Return the layout configuration used by this prepared layout.
pub fn TextSystemLayout::get_config(self : TextSystemLayout) -> LayoutConfig {
  self.config
}

///|
/// Return the checked font face captured by this prepared layout.
pub fn TextSystemLayout::get_face(self : TextSystemLayout) -> FontFace {
  self.face
}

///|
/// Return the computed text layout.
pub fn TextSystemLayout::get_layout(self : TextSystemLayout) -> TextLayout {
  self.layout
}

///|
/// Compute caret geometry for a text insertion index from this prepared layout.
pub fn TextSystemLayout::caret_for_index(
  self : TextSystemLayout,
  index : Int,
) -> TextCaret {
  text_caret_from_layout(self.face, self.layout, self.text, index, self.config)
}

///|
/// Compute nearest caret geometry at a layout-local position from this prepared
/// layout.
pub fn TextSystemLayout::caret_at_position(
  self : TextSystemLayout,
  x : Double,
  y : Double,
) -> TextCaret {
  text_caret_at_position_from_layout(
    self.face,
    self.layout,
    self.text,
    x,
    y,
    self.config,
  )
}

///|
/// Compute selection highlight rectangles from this prepared layout.
pub fn TextSystemLayout::selection_rects(
  self : TextSystemLayout,
  start_index : Int,
  end_index : Int,
) -> Array[TextSelectionRect] {
  text_selection_rects_from_layout(
    self.layout,
    self.text,
    start_index,
    end_index,
    self.config,
  )
}

///|
/// Compute caret geometry for a text insertion index using a registered font.
pub fn TextSystem::caret_for_text(
  self : TextSystem,
  key : String,
  text : String,
  index : Int,
  config : LayoutConfig,
) -> Result[TextCaret, FontLoadError] {
  match self.get_font_face(key) {
    Err(error) => Err(error)
    Ok(face) => {
      let layout = TextLayout::layout(face, text, config)
      Ok(text_caret_from_layout(face, layout, text, index, config))
    }
  }
}

///|
/// Compute caret geometry for the nearest insertion point at a layout-local
/// position using a registered font.
pub fn TextSystem::caret_at_text_position(
  self : TextSystem,
  key : String,
  text : String,
  x : Double,
  y : Double,
  config : LayoutConfig,
) -> Result[TextCaret, FontLoadError] {
  match self.get_font_face(key) {
    Err(error) => Err(error)
    Ok(face) => {
      let layout = TextLayout::layout(face, text, config)
      Ok(text_caret_at_position_from_layout(face, layout, text, x, y, config))
    }
  }
}

///|
/// Compute one highlight rectangle per visual line for a text selection range.
pub fn TextSystem::selection_rects_for_text(
  self : TextSystem,
  key : String,
  text : String,
  start_index : Int,
  end_index : Int,
  config : LayoutConfig,
) -> Result[Array[TextSelectionRect], FontLoadError] {
  match self.get_font_face(key) {
    Err(error) => Err(error)
    Ok(face) => {
      let layout = TextLayout::layout(face, text, config)
      Ok(
        text_selection_rects_from_layout(
          layout, text, start_index, end_index, config,
        ),
      )
    }
  }
}

///|
/// Return the clamped text insertion index.
pub fn TextCaret::get_index(self : TextCaret) -> Int {
  self.index
}

///|
/// Return the zero-based visual line containing this caret.
pub fn TextCaret::get_line(self : TextCaret) -> Int {
  self.line
}

///|
/// Return caret x in layout-local coordinates.
pub fn TextCaret::get_x(self : TextCaret) -> Double {
  self.x
}

///|
/// Return caret top y in layout-local coordinates.
pub fn TextCaret::get_y(self : TextCaret) -> Double {
  self.y
}

///|
/// Return caret rectangle height.
pub fn TextCaret::get_height(self : TextCaret) -> Double {
  self.height
}

///|
/// Return the baseline y for the caret line.
pub fn TextCaret::get_baseline_y(self : TextCaret) -> Double {
  self.baseline_y
}

///|
/// Return the clamped source start index covered by this selection rect.
pub fn TextSelectionRect::get_start_index(self : TextSelectionRect) -> Int {
  self.start_index
}

///|
/// Return the clamped source end index covered by this selection rect.
pub fn TextSelectionRect::get_end_index(self : TextSelectionRect) -> Int {
  self.end_index
}

///|
/// Return the zero-based visual line containing this selection rect.
pub fn TextSelectionRect::get_line(self : TextSelectionRect) -> Int {
  self.line
}

///|
/// Return selection rect x in layout-local coordinates.
pub fn TextSelectionRect::get_x(self : TextSelectionRect) -> Double {
  self.x
}

///|
/// Return selection rect top y in layout-local coordinates.
pub fn TextSelectionRect::get_y(self : TextSelectionRect) -> Double {
  self.y
}

///|
/// Return selection rect width.
pub fn TextSelectionRect::get_width(self : TextSelectionRect) -> Double {
  self.width
}

///|
/// Return selection rect height.
pub fn TextSelectionRect::get_height(self : TextSelectionRect) -> Double {
  self.height
}

///|
/// Return the baseline y for the selection rect line.
pub fn TextSelectionRect::get_baseline_y(self : TextSelectionRect) -> Double {
  self.baseline_y
}

///|
fn text_caret_from_layout(
  face : FontFace,
  layout : TextLayout,
  text : String,
  index : Int,
  config : LayoutConfig,
) -> TextCaret {
  let caret_index = clamp_text_caret_index(text, index)
  let runs = layout.get_runs()
  guard runs.length() > 0 else {
    return empty_text_caret(face, caret_index, config)
  }

  let spans = text_line_source_spans(text, runs)
  let line = text_caret_line_for_index(spans, caret_index)
  let run = runs[line]
  let span = spans[line]
  let visible_before = visible_text_count_before(
    text,
    span.start_index,
    caret_index.min(span.end_index),
  )
  let baseline_y = run.get_baseline_y()
  {
    index: caret_index,
    line,
    x: text_caret_x_for_run(run, visible_before),
    y: baseline_y - layout.get_baseline(),
    height: config.line_height,
    baseline_y,
  }
}

///|
fn text_caret_at_position_from_layout(
  face : FontFace,
  layout : TextLayout,
  text : String,
  x : Double,
  y : Double,
  config : LayoutConfig,
) -> TextCaret {
  let runs = layout.get_runs()
  guard runs.length() > 0 else { return empty_text_caret(face, 0, config) }

  let hit_x = normalize_text_hit_coordinate(x)
  let hit_y = normalize_text_hit_coordinate(y)
  let line = text_caret_line_for_y(layout, runs, hit_y, config)
  let run = runs[line]
  let spans = text_line_source_spans(text, runs)
  let span = spans[line]
  let visible_before = text_caret_visible_count_for_x(run, hit_x)
  let index = text_index_after_visible_count(
    text,
    span.start_index,
    span.end_index,
    visible_before,
  )
  let baseline_y = run.get_baseline_y()
  {
    index,
    line,
    x: text_caret_x_for_run(run, visible_before),
    y: baseline_y - layout.get_baseline(),
    height: config.line_height,
    baseline_y,
  }
}

///|
fn normalize_text_hit_coordinate(value : Double) -> Double {
  guard value == value else { return 0.0 }
  guard value - value == value - value else {
    if value < 0.0 {
      return 0.0 - text_hit_coordinate_limit
    } else {
      return text_hit_coordinate_limit
    }
  }
  value
}

///|
let text_hit_coordinate_limit = 1.0e100

///|
fn empty_text_caret(
  face : FontFace,
  index : Int,
  config : LayoutConfig,
) -> TextCaret {
  let baseline_y = scaled_ascent(face, config)
  { index, line: 0, x: 0.0, y: 0.0, height: config.line_height, baseline_y }
}

///|
fn clamp_text_caret_index(text : String, index : Int) -> Int {
  normalize_text_caret_index(text, index.max(0).min(text.length()))
}

///|
fn normalize_text_caret_index(text : String, index : Int) -> Int {
  guard index > 0 && index < text.length() else { return index }
  match text.get_char(index) {
    None => next_text_char_index(text, index)
    Some(_) =>
      match (text.get_char(index - 1), text.get_char(index)) {
        (Some('\r'), Some('\n')) => next_text_char_index(text, index)
        _ => index
      }
  }
}

///|
fn clamp_text_range(
  text : String,
  start_index : Int,
  end_index : Int,
) -> (Int, Int) {
  let start = clamp_text_caret_index(text, start_index)
  let end = clamp_text_caret_index(text, end_index)
  if start <= end {
    (start, end)
  } else {
    (end, start)
  }
}

///|
fn text_selection_rects_from_layout(
  layout : TextLayout,
  text : String,
  start_index : Int,
  end_index : Int,
  config : LayoutConfig,
) -> Array[TextSelectionRect] {
  let (range_start, range_end) = clamp_text_range(text, start_index, end_index)
  guard range_start < range_end else { return [] }
  let runs = layout.get_runs()
  guard runs.length() > 0 else { return [] }

  let spans = text_line_source_spans(text, runs)
  let rects = []
  for i in 0..<runs.length() {
    let span = spans[i]
    let rect_start = range_start.max(span.start_index)
    let rect_end = range_end.min(span.end_index)
    if rect_start < rect_end {
      let run = runs[i]
      let start_visible = visible_text_count_before(
        text,
        span.start_index,
        rect_start,
      )
      let end_visible = visible_text_count_before(
        text,
        span.start_index,
        rect_end,
      )
      let x = text_caret_x_for_run(run, start_visible)
      let end_x = text_caret_x_for_run(run, end_visible)
      if end_x > x {
        let baseline_y = run.get_baseline_y()
        rects.push({
          start_index: rect_start,
          end_index: rect_end,
          line: i,
          x,
          y: baseline_y - layout.get_baseline(),
          width: end_x - x,
          height: config.line_height,
          baseline_y,
        })
      }
    }
  }
  rects
}

///|
fn scaled_ascent(face : FontFace, config : LayoutConfig) -> Double {
  let metrics = face.get_metrics()
  guard metrics.units_per_em > 0 else { return config.font_size }
  metrics.ascent.to_double() *
  config.font_size /
  metrics.units_per_em.to_double()
}

///|
fn text_line_source_spans(
  text : String,
  runs : Array[GlyphRun],
) -> Array[TextLineSourceSpan] {
  let spans = []
  let mut cursor = 0
  for run in runs {
    let start_index = cursor
    cursor = consume_visible_text(text, cursor, run.glyph_count())
    cursor = consume_zero_width_text_before_line_boundary(text, cursor)
    spans.push({ start_index, end_index: cursor })
    cursor = consume_line_break_at(text, cursor)
  }
  spans
}

///|
fn consume_visible_text(text : String, index : Int, count : Int) -> Int {
  let mut cursor = index
  let mut remaining = count
  while cursor < text.length() && remaining > 0 {
    match text.get_char(cursor) {
      Some(ch) =>
        if is_text_line_break(ch) {
          return cursor
        } else {
          if is_visible_layout_char(ch) {
            remaining = remaining - 1
          }
          cursor = next_text_char_index(text, cursor)
        }
      None => cursor = next_text_char_index(text, cursor)
    }
  }
  cursor
}

///|
fn consume_line_break_at(text : String, index : Int) -> Int {
  match text.get_char(index) {
    Some('\r') => {
      let next_index = next_text_char_index(text, index)
      match text.get_char(next_index) {
        Some('\n') => next_text_char_index(text, next_index)
        _ => next_index
      }
    }
    Some('\n') => next_text_char_index(text, index)
    _ => index
  }
}

///|
fn consume_zero_width_text_before_line_boundary(
  text : String,
  index : Int,
) -> Int {
  let mut cursor = index
  while cursor < text.length() {
    match text.get_char(cursor) {
      Some(ch) =>
        if is_text_line_break(ch) {
          return cursor
        } else if is_visible_layout_char(ch) {
          return cursor
        } else {
          cursor = next_text_char_index(text, cursor)
        }
      None => cursor = next_text_char_index(text, cursor)
    }
  }
  cursor
}

///|
fn text_caret_line_for_index(
  spans : Array[TextLineSourceSpan],
  index : Int,
) -> Int {
  guard spans.length() > 0 else { return 0 }
  for i in 0..<spans.length() {
    let span = spans[i]
    if index < span.end_index {
      return i
    }
    if index == span.end_index {
      if i + 1 < spans.length() && spans[i + 1].start_index == index {
        continue
      }
      return i
    }
    if index < span.start_index {
      return i
    }
  }
  spans.length() - 1
}

///|
fn text_caret_line_for_y(
  layout : TextLayout,
  runs : Array[GlyphRun],
  y : Double,
  config : LayoutConfig,
) -> Int {
  guard runs.length() > 0 else { return 0 }
  for i in 0..<runs.length() {
    let top = runs[i].get_baseline_y() - layout.get_baseline()
    if y < top + config.line_height {
      return i
    }
  }
  runs.length() - 1
}

///|
fn visible_text_count_before(
  text : String,
  start_index : Int,
  end_index : Int,
) -> Int {
  let mut count = 0
  let mut cursor = start_index
  while cursor < end_index && cursor < text.length() {
    match text.get_char(cursor) {
      Some(ch) =>
        if is_text_line_break(ch) {
          return count
        } else {
          if is_visible_layout_char(ch) {
            count = count + 1
          }
          cursor = next_text_char_index(text, cursor)
        }
      None => cursor = next_text_char_index(text, cursor)
    }
  }
  count
}

///|
fn text_caret_visible_count_for_x(run : GlyphRun, x : Double) -> Int {
  let glyphs = run.get_glyphs()
  guard glyphs.length() > 0 else { return 0 }
  for i in 0..<glyphs.length() {
    let left = text_caret_x_for_run(run, i)
    let right = text_caret_x_for_run(run, i + 1)
    if x <= left + (right - left) / 2.0 {
      return i
    }
  }
  glyphs.length()
}

///|
fn text_index_after_visible_count(
  text : String,
  start_index : Int,
  end_index : Int,
  visible_count : Int,
) -> Int {
  guard visible_count > 0 else { return start_index }
  let mut remaining = visible_count
  let mut cursor = start_index
  while cursor < end_index && cursor < text.length() {
    match text.get_char(cursor) {
      Some(ch) =>
        if is_text_line_break(ch) {
          return cursor
        } else {
          if is_visible_layout_char(ch) {
            remaining = remaining - 1
            if remaining <= 0 {
              return next_text_char_index(text, cursor)
            }
          }
          cursor = next_text_char_index(text, cursor)
        }
      None => cursor = next_text_char_index(text, cursor)
    }
  }
  end_index
}

///|
fn next_text_char_index(text : String, index : Int) -> Int {
  let mut cursor = (index + 1).max(0)
  while cursor < text.length() {
    match text.get_char(cursor) {
      Some(_) => return cursor
      None => cursor = cursor + 1
    }
  }
  text.length()
}

///|
fn text_caret_x_for_run(run : GlyphRun, visible_before : Int) -> Double {
  let glyphs = run.get_glyphs()
  guard glyphs.length() > 0 else { return 0.0 }
  let glyph_index = visible_before.max(0).min(glyphs.length())
  if glyph_index < glyphs.length() {
    glyphs[glyph_index].origin_x
  } else {
    let last = glyphs[glyphs.length() - 1]
    last.origin_x + last.get_advance_width()
  }
}

///|
fn is_text_line_break(ch : Char) -> Bool {
  ch is '\n' || ch is '\r'
}

///|
fn is_visible_layout_char(ch : Char) -> Bool {
  !(ch is '\t') && !is_text_line_break(ch)
}

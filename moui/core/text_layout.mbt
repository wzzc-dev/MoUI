///|
pub(all) struct TextLayoutInput {
  text : String
  font : FontSpec
  max_width : Double?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextLayoutResult {
  size : Size
  baseline : Double
  caret_positions : Array[Double]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextParagraphLineMetrics {
  line_index : Int
  text_range : TextRange
  origin : Point
  size : Size
  baseline : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextParagraphVisualOrderMetadata {
  logical_text : String
  visual_text : String
  logical_cluster_count : Int
  visual_cluster_count : Int
  segment_count : Int
  glyph_count : Int
  visual_order_differs : Bool
  bidi_visual_order_ready : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextParagraphLayoutMetadata {
  text_system_id : String
  paragraph_layout_available : Bool
  line_metrics_available : Bool
  selection_rects_available : Bool
  hit_test_available : Bool
  native_paragraph_ready : Bool
  bidi_visual_order_ready : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextParagraphHitTestResult {
  offset : Int
  line_index : Int
  caret_rect : Rect
  is_inside : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextParagraphLayoutResult {
  text : String
  size : Size
  baseline : Double
  lines : Array[TextParagraphLineMetrics]
  caret_rects : Array[Rect]
  visual_order : TextParagraphVisualOrderMetadata
  metadata : TextParagraphLayoutMetadata
} derive(Eq, Debug, ToJson)

///|
pub struct TextSystem {
  id : String
  measure : (TextLayoutInput) -> TextLayoutResult
  paragraph_layout : (TextLayoutInput) -> TextParagraphLayoutResult
  register_font_data : (FontFamily, Bytes) -> Unit
}

///|
pub fn TextLayoutInput::new(
  text~ : String,
  font~ : FontSpec,
  max_width? : Double,
) -> TextLayoutInput {
  { text, font, max_width }
}

///|
pub fn TextSystem::new(
  id~ : String,
  measure~ : (TextLayoutInput) -> TextLayoutResult,
  paragraph_layout? : ((TextLayoutInput) -> TextParagraphLayoutResult)? = None,
  register_font_data? : (FontFamily, Bytes) -> Unit = (_family, _data) => (),
) -> TextSystem {
  let paragraph_layout = match paragraph_layout {
    Some(layout) => layout
    None => input => fallback_paragraph_layout_result(input, measure, id)
  }
  { id, measure, paragraph_layout, register_font_data }
}

///|
pub fn TextSystem::fallback() -> TextSystem {
  TextSystem::new(
    id="core-fallback-text-system",
    measure=fallback_measure_text_layout,
  )
}

///|
pub fn TextSystem::id(self : TextSystem) -> String {
  self.id
}

///|
pub fn TextSystem::measure_text(
  self : TextSystem,
  input : TextLayoutInput,
) -> TextLayoutResult {
  (self.measure)(input)
}

///|
pub fn TextSystem::layout_paragraph(
  self : TextSystem,
  input : TextLayoutInput,
) -> TextParagraphLayoutResult {
  match text_paragraph_cache_lookup(self.id, input) {
    Some(result) => result
    None => {
      let result = (self.paragraph_layout)(input)
      text_paragraph_cache_store(self.id, input, result)
      result
    }
  }
}

///|
pub fn TextSystem::register_font_data(
  self : TextSystem,
  family : FontFamily,
  data : Bytes,
) -> Unit {
  (self.register_font_data)(family, data)
  // Measured widths (and therefore cached paragraph layouts) can change
  // whenever any font data is registered, for any backend.
  text_paragraph_cache_font_generation.val = text_paragraph_cache_font_generation.val +
    1
}

///|
pub fn TextParagraphLayoutResult::line_count(
  self : TextParagraphLayoutResult,
) -> Int {
  self.lines.length()
}

///|
pub fn TextParagraphLayoutResult::caret_rect_at(
  self : TextParagraphLayoutResult,
  offset : Int,
) -> Rect {
  if self.caret_rects.is_empty() {
    return Rect::new(x=0.0, y=0.0, width=1.0, height=0.0)
  }
  let boundaries = TextGraphemeBoundaries::new(text=self.text)
  let offset = boundaries.nearest_boundary(offset)
  self.caret_rects[clamp_int(offset, 0, self.caret_rects.length() - 1)]
}

///|
pub fn TextParagraphLayoutResult::selection_rects(
  self : TextParagraphLayoutResult,
  range : TextRange,
) -> Array[Rect] {
  let boundaries = TextGraphemeBoundaries::new(text=self.text)
  let normalized = normalize_grapheme_range(boundaries, range)
  if normalized.is_collapsed() {
    return [self.caret_rect_at(normalized.start)]
  }
  let rects : Array[Rect] = []
  for line in self.lines {
    let start = max_int(normalized.start, line.text_range.start)
    let end = min_int(normalized.end, line.text_range.end)
    if start < end {
      let start_rect = self.caret_rect_at(start)
      let end_rect = self.caret_rect_at(end)
      let x0 = start_rect.origin.x.min(end_rect.origin.x)
      let x1 = start_rect.origin.x.max(end_rect.origin.x)
      rects.push(
        Rect::new(
          x=x0,
          y=line.origin.y,
          width=(x1 - x0).max(1.0),
          height=line.size.height,
        ),
      )
    }
  }
  rects
}

///|
pub fn TextParagraphLayoutResult::hit_test(
  self : TextParagraphLayoutResult,
  point : Point,
) -> TextParagraphHitTestResult {
  let line = self.closest_line_for_point(point)
  let mut best_offset = line.text_range.start
  let mut best_distance = 1.0e18
  let hit_end = line.text_range.end + 1
  for offset in line.text_range.start..<hit_end {
    let rect = self.caret_rect_at(offset)
    let distance = if point.x >= rect.origin.x {
      point.x - rect.origin.x
    } else {
      rect.origin.x - point.x
    }
    if distance < best_distance {
      best_distance = distance
      best_offset = offset
    }
  }
  let boundaries = TextGraphemeBoundaries::new(text=self.text)
  best_offset = boundaries.nearest_boundary(best_offset)
  let caret_rect = self.caret_rect_at(best_offset)
  {
    offset: best_offset,
    line_index: line.line_index,
    caret_rect,
    is_inside: point.x >= 0.0 &&
    point.y >= 0.0 &&
    point.x <= self.size.width &&
    point.y <= self.size.height,
  }
}

///|
fn TextParagraphLayoutResult::closest_line_for_point(
  self : TextParagraphLayoutResult,
  point : Point,
) -> TextParagraphLineMetrics {
  if self.lines.is_empty() {
    return {
      line_index: 0,
      text_range: TextRange::collapsed(0),
      origin: Point::new(x=0.0, y=0.0),
      size: Size::new(width=0.0, height=0.0),
      baseline: 0.0,
    }
  }
  let mut closest = self.lines[0]
  let mut closest_distance = 1.0e18
  for line in self.lines {
    let line_top = line.origin.y
    let line_bottom = line.origin.y + line.size.height
    let distance = if point.y < line_top {
      line_top - point.y
    } else if point.y > line_bottom {
      point.y - line_bottom
    } else {
      0.0
    }
    if distance < closest_distance {
      closest = line
      closest_distance = distance
    }
  }
  closest
}

///|
fn fallback_measure_text_layout(input : TextLayoutInput) -> TextLayoutResult {
  let raw = fallback_text_layout_result(input)
  match input.max_width {
    Some(max_width) => clamp_text_layout_result(raw, max_width)
    None => raw
  }
}

///|
fn clamp_text_layout_result(
  result : TextLayoutResult,
  max_width : Double,
) -> TextLayoutResult {
  let carets : Array[Double] = []
  for caret in result.caret_positions {
    carets.push(min_double(caret, max_width))
  }
  {
    size: Size::new(
      width=min_double(result.size.width, max_width),
      height=result.size.height,
    ),
    baseline: result.baseline,
    caret_positions: carets,
  }
}

///|
fn fallback_paragraph_layout_result(
  input : TextLayoutInput,
  measure : (TextLayoutInput) -> TextLayoutResult,
  text_system_id : String,
) -> TextParagraphLayoutResult {
  let measured = measure(TextLayoutInput::new(text=input.text, font=input.font))
  let line_ranges = fallback_paragraph_line_ranges(input, measured)
  let caret_rects : Array[Rect] = []
  let text_length = input.text.to_array().length()
  let caret_count = text_length + 1
  for _ in 0..<caret_count {
    caret_rects.push(Rect::new(x=0.0, y=0.0, width=1.0, height=0.0))
  }
  let lines : Array[TextParagraphLineMetrics] = []
  let mut y = 0.0
  let mut width = 0.0
  let mut first_baseline = 0.0
  for line_index, range in line_ranges {
    let line_measured = fallback_paragraph_range_measure(
      measured,
      range,
      input.font,
    )
    let line_height = line_measured.size.height.max(input.font.size * 1.25)
    let line_width = fallback_paragraph_line_width(
      line_measured.size.width,
      input,
    )
    let baseline = y + line_measured.baseline
    if line_index == 0 {
      first_baseline = baseline
    }
    lines.push({
      line_index,
      text_range: range,
      origin: Point::new(x=0.0, y~),
      size: Size::new(width=line_width, height=line_height),
      baseline,
    })
    fallback_fill_paragraph_caret_rects(
      caret_rects,
      range,
      line_measured,
      y~,
      line_height~,
    )
    width = width.max(line_width)
    y = y + line_height
  }
  {
    text: input.text,
    size: Size::new(width~, height=y),
    baseline: first_baseline,
    lines,
    caret_rects,
    visual_order: fallback_paragraph_visual_order(input.text),
    metadata: {
      text_system_id,
      paragraph_layout_available: true,
      line_metrics_available: !lines.is_empty(),
      selection_rects_available: true,
      hit_test_available: true,
      native_paragraph_ready: false,
      bidi_visual_order_ready: false,
    },
  }
}

///|
fn fallback_paragraph_line_ranges(
  input : TextLayoutInput,
  measured : TextLayoutResult,
) -> Array[TextRange] {
  let chars = input.text.to_array()
  let length = chars.length()
  if length == 0 {
    return [TextRange::collapsed(0)]
  }
  let boundaries = TextGraphemeBoundaries::new(text=input.text)
  let ranges : Array[TextRange] = []
  let mut line_start = 0
  let mut cursor = 0
  let mut last_soft_break = -1
  while cursor < length {
    let next = boundaries.next_boundary(cursor)
    let cluster = String::from_array(chars[cursor:next])
    if cluster == "\n" {
      ranges.push(TextRange::new(start=line_start, end=cursor))
      line_start = next
      cursor = next
      last_soft_break = -1
    } else {
      let candidate_width = fallback_paragraph_caret_span_width(
        measured, line_start, next,
      )
      // Trailing spaces and tabs hang past the line box (matching
      // SkParagraph): they never break the line by themselves, they
      // only open a soft break that the next non-blank cluster pays
      // for when it finally overflows.
      let cluster_hangs = cluster == " " || cluster == "\t"
      let overflows = fallback_paragraph_should_wrap(
        input.max_width,
        candidate_width,
      )
      if overflows && !cluster_hangs && line_start < cursor {
        let break_end = if last_soft_break > line_start {
          last_soft_break
        } else {
          cursor
        }
        ranges.push(TextRange::new(start=line_start, end=break_end))
        line_start = break_end
        cursor = line_start
        last_soft_break = -1
      } else {
        if fallback_paragraph_cluster_is_soft_break(cluster) {
          last_soft_break = next
        }
        cursor = next
      }
    }
  }
  ranges.push(TextRange::new(start=line_start, end=length))
  ranges
}

///|
fn fallback_paragraph_range_measure(
  measured : TextLayoutResult,
  range : TextRange,
  font : FontSpec,
) -> TextLayoutResult {
  let origin = fallback_paragraph_caret_position(measured, range.start)
  let carets : Array[Double] = []
  for offset in range.start..<=range.end {
    carets.push(
      max_double(
        0.0,
        fallback_paragraph_caret_position(measured, offset) - origin,
      ),
    )
  }
  {
    size: Size::new(
      width=fallback_paragraph_caret_span_width(
        measured,
        range.start,
        range.end,
      ),
      height=measured.size.height.max(font.size * 1.25),
    ),
    baseline: measured.baseline,
    caret_positions: carets,
  }
}

///|
fn fallback_paragraph_caret_span_width(
  measured : TextLayoutResult,
  start : Int,
  end : Int,
) -> Double {
  max_double(
    0.0,
    fallback_paragraph_caret_position(measured, end) -
    fallback_paragraph_caret_position(measured, start),
  )
}

///|
fn fallback_paragraph_caret_position(
  measured : TextLayoutResult,
  offset : Int,
) -> Double {
  if measured.caret_positions.is_empty() {
    return 0.0
  }
  measured.caret_positions[clamp_int(
    offset,
    0,
    measured.caret_positions.length() - 1,
  )]
}

///|
fn fallback_paragraph_should_wrap(
  max_width : Double?,
  candidate_width : Double,
) -> Bool {
  match max_width {
    Some(width) => width > 0.0 && candidate_width > width
    None => false
  }
}

///|
fn fallback_paragraph_cluster_is_soft_break(cluster : String) -> Bool {
  cluster == " " ||
  cluster == "\t" ||
  cluster == "-" ||
  cluster == "、" ||
  cluster == "，" ||
  cluster == "。" ||
  cluster == "；" ||
  cluster == "：" ||
  cluster == "）" ||
  cluster == ")"
}

///|
fn fallback_paragraph_line_width(
  measured_width : Double,
  input : TextLayoutInput,
) -> Double {
  match input.max_width {
    Some(max_width) => measured_width.min(max_width.max(0.0))
    None => measured_width
  }
}

///|
fn fallback_fill_paragraph_caret_rects(
  caret_rects : Array[Rect],
  range : TextRange,
  measured : TextLayoutResult,
  y~ : Double,
  line_height~ : Double,
) -> Unit {
  let line_length = range.end - range.start
  let line_caret_count = line_length + 1
  for line_offset in 0..<line_caret_count {
    let global = range.start + line_offset
    if global >= 0 && global < caret_rects.length() {
      let x = if line_offset < measured.caret_positions.length() {
        measured.caret_positions[line_offset]
      } else {
        measured.size.width
      }
      caret_rects[global] = Rect::new(x~, y~, width=1.0, height=line_height)
    }
  }
}

///|
fn fallback_paragraph_visual_order(
  text : String,
) -> TextParagraphVisualOrderMetadata {
  let clusters = TextGraphemeBoundaries::new(text~).cluster_count()
  {
    logical_text: text,
    visual_text: text,
    logical_cluster_count: clusters,
    visual_cluster_count: clusters,
    segment_count: if text == "" {
      0
    } else {
      1
    },
    glyph_count: text.to_array().length(),
    visual_order_differs: false,
    bidi_visual_order_ready: false,
  }
}

///|
fn fallback_text_char_advance(ch : Char, font_size : Double) -> Double {
  if ch == ' ' || ch == '\t' {
    font_size * 0.35
  } else if (ch >= '0' && ch <= '9') ||
    (ch >= 'A' && ch <= 'Z') ||
    (ch >= 'a' && ch <= 'z') {
    font_size * 0.55
  } else {
    font_size * 0.95
  }
}

///|
fn fallback_text_layout_result(input : TextLayoutInput) -> TextLayoutResult {
  let mut width = 0.0
  let carets : Array[Double] = []
  carets.push(0.0)
  let mut cursor = 0.0
  for ch in input.text {
    let advance = fallback_text_char_advance(ch, input.font.size)
    cursor = cursor + advance
    width = width + advance
    carets.push(cursor)
  }
  let carets = fallback_stabilize_grapheme_cluster_carets(input.text, carets)
  {
    size: Size::new(width~, height=input.font.size * 1.25),
    baseline: input.font.size * 0.8,
    caret_positions: carets,
  }
}

///|
test "fallback paragraph derives wrapping from one text measurement" {
  let measure_count = [0]
  let system = TextSystem::new(id="counted-fallback", measure=input => {
    measure_count[0] = measure_count[0] + 1
    fallback_text_layout_result(input)
  })
  let paragraph = system.layout_paragraph(
    TextLayoutInput::new(
      text="one two three four five six seven eight nine ten",
      font=FontSpec::new(size=14.0),
      max_width=80.0,
    ),
  )
  assert_true(paragraph.lines.length() > 1)
  assert_eq(measure_count[0], 1)
  assert_eq(paragraph.caret_rects.length(), 49)
}

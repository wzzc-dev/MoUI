///|
priv struct SunTextLine {
  text : String
  width : Double
  start_scalar : Int
  scalar_count : Int
}

///|
priv struct SunTextLinePlan {
  lines : Array[SunTextLine]
  line_height : Double
  baseline : Double
}

///|
priv enum SunTextLayoutToken {
  Text(String, Int)
  LineBreak(Int)
}

///|
fn sun_text_line_plan(
  faces : Array[@sun_text.FontFace],
  text : String,
  config : @sun_text.LayoutConfig,
) -> SunTextLinePlan {
  let lines : Array[SunTextLine] = []
  let line_height = config.line_height.max(1.0)
  let baseline = sun_text_baseline_for_faces(faces, config)
  let tokens = sun_text_layout_tokens(text)
  let mut current_text = ""
  let mut current_width = 0.0
  let mut current_start = 0
  let mut current_scalar_count = 0
  let mut cursor_scalar = 0
  let mut saw_line = false
  for token in tokens {
    match token {
      SunTextLayoutToken::Text(token_text, token_scalar_count) => {
        let token_width = sun_measure_fallback_line_width(
          faces, token_text, config,
        )
        let is_space = token_text is " "
        let needs_break = current_scalar_count > 0 &&
          !is_space &&
          config.max_width > 0.0 &&
          current_width + token_width > config.max_width
        if needs_break {
          sun_text_line_plan_push(
            lines, faces, config, current_text, current_start, current_scalar_count,
          )
          saw_line = true
          current_start = cursor_scalar
          current_text = ""
          current_width = 0.0
          current_scalar_count = 0
        }
        current_text = current_text + token_text
        current_width = current_width + token_width
        current_scalar_count += token_scalar_count
        cursor_scalar += token_scalar_count
      }
      SunTextLayoutToken::LineBreak(line_break_scalar_count) => {
        sun_text_line_plan_push(
          lines, faces, config, current_text, current_start, current_scalar_count,
        )
        saw_line = true
        cursor_scalar += line_break_scalar_count
        current_start = cursor_scalar
        current_text = ""
        current_width = 0.0
        current_scalar_count = 0
      }
    }
  }
  if current_scalar_count > 0 || saw_line || lines.is_empty() {
    sun_text_line_plan_push(
      lines, faces, config, current_text, current_start, current_scalar_count,
    )
  }
  { lines, line_height, baseline }
}

///|
fn sun_text_line_plan_push(
  lines : Array[SunTextLine],
  faces : Array[@sun_text.FontFace],
  config : @sun_text.LayoutConfig,
  text : String,
  start_scalar : Int,
  scalar_count : Int,
) -> Unit {
  lines.push({
    text,
    width: sun_measure_fallback_line_width(faces, text, config),
    start_scalar,
    scalar_count,
  })
}

///|
fn sun_text_layout_tokens(text : String) -> Array[SunTextLayoutToken] {
  let tokens : Array[SunTextLayoutToken] = []
  let chars = text.to_array()
  let current_word : Array[Char] = []
  let mut current_word_class : @sun_text.LineBreakClass? = None
  let mut index = 0
  while index < chars.length() {
    let ch = chars[index]
    if ch is '\n' || ch is '\r' {
      sun_text_layout_tokens_flush_word(tokens, current_word)
      let line_break_scalar_count = if ch is '\r' &&
        index + 1 < chars.length() &&
        chars[index + 1] is '\n' {
        index += 1
        2
      } else {
        1
      }
      tokens.push(SunTextLayoutToken::LineBreak(line_break_scalar_count))
      current_word_class = None
    } else if ch is ' ' || ch is '\t' {
      sun_text_layout_tokens_flush_word(tokens, current_word)
      current_word_class = None
      if ch is ' ' {
        tokens.push(SunTextLayoutToken::Text(" ", 1))
      }
    } else {
      let curr_class = @sun_text.get_line_break_class(ch.to_int())
      match current_word_class {
        Some(prev_class) =>
          if sun_should_split_unspaced_layout_token(prev_class, curr_class) {
            sun_text_layout_tokens_flush_word(tokens, current_word)
            current_word_class = None
          }
        None => ()
      }
      current_word.push(ch)
      current_word_class = Some(curr_class)
    }
    index += 1
  }
  sun_text_layout_tokens_flush_word(tokens, current_word)
  tokens
}

///|
fn sun_text_layout_tokens_flush_word(
  tokens : Array[SunTextLayoutToken],
  current_word : Array[Char],
) -> Unit {
  if current_word.length() > 0 {
    tokens.push(
      SunTextLayoutToken::Text(
        String::from_array(current_word),
        current_word.length(),
      ),
    )
    current_word.clear()
  }
}

///|
fn sun_should_split_unspaced_layout_token(
  prev_class : @sun_text.LineBreakClass,
  curr_class : @sun_text.LineBreakClass,
) -> Bool {
  @sun_text.is_line_break_allowed(prev_class, curr_class) &&
  sun_can_start_unspaced_layout_token(curr_class) &&
  (
    sun_is_unspaced_layout_break_class(prev_class) ||
    sun_is_unspaced_layout_break_class(curr_class)
  )
}

///|
fn sun_can_start_unspaced_layout_token(
  class : @sun_text.LineBreakClass,
) -> Bool {
  match class {
    @sun_text.LineBreakClass::CL => false
    @sun_text.LineBreakClass::CP => false
    @sun_text.LineBreakClass::EX => false
    @sun_text.LineBreakClass::IS => false
    @sun_text.LineBreakClass::SY => false
    @sun_text.LineBreakClass::NS => false
    _ => true
  }
}

///|
fn sun_is_unspaced_layout_break_class(class : @sun_text.LineBreakClass) -> Bool {
  match class {
    @sun_text.LineBreakClass::ID => true
    @sun_text.LineBreakClass::H2 => true
    @sun_text.LineBreakClass::H3 => true
    @sun_text.LineBreakClass::JL => true
    @sun_text.LineBreakClass::JV => true
    @sun_text.LineBreakClass::JT => true
    _ => false
  }
}

///|
fn SunRasterRenderer::paragraph_layout_result(
  self : SunRasterRenderer,
  input : @core.TextLayoutInput,
) -> @core.TextParagraphLayoutResult {
  let faces = self.resolved_faces(input.font)
  if faces.is_empty() {
    return @core.TextSystem::new(id="sun-raster-text-system", measure=measure_input => {
      self.measure_text_layout(measure_input)
    }).layout_paragraph(input)
  }
  let config = sun_text_layout_config(
    input.font,
    input.max_width.unwrap_or(1000000000.0),
  )
  let plan = sun_text_line_plan(faces, input.text, config)
  let text_length = input.text.to_array().length()
  let caret_rects : Array[@core.Rect] = []
  for _ in 0..<(text_length + 1) {
    caret_rects.push(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=plan.line_height),
    )
  }
  let lines : Array[@core.TextParagraphLineMetrics] = []
  let mut y = 0.0
  let mut width = 0.0
  let mut first_baseline = 0.0
  for line_index in 0..<plan.lines.length() {
    let line = plan.lines[line_index]
    let measured = self.measure_single_line_text(faces, line.text, config)
    let baseline = y + plan.baseline
    if line_index == 0 {
      first_baseline = baseline
    }
    let line_width = line.width.max(measured.size.width)
    lines.push({
      line_index,
      text_range: @core.TextRange::new(
        start=line.start_scalar,
        end=line.start_scalar + line.scalar_count,
      ),
      origin: @core.Point::new(x=0.0, y~),
      size: @core.Size::new(width=line_width, height=plan.line_height),
      baseline,
    })
    let line_carets = measured.caret_positions
    for line_offset in 0..<(line.scalar_count + 1) {
      let global = line.start_scalar + line_offset
      if global < caret_rects.length() && line_offset < line_carets.length() {
        caret_rects[global] = @core.Rect::new(
          x=line_carets[line_offset],
          y~,
          width=1.0,
          height=plan.line_height,
        )
      }
    }
    width = width.max(line_width)
    y = y + plan.line_height
  }
  let visual_order = sun_text_visual_order_metadata(input.text)
  @core.TextParagraphLayoutResult::{
    text: input.text,
    size: @core.Size::new(
      width=width.min(input.max_width.unwrap_or(width)),
      height=y,
    ),
    baseline: first_baseline,
    lines,
    caret_rects: sun_stabilize_grapheme_cluster_caret_rects(
      input.text,
      caret_rects,
    ),
    visual_order,
    metadata: {
      text_system_id: "sun-raster-text-system",
      paragraph_layout_available: true,
      line_metrics_available: !lines.is_empty(),
      selection_rects_available: true,
      hit_test_available: true,
      native_paragraph_ready: false,
      bidi_visual_order_ready: visual_order.bidi_visual_order_ready,
    },
  }
}

///|
fn sun_text_visual_order_metadata(
  text : String,
) -> @core.TextParagraphVisualOrderMetadata {
  let logical_clusters = sun_text_grapheme_clusters(text)
  let visual_clusters = sun_text_bidi_visual_clusters(logical_clusters)
  {
    logical_text: sun_text_join_clusters(logical_clusters),
    visual_text: sun_text_join_clusters(visual_clusters),
    logical_cluster_count: logical_clusters.length(),
    visual_cluster_count: visual_clusters.length(),
    segment_count: sun_text_segment_count(visual_clusters),
    glyph_count: text.to_array().length(),
    visual_order_differs: !sun_text_cluster_arrays_equal(
      logical_clusters, visual_clusters,
    ),
    bidi_visual_order_ready: true,
  }
}

///|
fn sun_text_grapheme_clusters(text : String) -> Array[String] {
  let chars = text.to_array()
  let boundaries = @core.TextGraphemeBoundaries::new(text~).boundaries()
  let clusters : Array[String] = []
  if boundaries.length() < 2 {
    return clusters
  }
  for boundary_index in 0..<(boundaries.length() - 1) {
    let start = boundaries[boundary_index]
    let end = boundaries[boundary_index + 1]
    if end > start {
      clusters.push(String::from_array(chars[start:end]))
    }
  }
  clusters
}

///|
fn sun_text_bidi_visual_clusters(clusters : Array[String]) -> Array[String] {
  let visual : Array[String] = []
  let mut index = 0
  while index < clusters.length() {
    let rtl = sun_text_cluster_is_rtl(clusters[index])
    let start = index
    index = index + 1
    while index < clusters.length() &&
          sun_text_cluster_is_rtl(clusters[index]) == rtl {
      index = index + 1
    }
    if rtl {
      let mut cursor = index
      while cursor > start {
        cursor = cursor - 1
        visual.push(clusters[cursor])
      }
    } else {
      for cursor in start..<index {
        visual.push(clusters[cursor])
      }
    }
  }
  visual
}

///|
fn sun_text_cluster_is_rtl(cluster : String) -> Bool {
  let representative = @render.representative_fallback_codepoint(
    cluster,
    skip_joiners=true,
  )
  sun_codepoint_is_hebrew_script(representative) ||
  sun_codepoint_is_arabic_script(representative)
}

///|
fn sun_text_segment_count(clusters : Array[String]) -> Int {
  if clusters.is_empty() {
    return 0
  }
  let mut count = 0
  let mut current_class = -1
  for cluster in clusters {
    let cluster_class = sun_text_segment_class(cluster)
    if count == 0 || cluster_class != current_class {
      count = count + 1
      current_class = cluster_class
    }
  }
  count
}

///|
fn sun_text_segment_class(cluster : String) -> Int {
  let representative = @render.representative_fallback_codepoint(
    cluster,
    skip_joiners=true,
  )
  if @render.codepoint_is_emoji_hint(representative) {
    1
  } else if @render.codepoint_is_cjk_ideograph(representative) ||
    @render.codepoint_is_kana(representative) {
    2
  } else if @render.codepoint_is_hangul_cluster_codepoint(representative) {
    3
  } else if sun_codepoint_is_hebrew_script(representative) ||
    sun_codepoint_is_arabic_script(representative) {
    4
  } else if representative < 0x0300 {
    0
  } else {
    5
  }
}

///|
fn sun_text_join_clusters(clusters : Array[String]) -> String {
  let chars : Array[Char] = []
  for cluster in clusters {
    for ch in cluster {
      chars.push(ch)
    }
  }
  String::from_array(chars)
}

///|
fn sun_text_cluster_arrays_equal(
  left : Array[String],
  right : Array[String],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
fn sun_stabilize_grapheme_cluster_caret_rects(
  text : String,
  caret_rects : Array[@core.Rect],
) -> Array[@core.Rect] {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let stabilized = caret_rects.copy()
  for index in 0..<stabilized.length() {
    let nearest = boundaries.nearest_boundary(index)
    if nearest >= 0 && nearest < caret_rects.length() {
      stabilized[index] = caret_rects[nearest]
    }
  }
  stabilized
}

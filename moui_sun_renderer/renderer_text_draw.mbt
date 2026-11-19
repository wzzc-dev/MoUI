///|
fn SunRasterRenderer::draw_text_placeholder(
  self : SunRasterRenderer,
  run : @core.TextRun,
  opacity : Double,
) -> Unit {
  guard run.frame.size.width > 0.0 && run.frame.size.height > 0.0 else {
    return
  }
  guard run.text.length() > 0 else { return }
  let font_size = sun_text_placeholder_font_size(run.font.size)
  let unit = (font_size / 7.0).max(1.0)
  let advance = unit * 6.0
  let line_height = (font_size * 1.2).max(unit * 8.0)
  let paint = sun_paint(run.color, opacity)
  let lines = sun_text_placeholder_lines(run.text)
  let mut line_index = 0
  for line in lines {
    let line_top = run.frame.origin.y +
      line_index.to_double() * line_height +
      (line_height - unit * 7.0).max(0.0) * 0.5
    guard line_top < run.frame.origin.y + run.frame.size.height else { return }
    let line_width = line.length().to_double() * advance
    let start_x = sun_text_placeholder_start_x(run, line_width)
    self.draw_text_placeholder_line(
      line,
      start_x,
      line_top,
      unit,
      advance,
      run.frame,
      paint,
    )
    line_index = line_index + 1
  }
}

///|
fn SunRasterRenderer::draw_text_placeholder_line(
  self : SunRasterRenderer,
  line : Array[Char],
  start_x : Double,
  top : Double,
  unit : Double,
  advance : Double,
  frame : @core.Rect,
  paint : @sun_graphics.Paint,
) -> Unit {
  let left = frame.origin.x
  let top_bound = frame.origin.y
  let right = frame.origin.x + frame.size.width
  let bottom = frame.origin.y + frame.size.height
  let mut cursor_x = start_x
  for ch in line {
    if cursor_x >= right {
      return
    }
    let glyph = sun_debug_glyph_rows(ch)
    for row in 0..<glyph.length() {
      let row_bits = glyph[row]
      for col in 0..<5 {
        if row_bits.land(1 << (4 - col)) != 0 {
          let cell_x = cursor_x + col.to_double() * unit
          let cell_y = top + row.to_double() * unit
          let draw_left = cell_x.max(left)
          let draw_top = cell_y.max(top_bound)
          let draw_right = (cell_x + unit).min(right)
          let draw_bottom = (cell_y + unit).min(bottom)
          if draw_left < draw_right && draw_top < draw_bottom {
            self.canvas.fill_rect(
              draw_left,
              draw_top,
              draw_right - draw_left,
              draw_bottom - draw_top,
              paint,
            )
          }
        }
      }
    }
    cursor_x = cursor_x + advance
  }
}

///|
fn sun_text_placeholder_font_size(size : Double) -> Double {
  guard size == size && size > 0.0 else { return 12.0 }
  size.max(6.0).min(96.0)
}

///|
fn sun_text_placeholder_start_x(
  run : @core.TextRun,
  line_width : Double,
) -> Double {
  match run.align {
    TextStart => run.frame.origin.x
    TextCenter => run.frame.origin.x + (run.frame.size.width - line_width) * 0.5
    TextEnd => run.frame.origin.x + run.frame.size.width - line_width
  }
}

///|
fn sun_text_placeholder_lines(text : String) -> Array[Array[Char]] {
  let lines : Array[Array[Char]] = []
  let current : Array[Char] = []
  for ch in text {
    if ch.to_int() == 10 {
      lines.push(current.copy())
      current.clear()
    } else {
      current.push(ch)
    }
  }
  lines.push(current.copy())
  lines
}

///|
fn sun_debug_glyph_rows(ch : Char) -> Array[Int32] {
  let code = ch.to_int()
  let normalized = if code >= 97 && code <= 122 { code - 32 } else { code }
  match normalized {
    32 | 9 => [0, 0, 0, 0, 0, 0, 0]
    33 => [4, 4, 4, 4, 4, 0, 4]
    34 => [10, 10, 10, 0, 0, 0, 0]
    35 => [10, 31, 10, 10, 31, 10, 0]
    36 => [4, 15, 20, 14, 5, 30, 4]
    37 => [24, 25, 2, 4, 8, 19, 3]
    38 => [12, 18, 20, 8, 21, 18, 13]
    39 => [4, 4, 8, 0, 0, 0, 0]
    40 => [2, 4, 8, 8, 8, 4, 2]
    41 => [8, 4, 2, 2, 2, 4, 8]
    42 => [0, 4, 21, 14, 21, 4, 0]
    43 => [0, 4, 4, 31, 4, 4, 0]
    44 => [0, 0, 0, 0, 4, 4, 8]
    45 => [0, 0, 0, 31, 0, 0, 0]
    46 => [0, 0, 0, 0, 0, 12, 12]
    47 => [1, 2, 4, 8, 16, 0, 0]
    48 => [14, 17, 19, 21, 25, 17, 14]
    49 => [4, 12, 4, 4, 4, 4, 14]
    50 => [14, 17, 1, 2, 4, 8, 31]
    51 => [30, 1, 1, 14, 1, 1, 30]
    52 => [2, 6, 10, 18, 31, 2, 2]
    53 => [31, 16, 30, 1, 1, 17, 14]
    54 => [6, 8, 16, 30, 17, 17, 14]
    55 => [31, 1, 2, 4, 8, 8, 8]
    56 => [14, 17, 17, 14, 17, 17, 14]
    57 => [14, 17, 17, 15, 1, 2, 12]
    58 => [0, 12, 12, 0, 12, 12, 0]
    59 => [0, 12, 12, 0, 4, 4, 8]
    60 => [2, 4, 8, 16, 8, 4, 2]
    61 => [0, 0, 31, 0, 31, 0, 0]
    62 => [8, 4, 2, 1, 2, 4, 8]
    63 => [14, 17, 1, 2, 4, 0, 4]
    64 => [14, 17, 23, 21, 23, 16, 14]
    65 => [14, 17, 17, 31, 17, 17, 17]
    66 => [30, 17, 17, 30, 17, 17, 30]
    67 => [14, 17, 16, 16, 16, 17, 14]
    68 => [30, 17, 17, 17, 17, 17, 30]
    69 => [31, 16, 16, 30, 16, 16, 31]
    70 => [31, 16, 16, 30, 16, 16, 16]
    71 => [14, 17, 16, 23, 17, 17, 15]
    72 => [17, 17, 17, 31, 17, 17, 17]
    73 => [14, 4, 4, 4, 4, 4, 14]
    74 => [7, 2, 2, 2, 18, 18, 12]
    75 => [17, 18, 20, 24, 20, 18, 17]
    76 => [16, 16, 16, 16, 16, 16, 31]
    77 => [17, 27, 21, 21, 17, 17, 17]
    78 => [17, 25, 21, 19, 17, 17, 17]
    79 => [14, 17, 17, 17, 17, 17, 14]
    80 => [30, 17, 17, 30, 16, 16, 16]
    81 => [14, 17, 17, 17, 21, 18, 13]
    82 => [30, 17, 17, 30, 20, 18, 17]
    83 => [15, 16, 16, 14, 1, 1, 30]
    84 => [31, 4, 4, 4, 4, 4, 4]
    85 => [17, 17, 17, 17, 17, 17, 14]
    86 => [17, 17, 17, 17, 17, 10, 4]
    87 => [17, 17, 17, 21, 21, 21, 10]
    88 => [17, 17, 10, 4, 10, 17, 17]
    89 => [17, 17, 10, 4, 4, 4, 4]
    90 => [31, 1, 2, 4, 8, 16, 31]
    91 => [14, 8, 8, 8, 8, 8, 14]
    92 => [16, 8, 4, 2, 1, 0, 0]
    93 => [14, 2, 2, 2, 2, 2, 14]
    94 => [4, 10, 17, 0, 0, 0, 0]
    95 => [0, 0, 0, 0, 0, 0, 31]
    96 => [8, 4, 2, 0, 0, 0, 0]
    123 => [2, 4, 4, 8, 4, 4, 2]
    124 => [4, 4, 4, 0, 4, 4, 4]
    125 => [8, 4, 4, 2, 4, 4, 8]
    126 => [0, 8, 21, 2, 0, 0, 0]
    _ => [31, 17, 21, 17, 21, 17, 31]
  }
}

///|
fn SunRasterRenderer::draw_text(
  self : SunRasterRenderer,
  run : @core.TextRun,
  opacity : Double,
) -> Unit {
  guard run.frame.size.width > 0.0 && run.frame.size.height > 0.0 else {
    return
  }
  // No registered face: the placeholder draws in the run's coordinate space
  // and the canvas transform applies once. Transforming the run first would
  // scale it a second time and push the glyphs off the frame.
  if self.resolved_faces(run.font).is_empty() {
    self.draw_text_placeholder(run, opacity)
    return
  }
  let device_run = sun_transformed_text_run(self.canvas.get_transform(), run)
  self.canvas.save()
  self.canvas.intersect_clip_rect(
    @sun_graphics.Rect::new(
      x=device_run.frame.origin.x,
      y=device_run.frame.origin.y,
      width=device_run.frame.size.width,
      height=device_run.frame.size.height,
    ),
  )
  self.draw_text_clipped(device_run, opacity)
  ignore(self.canvas.restore())
}

///|
fn sun_transformed_text_run(
  transform : @sun_graphics.Transform,
  run : @core.TextRun,
) -> @core.TextRun {
  let frame = sun_core_rect_from_sun_rect(
    sun_transformed_rect_bounds(transform, run.frame),
  )
  let font_scale = sun_text_transform_font_scale(transform)
  @core.TextRun::new(
    text=run.text,
    frame~,
    font=@core.FontSpec::new(
      families=run.font.families,
      size=run.font.size * font_scale,
      weight=run.font.weight,
      style=run.font.style,
      line_height?=run.font.line_height.map(value => value * font_scale),
      letter_spacing?=run.font.letter_spacing.map(value => value * font_scale),
      features=run.font.features,
    ),
    color=run.color,
    align=run.align,
  )
}

///|
fn sun_core_rect_from_sun_rect(rect : @sun_graphics.Rect) -> @core.Rect {
  @core.Rect::new(x=rect.x, y=rect.y, width=rect.width, height=rect.height)
}

///|
fn sun_text_transform_font_scale(transform : @sun_graphics.Transform) -> Double {
  let (origin_x, origin_y) = transform.apply(0.0, 0.0)
  let (vertical_x, vertical_y) = transform.apply(0.0, 1.0)
  let dx = vertical_x - origin_x
  let dy = vertical_y - origin_y
  let scale = (dx * dx + dy * dy).sqrt()
  if scale > 0.0 {
    scale
  } else {
    1.0
  }
}

///|
fn SunRasterRenderer::draw_text_clipped(
  self : SunRasterRenderer,
  run : @core.TextRun,
  opacity : Double,
) -> Unit {
  let config = sun_text_layout_config(run.font, run.frame.size.width)
  let faces = self.resolved_faces(run.font)
  guard !faces.is_empty() else {
    self.draw_text_placeholder(run, opacity)
    return
  }
  let plan = sun_text_line_plan(faces, run.text, config)
  guard !plan.lines.is_empty() else { return }
  let paint = sun_paint(run.color, opacity)
  let line_height = plan.line_height
  // A single line is centred in its frame with the face ascent/descent box,
  // which is exactly what Skia's renderer uses; the nominal `size * 1.2` line
  // height floated every label ~1 logical px above Skia's baseline in the same
  // frame. Multi-line runs keep the configured pitch, the same geometry the
  // paragraph layout reports and paints.
  let total_height = if plan.lines.length() <= 1 {
    sun_text_metric_span(faces, config)
  } else {
    line_height * plan.lines.length().to_double()
  }
  let origin_y = run.frame.origin.y +
    (run.frame.size.height - total_height).max(0.0) * 0.5
  let renderer = @sun_renderer.Renderer::new(self.canvas)
  let mut line_index = 0
  for line in plan.lines {
    // The fallback line API takes the line-box top and adds the face baseline
    // itself; passing a baseline here shifted every line down by its ascent.
    let line_top_y = origin_y + line_index.to_double() * line_height
    if line_top_y > run.frame.origin.y + run.frame.size.height {
      return
    }
    let x = sun_text_placeholder_start_x(run, line.width)
    let key = sun_text_cache_key(run, line_index, line.text)
    let result = renderer.draw_text_fallback_line_cached_with_renderer_resources(
      faces,
      line.text,
      x,
      line_top_y,
      config,
      self.resources,
      key,
      paint,
    )
    if result.get_plan().has_missing_glyphs() {
      self.record_unsupported_command(
        "DrawText",
        "Sun renderer fell back to placeholder glyphs for missing fallback spans in text: \{run.text}",
      )
      self.draw_text_placeholder(
        @core.TextRun::new(
          text=line.text,
          frame=@core.Rect::new(
            x~,
            y=origin_y + line_index.to_double() * line_height,
            width=run.frame.size.width,
            height=line_height,
          ),
          font=run.font,
          color=run.color,
          align=TextStart,
        ),
        opacity,
      )
    }
    line_index += 1
  }
}

///|
fn sun_text_layout_config(
  font : @core.FontSpec,
  max_width : Double,
) -> @sun_text.LayoutConfig {
  @sun_text.LayoutConfig::new(
    max_width=max_width.max(0.0),
    font_size=font.size,
    line_height=font.line_height.unwrap_or((font.size * 1.2).max(1.0)),
    alignment=Left,
    letter_spacing=font.letter_spacing.unwrap_or(0.0),
  )
}

///|
fn SunRasterRenderer::measure_text_layout(
  self : SunRasterRenderer,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let faces = self.resolved_faces(input.font)
  if faces.is_empty() {
    return @core.TextSystem::fallback().measure_text(input)
  }
  let config = sun_text_layout_config(
    input.font,
    input.max_width.unwrap_or(1000000000.0),
  )
  let plan = sun_text_line_plan(faces, input.text, config)
  let carets : Array[Double] = []
  let chars = input.text.to_array()
  for _ in 0..<(chars.length() + 1) {
    carets.push(0.0)
  }
  let mut max_width = 0.0
  let mut baseline = 0.0
  for line_index in 0..<plan.lines.length() {
    let line = plan.lines[line_index]
    let measured = self.measure_single_line_text(faces, line.text, config)
    if line_index == 0 {
      baseline = measured.baseline
    }
    let line_carets = measured.caret_positions
    for line_offset in 0..<(line.scalar_count + 1) {
      let global = line.start_scalar + line_offset
      if global < carets.length() && line_offset < line_carets.length() {
        carets[global] = line_carets[line_offset]
      }
    }
    max_width = max_width.max(line.width.max(measured.size.width))
  }
  let stabilized = @core.fallback_stabilize_grapheme_cluster_carets(
    input.text,
    carets,
  )
  let result : @core.TextLayoutResult = {
    size: @core.Size::new(
      width=max_width.min(input.max_width.unwrap_or(max_width)),
      height=if plan.lines.length() <= 1 {
        sun_text_metric_span(faces, config)
      } else {
        plan.line_height * plan.lines.length().to_double()
      },
    ),
    baseline,
    caret_positions: stabilized,
  }
  result
}

///|
fn SunRasterRenderer::measure_single_line_text(
  self : SunRasterRenderer,
  faces : Array[@sun_text.FontFace],
  text : String,
  config : @sun_text.LayoutConfig,
) -> @core.TextLayoutResult {
  ignore(self)
  if text == "" {
    return {
      size: @core.Size::new(
        width=0.0,
        height=sun_text_metric_span(faces, config),
      ),
      baseline: sun_text_baseline_for_faces(faces, config),
      caret_positions: [0.0],
    }
  }
  let fallback = @sun_text.plan_font_fallback(faces, text)
  let carets : Array[Double] = [0.0]
  let mut width = 0.0
  let mut emitted_scalars = 0
  for span in fallback.get_spans() {
    let span_width = if span.is_missing() {
      sun_measure_missing_span_width(span.get_text(), config)
    } else {
      @sun_text.TextLayout::layout(
        faces[span.get_face_index()],
        span.get_text(),
        config,
      ).get_width()
    }
    let per_scalar = if span.get_char_count() > 0 {
      span_width / span.get_char_count().to_double()
    } else {
      0.0
    }
    for _ in 0..<span.get_char_count() {
      emitted_scalars += 1
      width += per_scalar
      if emitted_scalars > 0 {
        carets.push(width)
      }
    }
  }
  while carets.length() < text.to_array().length() + 1 {
    carets.push(width)
  }
  {
    size: @core.Size::new(width~, height=config.line_height),
    baseline: sun_text_baseline_for_faces(faces, config),
    caret_positions: carets,
  }
}

///|
fn sun_measure_fallback_line_width(
  faces : Array[@sun_text.FontFace],
  text : String,
  config : @sun_text.LayoutConfig,
) -> Double {
  let result = sun_measure_single_line_text_like(text, faces, config)
  result
}

///|
fn sun_measure_single_line_text_like(
  text : String,
  faces : Array[@sun_text.FontFace],
  config : @sun_text.LayoutConfig,
) -> Double {
  if text == "" {
    return 0.0
  }
  let plan = @sun_text.plan_font_fallback(faces, text)
  let mut width = 0.0
  let mut emitted_scalars = 0
  for span in plan.get_spans() {
    if emitted_scalars > 0 {
      width += config.letter_spacing
    }
    let span_width = if span.is_missing() {
      sun_measure_missing_span_width(span.get_text(), config)
    } else {
      @sun_text.TextLayout::layout(
        faces[span.get_face_index()],
        span.get_text(),
        config,
      ).get_width()
    }
    width += span_width
    emitted_scalars += span.get_char_count()
  }
  width
}

///|
fn sun_measure_missing_span_width(
  text : String,
  config : @sun_text.LayoutConfig,
) -> Double {
  let scalar_count = text.to_array().length()
  if scalar_count <= 0 {
    0.0
  } else {
    config.font_size * 0.6 * scalar_count.to_double()
  }
}

///|
fn sun_text_baseline_for_faces(
  faces : Array[@sun_text.FontFace],
  config : @sun_text.LayoutConfig,
) -> Double {
  if faces.is_empty() {
    return config.font_size * 0.8
  }
  let units = faces[0].get_units_per_em().to_double()
  if units <= 0.0 {
    config.font_size * 0.8
  } else {
    faces[0].get_metrics().ascent.to_double() * config.font_size / units
  }
}

///|
/// Face metric span (`ascent - descent + line_gap`) at `config.font_size`.
///
/// Skia both measures a run and places it in its frame with the face's
/// ascent/descent box, and only falls back to `size * 1.25` when the face
/// metrics are unusable. Sun's configured `line_height` stays the pitch between
/// wrapped lines; it is not the box a single line is centred in.
fn sun_text_metric_span(
  faces : Array[@sun_text.FontFace],
  config : @sun_text.LayoutConfig,
) -> Double {
  let fallback = (config.font_size * 1.25).max(1.0)
  guard !faces.is_empty() else { return fallback }
  let units = faces[0].get_units_per_em().to_double()
  guard units > 0.0 else { return fallback }
  let metrics = faces[0].get_metrics()
  let ascent = metrics.ascent.to_double()
  let descent = metrics.descent.to_double()
  let line_gap = metrics.line_gap.to_double()
  let scale = config.font_size / units
  let span = (ascent - descent + line_gap).max(ascent - descent).max(0.0) *
    scale
  span.max(ascent * scale).max(1.0)
}

///|
fn sun_text_cache_key(
  run : @core.TextRun,
  line_index : Int32,
  text : String,
) -> String {
  "sun:text:" +
  line_index.to_string() +
  ":" +
  run.font.size.to_string() +
  ":" +
  run.color.to_json().stringify() +
  ":" +
  text
}

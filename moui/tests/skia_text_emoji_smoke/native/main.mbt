///|
fn fail_smoke(message : String) -> Unit {
  println(message)
  abort("MoUI Skia text/emoji smoke failed")
}

///|
fn pixel_offset(frame : @skia_renderer.SkiaPixelFrame, x : Int, y : Int) -> Int {
  y * frame.row_bytes + x * 4
}

///|
fn rect_min_x(rect : @core.Rect) -> Int {
  rect.origin.x.floor().to_int().max(0)
}

///|
fn rect_min_y(rect : @core.Rect) -> Int {
  rect.origin.y.floor().to_int().max(0)
}

///|
fn rect_max_x(frame : @skia_renderer.SkiaPixelFrame, rect : @core.Rect) -> Int {
  (rect.origin.x + rect.size.width).ceil().to_int().min(frame.width)
}

///|
fn rect_max_y(frame : @skia_renderer.SkiaPixelFrame, rect : @core.Rect) -> Int {
  (rect.origin.y + rect.size.height).ceil().to_int().min(frame.height)
}

///|
fn rect_high_saturation_pixels(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
) -> Int {
  let mut count = 0
  for y in rect_min_y(rect)..<rect_max_y(frame, rect) {
    for x in rect_min_x(rect)..<rect_max_x(frame, rect) {
      let offset = pixel_offset(frame, x, y)
      if offset + 3 < frame.pixels.length() {
        let r = frame.pixels[offset].to_int()
        let g = frame.pixels[offset + 1].to_int()
        let b = frame.pixels[offset + 2].to_int()
        let a = frame.pixels[offset + 3].to_int()
        if a >= 160 {
          let max_channel = r.max(g).max(b)
          let min_channel = r.min(g).min(b)
          if max_channel >= 140 && max_channel - min_channel >= 64 {
            count = count + 1
          }
        }
      }
    }
  }
  count
}

///|
fn rect_alpha_pixels(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
) -> Int {
  let mut count = 0
  for y in rect_min_y(rect)..<rect_max_y(frame, rect) {
    for x in rect_min_x(rect)..<rect_max_x(frame, rect) {
      let offset = pixel_offset(frame, x, y)
      if offset + 3 < frame.pixels.length() {
        let a = frame.pixels[offset + 3].to_int()
        if a >= 160 {
          count = count + 1
        }
      }
    }
  }
  count
}

///|
fn row_seen(rows : Array[Int], row : Int) -> Bool {
  rows.any(value => value == row)
}

///|
fn rect_dark_rows(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
) -> Int {
  let rows : Array[Int] = []
  for y in rect_min_y(rect)..<rect_max_y(frame, rect) {
    for x in rect_min_x(rect)..<rect_max_x(frame, rect) {
      let offset = pixel_offset(frame, x, y)
      if offset + 3 < frame.pixels.length() {
        let r = frame.pixels[offset].to_int()
        let g = frame.pixels[offset + 1].to_int()
        let b = frame.pixels[offset + 2].to_int()
        let a = frame.pixels[offset + 3].to_int()
        if a >= 160 && r <= 80 && g <= 80 && b <= 80 && !row_seen(rows, y) {
          rows.push(y)
        }
      }
    }
  }
  rows.length()
}

///|
fn rect_blue_pixels(
  frame : @skia_renderer.SkiaPixelFrame,
  rect : @core.Rect,
) -> Int {
  let mut count = 0
  for y in rect_min_y(rect)..<rect_max_y(frame, rect) {
    for x in rect_min_x(rect)..<rect_max_x(frame, rect) {
      let offset = pixel_offset(frame, x, y)
      if offset + 3 < frame.pixels.length() {
        let r = frame.pixels[offset].to_int()
        let g = frame.pixels[offset + 1].to_int()
        let b = frame.pixels[offset + 2].to_int()
        let a = frame.pixels[offset + 3].to_int()
        if a >= 160 && b >= 120 && b - r >= 48 && b - g >= 48 {
          count = count + 1
        }
      }
    }
  }
  count
}

///|
fn int_array_equals(left : Array[Int], right : Array[Int]) -> Bool {
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
struct SkiaParagraphSmokeLine {
  text : String
  frame : @core.Rect
  line_index : Int
  baseline : Double
  measured_width : Double
}

///|
fn paragraph_font() -> @core.FontSpec {
  @core.FontSpec::new(size=18.0, weight=500)
}

///|
fn paragraph_text() -> String {
  "Smoke wrap line alpha beta gamma delta epsilon zeta"
}

///|
fn emoji_diagnostic_text() -> String {
  "\u{1F469}\u{200D}\u{1F4BB}"
}

///|
fn emoji_diagnostic_font() -> @core.FontSpec {
  @core.FontSpec::new(
    families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
    size=32.0,
    weight=400,
  )
}

///|
fn skia_color_emoji_glyph_key_metadata_ready(
  fallback : @skia_renderer.SkiaEmojiFontFallbackDiagnostic,
) -> Bool {
  let language_tags_key = fallback.fallback_language_tags.join("+")
  fallback.glyph_key.contains(fallback.font_source) &&
  fallback.glyph_key.contains(fallback.text_system_id) &&
  fallback.glyph_key.contains(fallback.shaper) &&
  fallback.glyph_key.contains("script=\{fallback.fallback_script_tag}") &&
  fallback.glyph_key.contains("langs=\{fallback.fallback_request_language_count}") &&
  fallback.glyph_key.contains("lang-tags=\{language_tags_key}") &&
  fallback.glyph_key.contains("emoji-u+\{fallback.fallback_character}") &&
  fallback.glyph_key.contains(fallback.glyph_format)
}

///|
fn skia_color_emoji_fallback_language_metadata_ready(
  fallback : @skia_renderer.SkiaEmojiFontFallbackDiagnostic,
) -> Bool {
  fallback.fallback_language_tags.length() == fallback.fallback_language_tag_count &&
  fallback.fallback_language_tag_count >= 1 &&
  fallback.fallback_request_language_count == fallback.fallback_language_tag_count &&
  fallback.fallback_language_tags[0] == fallback.fallback_script_tag
}

///|
fn skia_color_emoji_diagnostic_metadata_ready(
  fallback : @skia_renderer.SkiaEmojiFontFallbackDiagnostic,
  high_saturation_pixels : Int,
  alpha_pixels : Int,
) -> Bool {
  fallback.font_family != "" &&
  fallback.font_family != "unknown" &&
  fallback.font_source != "" &&
  fallback.font_source != "unknown" &&
  fallback.text_system_id != "" &&
  fallback.text_system_id != "unknown" &&
  fallback.shaper != "" &&
  fallback.shaper != "unknown" &&
  fallback.emoji_hint &&
  fallback.fallback_request_ready &&
  fallback.missing_glyph_recovery_ready &&
  fallback.fallback_script_tag != "" &&
  skia_color_emoji_fallback_language_metadata_ready(fallback) &&
  fallback.glyph_format == "rgba" &&
  fallback.glyph_count >= 1 &&
  fallback.cluster_count >= 1 &&
  fallback.glyph_width > 0 &&
  fallback.glyph_height > 0 &&
  fallback.resolved_missing_glyph_count >= 0 &&
  high_saturation_pixels >= 8 &&
  alpha_pixels > 0 &&
  skia_color_emoji_glyph_key_metadata_ready(fallback)
}

///|
fn smoke_text_field_view(value : @core.Binding[String]) -> @core.View[Unit] {
  @core.View::text_field(
    value~,
    placeholder="Input",
    size=@core.Size::new(width=168.0, height=44.0),
    font=@core.FontSpec::new(size=18.0, weight=500),
    foreground=@core.Color::black(),
    placeholder_color=@core.Color::gray(),
    background=@core.Brush::solid(@core.Color::white()),
    cursor_color=@core.Color::blue(),
    corner_radius=4.0,
  )
}

///|
fn focus_smoke_text_field(runtime : @core.AppRuntime) -> Unit {
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=12.0, y=12.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
}

///|
fn commands_with_clear(
  commands : Array[@core.DrawCommand],
) -> Array[@core.DrawCommand] {
  let result : Array[@core.DrawCommand] = [
    @core.DrawCommand::Clear(@core.Color::white()),
  ]
  for command in commands {
    result.push(command)
  }
  result
}

///|
fn skia_paragraph_diagnostic_lines(
  layout : @core.TextParagraphLayoutResult,
) -> Array[SkiaParagraphSmokeLine] {
  let max_width = 96.0
  let start_x = 8.0
  let start_y = 94.0
  println(
    "MoUI Skia text/emoji smoke paragraph layout text_system=\{layout.metadata.text_system_id} engine=\{if layout.metadata.native_paragraph_ready { "skparagraph" } else { "fallback" }} lines=\{layout.line_count()} native_paragraph_ready=\{layout.metadata.native_paragraph_ready} bidi_visual_order_ready=\{layout.metadata.bidi_visual_order_ready}",
  )
  let lines : Array[SkiaParagraphSmokeLine] = []
  let chars = paragraph_text().to_array()
  for line in layout.lines {
    let line_text = String::from_array(
      chars[line.text_range.start:line.text_range.end],
    )
    let y = start_y + line.origin.y
    let frame = @core.Rect::new(
      x=start_x,
      y~,
      width=max_width,
      height=line.size.height,
    )
    lines.push({
      text: line_text,
      frame,
      line_index: line.line_index,
      baseline: start_y + line.baseline,
      measured_width: line.size.width,
    })
  }
  lines
}

///|
fn skia_paragraph_layout(
  system : @core.TextSystem,
) -> @core.TextParagraphLayoutResult {
  system.layout_paragraph(
    @core.TextLayoutInput::new(
      text=paragraph_text(),
      font=paragraph_font(),
      max_width=96.0,
    ),
  )
}

///|
fn selection_rect_has_geometry(rect : @core.Rect) -> Bool {
  rect.size.width > 0.0 && rect.size.height > 0.0
}

///|
fn selection_rect_overlaps_line(
  rect : @core.Rect,
  line : @core.TextParagraphLineMetrics,
) -> Bool {
  let rect_bottom = rect.origin.y + rect.size.height
  let line_bottom = line.origin.y + line.size.height
  rect.origin.y < line_bottom && rect_bottom > line.origin.y
}

///|
fn selection_rect_geometry_observation_available(
  rects : Array[@core.Rect],
  first_line : @core.TextParagraphLineMetrics,
  second_line : @core.TextParagraphLineMetrics,
) -> Bool {
  if rects.length() < 2 {
    return false
  }
  let mut covers_first_line = false
  let mut covers_second_line = false
  for rect in rects {
    if !selection_rect_has_geometry(rect) {
      return false
    }
    if selection_rect_overlaps_line(rect, first_line) {
      covers_first_line = true
    }
    if selection_rect_overlaps_line(rect, second_line) {
      covers_second_line = true
    }
  }
  covers_first_line && covers_second_line
}

///|
fn selection_rect_observation_available(
  layout : @core.TextParagraphLayoutResult,
) -> Bool {
  if !layout.metadata.native_paragraph_ready ||
    !layout.metadata.selection_rects_available ||
    !layout.metadata.hit_test_available ||
    layout.lines.length() < 2 {
    return false
  }
  let selection = @core.TextRange::new(
    start=layout.lines[0].text_range.start,
    end=layout.lines[1].text_range.end,
  )
  let rects = layout.selection_rects(selection)
  let hit = layout.hit_test(
    @core.Point::new(
      x=(layout.lines[1].origin.x + layout.lines[1].size.width * 0.5).min(
        layout.size.width,
      ),
      y=layout.lines[1].origin.y + layout.lines[1].size.height * 0.5,
    ),
  )
  let rect_geometry = selection_rect_geometry_observation_available(
    rects,
    layout.lines[0],
    layout.lines[1],
  )
  println(
    "MoUI Skia text/emoji smoke selection engine=skparagraph selection_rects_available=\{layout.metadata.selection_rects_available} hit_test_available=\{layout.metadata.hit_test_available} hit_inside=\{hit.is_inside} rect_count=\{rects.length()} rect_geometry=\{rect_geometry} line_range=\{layout.lines[0].line_index}..\{layout.lines[1].line_index} hit_line=\{hit.line_index} hit_offset=\{hit.offset}",
  )
  rects.length() >= 2 &&
  rect_geometry &&
  hit.is_inside &&
  hit.line_index == layout.lines[1].line_index &&
  hit.offset >= layout.lines[1].text_range.start &&
  hit.offset <= layout.lines[1].text_range.end
}

///|
fn grapheme_editing_observation_available() -> Bool {
  let text = "A\u{1F469}\u{200D}\u{1F4BB}B"
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let boundary_indexes = boundaries.boundaries()
  let delete_previous = boundaries.delete_range(4, 1, 0)
  let normalized_selection = boundaries.normalize_range(
    @core.TextRange::new(start=2, end=3),
  )
  let utf8_offset = boundaries.utf8_offset(4)
  println(
    "MoUI Skia text/emoji smoke grapheme boundaries=\{boundary_indexes.length()} clusters=\{boundaries.cluster_count()} delete=\{delete_previous.start}..\{delete_previous.end} normalized=\{normalized_selection.start}..\{normalized_selection.end} utf8_offset=\{utf8_offset}",
  )
  int_array_equals(boundary_indexes, [0, 1, 4, 5]) &&
  boundaries.previous_boundary(4) == 1 &&
  boundaries.next_boundary(1) == 4 &&
  delete_previous.start == 1 &&
  delete_previous.end == 4 &&
  normalized_selection.start == 1 &&
  normalized_selection.end == 4 &&
  utf8_offset == 12
}

///|
fn ime_candidate_anchor_observation_available(
  text_system : @core.TextSystem,
) -> Bool {
  let value = @core.State::new("A\u{1F469}\u{200D}\u{1F4BB}B")
  let runtime = @core.AppRuntime::new_view(
    root=smoke_text_field_view(value.binding()),
    size=@core.Size::new(width=176.0, height=64.0),
  )
  runtime.set_text_system(text_system)
  focus_smoke_text_field(runtime)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let input = runtime.focused_text_input()
  let diagnostics = @host.text_input_ime_request_diagnostics(input)
  println(
    "MoUI Skia text/emoji smoke ime anchor cursor=\{diagnostics.cursor} cursor_utf8=\{diagnostics.cursor_utf8} anchor_utf8=\{diagnostics.anchor_utf8} cursor_grapheme_boundary=\{diagnostics.cursor_is_grapheme_boundary} anchor_grapheme_boundary=\{diagnostics.anchor_is_grapheme_boundary} candidate_x=\{diagnostics.candidate_anchor.origin.x} candidate_y=\{diagnostics.candidate_anchor.origin.y} surrounding_utf8=\{diagnostics.surrounding_text_utf8_length}",
  )
  input.focused &&
  diagnostics.cursor_is_grapheme_boundary &&
  diagnostics.anchor_is_grapheme_boundary &&
  diagnostics.has_surrounding_text &&
  diagnostics.cursor == 5 &&
  diagnostics.cursor_utf8 == 13 &&
  diagnostics.anchor_utf8 == 13 &&
  diagnostics.candidate_anchor.size.width >= 1.0 &&
  diagnostics.candidate_anchor.size.height >= 1.0 &&
  diagnostics.candidate_anchor.origin.x > input.frame.origin.x
}

///|
fn ime_composition_visual_observation_available(
  renderer : @skia_renderer.SkiaRasterRenderer,
  text_system : @core.TextSystem,
) -> Bool {
  let value = @core.State::new("x")
  let runtime = @core.AppRuntime::new_view(
    root=smoke_text_field_view(value.binding()),
    size=@core.Size::new(width=176.0, height=64.0),
  )
  runtime.set_text_system(text_system)
  focus_smoke_text_field(runtime)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::CompositionStart),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::CompositionUpdate(
        @core.CompositionUpdate::new(
          text="你🙂a",
          cursor=Some(@core.TextRange::new(start=2, end=2)),
        ),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  guard input.composition is Some(composition) else { return false }
  guard input.composition_cursor is Some(composition_cursor) else {
    return false
  }
  renderer.render(commands_with_clear(runtime.draw_commands())) catch {
    err => {
      println(
        "MoUI Skia text/emoji smoke composition render failed: \{err.message()}",
      )
      return false
    }
  }
  match renderer.last_frame() {
    Some(frame) => {
      let text_rows = rect_dark_rows(frame, input.frame)
      let cursor_pixels = rect_blue_pixels(frame, input.caret_rect)
      println(
        "MoUI Skia text/emoji smoke composition text=\{composition} cursor=\{composition_cursor.start}..\{composition_cursor.end} dark_rows=\{text_rows} cursor_pixels=\{cursor_pixels}",
      )
      composition == "你🙂a" &&
      composition_cursor.start == 2 &&
      composition_cursor.end == 2 &&
      text_rows >= 4 &&
      cursor_pixels >= 4
    }
    None => false
  }
}

///|
fn skia_text_emoji_smoke_commands(
  paragraph_lines : Array[SkiaParagraphSmokeLine],
) -> Array[@core.DrawCommand] {
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=emoji_diagnostic_text(),
        frame=@core.Rect::new(x=8.0, y=8.0, width=72.0, height=44.0),
        font=emoji_diagnostic_font(),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
  ]
  for command in skia_bidi_visual_order_commands() {
    commands.push(command)
  }
  for line in paragraph_lines {
    commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text=line.text,
          frame=line.frame,
          font=paragraph_font(),
          color=@core.Color::black(),
          align=@core.TextAlign::TextStart,
        ),
      ),
    )
  }
  commands
}

///|
fn skia_bidi_visual_order_commands() -> Array[@core.DrawCommand] {
  [
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="ABC \u{05D0}\u{05D1}\u{05D2} 123",
        frame=@core.Rect::new(x=8.0, y=58.0, width=150.0, height=28.0),
        font=@core.FontSpec::new(size=20.0, weight=500),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
  ]
}

///|
fn carets_are_monotonic(carets : Array[Double]) -> Bool {
  if carets.length() <= 1 {
    return true
  }
  for index in 1..<carets.length() {
    if carets[index] < carets[index - 1] {
      return false
    }
  }
  true
}

///|
fn zwj_has_no_interior_caret(system : @core.TextSystem) -> Bool {
  let text = emoji_diagnostic_text()
  let layout = system.measure_text(
    @core.TextLayoutInput::new(text~, font=emoji_diagnostic_font()),
  )
  if layout.caret_positions.length() != text.to_array().length() + 1 ||
    !carets_are_monotonic(layout.caret_positions) {
    return false
  }
  if layout.caret_positions.length() < 4 {
    return false
  }
  let anchor = layout.caret_positions[0]
  layout.caret_positions[1] == anchor &&
  layout.caret_positions[2] == anchor &&
  layout.caret_positions[3] > anchor
}

///|
fn paragraph_wraps(lines : Array[SkiaParagraphSmokeLine]) -> Bool {
  if lines.length() < 3 {
    return false
  }
  for line in lines {
    if line.measured_width <= 0.0 ||
      line.measured_width > line.frame.size.width + 0.01 ||
      line.baseline <= line.frame.origin.y {
      return false
    }
  }
  true
}

///|
fn paragraph_later_line_pixels(
  frame : @skia_renderer.SkiaPixelFrame,
  lines : Array[SkiaParagraphSmokeLine],
) -> Bool {
  if lines.length() < 3 {
    return false
  }
  let line_1_rows = rect_dark_rows(frame, lines[1].frame)
  let line_2_rows = rect_dark_rows(frame, lines[2].frame)
  line_1_rows >= 4 && line_2_rows >= 4
}

///|
fn bidi_visual_order_observed_available(
  frame : @skia_renderer.SkiaPixelFrame,
  text_system : @core.TextSystem,
) -> Bool {
  let sample = "ABC \u{05D0}\u{05D1}\u{05D2} 123"
  let layout = text_system.layout_paragraph(
    @core.TextLayoutInput::new(
      text=sample,
      font=@core.FontSpec::new(size=20.0, weight=500),
      max_width=220.0,
    ),
  )
  println(
    "MoUI Skia text/emoji smoke bidi engine=\{if layout.metadata.native_paragraph_ready { "skparagraph" } else { "fallback" }} logical=\{layout.visual_order.logical_text} visual=\{layout.visual_order.visual_text} segments=\{layout.visual_order.segment_count} glyphs=\{layout.visual_order.glyph_count} native_paragraph_ready=\{layout.metadata.native_paragraph_ready} bidi_visual_order_ready=\{layout.metadata.bidi_visual_order_ready}",
  )
  layout.metadata.native_paragraph_ready &&
  layout.metadata.bidi_visual_order_ready &&
  layout.visual_order.visual_order_differs &&
  layout.visual_order.logical_cluster_count ==
  layout.visual_order.visual_cluster_count &&
  layout.visual_order.segment_count >= 3 &&
  layout.visual_order.glyph_count >= 6 &&
  rect_dark_rows(
    frame,
    @core.Rect::new(x=8.0, y=58.0, width=150.0, height=28.0),
  ) >=
  4
}

///|
fn main {
  if !@skia_renderer.skia_available() {
    fail_smoke(
      "real Skia backend is unavailable; configure moui_skia/native before running text/emoji smoke",
    )
  }
  println(
    "MoUI Skia text/emoji smoke shaper_available=\{@skia_native.skia_shaper_available()}",
  )

  let captured : Ref[@skia_renderer.SkiaPixelFrame?] = Ref(None)
  let target = @skia_renderer.SkiaPresentTarget::new(
    description="MoUI Skia text/emoji smoke presenter",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  let renderer_result = try
    @skia_renderer.create_with_present_target(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=176.0, height=188.0),
        scale_factor=1.0,
      ),
      target,
    )
  catch {
    err => Err(err.message())
  } noraise {
    renderer => Ok(renderer)
  }
  guard renderer_result is Ok(renderer) else {
    fail_smoke("failed to create MoUI Skia text/emoji smoke renderer")
  }

  let paragraph_layout = skia_paragraph_layout(renderer.text_system())
  let paragraph_lines = skia_paragraph_diagnostic_lines(paragraph_layout)
  for line in paragraph_lines {
    println(
      "MoUI Skia text/emoji smoke paragraph line=\{line.line_index} text=\{line.text} baseline=\{line.baseline} measured_width=\{line.measured_width}",
    )
  }

  renderer.render(skia_text_emoji_smoke_commands(paragraph_lines)) catch {
    err =>
      fail_smoke(
        "failed to render MoUI Skia text/emoji smoke frame: \{err.message()}",
      )
  }

  let failures : Array[String] = []
  match captured.val {
    Some(frame) => {
      let emoji_pixels = rect_high_saturation_pixels(
        frame,
        @core.Rect::new(x=8.0, y=8.0, width=72.0, height=44.0),
      )
      let emoji_alpha_pixels = rect_alpha_pixels(
        frame,
        @core.Rect::new(x=8.0, y=8.0, width=72.0, height=44.0),
      )
      if emoji_pixels >= 8 {
        match
          @skia_renderer.skia_emoji_font_fallback_diagnostic(
            text=emoji_diagnostic_text(),
            font=emoji_diagnostic_font(),
          ) {
          Some(fallback) => {
            println(
              "MoUI Skia text/emoji smoke color emoji high_saturation_pixels=\{emoji_pixels} fallback_character=\{fallback.fallback_character} emoji_hint=\{fallback.emoji_hint} fallback_request_ready=\{fallback.fallback_request_ready}",
            )
            println(
              "MoUI renderer smoke colorEmojiPixels metadata font_family=\{fallback.font_family} font_source=\{fallback.font_source} text_system=\{fallback.text_system_id} shaper=\{fallback.shaper} glyph_format=\{fallback.glyph_format} glyph_count=\{fallback.glyph_count} cluster_count=\{fallback.cluster_count} high_saturation_pixels=\{emoji_pixels} alpha_pixels=\{emoji_alpha_pixels} glyph_key=\{fallback.glyph_key} glyph_width=\{fallback.glyph_width} glyph_height=\{fallback.glyph_height} fallback_script_tag=\{fallback.fallback_script_tag} fallback_language_tags=\{fallback.fallback_language_tags.join("+")} fallback_language_tag_count=\{fallback.fallback_language_tag_count} fallback_request_language_count=\{fallback.fallback_request_language_count} fallback_request_character=\{fallback.fallback_character} resolved_missing_glyph_count=\{fallback.resolved_missing_glyph_count} missing_glyph_recovery_ready=\{fallback.missing_glyph_recovery_ready}",
            )
            if skia_color_emoji_diagnostic_metadata_ready(
                fallback, emoji_pixels, emoji_alpha_pixels,
              ) {
              println(
                "MoUI renderer smoke colorEmojiPixels passed high-saturation-pixels glyph-or-raster font-metadata glyph-metadata fallback-request emoji-hint stable-glyph-key",
              )
            } else {
              failures.push(
                "colorEmojiPixels missing Skia emoji fallback request/glyph metadata readiness",
              )
            }
          }
          None =>
            failures.push(
              "colorEmojiPixels missing Skia emoji fallback font/glyph metadata",
            )
        }
      } else {
        failures.push(
          "colorEmojiPixels missing high-saturation Skia emoji pixels",
        )
      }

      if zwj_has_no_interior_caret(renderer.text_system()) && emoji_pixels >= 8 {
        println(
          "MoUI renderer smoke zwjGrapheme passed single-grapheme-cluster no-interior-caret",
        )
      } else {
        failures.push(
          "zwjGrapheme missing no-interior-caret plus emoji pixel observation",
        )
      }

      let paragraph_rows = rect_dark_rows(
        frame,
        @core.Rect::new(x=8.0, y=94.0, width=96.0, height=94.0),
      )
      if paragraph_layout.metadata.native_paragraph_ready &&
        paragraph_wraps(paragraph_lines) &&
        paragraph_later_line_pixels(frame, paragraph_lines) &&
        paragraph_rows >= 12 {
        println(
          "MoUI Skia text/emoji smoke paragraph dark_rows=\{paragraph_rows}",
        )
        println(
          "MoUI renderer smoke paragraphWrapping passed engine=skparagraph native_paragraph_ready=true line-metrics later-line-pixels",
        )
      } else {
        failures.push(
          "paragraphWrapping missing Skia line metrics and later-line pixels",
        )
      }

      if bidi_visual_order_observed_available(frame, renderer.text_system()) {
        println(
          "MoUI renderer smoke bidiLayout passed engine=skparagraph bidi_visual_order_ready=true visual-order",
        )
      } else {
        failures.push(
          "bidiLayout missing Skia visual-order glyph/paragraph observation",
        )
      }

      if selection_rect_observation_available(paragraph_layout) {
        println(
          "MoUI renderer smoke selectionRects passed engine=skparagraph selection-rects line-range rect-geometry hit-test",
        )
      } else {
        failures.push(
          "selectionRects missing Skia selection rectangles, line-range, rect geometry, and hit-test observation",
        )
      }

      if grapheme_editing_observation_available() {
        println(
          "MoUI renderer smoke graphemeEditing passed grapheme-boundaries edit-actions",
        )
      } else {
        failures.push(
          "graphemeEditing missing grapheme boundary edit-action observation",
        )
      }

      if ime_candidate_anchor_observation_available(renderer.text_system()) {
        println(
          "MoUI renderer smoke imeCandidateAnchor passed candidate-anchor surrounding-text grapheme-boundary utf8-offsets",
        )
      } else {
        failures.push(
          "imeCandidateAnchor missing candidate anchor and surrounding-text observation",
        )
      }

      if ime_composition_visual_observation_available(
          renderer,
          renderer.text_system(),
        ) {
        println(
          "MoUI renderer smoke imeCompositionVisual passed composition-range composition-cursor preedit-pixels",
        )
      } else {
        failures.push(
          "imeCompositionVisual missing composition range, composition cursor, and preedit pixel observation",
        )
      }
    }
    None =>
      failures.push("Skia text/emoji smoke presenter did not receive pixels")
  }

  renderer.dispose()
  if failures.length() > 0 {
    for failure in failures {
      println(failure)
    }
    fail_smoke("MoUI Skia text/emoji smoke observations are incomplete")
  }
  println("MoUI Skia text/emoji smoke passed")
}

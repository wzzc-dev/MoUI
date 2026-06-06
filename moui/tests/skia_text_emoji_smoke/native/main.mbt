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
struct SkiaParagraphProofLine {
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
fn paragraph_words() -> Array[String] {
  [
    "Proof", "wrap", "line", "alpha", "beta", "gamma", "delta", "epsilon", "zeta",
  ]
}

///|
fn measured_text_width(
  system : @core.TextSystem,
  text : String,
  font : @core.FontSpec,
) -> Double {
  system.measure_text(@core.TextLayoutInput::new(text~, font~)).size.width
}

///|
fn skia_paragraph_proof_lines(
  system : @core.TextSystem,
) -> Array[SkiaParagraphProofLine] {
  let font = paragraph_font()
  let max_width = 96.0
  let start_x = 8.0
  let start_y = 94.0
  let metrics = system.measure_text(
    @core.TextLayoutInput::new(text="Ag", font~),
  )
  let line_height = metrics.size.height.max(font.size * 1.25)
  let line_texts : Array[String] = []
  let mut current = ""
  for word in paragraph_words() {
    let candidate = if current == "" { word } else { current + " " + word }
    if current == "" ||
      measured_text_width(system, candidate, font) <= max_width {
      current = candidate
    } else {
      line_texts.push(current)
      current = word
    }
  }
  if current != "" {
    line_texts.push(current)
  }
  let lines : Array[SkiaParagraphProofLine] = []
  for index, line_text in line_texts {
    let y = start_y + index.to_double() * line_height
    let frame = @core.Rect::new(
      x=start_x,
      y~,
      width=max_width,
      height=line_height,
    )
    lines.push({
      text: line_text,
      frame,
      line_index: index,
      baseline: y + metrics.baseline,
      measured_width: measured_text_width(system, line_text, font),
    })
  }
  lines
}

///|
fn skia_text_emoji_smoke_commands(
  paragraph_lines : Array[SkiaParagraphProofLine],
) -> Array[@core.DrawCommand] {
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="\u{1F469}\u{200D}\u{1F4BB}",
        frame=@core.Rect::new(x=8.0, y=8.0, width=72.0, height=44.0),
        font=@core.FontSpec::new(
          families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
          size=32.0,
          weight=400,
        ),
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
  let text = "\u{1F469}\u{200D}\u{1F4BB}"
  let layout = system.measure_text(
    @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(
        families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
        size=32.0,
        weight=400,
      ),
    ),
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
fn paragraph_wraps(lines : Array[SkiaParagraphProofLine]) -> Bool {
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
  lines : Array[SkiaParagraphProofLine],
) -> Bool {
  if lines.length() < 3 {
    return false
  }
  let line_1_rows = rect_dark_rows(frame, lines[1].frame)
  let line_2_rows = rect_dark_rows(frame, lines[2].frame)
  line_1_rows >= 4 && line_2_rows >= 4
}

///|
fn bidi_visual_order_evidence_available(
  frame : @skia_renderer.SkiaPixelFrame,
) -> Bool {
  let sample = "ABC \u{05D0}\u{05D1}\u{05D2} 123"
  match
    @skia_renderer.skia_text_visual_order_proof(
      sample,
      font=@core.FontSpec::new(size=20.0, weight=500),
    ) {
    Some(proof) => {
      println(
        "MoUI Skia text/emoji smoke bidi logical=\{proof.logical_text} visual=\{proof.visual_text} segments=\{proof.segment_count} glyphs=\{proof.glyph_count} width=\{proof.width}",
      )
      proof.visual_order_differs &&
      proof.logical_cluster_count == proof.visual_cluster_count &&
      proof.segment_count >= 3 &&
      proof.glyph_count >= 6 &&
      rect_dark_rows(
        frame,
        @core.Rect::new(x=8.0, y=58.0, width=150.0, height=28.0),
      ) >=
      4
    }
    None => false
  }
}

///|
fn main {
  if !@skia_renderer.skia_available() {
    fail_smoke(
      "real Skia backend is unavailable; configure moui_skia/native before running text/emoji proof",
    )
  }
  println(
    "MoUI Skia text/emoji smoke shaper_available=\{@skia_native.skia_shaper_available()}",
  )

  let captured : Ref[@skia_renderer.SkiaPixelFrame?] = Ref(None)
  let target = @skia_renderer.SkiaPresentTarget::new(
    description="MoUI Skia text/emoji proof presenter",
    present=frame => {
      captured.val = Some(frame)
      true
    },
  )
  guard (try? @skia_renderer.create_with_present_target(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=176.0, height=188.0),
        scale_factor=1.0,
      ),
      target,
    ))
    is Ok(renderer) else {
    fail_smoke("failed to create MoUI Skia text/emoji proof renderer")
  }

  let paragraph_lines = skia_paragraph_proof_lines(renderer.text_system())
  for line in paragraph_lines {
    println(
      "MoUI Skia text/emoji smoke paragraph line=\{line.line_index} text=\{line.text} baseline=\{line.baseline} measured_width=\{line.measured_width}",
    )
  }

  renderer.render(skia_text_emoji_smoke_commands(paragraph_lines)) catch {
    err =>
      fail_smoke(
        "failed to render MoUI Skia text/emoji proof frame: \{err.message()}",
      )
  }

  let failures : Array[String] = []
  match captured.val {
    Some(frame) => {
      let emoji_pixels = rect_high_saturation_pixels(
        frame,
        @core.Rect::new(x=8.0, y=8.0, width=72.0, height=44.0),
      )
      if emoji_pixels >= 8 {
        println(
          "MoUI Skia text/emoji smoke color emoji high_saturation_pixels=\{emoji_pixels}",
        )
        println(
          "MoUI renderer proof colorEmojiPixels passed high-saturation-pixels glyph-or-raster",
        )
      } else {
        failures.push(
          "colorEmojiPixels missing high-saturation Skia emoji pixels",
        )
      }

      if zwj_has_no_interior_caret(renderer.text_system()) && emoji_pixels >= 8 {
        println(
          "MoUI renderer proof zwjGrapheme passed single-grapheme-cluster no-interior-caret",
        )
      } else {
        failures.push(
          "zwjGrapheme missing no-interior-caret plus emoji pixel evidence",
        )
      }

      let paragraph_rows = rect_dark_rows(
        frame,
        @core.Rect::new(x=8.0, y=94.0, width=96.0, height=94.0),
      )
      if paragraph_wraps(paragraph_lines) &&
        paragraph_later_line_pixels(frame, paragraph_lines) &&
        paragraph_rows >= 12 {
        println(
          "MoUI Skia text/emoji smoke paragraph dark_rows=\{paragraph_rows}",
        )
        println(
          "MoUI renderer proof paragraphWrapping passed line-metrics later-line-pixels",
        )
      } else {
        failures.push(
          "paragraphWrapping missing Skia line metrics and later-line pixels",
        )
      }

      if bidi_visual_order_evidence_available(frame) {
        println("MoUI renderer proof bidiLayout passed visual-order")
      } else {
        failures.push(
          "bidiLayout missing Skia visual-order glyph/paragraph evidence",
        )
      }
    }
    None =>
      failures.push("Skia text/emoji proof presenter did not receive pixels")
  }

  renderer.dispose()
  if failures.length() > 0 {
    for failure in failures {
      println(failure)
    }
    fail_smoke("MoUI Skia text/emoji proof observations are incomplete")
  }
  println("MoUI Skia text/emoji smoke passed")
}

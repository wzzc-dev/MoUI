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
fn skia_text_emoji_smoke_commands() -> Array[@core.DrawCommand] {
  [
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
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="ABC \u{05D0}\u{05D1}\u{05D2} 123",
        frame=@core.Rect::new(x=8.0, y=58.0, width=150.0, height=28.0),
        font=@core.FontSpec::new(size=20.0, weight=500),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="Proof wrap line alpha beta gamma delta epsilon zeta",
        frame=@core.Rect::new(x=8.0, y=94.0, width=96.0, height=86.0),
        font=@core.FontSpec::new(size=18.0, weight=500),
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
fn paragraph_wraps(system : @core.TextSystem) -> Bool {
  let text = "Proof wrap line alpha beta gamma delta epsilon zeta"
  let font = @core.FontSpec::new(size=18.0, weight=500)
  let unbounded = system.measure_text(@core.TextLayoutInput::new(text~, font~))
  let wrapped = system.measure_text(
    @core.TextLayoutInput::new(text~, font~, max_width=96.0),
  )
  wrapped.size.width <= 96.0 &&
  wrapped.size.height > unbounded.size.height * 1.5 &&
  wrapped.baseline > 0.0
}

///|
fn bidi_visual_order_evidence_available() -> Bool {
  // This smoke intentionally requires a real bidi/paragraph evidence surface.
  // Current Skia text diagnostics only prove logical caret coverage, so this
  // stays false until SkParagraph/bidi glyph order evidence is wired.
  false
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

  renderer.render(skia_text_emoji_smoke_commands()) catch {
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
        @core.Rect::new(x=8.0, y=94.0, width=96.0, height=86.0),
      )
      if paragraph_wraps(renderer.text_system()) && paragraph_rows >= 12 {
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
    }
    None =>
      failures.push("Skia text/emoji proof presenter did not receive pixels")
  }

  if bidi_visual_order_evidence_available() {
    println("MoUI renderer proof bidiLayout passed visual-order")
  } else {
    failures.push(
      "bidiLayout missing Skia visual-order glyph/paragraph evidence",
    )
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

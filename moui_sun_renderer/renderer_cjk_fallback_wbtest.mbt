///|
/// CJK text must resolve a covering face from the default macOS font stack.
/// `sun_default_platform_font_faces()` used to register only Latin faces
/// (Arial / Courier New / Times New Roman), so committed IME text drew
/// placeholder boxes and Chinese input looked unsupported on the Sun route.
/// The fallback face registers lazily on the first uncovered run, so the test
/// drives a real `DrawText` before asserting coverage.
test "sun default fonts cover CJK codepoints after the first CJK draw" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="cjk-fallback", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=400.0, height=120.0),
      scale_factor=2.0,
    ),
    target,
  )
  let font = @core.FontSpec::new(size=14.0)
  let run = @core.TextRun::new(
    text="你好",
    frame=@core.Rect::new(x=10.0, y=10.0, width=200.0, height=24.0),
    font~,
    color=@core.Color::black(),
  )
  let before = renderer.resolved_faces(font)
  assert_true(
    @sun_text.plan_font_fallback(before, "你好").get_missing_char_count() > 0,
  )
  let commands : Array[@core.DrawCommand] = [
    Clear(@core.Color::white()),
    DrawText(run),
  ]
  renderer.render(commands)
  let after = renderer.resolved_faces(font)
  assert_true(
    @sun_text.plan_font_fallback(after, "你好").get_missing_char_count() == 0,
  )
  // The committed characters must leave real ink on the canvas: coverage
  // alone would still pass if every glyph resolved to the empty outline.
  let pixmap = renderer.canvas.get_pixmap()
  let mut inked = 0
  for index in 0..<(pixmap.get_width() * pixmap.get_height()) {
    let pixel = pixmap.get_pixel(
      index % pixmap.get_width(),
      index / pixmap.get_width(),
    )
    if pixel.r < 200 && pixel.g < 200 && pixel.b < 200 {
      inked = inked + 1
    }
  }
  assert_true(inked > 500)
}

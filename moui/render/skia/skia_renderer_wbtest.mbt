///|
test "skia transform maps MoUI affine fields to Skia matrix members" {
  let transform = @core.Transform2D::{
    a: 2.0,
    b: 3.0,
    c: 5.0,
    d: 7.0,
    tx: 11.0,
    ty: 13.0,
  }
  let matrix = skia_matrix(transform)
  assert_true(
    matrix.values() == [2.0, 5.0, 11.0, 3.0, 7.0, 13.0, 0.0, 0.0, 1.0],
  )
  assert_true(
    matrix.map_point(@skia_mbt.Point::new(17.0, 19.0)) ==
    @skia_mbt.Point::new(140.0, 197.0),
  )
}

///|
test "skia font resolver maps MoUI font families to platform candidates" {
  assert_true(
    skia_font_family_candidates(@core.FontFamily::Name("Acme Sans")) ==
    ["Acme Sans"],
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::SystemUi).contains(
      "Helvetica Neue",
    ),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::SansSerif).contains(
      "Segoe UI",
    ),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::Serif).contains(
      "Times New Roman",
    ),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::UiMonospace).contains("Menlo"),
  )
  assert_true(
    skia_font_family_candidates(@core.FontFamily::Emoji).contains(
      "Apple Color Emoji",
    ),
  )
  assert_true(skia_font_slant(@core.FontStyle::Normal) == 0)
  assert_true(skia_font_slant(@core.FontStyle::Italic) == 1)
}

///|
test "skia emoji hints cover representative diagnostic samples" {
  assert_true(skia_text_contains_emoji_hint("\u{1F642}"))
  assert_true(skia_text_contains_emoji_hint("\u{2615}\u{FE0F}"))
  assert_true(skia_text_contains_emoji_hint("\u{1F469}\u{200D}\u{1F373}"))
  assert_false(skia_text_contains_emoji_hint("Plain MoUI"))
}

///|
test "skia emoji fallback is limited to the system font manager path" {
  let font = @core.FontSpec::new(size=18.0, weight=400)
  assert_true(
    skia_emoji_fallback_draw_font(
      font,
      "\u{1F642}",
      SkiaFontResolution::EmptyTypeface,
    )
    is None,
  )
  assert_true(
    skia_emoji_fallback_draw_font(
      font,
      "Plain MoUI",
      SkiaFontResolution::SystemFontMgr,
    )
    is None,
  )
  match
    skia_emoji_fallback_draw_font(
      font,
      "\u{1F642}",
      SkiaFontResolution::SystemFontMgr,
    ) {
    Some(emoji_font) => assert_true(emoji_font.size() == 18.0)
    None =>
      assert_true(!skia_available() || skia_system_emoji_font(font) is None)
  }
}

///|
test "skia font resolver preserves fallback availability" {
  match skia_test_font(@core.FontSpec::new(size=14.0, weight=400)) {
    Some(font) => assert_true(font.size() == 14.0)
    None => assert_true(!skia_available())
  }
  let missing = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("Definitely Missing MoUI Font"),
    size=15.0,
    weight=700,
    style=@core.FontStyle::Italic,
  )
  match skia_test_font(missing) {
    Some(font) => assert_true(font.size() == 15.0)
    None => assert_true(!skia_available())
  }
}

///|
fn skia_test_native_text_available() -> Bool {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => skia_test_font_has_visible_text(font, "Slim")
    None => false
  }
}

///|
fn skia_test_font_has_visible_text(
  font : @skia_native.Font,
  text : String,
) -> Bool {
  skia_measure_text_width(font, text) > 0.0 &&
  skia_glyph_run_has_visible_glyphs(skia_glyph_run(font, text))
}

///|
fn skia_test_font(font : @core.FontSpec) -> @skia_native.Font? {
  skia_font_with_resolution(font, SkiaFontResolution::SystemFontMgr)
}

///|
test "skia empty typeface resolution avoids system font manager" {
  let font_spec = @core.FontSpec::new(size=14.0, weight=400)
  match
    skia_font_with_resolution(font_spec, SkiaFontResolution::EmptyTypeface) {
    None => assert_true(!skia_available())
    Some(font) => {
      assert_true(font.size() == 14.0)
      let run = skia_glyph_run_with_shaper(font, "Slim", use_shaper=false)
      assert_true(run.glyphs.length() == run.positions.length())
      assert_true(run.clusters.is_empty())
    }
  }
}

///|
test "skia empty typeface drawing falls back when the glyph run is blank" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=1.0, height=1.0),
    ),
    target,
    font_resolution=SkiaFontResolution::EmptyTypeface,
  ) catch {
    _ => return ()
  }
  match
    renderer.skia_draw_text_payload(
      @core.FontSpec::new(size=18.0, weight=400),
      "Slim",
    ) {
    Some((font, run)) => {
      assert_true(font.size() == 18.0)
      assert_true(skia_glyph_run_has_visible_glyphs(run))
    }
    None => assert_false(skia_test_native_text_available())
  }
}

///|
fn skia_test_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
test "skia renderer dispose clears cached image resources and records disposal" {
  guard skia_available() else { return () }
  let source = skia_test_png_data_uri()
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source,
      frame: @core.Rect::new(x=0.0, y=0.0, width=4.0, height=4.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]) catch {
    err => fail("expected Skia image render: \{err.message()}")
  }
  assert_true(renderer.image_cache.get(source) is Some(_))
  guard renderer.image_lifecycle.lookup(source) is Some(ready) else {
    fail("expected ready image lifecycle record before dispose")
  }
  assert_true(ready.status == @render.ImageResourceStatus::ImageReady)
  renderer.dispose()
  assert_true(renderer.image_cache.get(source) is None)
  guard renderer.image_lifecycle.lookup(source) is Some(disposed) else {
    fail("expected disposed image lifecycle record after dispose")
  }
  assert_true(disposed.status == @render.ImageResourceStatus::ImageDisposed)
  inspect(renderer.image_resources().length(), content="1")
}

///|
test "skia renderer resize updates presented frame metrics" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=3.0, height=2.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=6.0),
      scale_factor=2.0,
    ),
  ) catch {
    err => fail("expected Skia renderer resize: \{err.message()}")
  }
  renderer.render([@core.DrawCommand::Clear(@core.Color::white())]) catch {
    err => fail("expected Skia renderer render: \{err.message()}")
  }
  guard renderer.last_frame() is Some(frame) else {
    fail("expected Skia renderer to keep last frame after render")
  }
  inspect(frame.width, content="16")
  inspect(frame.height, content="12")
  inspect(frame.scale_factor, content="2")
  inspect(renderer.present_count(), content="1")
}

///|
test "skia renderer reports presenter failure without counting present" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="failing-presenter", present=_ => {
    false
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=4.0, height=4.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  let result = try? renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
  ])
  match result {
    Err(SkiaRendererError::PresentFailed(description)) =>
      inspect(description, content="failing-presenter")
    _ => fail("expected Skia presenter failure")
  }
  inspect(renderer.present_count(), content="0")
  guard renderer.last_frame() is Some(frame) else {
    fail("expected failed presentation to keep rendered frame for diagnostics")
  }
  inspect(frame.width, content="4")
  inspect(frame.height, content="4")
}

///|
test "skia unsupported command diagnostics reset per frame" {
  guard skia_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=8.0, height=8.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="missing-shader",
        frame=@core.Rect::new(x=0.0, y=0.0, width=8.0, height=8.0),
        fallback=@core.Brush::solid(@core.Color::blue()),
      ),
    ),
  ]) catch {
    err => fail("expected Skia fallback render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="1")
  inspect(renderer.present_count(), content="1")
  renderer.render([@core.DrawCommand::Clear(@core.Color::white())]) catch {
    err => fail("expected Skia supported render: \{err.message()}")
  }
  inspect(renderer.unsupported_command_count(), content="0")
  inspect(renderer.present_count(), content="2")
}

///|
test "skia text baseline is centered in taller text frames" {
  let frame = @core.Rect::new(x=4.0, y=10.0, width=120.0, height=44.0)
  let metrics = SkiaTextMetrics::{ baseline: 12.0, height: 20.0 }
  inspect(skia_text_baseline_y(frame, metrics), content="34")
}

///|
test "skia empty typeface text system follows drawing fallback font metrics" {
  let input = @core.TextLayoutInput::new(
    text="你好 MoUI",
    font=@core.FontSpec::new(size=18.0, weight=400),
  )
  let system = skia_text_system(SkiaFontResolution::EmptyTypeface)
  if !skia_available() {
    assert_true(system.id() == @core.TextSystem::fallback().id())
  } else {
    assert_true(system.id() == "skia-raster-empty-typeface-text-system")
    match
      skia_draw_text_payload_for_resolution(
        input.font,
        input.text,
        SkiaFontResolution::EmptyTypeface,
      ) {
      Some((font, run)) => {
        let measured = system.measure_text(input)
        assert_true(measured.size.width == run.width)
        assert_true(
          measured.caret_positions[input.text.to_array().length()] == run.width,
        )
        assert_true(
          measured.size.width == skia_measure_text_width(font, input.text),
        )
        assert_true(
          measured.caret_positions[input.text.to_array().length()] == run.width,
        )
        assert_true(
          measured.size.width == skia_measure_text_width(font, input.text),
        )
      }
      None =>
        fail(
          "expected empty typeface text system to find a visible fallback font",
        )
    }
  }
}

///|
test "skia text system exposes measured caret positions" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let input = @core.TextLayoutInput::new(
        text="Slim",
        font=@core.FontSpec::new(size=18.0, weight=400),
      )
      let fallback = @core.TextSystem::fallback().measure_text(input)
      let glyph_run = skia_glyph_run(font, input.text)
      let layout = skia_text_layout_result(font, input, fallback, glyph_run~)
      inspect(layout.caret_positions.length(), content="5")
      inspect(layout.caret_positions[0], content="0")
      if skia_test_font_has_visible_text(font, "Slim") {
        assert_true(layout.size.width == skia_measure_text_width(font, "Slim"))
        assert_true(layout.caret_positions[4] == layout.size.width)
        assert_true(layout.baseline > 0.0)
        assert_true(layout.size.height >= layout.baseline)
        assert_true(layout.caret_positions[1] > 0.0)
        assert_true(layout.caret_positions[2] > layout.caret_positions[1])
      } else {
        assert_true(layout == fallback)
      }
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text drawing builds best available glyph runs" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let run = skia_glyph_run(font, "Slim")
      if skia_test_font_has_visible_text(font, "Slim") {
        inspect(run.glyphs.length(), content="4")
        inspect(run.positions.length(), content="4")
        assert_true(run.width > 0.0)
        assert_true(run.positions[0] == @skia_mbt.Point::zero())
        assert_true(run.positions[1].x > run.positions[0].x)
        assert_true(run.positions[2].x > run.positions[1].x)
        if @skia_native.skia_shaper_available() {
          assert_true(run.clusters.length() == run.glyphs.length())
        } else {
          assert_true(run.clusters.is_empty())
        }
      } else {
        assert_false(skia_glyph_run_has_visible_glyphs(run))
      }
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text metrics derive baseline and height from font metrics" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let metrics = skia_text_metrics(
        font,
        fallback_baseline=99.0,
        fallback_height=120.0,
      )
      if skia_test_font_has_visible_text(font, "Slim") {
        assert_true(metrics.baseline > 0.0)
        assert_true(metrics.height >= metrics.baseline)
        assert_true(metrics.baseline != 99.0)
        assert_true(metrics.height != 120.0)
      } else {
        assert_true(metrics.baseline == 99.0)
        assert_true(metrics.height == 120.0)
      }
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text layout consumes the draw payload glyph run" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let input = @core.TextLayoutInput::new(
        text="AB",
        font=@core.FontSpec::new(size=18.0, weight=400),
      )
      guard skia_font_can_measure_text(font, input.text) else { return () }
      let fallback = @core.TextSystem::fallback().measure_text(input)
      let glyph_run = SkiaGlyphRun::{
        glyphs: [@skia_native.GlyphId::new(10), @skia_native.GlyphId::new(11)],
        positions: [
          @skia_mbt.Point::new(0.0, 0.0),
          @skia_mbt.Point::new(77.0, 0.0),
        ],
        clusters: [0, 1],
        width: 123.0,
      }
      let layout = skia_text_layout_result(font, input, fallback, glyph_run~)
      inspect(layout.size.width, content="123")
      inspect(layout.caret_positions.length(), content="3")
      inspect(layout.caret_positions[0], content="0")
      inspect(layout.caret_positions[1], content="77")
      inspect(layout.caret_positions[2], content="123")
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text system clamps measured carets to max width" {
  match skia_test_font(@core.FontSpec::new(size=20.0, weight=400)) {
    Some(font) => {
      let input = @core.TextLayoutInput::new(
        text="MoUI",
        font=@core.FontSpec::new(size=20.0, weight=400),
        max_width=12.0,
      )
      let fallback = @core.TextSystem::fallback().measure_text(input)
      let glyph_run = skia_glyph_run(font, input.text)
      let layout = skia_text_layout_result(font, input, fallback, glyph_run~)
      inspect(layout.caret_positions.length(), content="5")
      inspect(layout.size.width, content="12")
      for caret in layout.caret_positions {
        assert_true(caret <= 12.0)
      }
      assert_true(layout.caret_positions[4] == 12.0)
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia shaped caret mapping uses glyph clusters when available" {
  let run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
    ],
    positions: [
      @skia_mbt.Point::new(0.0, 0.0),
      @skia_mbt.Point::new(9.0, 0.0),
      @skia_mbt.Point::new(21.0, 0.0),
    ],
    clusters: [0, 1, 4],
    width: 30.0,
  }
  match skia_shaped_caret_positions("A你B", run) {
    Some(carets) => {
      inspect(carets.length(), content="4")
      inspect(carets[0], content="0")
      inspect(carets[1], content="9")
      inspect(carets[2], content="21")
      inspect(carets[3], content="30")
    }
    None => fail("expected shaped caret mapping")
  }
}

///|
test "skia shaped caret mapping fills cluster gaps monotonically" {
  let run = SkiaGlyphRun::{
    glyphs: [@skia_native.GlyphId::new(10), @skia_native.GlyphId::new(11)],
    positions: [@skia_mbt.Point::new(0.0, 0.0), @skia_mbt.Point::new(18.0, 0.0)],
    clusters: [0, 5],
    width: 24.0,
  }
  match skia_shaped_caret_positions("A🙂B", run) {
    Some(carets) => {
      inspect(carets.length(), content="4")
      inspect(carets[0], content="0")
      inspect(carets[1], content="0")
      inspect(carets[2], content="18")
      inspect(carets[3], content="24")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected shaped caret mapping")
  }
}

///|
test "skia shaped caret mapping keeps emoji cluster caret coverage" {
  let variation_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
    ],
    positions: [
      @skia_mbt.Point::new(0.0, 0.0),
      @skia_mbt.Point::new(10.0, 0.0),
      @skia_mbt.Point::new(22.0, 0.0),
    ],
    clusters: [0, 1, 7],
    width: 30.0,
  }
  match skia_shaped_caret_positions("A\u{2615}\u{FE0F}B", variation_run) {
    Some(carets) => {
      inspect(carets.length(), content="5")
      inspect(carets[0], content="0")
      inspect(carets[1], content="10")
      inspect(carets[2], content="10")
      inspect(carets[3], content="22")
      inspect(carets[4], content="30")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected variation-selector caret mapping")
  }
  let zwj_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(20),
      @skia_native.GlyphId::new(21),
      @skia_native.GlyphId::new(22),
    ],
    positions: [
      @skia_mbt.Point::new(0.0, 0.0),
      @skia_mbt.Point::new(14.0, 0.0),
      @skia_mbt.Point::new(28.0, 0.0),
    ],
    clusters: [0, 1, 12],
    width: 34.0,
  }
  match skia_shaped_caret_positions("A\u{1F469}\u{200D}\u{1F373}B", zwj_run) {
    Some(carets) => {
      inspect(carets.length(), content="6")
      inspect(carets[0], content="0")
      inspect(carets[1], content="14")
      inspect(carets[2], content="14")
      inspect(carets[3], content="14")
      inspect(carets[4], content="28")
      inspect(carets[5], content="34")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected ZWJ caret mapping")
  }
}

///|
test "skia layout width follows caret source" {
  inspect(skia_layout_width_from_carets([0.0, 4.0, 9.0]), content="9")
  inspect(skia_layout_width_from_carets([]), content="0")
}

///|
test "skia shaped caret mapping rejects invalid shaped data" {
  let run = SkiaGlyphRun::{
    glyphs: [@skia_native.GlyphId::new(10)],
    positions: [@skia_mbt.Point::new(0.0, 0.0)],
    clusters: [],
    width: 10.0,
  }
  assert_true(skia_shaped_caret_positions("A", run) is None)
}

///|
test "skia text system keeps unicode caret coverage" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let text = "A你🙂"
      let carets = skia_caret_positions(font, text)
      inspect(carets.length(), content="4")
      if skia_font_can_measure_text(font, text) {
        assert_true(carets[0] == 0.0)
        assert_true(carets[1] > 0.0)
        assert_true(carets[2] >= carets[1])
        assert_true(carets[3] >= carets[2])
        assert_true(carets[3] == skia_measure_text_width(font, text))
      } else {
        assert_true(carets.all(caret => caret == 0.0))
      }
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text system keeps representative emoji caret coverage" {
  let system = skia_text_system(SkiaFontResolution::SystemFontMgr)
  for text in ["\u{1F642}", "\u{2615}\u{FE0F}", "\u{1F469}\u{200D}\u{1F373}"] {
    let input = @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(size=18.0, weight=400),
    )
    let layout = system.measure_text(input)
    assert_true(layout.caret_positions.length() == text.to_array().length() + 1)
    assert_true(skia_test_carets_are_monotonic(layout.caret_positions))
    assert_true(
      layout.size.width == layout.caret_positions[text.to_array().length()],
    )
  }
}

///|
fn skia_test_carets_are_monotonic(carets : Array[Double]) -> Bool {
  let mut previous = 0.0
  for index, caret in carets {
    if index == 0 {
      previous = caret
    } else if caret < previous {
      return false
    } else {
      previous = caret
    }
  }
  true
}

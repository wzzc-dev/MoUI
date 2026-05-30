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
test "skia font resolver preserves fallback availability" {
  match skia_font(@core.FontSpec::new(size=14.0, weight=400)) {
    Some(font) => assert_true(font.size() == 14.0)
    None => assert_true(!skia_available())
  }
  let missing = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("Definitely Missing MoUI Font"),
    size=15.0,
    weight=700,
    style=@core.FontStyle::Italic,
  )
  match skia_font(missing) {
    Some(font) => assert_true(font.size() == 15.0)
    None => assert_true(!skia_available())
  }
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
    None =>
      fail("expected empty typeface drawing to fall back to visible glyphs")
  }
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
        assert_true(measured.caret_positions[input.text.to_array().length()] == run.width)
        assert_true(measured.size.width == skia_measure_text_width(font, input.text))
      }
      None => fail("expected empty typeface text system to find a visible fallback font")
    }
  }
}

///|
test "skia text system exposes measured caret positions" {
  match skia_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let input = @core.TextLayoutInput::new(
        text="Slim",
        font=@core.FontSpec::new(size=18.0, weight=400),
      )
      let fallback = @core.TextSystem::fallback().measure_text(input)
      let layout = skia_text_layout_result(font, input, fallback)
      inspect(layout.caret_positions.length(), content="5")
      inspect(layout.caret_positions[0], content="0")
      assert_true(layout.size.width == skia_measure_text_width(font, "Slim"))
      assert_true(layout.caret_positions[4] == layout.size.width)
      assert_true(layout.baseline > 0.0)
      assert_true(layout.size.height >= layout.baseline)
      assert_true(layout.caret_positions[1] > 0.0)
      assert_true(layout.caret_positions[2] > layout.caret_positions[1])
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text drawing builds best available glyph runs" {
  match skia_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let run = skia_glyph_run(font, "Slim")
      inspect(run.glyphs.length(), content="4")
      inspect(run.positions.length(), content="4")
      assert_true(run.width > 0.0)
      assert_true(run.positions[0] == @skia_mbt.Point::zero())
      assert_true(run.positions[1].x > run.positions[0].x)
      assert_true(run.positions[2].x > run.positions[1].x)
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text metrics derive baseline and height from font metrics" {
  match skia_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let metrics = skia_text_metrics(
        font,
        fallback_baseline=99.0,
        fallback_height=120.0,
      )
      assert_true(metrics.baseline > 0.0)
      assert_true(metrics.height >= metrics.baseline)
      assert_true(metrics.baseline != 99.0)
      assert_true(metrics.height != 120.0)
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia text system clamps measured carets to max width" {
  match skia_font(@core.FontSpec::new(size=20.0, weight=400)) {
    Some(font) => {
      let input = @core.TextLayoutInput::new(
        text="MoUI",
        font=@core.FontSpec::new(size=20.0, weight=400),
        max_width=12.0,
      )
      let fallback = @core.TextSystem::fallback().measure_text(input)
      let layout = skia_text_layout_result(font, input, fallback)
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
test "skia text system keeps unicode caret coverage" {
  match skia_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let text = "A你🙂"
      let carets = skia_caret_positions(font, text)
      inspect(carets.length(), content="4")
      assert_true(carets[0] == 0.0)
      assert_true(carets[1] > 0.0)
      assert_true(carets[2] >= carets[1])
      assert_true(carets[3] >= carets[2])
      assert_true(carets[3] == skia_measure_text_width(font, text))
    }
    None => assert_true(!skia_available())
  }
}

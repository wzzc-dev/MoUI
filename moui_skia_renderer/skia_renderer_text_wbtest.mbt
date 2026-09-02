///|
test "skia text baseline is centered in taller text frames" {
  let frame = @core.Rect::new(x=4.0, y=10.0, width=120.0, height=44.0)
  let metrics = SkiaTextMetrics::{ baseline: 12.0, height: 20.0 }
  inspect(skia_text_baseline_y(frame, metrics), content="34")
}

///|
test "skia text placement clips to the TextRun frame" {
  let frame = @core.Rect::new(x=20.0, y=4.0, width=100.0, height=30.0)
  let run = @core.TextRun::new(
    text="Bounded",
    frame~,
    font=@core.FontSpec::new(size=16.0),
    color=@core.Color::black(),
    align=@core.TextAlign::TextEnd,
  )
  let glyph_run = SkiaGlyphRun::{
    glyphs: [@skia_native.GlyphId::new(10)],
    positions: [@moui_skia.Point::zero()],
    clusters: [0],
    width: 70.0,
  }
  let placement = skia_text_placement(run, glyph_run, SkiaTextMetrics::{
    baseline: 10.0,
    height: 20.0,
  })
  assert_true(placement.clip == frame)
  inspect(placement.origin.x.to_double(), content="50")
  inspect(placement.origin.y.to_double(), content="19")
}

///|
test "skia text draw skips non-positive text frames" {
  assert_true(
    skia_text_frame_can_draw(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
    ),
  )
  assert_false(
    skia_text_frame_can_draw(
      @core.Rect::new(x=0.0, y=0.0, width=0.0, height=1.0),
    ),
  )
  assert_false(
    skia_text_frame_can_draw(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=0.0),
    ),
  )
}

///|
test "skia empty typeface text system follows drawing fallback font metrics" {
  let input = @core.TextLayoutInput::new(
    text="你好 MoUI",
    font=@core.FontSpec::new(size=18.0, weight=400),
  )
  let system = skia_text_system(resolution=SkiaFontResolution::EmptyTypeface)
  if !skia_available() {
    assert_true(system.id() == @core.TextSystem::fallback().id())
  } else {
    assert_true(system.id() == "skia-raster-empty-typeface-text-system")
    match
      skia_resolved_text_layout_for_resolution(
        input.font,
        input.text,
        SkiaFontResolution::EmptyTypeface,
      ) {
      Some(layout) => {
        let measured = system.measure_text(input)
        assert_true(measured.size.width == layout.width)
        assert_true(
          measured.caret_positions[input.text.to_array().length()] ==
          layout.width,
        )
        assert_true(layout.segments.length() > 0)
      }
      None => {
        let measured = system.measure_text(input)
        let fallback = @core.TextSystem::fallback().measure_text(input)
        assert_true(measured == fallback)
      }
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
      let glyph_run = skia_glyph_run_with_shaper(
        font,
        input.text,
        use_shaper=true,
      )
      let layout = skia_text_layout_result(font, input, fallback, glyph_run~)
      inspect(layout.caret_positions.length(), content="5")
      inspect(layout.caret_positions[0], content="0")
      if skia_test_font_has_visible_text(font, "Slim") {
        let measured_width = skia_measure_text_width(font, "Slim")
        if @skia_native.skia_shaper_available() && glyph_run.width > 0.0 {
          assert_true(layout.size.width == glyph_run.width)
        } else {
          assert_true(layout.size.width == measured_width)
        }
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
test "skia mixed text segmentation preserves grapheme clusters" {
  let clusters = @render_common.text_grapheme_clusters(
    "A\u{1F469}\u{200D}\u{1F4BB}B\u{1F1FA}\u{1F1F8}",
  )
  inspect(clusters.length(), content="4")
  inspect(clusters[0], content="A")
  inspect(clusters[1].to_array().length(), content="3")
  inspect(clusters[2], content="B")
  inspect(clusters[3].to_array().length(), content="2")

  let indic_clusters = @render_common.text_grapheme_clusters("क़्ष")
  inspect(indic_clusters.length(), content="1")
  inspect(indic_clusters[0].to_array().length(), content="4")
  let indic_latin_clusters = @render_common.text_grapheme_clusters("क़्A")
  inspect(indic_latin_clusters.length(), content="2")
  inspect(indic_latin_clusters[0].to_array().length(), content="3")
  inspect(indic_latin_clusters[1], content="A")
  let musical_clusters = @render_common.text_grapheme_clusters("A\u{1D165}B")
  inspect(musical_clusters.length(), content="2")
  inspect(musical_clusters[0].to_array().length(), content="2")
  inspect(musical_clusters[1], content="B")

  let segments = @render_common.text_mixed_segments("AB你好\u{1F642}CD")
  inspect(segments.length(), content="4")
  inspect(segments[0], content="AB")
  inspect(segments[1], content="你好")
  inspect(segments[2], content="\u{1F642}")
  inspect(segments[3], content="CD")

  let indic_segments = @render_common.text_mixed_segments("Aक़्षB")
  inspect(indic_segments.length(), content="3")
  inspect(indic_segments[0], content="A")
  inspect(indic_segments[1], content="क़्ष")
  inspect(indic_segments[2], content="B")

  let musical_segments = @render_common.text_mixed_segments("A\u{1D165}B")
  inspect(musical_segments.length(), content="2")
  inspect(musical_segments[0].to_array().length(), content="2")
  inspect(musical_segments[1], content="B")
}

///|
fn skia_test_core_grapheme_cluster_texts(text : String) -> Array[String] {
  let chars = text.to_array()
  let boundaries = @core.TextGraphemeBoundaries::new(text~).boundaries()
  let clusters : Array[String] = []
  if boundaries.length() < 2 {
    return clusters
  }
  for boundary_index in 0..<(boundaries.length() - 1) {
    let start = boundaries[boundary_index]
    let end = boundaries[boundary_index + 1]
    clusters.push(String::from_array(chars[start:end]))
  }
  clusters
}

///|
fn assert_skia_grapheme_clusters_match_core(
  text : String,
  expected_boundaries : Array[Int],
) -> Unit raise {
  let boundaries = @core.TextGraphemeBoundaries::new(text~).boundaries()
  if boundaries.length() != expected_boundaries.length() {
    fail(
      "expected \{expected_boundaries.length()} core grapheme boundaries, got \{boundaries.length()}",
    )
  }
  for index in 0..<expected_boundaries.length() {
    inspect(boundaries[index], content="\{expected_boundaries[index]}")
  }
  let expected = skia_test_core_grapheme_cluster_texts(text)
  let actual = @render_common.text_grapheme_clusters(text)
  if actual.length() != expected.length() {
    fail(
      "expected \{expected.length()} Skia grapheme clusters, got \{actual.length()}",
    )
  }
  for index in 0..<expected.length() {
    inspect(actual[index], content=expected[index])
  }
}

///|
fn assert_skia_grapheme_utf8_offsets(
  text : String,
  indexes : Array[Int],
  expected : Array[Int],
) -> Unit raise {
  if indexes.length() != expected.length() {
    fail("expected matching index and utf8-offset fixture lengths")
  }
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  for index in 0..<indexes.length() {
    inspect(
      boundaries.utf8_offset(indexes[index]),
      content="\{expected[index]}",
    )
  }
}

///|
fn assert_skia_grapheme_nearest_utf8_offsets(
  text : String,
  indexes : Array[Int],
  expected : Array[Int],
) -> Unit raise {
  if indexes.length() != expected.length() {
    fail("expected matching index and normalized utf8-offset fixture lengths")
  }
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  for index in 0..<indexes.length() {
    inspect(
      boundaries.nearest_boundary_utf8_offset(indexes[index]),
      content="\{expected[index]}",
    )
  }
}

///|
test "skia grapheme clustering follows core IME boundary contract" {
  assert_skia_grapheme_clusters_match_core("A\u{1F469}\u{200D}\u{1F4BB}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core(
    "A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B",
    [0, 1, 5, 6],
  )
  assert_skia_grapheme_clusters_match_core("A1\u{FE0F}\u{20E3}B", [0, 1, 4, 5])
  assert_skia_grapheme_clusters_match_core("\u{1F1FA}\u{1F1F8}\u{1F1E8}", [
    0, 2, 3,
  ])
  assert_skia_grapheme_clusters_match_core("A\u{0600}B", [0, 1, 3])
  assert_skia_grapheme_clusters_match_core("A\u{0D4E}\u{0D15}B", [0, 1, 3, 4])
  assert_skia_grapheme_clusters_match_core("A\u{13430}\u{0301}B", [
    0, 1, 2, 3, 4,
  ])
  assert_skia_grapheme_clusters_match_core("A\u{1FC00}\u{200D}\u{1FC01}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core("A\u{0600}\u{0628}\u{0651}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core("A\u{1100}\u{1161}\u{11A8}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core("A\u{A960}\u{D7B0}\u{D7CB}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core("Aक्‍षB", [0, 1, 5, 6])
  assert_skia_grapheme_clusters_match_core("Aक़्षB", [0, 1, 5, 6])
  assert_skia_grapheme_clusters_match_core("Aक्‌षB", [0, 1, 4, 5, 6])
  assert_skia_grapheme_clusters_match_core("\u{094D}\u{0915}", [0, 1, 2])
  assert_skia_grapheme_clusters_match_core("a\u{094D}\u{0924}", [0, 2, 3])
  assert_skia_grapheme_clusters_match_core("A\u{1B32}\u{1B44}\u{1B2F}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_clusters_match_core(
    "A\u{179F}\u{17D2}\u{178F}\u{17D2}\u{179A}\u{17B8}B",
    [0, 1, 7, 8],
  )
  assert_skia_grapheme_clusters_match_core("A\u{1000}\u{1039}\u{1001}B", [
    0, 1, 4, 5,
  ])
  assert_skia_grapheme_utf8_offsets(
    "A\u{1F469}\u{200D}\u{1F4BB}B",
    [0, 1, 4, 5],
    [0, 1, 12, 13],
  )
  assert_skia_grapheme_utf8_offsets("A1\u{FE0F}\u{20E3}B", [0, 1, 4, 5], [
    0, 1, 8, 9,
  ])
  assert_skia_grapheme_nearest_utf8_offsets("A1\u{FE0F}\u{20E3}B", [2, 3], [
    1, 8,
  ])
  assert_skia_grapheme_utf8_offsets(
    "A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B",
    [0, 1, 5, 6],
    [0, 1, 17, 18],
  )
  assert_skia_grapheme_utf8_offsets("Aक्‍षB", [0, 1, 5, 6], [
    0, 1, 13, 14,
  ])
  assert_skia_grapheme_nearest_utf8_offsets("Aक्‍षB", [2, 3, 4], [
    1, 1, 13,
  ])
  assert_skia_grapheme_utf8_offsets("Aक्‌षB", [0, 1, 4, 5, 6], [
    0, 1, 10, 13, 14,
  ])
}

///|
test "skia resolved mixed text layout accumulates segment carets" {
  guard skia_available() else { return () }
  let text = "A你\u{1F642}B"
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::system_ui().with_fallback(
      @core.FontFamily::Emoji,
    ),
    size=18.0,
    weight=400,
  )
  match
    skia_resolved_text_layout_for_resolution(
      font,
      text,
      SkiaFontResolution::SystemFontMgr,
    ) {
    Some(layout) => {
      inspect(layout.segments.length(), content="4")
      assert_true(layout.width > 0.0)
      assert_true(layout.metrics.baseline > 0.0)
      let carets = skia_resolved_text_caret_positions(text, layout)
      inspect(carets.length(), content="\{text.to_array().length() + 1}")
      assert_true(skia_test_carets_are_monotonic(carets))
      assert_true(carets[carets.length() - 1] == layout.width)

      let system = skia_text_system()
      let measured = system.measure_text(
        @core.TextLayoutInput::new(text~, font~),
      )
      assert_true(measured.size.width == layout.width)
      assert_true(
        measured.caret_positions[measured.caret_positions.length() - 1] ==
        layout.width,
      )
    }
    None => {
      let system = skia_text_system()
      let input = @core.TextLayoutInput::new(text~, font~)
      let measured = system.measure_text(input)
      let fallback = @core.TextSystem::fallback().measure_text(input)
      assert_true(measured == fallback)
    }
  }
}

///|
test "skia text drawing builds best available glyph runs" {
  match skia_test_font(@core.FontSpec::new(size=18.0, weight=400)) {
    Some(font) => {
      let run = skia_glyph_run_with_shaper(font, "Slim", use_shaper=true)
      if skia_test_font_has_visible_text(font, "Slim") {
        inspect(run.glyphs.length(), content="4")
        inspect(run.positions.length(), content="4")
        assert_true(run.width > 0.0)
        assert_true(run.positions[0] == @moui_skia.Point::zero())
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
test "skia draw payload keeps shaped width and carets together" {
  guard skia_available() else { return () }
  let text = "TaTaTaTaTaTaTaTa"
  let font_spec = @core.FontSpec::new(size=18.0, weight=400)
  match
    skia_draw_text_payload_for_resolution(
      font_spec,
      text,
      SkiaFontResolution::SystemFontMgr,
    ) {
    Some((draw_font, glyph_run)) => {
      if @skia_native.skia_shaper_available() {
        assert_true(glyph_run.clusters.length() == glyph_run.glyphs.length())
      } else {
        assert_true(glyph_run.clusters.is_empty())
      }
      assert_true(glyph_run.width > 0.0)
      let input = @core.TextLayoutInput::new(text~, font=font_spec)
      let fallback = @core.TextSystem::fallback().measure_text(input)
      let layout = skia_text_layout_result(
        draw_font,
        input,
        fallback,
        glyph_run~,
      )
      inspect(layout.size.width, content="\{glyph_run.width}")
      inspect(
        layout.caret_positions[layout.caret_positions.length() - 1],
        content="\{glyph_run.width}",
      )
      let measured = skia_text_system().measure_text(input)
      inspect(measured.size.width, content="\{glyph_run.width}")
      inspect(
        measured.caret_positions[measured.caret_positions.length() - 1],
        content="\{glyph_run.width}",
      )
    }
    None => fail("expected Skia draw text payload")
  }
}

///|
test "skia text segment draws shaped glyph pixels and falls back visibly" {
  guard skia_test_native_text_available() else { return () }
  let text = "TaTaTaTaTaTaTaTa"
  let font_spec = @core.FontSpec::new(size=24.0, weight=400)
  match
    skia_draw_text_payload_for_resolution(
      font_spec,
      text,
      SkiaFontResolution::SystemFontMgr,
    ) {
    None => fail("expected Skia draw text payload")
    Some((font, glyph_run)) => {
      let paint = skia_paint(@core.Color::black())
      match
        @skia_native.Surface::raster_n32_premul(@moui_skia.ISize::new(240, 48)) {
        None => ()
        Some(surface) =>
          match surface.canvas() {
            None => ()
            Some(canvas) => {
              canvas.clear(@moui_skia.Color::white())
              let used_glyph_run = skia_draw_text_segment(
                canvas,
                { text, font, glyph_run, x_offset: 0.0 },
                @moui_skia.Point::new(4, 32),
                paint,
              )
              assert_true(used_glyph_run)
              match surface.read_pixels() {
                None => ()
                Some(pixmap) => {
                  let frame = SkiaPixelFrame::{
                    width: pixmap.width(),
                    height: pixmap.height(),
                    row_bytes: pixmap.row_bytes(),
                    scale_factor: 1.0,
                    pixels: pixmap.pixels,
                  }
                  assert_true(
                    skia_test_region_has_dark_pixel(
                      frame,
                      @core.Rect::new(x=0.0, y=0.0, width=240.0, height=48.0),
                    ),
                  )
                }
              }
            }
          }
      }
      let invalid_run = SkiaGlyphRun::{
        glyphs: [],
        positions: [],
        clusters: [],
        width: glyph_run.width,
      }
      match
        @skia_native.Surface::raster_n32_premul(@moui_skia.ISize::new(240, 48)) {
        None => ()
        Some(surface) =>
          match surface.canvas() {
            None => ()
            Some(canvas) => {
              canvas.clear(@moui_skia.Color::white())
              let used_glyph_run = skia_draw_text_segment(
                canvas,
                { text, font, glyph_run: invalid_run, x_offset: 0.0 },
                @moui_skia.Point::new(4, 32),
                paint,
              )
              assert_false(used_glyph_run)
              match surface.read_pixels() {
                None => ()
                Some(pixmap) => {
                  let frame = SkiaPixelFrame::{
                    width: pixmap.width(),
                    height: pixmap.height(),
                    row_bytes: pixmap.row_bytes(),
                    scale_factor: 1.0,
                    pixels: pixmap.pixels,
                  }
                  assert_true(
                    skia_test_region_has_dark_pixel(
                      frame,
                      @core.Rect::new(x=0.0, y=0.0, width=240.0, height=48.0),
                    ),
                  )
                }
              }
            }
          }
      }
    }
  }
}

///|
test "skia missing glyph recovery requires improved fallback coverage" {
  let partial = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(12),
      @skia_native.GlyphId::new(0),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let improved = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(12),
      @skia_native.GlyphId::new(13),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let same = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(14),
      @skia_native.GlyphId::new(0),
      @skia_native.GlyphId::new(0),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  let complete = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(12),
      @skia_native.GlyphId::new(13),
      @skia_native.GlyphId::new(14),
    ],
    positions: [
      @moui_skia.Point::zero(),
      @moui_skia.Point::new(8.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [],
    width: 24.0,
  }
  inspect(skia_glyph_run_missing_glyph_count(partial), content="2")
  inspect(skia_glyph_run_missing_glyph_count(improved), content="1")
  assert_false(skia_glyph_run_can_draw_text(partial))
  assert_true(skia_glyph_run_can_draw_text(complete))
  assert_true(skia_glyph_run_improves_missing_glyphs(partial, improved))
  assert_false(skia_glyph_run_improves_missing_glyphs(partial, same))
  assert_false(skia_glyph_run_improves_missing_glyphs(improved, partial))
  assert_true(skia_sample_missing_glyph_recovery_ready())
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
test "skia text layout consumes draw payload width" {
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
          @moui_skia.Point::new(0.0, 0.0),
          @moui_skia.Point::new(77.0, 0.0),
        ],
        clusters: [0, 1],
        width: 123.0,
      }
      let layout = skia_text_layout_result(font, input, fallback, glyph_run~)
      inspect(layout.size.width, content="123")
      inspect(layout.caret_positions.length(), content="3")
      inspect(layout.caret_positions[0], content="0")
      inspect(layout.caret_positions[2], content="123")
    }
    None => assert_true(!skia_available())
  }
}

///|
test "skia To caret uses kerned glyph origin for visual cursor guard" {
  match skia_test_font(@core.FontSpec::new(size=24.0, weight=400)) {
    Some(font) => {
      guard @skia_native.skia_shaper_available() else { return () }
      let input = @core.TextLayoutInput::new(
        text="To",
        font=@core.FontSpec::new(size=24.0, weight=400),
      )
      guard skia_font_can_measure_text(font, input.text) else { return () }
      let fallback = @core.TextSystem::fallback().measure_text(input)
      let glyph_run = skia_glyph_run_with_shaper(
        font,
        input.text,
        use_shaper=true,
      )
      guard glyph_run.glyphs.length() == 2 && glyph_run.positions.length() == 2 else {
        return ()
      }
      let kerned_o_origin = glyph_run.positions[1].x.to_double()
      let layout = skia_text_layout_result(font, input, fallback, glyph_run~)
      assert_true((layout.caret_positions[1] - kerned_o_origin).abs() < 0.001)
      assert_true(layout.caret_positions[2] == glyph_run.width)
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
      let glyph_run = skia_glyph_run_with_shaper(
        font,
        input.text,
        use_shaper=true,
      )
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
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(9.0, 0.0),
      @moui_skia.Point::new(21.0, 0.0),
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
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(18.0, 0.0),
    ],
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
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(10.0, 0.0),
      @moui_skia.Point::new(22.0, 0.0),
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
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(14.0, 0.0),
      @moui_skia.Point::new(28.0, 0.0),
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
test "skia shaped caret mapping stabilizes Indic cluster interiors" {
  let matra_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(11.0, 0.0),
      @moui_skia.Point::new(24.0, 0.0),
    ],
    clusters: [0, 1, 7],
    width: 32.0,
  }
  match skia_shaped_caret_positions("A\u{0915}\u{093F}B", matra_run) {
    Some(carets) => {
      inspect(carets.length(), content="5")
      inspect(carets[0], content="0")
      inspect(carets[1], content="11")
      inspect(carets[2], content="11")
      inspect(carets[3], content="24")
      inspect(carets[4], content="32")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected Devanagari matra shaped caret mapping")
  }

  let virama_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(20),
      @skia_native.GlyphId::new(21),
      @skia_native.GlyphId::new(22),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(10.0, 0.0),
      @moui_skia.Point::new(30.0, 0.0),
    ],
    clusters: [0, 1, 13],
    width: 38.0,
  }
  match
    skia_shaped_caret_positions(
      "A\u{0915}\u{094D}\u{200D}\u{0937}B", virama_run,
    ) {
    Some(carets) => {
      inspect(carets.length(), content="7")
      inspect(carets[0], content="0")
      inspect(carets[1], content="10")
      inspect(carets[2], content="10")
      inspect(carets[3], content="10")
      inspect(carets[4], content="10")
      inspect(carets[5], content="30")
      inspect(carets[6], content="38")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected Devanagari virama ZWJ shaped caret mapping")
  }
}

///|
test "skia shaped caret mapping stabilizes Hangul Jamo cluster interiors" {
  let hangul_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(9.0, 0.0),
      @moui_skia.Point::new(26.0, 0.0),
    ],
    clusters: [0, 1, 10],
    width: 34.0,
  }
  match skia_shaped_caret_positions("A\u{1100}\u{1161}\u{11A8}B", hangul_run) {
    Some(carets) => {
      inspect(carets.length(), content="6")
      inspect(carets[0], content="0")
      inspect(carets[1], content="9")
      inspect(carets[2], content="9")
      inspect(carets[3], content="9")
      inspect(carets[4], content="26")
      inspect(carets[5], content="34")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected Hangul Jamo shaped caret mapping")
  }
}

///|
test "skia shaped caret mapping stabilizes representative cluster interiors" {
  let combining_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(10),
      @skia_native.GlyphId::new(11),
      @skia_native.GlyphId::new(12),
      @skia_native.GlyphId::new(13),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(7.0, 0.0),
      @moui_skia.Point::new(13.0, 0.0),
      @moui_skia.Point::new(16.0, 0.0),
    ],
    clusters: [0, 1, 2, 4],
    width: 24.0,
  }
  match skia_shaped_caret_positions("Ae\u{0301}B", combining_run) {
    Some(carets) => {
      inspect(carets.length(), content="5")
      inspect(carets[0], content="0")
      inspect(carets[1], content="7")
      inspect(carets[2], content="7")
      inspect(carets[3], content="16")
      inspect(carets[4], content="24")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected combining-mark shaped caret mapping")
  }

  let skin_tone_run = SkiaGlyphRun::{
    glyphs: [
      @skia_native.GlyphId::new(20),
      @skia_native.GlyphId::new(21),
      @skia_native.GlyphId::new(22),
      @skia_native.GlyphId::new(23),
    ],
    positions: [
      @moui_skia.Point::new(0.0, 0.0),
      @moui_skia.Point::new(12.0, 0.0),
      @moui_skia.Point::new(18.0, 0.0),
      @moui_skia.Point::new(26.0, 0.0),
    ],
    clusters: [0, 1, 5, 9],
    width: 34.0,
  }
  match skia_shaped_caret_positions("A\u{1F44B}\u{1F3FD}B", skin_tone_run) {
    Some(carets) => {
      inspect(carets.length(), content="5")
      inspect(carets[0], content="0")
      inspect(carets[1], content="12")
      inspect(carets[2], content="12")
      inspect(carets[3], content="26")
      inspect(carets[4], content="34")
      assert_true(skia_test_carets_are_monotonic(carets))
    }
    None => fail("expected emoji-modifier shaped caret mapping")
  }
}

///|
test "skia fallback caret stabilization keeps representative cluster interiors stable" {
  let combining = skia_stabilize_grapheme_cluster_carets("Ae\u{0301}B", [
    0.0, 7.0, 13.0, 16.0, 24.0,
  ])
  inspect(combining.length(), content="5")
  inspect(combining[0], content="0")
  inspect(combining[1], content="7")
  inspect(combining[2], content="7")
  inspect(combining[3], content="16")
  inspect(combining[4], content="24")
  assert_true(skia_test_carets_are_monotonic(combining))

  let variation = skia_stabilize_grapheme_cluster_carets("A\u{2615}\u{FE0F}B", [
    0.0, 10.0, 18.0, 22.0, 30.0,
  ])
  inspect(variation.length(), content="5")
  inspect(variation[0], content="0")
  inspect(variation[1], content="10")
  inspect(variation[2], content="10")
  inspect(variation[3], content="22")
  inspect(variation[4], content="30")
  assert_true(skia_test_carets_are_monotonic(variation))

  let zwj = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F469}\u{200D}\u{1F373}B",
    [0.0, 14.0, 20.0, 22.0, 28.0, 34.0],
  )
  inspect(zwj.length(), content="6")
  inspect(zwj[0], content="0")
  inspect(zwj[1], content="14")
  inspect(zwj[2], content="14")
  inspect(zwj[3], content="14")
  inspect(zwj[4], content="28")
  inspect(zwj[5], content="34")
  assert_true(skia_test_carets_are_monotonic(zwj))

  let variation_zwj = skia_stabilize_grapheme_cluster_carets(
    "A\u{2764}\u{FE0F}\u{200D}\u{1F525}B",
    [0.0, 8.0, 12.0, 14.0, 16.0, 26.0, 30.0],
  )
  inspect(variation_zwj.length(), content="7")
  inspect(variation_zwj[0], content="0")
  inspect(variation_zwj[1], content="8")
  inspect(variation_zwj[2], content="8")
  inspect(variation_zwj[3], content="8")
  inspect(variation_zwj[4], content="8")
  inspect(variation_zwj[5], content="26")
  inspect(variation_zwj[6], content="30")
  assert_true(skia_test_carets_are_monotonic(variation_zwj))

  let flag = skia_stabilize_grapheme_cluster_carets("A\u{1F1FA}\u{1F1F8}B", [
    0.0, 11.0, 18.0, 27.0, 34.0,
  ])
  inspect(flag.length(), content="5")
  inspect(flag[0], content="0")
  inspect(flag[1], content="11")
  inspect(flag[2], content="11")
  inspect(flag[3], content="27")
  inspect(flag[4], content="34")
  assert_true(skia_test_carets_are_monotonic(flag))

  let paired_flags = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F1FA}\u{1F1F8}\u{1F1EF}\u{1F1F5}B",
    [0.0, 9.0, 13.0, 21.0, 27.0, 35.0, 43.0],
  )
  inspect(paired_flags.length(), content="7")
  inspect(paired_flags[0], content="0")
  inspect(paired_flags[1], content="9")
  inspect(paired_flags[2], content="9")
  inspect(paired_flags[3], content="21")
  inspect(paired_flags[4], content="21")
  inspect(paired_flags[5], content="35")
  inspect(paired_flags[6], content="43")
  assert_true(skia_test_carets_are_monotonic(paired_flags))

  let tag_flag = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B",
    [0.0, 9.0, 11.0, 13.0, 15.0, 25.0, 33.0],
  )
  inspect(tag_flag.length(), content="7")
  inspect(tag_flag[0], content="0")
  inspect(tag_flag[1], content="9")
  inspect(tag_flag[2], content="9")
  inspect(tag_flag[3], content="9")
  inspect(tag_flag[4], content="9")
  inspect(tag_flag[5], content="25")
  inspect(tag_flag[6], content="33")
  assert_true(skia_test_carets_are_monotonic(tag_flag))

  let keycap = skia_stabilize_grapheme_cluster_carets("A1\u{FE0F}\u{20E3}B", [
    0.0, 9.0, 13.0, 15.0, 24.0, 31.0,
  ])
  inspect(keycap.length(), content="6")
  inspect(keycap[0], content="0")
  inspect(keycap[1], content="9")
  inspect(keycap[2], content="9")
  inspect(keycap[3], content="9")
  inspect(keycap[4], content="24")
  inspect(keycap[5], content="31")
  assert_true(skia_test_carets_are_monotonic(keycap))

  let skin_tone = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F44B}\u{1F3FD}B",
    [0.0, 12.0, 18.0, 26.0, 34.0],
  )
  inspect(skin_tone.length(), content="5")
  inspect(skin_tone[0], content="0")
  inspect(skin_tone[1], content="12")
  inspect(skin_tone[2], content="12")
  inspect(skin_tone[3], content="26")
  inspect(skin_tone[4], content="34")
  assert_true(skia_test_carets_are_monotonic(skin_tone))

  let skin_tone_zwj = skia_stabilize_grapheme_cluster_carets(
    "A\u{1F9D1}\u{1F3FD}\u{200D}\u{1F4BB}B",
    [0.0, 10.0, 14.0, 16.0, 18.0, 30.0, 38.0],
  )
  inspect(skin_tone_zwj.length(), content="7")
  inspect(skin_tone_zwj[0], content="0")
  inspect(skin_tone_zwj[1], content="10")
  inspect(skin_tone_zwj[2], content="10")
  inspect(skin_tone_zwj[3], content="10")
  inspect(skin_tone_zwj[4], content="10")
  inspect(skin_tone_zwj[5], content="30")
  inspect(skin_tone_zwj[6], content="38")
  assert_true(skia_test_carets_are_monotonic(skin_tone_zwj))
}

///|
test "skia fallback caret stabilization keeps Indic and Arabic marks stable" {
  let devanagari_matra = skia_stabilize_grapheme_cluster_carets(
    "A\u{0915}\u{093F}B",
    [0.0, 8.0, 14.0, 22.0, 30.0],
  )
  inspect(devanagari_matra.length(), content="5")
  inspect(devanagari_matra[0], content="0")
  inspect(devanagari_matra[1], content="8")
  inspect(devanagari_matra[2], content="8")
  inspect(devanagari_matra[3], content="22")
  inspect(devanagari_matra[4], content="30")
  assert_true(skia_test_carets_are_monotonic(devanagari_matra))

  let devanagari_conjunct = skia_stabilize_grapheme_cluster_carets(
    "A\u{0915}\u{094D}\u{200D}\u{0937}B",
    [0.0, 10.0, 14.0, 16.0, 20.0, 30.0, 38.0],
  )
  inspect(devanagari_conjunct.length(), content="7")
  inspect(devanagari_conjunct[0], content="0")
  inspect(devanagari_conjunct[1], content="10")
  inspect(devanagari_conjunct[2], content="10")
  inspect(devanagari_conjunct[3], content="10")
  inspect(devanagari_conjunct[4], content="10")
  inspect(devanagari_conjunct[5], content="30")
  inspect(devanagari_conjunct[6], content="38")
  assert_true(skia_test_carets_are_monotonic(devanagari_conjunct))

  let devanagari_no_zwj_conjunct = skia_stabilize_grapheme_cluster_carets(
    "A\u{0915}\u{094D}\u{0937}B",
    [0.0, 10.0, 14.0, 20.0, 30.0, 38.0],
  )
  inspect(devanagari_no_zwj_conjunct.length(), content="6")
  inspect(devanagari_no_zwj_conjunct[0], content="0")
  inspect(devanagari_no_zwj_conjunct[1], content="10")
  inspect(devanagari_no_zwj_conjunct[2], content="10")
  inspect(devanagari_no_zwj_conjunct[3], content="10")
  inspect(devanagari_no_zwj_conjunct[4], content="30")
  inspect(devanagari_no_zwj_conjunct[5], content="38")
  assert_true(skia_test_carets_are_monotonic(devanagari_no_zwj_conjunct))

  let arabic_marks = skia_stabilize_grapheme_cluster_carets(
    "A\u{0646}\u{0651}\u{064E}B",
    [0.0, 9.0, 13.0, 15.0, 24.0, 31.0],
  )
  inspect(arabic_marks.length(), content="6")
  inspect(arabic_marks[0], content="0")
  inspect(arabic_marks[1], content="9")
  inspect(arabic_marks[2], content="9")
  inspect(arabic_marks[3], content="9")
  inspect(arabic_marks[4], content="24")
  inspect(arabic_marks[5], content="31")
  assert_true(skia_test_carets_are_monotonic(arabic_marks))

  let arabic_prepend = skia_stabilize_grapheme_cluster_carets(
    "A\u{0600}\u{0628}\u{0651}B",
    [0.0, 8.0, 11.0, 14.0, 23.0, 31.0],
  )
  inspect(arabic_prepend.length(), content="6")
  inspect(arabic_prepend[0], content="0")
  inspect(arabic_prepend[1], content="8")
  inspect(arabic_prepend[2], content="8")
  inspect(arabic_prepend[3], content="8")
  inspect(arabic_prepend[4], content="23")
  inspect(arabic_prepend[5], content="31")
  assert_true(skia_test_carets_are_monotonic(arabic_prepend))
}

///|
test "skia fallback caret stabilization keeps Southeast and South Asian marks stable" {
  let thai_mark = skia_stabilize_grapheme_cluster_carets("A\u{0E01}\u{0E34}B", [
    0.0, 8.0, 13.0, 21.0, 29.0,
  ])
  inspect(thai_mark.length(), content="5")
  inspect(thai_mark[0], content="0")
  inspect(thai_mark[1], content="8")
  inspect(thai_mark[2], content="8")
  inspect(thai_mark[3], content="21")
  inspect(thai_mark[4], content="29")
  assert_true(skia_test_carets_are_monotonic(thai_mark))

  let lao_mark = skia_stabilize_grapheme_cluster_carets("A\u{0E81}\u{0EB4}B", [
    0.0, 8.0, 13.0, 21.0, 29.0,
  ])
  inspect(lao_mark.length(), content="5")
  inspect(lao_mark[0], content="0")
  inspect(lao_mark[1], content="8")
  inspect(lao_mark[2], content="8")
  inspect(lao_mark[3], content="21")
  inspect(lao_mark[4], content="29")
  assert_true(skia_test_carets_are_monotonic(lao_mark))

  let sinhala_vowel = skia_stabilize_grapheme_cluster_carets(
    "A\u{0D9A}\u{0DCF}B",
    [0.0, 9.0, 15.0, 24.0, 31.0],
  )
  inspect(sinhala_vowel.length(), content="5")
  inspect(sinhala_vowel[0], content="0")
  inspect(sinhala_vowel[1], content="9")
  inspect(sinhala_vowel[2], content="9")
  inspect(sinhala_vowel[3], content="24")
  inspect(sinhala_vowel[4], content="31")
  assert_true(skia_test_carets_are_monotonic(sinhala_vowel))

  let sinhala_virama = skia_stabilize_grapheme_cluster_carets(
    "A\u{0D9A}\u{0DCA}\u{0DBB}B",
    [0.0, 9.0, 13.0, 18.0, 25.0, 32.0],
  )
  inspect(sinhala_virama.length(), content="6")
  inspect(sinhala_virama[0], content="0")
  inspect(sinhala_virama[1], content="9")
  inspect(sinhala_virama[2], content="9")
  inspect(sinhala_virama[3], content="18")
  inspect(sinhala_virama[4], content="25")
  inspect(sinhala_virama[5], content="32")
  assert_true(skia_test_carets_are_monotonic(sinhala_virama))

  let khmer_vowel = skia_stabilize_grapheme_cluster_carets(
    "A\u{1780}\u{17B6}B",
    [0.0, 9.0, 15.0, 24.0, 31.0],
  )
  inspect(khmer_vowel.length(), content="5")
  inspect(khmer_vowel[0], content="0")
  inspect(khmer_vowel[1], content="9")
  inspect(khmer_vowel[2], content="9")
  inspect(khmer_vowel[3], content="24")
  inspect(khmer_vowel[4], content="31")
  assert_true(skia_test_carets_are_monotonic(khmer_vowel))

  let khmer_coeng = skia_stabilize_grapheme_cluster_carets(
    "A\u{1780}\u{17D2}\u{179A}B",
    [0.0, 9.0, 13.0, 18.0, 25.0, 32.0],
  )
  inspect(khmer_coeng.length(), content="6")
  inspect(khmer_coeng[0], content="0")
  inspect(khmer_coeng[1], content="9")
  inspect(khmer_coeng[2], content="9")
  inspect(khmer_coeng[3], content="9")
  inspect(khmer_coeng[4], content="25")
  inspect(khmer_coeng[5], content="32")
  assert_true(skia_test_carets_are_monotonic(khmer_coeng))

  let myanmar_conjunct = skia_stabilize_grapheme_cluster_carets(
    "A\u{1000}\u{1039}\u{1001}B",
    [0.0, 10.0, 14.0, 18.0, 25.0, 32.0],
  )
  inspect(myanmar_conjunct.length(), content="6")
  inspect(myanmar_conjunct[0], content="0")
  inspect(myanmar_conjunct[1], content="10")
  inspect(myanmar_conjunct[2], content="10")
  inspect(myanmar_conjunct[3], content="10")
  inspect(myanmar_conjunct[4], content="25")
  inspect(myanmar_conjunct[5], content="32")
  assert_true(skia_test_carets_are_monotonic(myanmar_conjunct))

  let myanmar_mark = skia_stabilize_grapheme_cluster_carets(
    "A\u{1000}\u{103A}B",
    [0.0, 10.0, 14.0, 22.0, 30.0],
  )
  inspect(myanmar_mark.length(), content="5")
  inspect(myanmar_mark[0], content="0")
  inspect(myanmar_mark[1], content="10")
  inspect(myanmar_mark[2], content="10")
  inspect(myanmar_mark[3], content="22")
  inspect(myanmar_mark[4], content="30")
  assert_true(skia_test_carets_are_monotonic(myanmar_mark))
}

///|
test "skia fallback caret stabilization keeps Hangul Jamo clusters stable" {
  assert_true(@render_common.codepoint_is_hangul_l(0x1100))
  assert_true(@render_common.codepoint_is_hangul_l(0xA960))
  assert_true(@render_common.codepoint_is_hangul_v(0x1161))
  assert_true(@render_common.codepoint_is_hangul_v(0xD7B0))
  assert_true(@render_common.codepoint_is_hangul_t(0x11A8))
  assert_true(@render_common.codepoint_is_hangul_t(0xD7CB))
  assert_true(@render_common.codepoint_is_hangul_lv(0xAC00))
  assert_true(@render_common.codepoint_is_hangul_lvt(0xAC01))
  assert_false(@render_common.codepoint_is_hangul_cluster_codepoint(0x3131))

  let modern_jamo = skia_stabilize_grapheme_cluster_carets(
    "A\u{1100}\u{1161}\u{11A8}B",
    [0.0, 9.0, 13.0, 18.0, 26.0, 34.0],
  )
  inspect(modern_jamo.length(), content="6")
  inspect(modern_jamo[0], content="0")
  inspect(modern_jamo[1], content="9")
  inspect(modern_jamo[2], content="9")
  inspect(modern_jamo[3], content="9")
  inspect(modern_jamo[4], content="26")
  inspect(modern_jamo[5], content="34")
  assert_true(skia_test_carets_are_monotonic(modern_jamo))

  let extended_jamo = skia_stabilize_grapheme_cluster_carets(
    "A\u{A960}\u{D7B0}\u{D7CB}B",
    [0.0, 8.0, 12.0, 17.0, 25.0, 33.0],
  )
  inspect(extended_jamo.length(), content="6")
  inspect(extended_jamo[0], content="0")
  inspect(extended_jamo[1], content="8")
  inspect(extended_jamo[2], content="8")
  inspect(extended_jamo[3], content="8")
  inspect(extended_jamo[4], content="25")
  inspect(extended_jamo[5], content="33")
  assert_true(skia_test_carets_are_monotonic(extended_jamo))

  let lv_plus_trailing = skia_stabilize_grapheme_cluster_carets(
    "A\u{AC00}\u{11A8}B",
    [0.0, 9.0, 14.0, 24.0, 31.0],
  )
  inspect(lv_plus_trailing.length(), content="5")
  inspect(lv_plus_trailing[0], content="0")
  inspect(lv_plus_trailing[1], content="9")
  inspect(lv_plus_trailing[2], content="9")
  inspect(lv_plus_trailing[3], content="24")
  inspect(lv_plus_trailing[4], content="31")
  assert_true(skia_test_carets_are_monotonic(lv_plus_trailing))
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
    positions: [@moui_skia.Point::new(0.0, 0.0)],
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
  let system = skia_text_system(resolution=SkiaFontResolution::SystemFontMgr)
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

///|
/// The SkShaper path falls back to system fonts while shaping, but painting
/// maps glyph ids through the payload's primary typeface. When the primary
/// font does not cover the text itself, those ids reference unrelated glyphs
/// and the run paints blank on GPU canvases even though the run reports
/// complete coverage. The payload font must map every character through its
/// own cmap.
test "skia cjk text payload draws with a typeface covering that text" {
  guard skia_test_native_text_available() else { return () }
  let font_spec = @core.FontSpec::new(size=16.0, weight=400)
  let text = "应用逻辑。原生宿主"
  match
    skia_draw_text_payload_for_resolution(
      font_spec,
      text,
      SkiaFontResolution::SystemFontMgr,
    ) {
    None => ()
    Some((font, _)) => {
      if !skia_font_covers_text(font, text) {
        let host_has_cjk = match @skia_native.FontMgr::default() {
          None => false
          Some(mgr) =>
            match mgr.match_family_style_character(b"", [], 0x5E94) {
              None => false
              Some(_) => true
            }
        }
        assert_true(!host_has_cjk)
      }
    }
  }
}

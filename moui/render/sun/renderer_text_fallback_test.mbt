///|
test "sun renderer text system measures mixed emoji through registered fallback faces" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinOnly"),
    sun_test_ttf_for_codes([65]),
  )
  text_system.register_font_data(
    @core.FontFamily::Emoji,
    sun_test_ttf_for_codes([0x1F600]),
  )

  let text = sun_test_string_from_codepoints([65, 0x1F600])
  let result = text_system.measure_text(
    @core.TextLayoutInput::new(
      text~,
      font=@core.FontSpec::new(
        families=@core.FontFamilyStack::new([
          @core.FontFamily::Name("SunLatinOnly"),
        ]),
        size=10.0,
      ),
      max_width=100.0,
    ),
  )

  inspect(result.size.width, content="20")
  inspect(result.caret_positions.length(), content="3")
  assert_true(result.caret_positions[0] == 0.0)
  assert_true(result.caret_positions[1] > result.caret_positions[0])
  assert_true(result.caret_positions[2] > result.caret_positions[1])
}

///|
test "sun renderer draws mixed emoji text without missing fallback diagnostic" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinOnly"),
    sun_test_ttf_for_codes([65]),
  )
  text_system.register_font_data(
    @core.FontFamily::Emoji,
    sun_test_ttf_for_codes([0x1F600]),
  )

  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=sun_test_string_from_codepoints([65, 0x1F600]),
        frame=@core.Rect::new(x=0.0, y=0.0, width=48.0, height=16.0),
        font=@core.FontSpec::new(
          families=@core.FontFamilyStack::new([
            @core.FontFamily::Name("SunLatinOnly"),
          ]),
          size=10.0,
        ),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
  ])

  inspect(renderer.unsupported_command_count(), content="0")
}

///|
test "sun renderer registers font file for requested family" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  let path = sun_renderer_text_temp_path("moui-sun-renderer-font-file.ttf")
  @fs.write_bytes_to_file(path, sun_test_ttf_for_codes([65, 66])) catch {
    _ => fail("failed to write Sun renderer font fixture")
  }

  renderer.register_font_file("sun-file-font", path)
  let result = renderer
    .text_system()
    .measure_text(
      @core.TextLayoutInput::new(
        text="AB",
        font=@core.FontSpec::new(
          families=@core.FontFamilyStack::new([
            @core.FontFamily::Name("sun-file-font"),
          ]),
          size=10.0,
        ),
        max_width=100.0,
      ),
    )

  inspect(result.size.width, content="20")
  inspect(result.caret_positions.length(), content="3")
}

///|
test "sun renderer text drawing clips glyphs to the TextRun frame" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinOnly"),
    sun_test_ttf_for_codes([65]),
  )

  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="AAAAAA",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=16.0),
        font=@core.FontSpec::new(
          families=@core.FontFamilyStack::new([
            @core.FontFamily::Name("SunLatinOnly"),
          ]),
          size=10.0,
        ),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
  ])

  match presented.val {
    Some(frame) => {
      assert_false(
        sun_text_test_region_has_dark_pixel(
          frame,
          @core.Rect::new(x=8.0, y=0.0, width=32.0, height=16.0),
        ),
      )
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer text drawing scales nonzero 2x frame without hiding glyphs" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=64.0, height=32.0),
      scale_factor=2.0,
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinOnly"),
    sun_test_ttf_for_codes([65]),
  )

  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="A",
        frame=@core.Rect::new(x=20.0, y=8.0, width=24.0, height=16.0),
        font=@core.FontSpec::new(
          families=@core.FontFamilyStack::new([
            @core.FontFamily::Name("SunLatinOnly"),
          ]),
          size=10.0,
        ),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
  ])

  match presented.val {
    Some(frame) => {
      inspect(frame.width, content="128")
      inspect(frame.height, content="64")
      assert_true(
        sun_text_test_region_has_dark_pixel(
          frame,
          @core.Rect::new(x=40.0, y=32.0, width=24.0, height=16.0),
        ),
      )
      assert_false(
        sun_text_test_region_has_dark_pixel(
          frame,
          @core.Rect::new(x=20.0, y=10.0, width=20.0, height=10.0),
        ),
      )
      assert_false(
        sun_text_test_region_has_dark_pixel(
          frame,
          @core.Rect::new(x=88.0, y=16.0, width=32.0, height=32.0),
        ),
      )
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
test "sun renderer text system reports renderer paragraph metadata" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  inspect(text_system.id(), content="sun-raster-text-system")
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinOnly"),
    sun_test_ttf_for_codes([65]),
  )
  let paragraph = text_system.layout_paragraph(
    @core.TextLayoutInput::new(
      text="A",
      font=@core.FontSpec::new(
        families=@core.FontFamilyStack::new([
          @core.FontFamily::Name("SunLatinOnly"),
        ]),
        size=10.0,
      ),
      max_width=100.0,
    ),
  )
  inspect(paragraph.metadata.text_system_id, content="sun-raster-text-system")
  assert_true(paragraph.metadata.paragraph_layout_available)
}

///|
test "sun renderer text maturity diagnostic separates geometry readiness from gaps" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  renderer.register_font_bytes("sun-diag", sun_test_ttf_for_codes([65, 0x20]))
  let diagnostic = renderer.text_maturity_diagnostic(text="A A", max_width=12.0)
  inspect(diagnostic.text_system_id, content="sun-raster-text-system")
  assert_true(diagnostic.registered_font_count >= 1)
  assert_true(diagnostic.paragraph_layout_ready)
  assert_true(diagnostic.line_metrics_ready)
  assert_true(diagnostic.selection_rects_ready)
  assert_true(diagnostic.hit_test_ready)
  assert_true(diagnostic.bidi_visual_order_ready)
  assert_false(diagnostic.native_paragraph_ready)
  assert_false(diagnostic.color_emoji_ready)
  assert_true(diagnostic.paragraph_line_count >= 2)
  assert_true(diagnostic.selection_rect_count > 0)
  assert_true(diagnostic.hit_test_inside)
  inspect(diagnostic.ready_count, content="7")
  inspect(diagnostic.gap_count, content="2")
  assert_true(diagnostic.summary().contains("Sun text maturity audit partial"))
  assert_true(diagnostic.summary().contains("paragraph geometry ready"))
  assert_true(
    diagnostic.summary().contains("Unicode 17 grapheme boundary contract ready"),
  )
  assert_true(
    diagnostic
    .summary()
    .contains("bidi ready; native paragraph/color emoji pending"),
  )
}

///|
test "sun renderer text selection diagnostic records wrapped geometry" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  renderer.register_font_bytes("sun-diag", sun_test_ttf_for_codes([65, 0x20]))
  let diagnostic = renderer.text_selection_geometry_diagnostic(
    text="A A",
    selection=Some(@core.TextRange::new(start=0, end=3)),
    max_width=12.0,
  )
  inspect(diagnostic.text, content="A A")
  inspect(diagnostic.selection_range.start, content="0")
  inspect(diagnostic.selection_range.end, content="3")
  assert_true(diagnostic.selection_rect_count >= 2)
  assert_true(diagnostic.selected_line_count >= 2)
  assert_true(diagnostic.line_count >= 2)
  assert_true(diagnostic.hit_test_inside)
  assert_true(diagnostic.hit_test_offset >= 0)
  assert_true(diagnostic.hit_test_line_index >= 0)
  assert_true(diagnostic.bidi_visual_order_ready)
  assert_false(diagnostic.visual_order_differs)
  inspect(diagnostic.visual_segment_count, content="1")
  assert_false(diagnostic.bidi_visual_order_observed)
}

///|
test "sun renderer text selection diagnostic observes rtl visual order" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=96.0, height=24.0),
    ),
    target,
  )
  renderer.register_font_bytes(
    "sun-bidi-diag",
    sun_test_ttf_for_codes([
      0x20, 0x31, 0x32, 0x33, 65, 66, 67, 0x05D0, 0x05D1, 0x05D2,
    ]),
  )
  let diagnostic = renderer.text_selection_geometry_diagnostic(
    text="ABC \u{05D0}\u{05D1}\u{05D2} 123",
    max_width=96.0,
  )
  assert_true(diagnostic.bidi_visual_order_ready)
  assert_true(diagnostic.visual_order_differs)
  inspect(diagnostic.visual_segment_count, content="3")
  assert_true(diagnostic.bidi_visual_order_observed)
}

///|
test "sun renderer text visual order diagnostic records rtl metadata" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=96.0, height=24.0),
    ),
    target,
  )
  renderer.register_font_bytes(
    "sun-visual-order",
    sun_test_ttf_for_codes([
      0x20, 0x31, 0x32, 0x33, 65, 66, 67, 0x05D0, 0x05D1, 0x05D2,
    ]),
  )

  guard renderer.text_visual_order_diagnostic(
      "ABC \u{05D0}\u{05D1}\u{05D2} 123",
      font=@core.FontSpec::new(
        families=@core.FontFamilyStack::new([
          @core.FontFamily::Name("sun-visual-order"),
        ]),
        size=10.0,
      ),
    )
    is Some(diagnostic) else {
    fail("expected Sun visual order diagnostic")
  }
  inspect(diagnostic.logical_text, content="ABC \u{05D0}\u{05D1}\u{05D2} 123")
  inspect(diagnostic.visual_text, content="ABC \u{05D2}\u{05D1}\u{05D0} 123")
  assert_true(diagnostic.bidi_visual_order_ready)
  assert_true(diagnostic.visual_order_differs)
  inspect(diagnostic.logical_cluster_count, content="11")
  inspect(diagnostic.visual_cluster_count, content="11")
  inspect(diagnostic.segment_count, content="3")
  inspect(diagnostic.glyph_count, content="11")
  assert_true(diagnostic.width > 0.0)
}

///|
test "sun renderer text selection diagnostic defaults to wrapped line range" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  renderer.register_font_bytes("sun-diag", sun_test_ttf_for_codes([65, 0x20]))
  let diagnostic = renderer.text_selection_geometry_diagnostic(
    text="A A",
    max_width=12.0,
  )
  inspect(diagnostic.selection_range.start, content="0")
  inspect(diagnostic.selection_range.end, content="3")
  assert_true(diagnostic.selected_line_count >= 2)
  assert_true(diagnostic.selection_rect_count >= 2)
}

///|
test "sun renderer text selection diagnostic normalizes grapheme range" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  renderer.register_font_bytes(
    "sun-combining",
    sun_test_ttf_for_codes([65, 0x65, 0x0301, 66]),
  )
  let diagnostic = renderer.text_selection_geometry_diagnostic(
    text="Ae\u{0301}B",
    selection=Some(@core.TextRange::new(start=2, end=3)),
    max_width=96.0,
  )
  inspect(diagnostic.selection_range.start, content="1")
  inspect(diagnostic.selection_range.end, content="3")
  assert_true(diagnostic.selection_rect_count >= 1)
  inspect(diagnostic.visual_segment_count, content="3")
  assert_false(diagnostic.bidi_visual_order_observed)
}

///|
test "sun renderer emoji fallback diagnostic reports registered font fallback without color proof" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinOnly"),
    sun_test_ttf_for_codes([65]),
  )
  text_system.register_font_data(
    @core.FontFamily::Emoji,
    sun_test_ttf_for_codes([0x1F600]),
  )
  let diagnostic = renderer.emoji_font_fallback_diagnostic(
    text=sun_test_string_from_codepoints([65, 0x1F600]),
    font=@core.FontSpec::new(
      families=@core.FontFamilyStack::new([
        @core.FontFamily::Name("SunLatinOnly"),
      ]),
      size=10.0,
    ),
  )
  inspect(diagnostic.text_system_id, content="sun-raster-text-system")
  inspect(diagnostic.requested_font_family, content="SunLatinOnly")
  inspect(diagnostic.font_source, content="sun-registered-font-chain")
  inspect(diagnostic.shaper, content="font-fallback-plan")
  assert_true(diagnostic.resolved_fallback_face_index > 0)
  inspect(
    diagnostic.resolved_font_name,
    content="sun-registered-face-\{diagnostic.resolved_fallback_face_index}",
  )
  inspect(diagnostic.fallback_language_tags.length(), content="2")
  inspect(diagnostic.fallback_language_tags[0], content="und-Zsye")
  inspect(diagnostic.fallback_language_tags[1], content="en")
  inspect(diagnostic.fallback_script_tag, content="und-Zsye")
  inspect(diagnostic.fallback_language_tag_count, content="2")
  inspect(diagnostic.fallback_request_language_count, content="2")
  assert_true(diagnostic.registered_font_count >= 2)
  assert_true(diagnostic.resolved_face_count >= 2)
  assert_true(diagnostic.span_count >= 2)
  assert_true(diagnostic.fallback_span_count >= 1)
  inspect(diagnostic.missing_char_count, content="0")
  inspect(diagnostic.covered_char_count, content="2")
  assert_true(diagnostic.emoji_hint)
  assert_true(diagnostic.emoji_fallback_attempted)
  assert_true(diagnostic.fallback_request_ready)
  assert_true(diagnostic.registered_font_fallback_ready)
  assert_true(diagnostic.missing_glyph_recovery_ready)
  assert_false(diagnostic.deterministic_color_emoji_ready)
  inspect(diagnostic.glyph_format, content="coverage-mask")
  assert_true(diagnostic.glyph_key.contains("sun-registered-font-chain"))
  assert_true(diagnostic.glyph_key.contains("sun-raster-text-system"))
  assert_true(diagnostic.glyph_key.contains("font-fallback-plan"))
  assert_true(
    diagnostic.glyph_key.contains(
      "resolved-face=\{diagnostic.resolved_fallback_face_index}",
    ),
  )
  assert_true(diagnostic.glyph_key.contains("script=und-Zsye"))
  assert_true(diagnostic.glyph_key.contains("langs=2"))
  assert_true(diagnostic.glyph_key.contains("lang-tags=und-Zsye+en"))
  assert_true(diagnostic.glyph_key.contains("format=coverage-mask"))
  inspect(diagnostic.glyph_count, content="2")
  inspect(diagnostic.cluster_count, content="2")
  assert_true(diagnostic.glyph_width > 0)
  assert_true(diagnostic.glyph_height > 0)
  inspect(diagnostic.resolved_missing_glyph_count, content="0")
  inspect(diagnostic.fallback_character, content="128512")
  assert_true(diagnostic.summary().contains("registered-font fallback ready"))
  assert_true(diagnostic.summary().contains("color emoji pending"))
}

///|
test "sun renderer fallback diagnostic prefers non ascii representative script metadata" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=48.0, height=16.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinOnly"),
    sun_test_ttf_for_codes([65]),
  )
  text_system.register_font_data(
    @core.FontFamily::Name("SunCjk"),
    sun_test_ttf_for_codes([0x4F60]),
  )
  let diagnostic = renderer.emoji_font_fallback_diagnostic(
    text=sun_test_string_from_codepoints([65, 0x4F60, 66]),
    font=@core.FontSpec::new(
      families=@core.FontFamilyStack::new([
        @core.FontFamily::Name("SunLatinOnly"),
      ]),
      size=10.0,
    ),
  )
  assert_false(diagnostic.emoji_hint)
  assert_true(diagnostic.fallback_request_ready)
  assert_true(diagnostic.resolved_fallback_face_index > 0)
  inspect(diagnostic.fallback_character, content="20320")
  inspect(diagnostic.fallback_language_tags.length(), content="2")
  inspect(diagnostic.fallback_language_tags[0], content="zh-Hans")
  inspect(diagnostic.fallback_language_tags[1], content="en")
  inspect(diagnostic.fallback_script_tag, content="zh-Hans")
  assert_true(diagnostic.glyph_key.contains("script=zh-Hans"))
  assert_true(diagnostic.glyph_key.contains("lang-tags=zh-Hans+en"))
}

///|
test "sun renderer text system wraps measured text to max width" {
  let target = SunPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=24.0, height=32.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinSpace"),
    sun_test_ttf_for_codes([65, 0x20]),
  )

  let result = text_system.measure_text(
    @core.TextLayoutInput::new(
      text="A A",
      font=@core.FontSpec::new(
        families=@core.FontFamilyStack::new([
          @core.FontFamily::Name("SunLatinSpace"),
        ]),
        size=10.0,
      ),
      max_width=12.0,
    ),
  )

  inspect(result.size.width, content="12")
  inspect(result.size.height, content="24")
  inspect(result.baseline, content="10")
  inspect(result.caret_positions.length(), content="4")
  assert_true(result.caret_positions[1] > 0.0)
  inspect(result.caret_positions[2], content="0")
  assert_true(result.caret_positions[3] > 0.0)
}

///|
test "sun renderer draws wrapped fallback text on later visual lines" {
  let presented = Ref(None)
  let target = SunPresentTarget::new(description="test", present=frame => {
    presented.val = Some(frame)
    true
  })
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=12.0, height=30.0),
    ),
    target,
  )
  let text_system = renderer.text_system()
  text_system.register_font_data(
    @core.FontFamily::Name("SunLatinSpace"),
    sun_test_ttf_for_codes([65, 0x20]),
  )

  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="A A",
        frame=@core.Rect::new(x=0.0, y=0.0, width=12.0, height=30.0),
        font=@core.FontSpec::new(
          families=@core.FontFamilyStack::new([
            @core.FontFamily::Name("SunLatinSpace"),
          ]),
          size=10.0,
        ),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
  ])

  match presented.val {
    Some(frame) => {
      assert_true(sun_test_dark_pixel_count(frame, row_start=0, row_end=14) > 0)
      assert_true(
        sun_test_dark_pixel_count(frame, row_start=14, row_end=30) > 0,
      )
      inspect(renderer.unsupported_command_count(), content="0")
    }
    None => fail("expected Sun frame")
  }
}

///|
fn sun_renderer_text_temp_path(filename : String) -> String {
  let dir = match @env.get_env_var("TMPDIR") {
    Some(value) => value
    None =>
      match @env.get_env_var("TEMP") {
        Some(value) => value
        None =>
          match @env.get_env_var("TMP") {
            Some(value) => value
            None => "/tmp"
          }
      }
  }
  if dir.has_suffix("/") || dir.has_suffix("\\") {
    dir + filename
  } else {
    dir + "/" + filename
  }
}

///|
priv struct SunTestGlyph {
  codepoint : Int
  advance : Int
  bytes : Array[Byte]
}

///|
priv struct SunTestPoint {
  x : Int
  y : Int
  on_curve : Bool
}

///|
priv struct SunTestContour {
  points : Array[SunTestPoint]
}

///|
priv struct SunTestOutline {
  contours : Array[SunTestContour]
  xmin : Int
  ymin : Int
  xmax : Int
  ymax : Int
}

///|
fn sun_test_ttf_for_codes(codepoints : Array[Int]) -> Bytes {
  let glyphs = []
  for codepoint in codepoints {
    glyphs.push(sun_test_glyph_for_codepoint(codepoint))
  }
  sun_test_ttf_with_glyphs(glyphs)
}

///|
fn sun_test_ttf_with_glyphs(glyphs : Array[SunTestGlyph]) -> Bytes {
  let tags : Array[Bytes] = [
    b"cmap", b"glyf", b"head", b"hhea", b"hmtx", b"loca", b"maxp",
  ]
  let tables = [
    sun_test_cmap_table(glyphs),
    sun_test_glyf_table(glyphs),
    sun_test_head_table(),
    sun_test_hhea_table(glyphs),
    sun_test_hmtx_table(glyphs),
    sun_test_loca_table(glyphs),
    sun_test_maxp_table(glyphs),
  ]
  let offsets = []
  let mut current = 12 + tags.length() * 16
  for table in tables {
    offsets.push(current)
    current = sun_test_align4(current + table.length())
  }

  let out : Array[Byte] = []
  sun_test_append_u32(out, 0x00010000)
  sun_test_append_u16(out, tags.length())
  sun_test_append_u16(out, 0)
  sun_test_append_u16(out, 0)
  sun_test_append_u16(out, 0)

  for i in 0..<tags.length() {
    sun_test_append_bytes(out, tags[i])
    sun_test_append_u32(out, 0)
    sun_test_append_u32(out, offsets[i])
    sun_test_append_u32(out, tables[i].length())
  }

  for i in 0..<tables.length() {
    while out.length() < offsets[i] {
      sun_test_append_byte(out, 0)
    }
    sun_test_append_array(out, tables[i])
    sun_test_pad4(out)
  }

  Bytes::from_array(out)
}

///|
fn sun_test_glyph_for_codepoint(codepoint : Int) -> SunTestGlyph {
  let bytes = if codepoint is 0x20 { [] } else { sun_test_box_glyph() }
  { codepoint, advance: if codepoint is 0x20 { 5 } else { 10 }, bytes }
}

///|
fn sun_test_head_table() -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u32(out, 0x00010000)
  sun_test_append_u32(out, 0)
  sun_test_append_u32(out, 0)
  sun_test_append_u32(out, 0x5F0F3CF5)
  sun_test_append_u16(out, 0)
  sun_test_append_u16(out, 10)
  sun_test_append_zeroes(out, 16)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 10)
  sun_test_append_i16(out, 10)
  sun_test_append_u16(out, 0)
  sun_test_append_u16(out, 0)
  sun_test_append_i16(out, 2)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 0)
  out
}

///|
fn sun_test_hhea_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u32(out, 0x00010000)
  sun_test_append_i16(out, 10)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 0)
  sun_test_append_u16(out, 10)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 10)
  sun_test_append_i16(out, 1)
  sun_test_append_i16(out, 0)
  sun_test_append_i16(out, 0)
  sun_test_append_zeroes(out, 8)
  sun_test_append_i16(out, 0)
  sun_test_append_u16(out, glyphs.length() + 1)
  out
}

///|
fn sun_test_hmtx_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u16(out, 0)
  sun_test_append_i16(out, 0)
  for glyph in glyphs {
    sun_test_append_u16(out, glyph.advance)
    sun_test_append_i16(out, 0)
  }
  out
}

///|
fn sun_test_maxp_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u32(out, 0x00010000)
  sun_test_append_u16(out, glyphs.length() + 1)
  out
}

///|
fn sun_test_loca_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u16(out, 0)
  let mut offset = 0
  for glyph in glyphs {
    sun_test_append_u16(out, offset / 2)
    offset = sun_test_align2(offset + glyph.bytes.length())
  }
  sun_test_append_u16(out, offset / 2)
  out
}

///|
fn sun_test_glyf_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  for glyph in glyphs {
    sun_test_append_array(out, glyph.bytes)
    while out.length() % 2 != 0 {
      sun_test_append_byte(out, 0)
    }
  }
  out
}

///|
fn sun_test_box_glyph() -> Array[Byte] {
  sun_test_simple_glyph({
    contours: [
      {
        points: [
          { x: 0, y: 10, on_curve: true },
          { x: 10, y: 10, on_curve: true },
          { x: 10, y: 0, on_curve: true },
          { x: 0, y: 0, on_curve: true },
        ],
      },
    ],
    xmin: 0,
    ymin: 0,
    xmax: 10,
    ymax: 10,
  })
}

///|
fn sun_test_simple_glyph(glyph : SunTestOutline) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_i16(out, glyph.contours.length())
  sun_test_append_i16(out, glyph.xmin)
  sun_test_append_i16(out, glyph.ymin)
  sun_test_append_i16(out, glyph.xmax)
  sun_test_append_i16(out, glyph.ymax)

  let points : Array[SunTestPoint] = []
  let mut end_point = -1
  for contour in glyph.contours {
    for point in contour.points {
      points.push(point)
      end_point = end_point + 1
    }
    sun_test_append_u16(out, end_point)
  }
  sun_test_append_u16(out, 0)

  let flags : Array[Int] = []
  let x_bytes : Array[Byte] = []
  let y_bytes : Array[Byte] = []
  let mut prev_x = 0
  let mut prev_y = 0
  for point in points {
    let dx = point.x - prev_x
    let dy = point.y - prev_y
    let mut flag = if point.on_curve { 0x01 } else { 0 }
    flag = flag.lor(sun_test_encode_x_delta(dx, x_bytes))
    flag = flag.lor(sun_test_encode_y_delta(dy, y_bytes))
    flags.push(flag)
    prev_x = point.x
    prev_y = point.y
  }

  for flag in flags {
    sun_test_append_byte(out, flag)
  }
  sun_test_append_array(out, x_bytes)
  sun_test_append_array(out, y_bytes)
  while out.length() % 2 != 0 {
    sun_test_append_byte(out, 0)
  }
  out
}

///|
fn sun_test_encode_x_delta(delta : Int, out : Array[Byte]) -> Int {
  if delta == 0 {
    0x10
  } else if delta.abs() <= 255 {
    sun_test_append_byte(out, delta.abs())
    if delta > 0 {
      0x12
    } else {
      0x02
    }
  } else {
    sun_test_append_i16(out, delta)
    0
  }
}

///|
fn sun_test_encode_y_delta(delta : Int, out : Array[Byte]) -> Int {
  if delta == 0 {
    0x20
  } else if delta.abs() <= 255 {
    sun_test_append_byte(out, delta.abs())
    if delta > 0 {
      0x24
    } else {
      0x04
    }
  } else {
    sun_test_append_i16(out, delta)
    0
  }
}

///|
fn sun_test_cmap_table(glyphs : Array[SunTestGlyph]) -> Array[Byte] {
  let out : Array[Byte] = []
  sun_test_append_u16(out, 0)
  sun_test_append_u16(out, 1)
  sun_test_append_u16(out, 3)
  sun_test_append_u16(out, 10)
  sun_test_append_u32(out, 12)
  sun_test_append_u16(out, 12)
  sun_test_append_u16(out, 0)
  sun_test_append_u32(out, 16 + glyphs.length() * 12)
  sun_test_append_u32(out, 0)
  sun_test_append_u32(out, glyphs.length())
  for i in 0..<glyphs.length() {
    sun_test_append_u32(out, glyphs[i].codepoint)
    sun_test_append_u32(out, glyphs[i].codepoint)
    sun_test_append_u32(out, i + 1)
  }
  out
}

///|
fn sun_test_append_u16(out : Array[Byte], value : Int) -> Unit {
  sun_test_append_byte(out, value >> 8)
  sun_test_append_byte(out, value)
}

///|
fn sun_test_append_i16(out : Array[Byte], value : Int) -> Unit {
  let unsigned = if value < 0 { value + 65536 } else { value }
  sun_test_append_u16(out, unsigned)
}

///|
fn sun_test_append_u32(out : Array[Byte], value : Int) -> Unit {
  sun_test_append_byte(out, value >> 24)
  sun_test_append_byte(out, value >> 16)
  sun_test_append_byte(out, value >> 8)
  sun_test_append_byte(out, value)
}

///|
fn sun_test_append_byte(out : Array[Byte], value : Int) -> Unit {
  out.push(value.land(0xFF).to_byte())
}

///|
fn sun_test_append_bytes(out : Array[Byte], bytes : Bytes) -> Unit {
  for i in 0..<bytes.length() {
    out.push(bytes[i])
  }
}

///|
fn sun_test_append_array(out : Array[Byte], bytes : Array[Byte]) -> Unit {
  for byte in bytes {
    out.push(byte)
  }
}

///|
fn sun_test_append_zeroes(out : Array[Byte], count : Int) -> Unit {
  for _ in 0..<count {
    sun_test_append_byte(out, 0)
  }
}

///|
fn sun_test_pad4(out : Array[Byte]) -> Unit {
  while out.length() % 4 != 0 {
    sun_test_append_byte(out, 0)
  }
}

///|
fn sun_test_align4(value : Int) -> Int {
  if value % 4 == 0 {
    value
  } else {
    value + 4 - value % 4
  }
}

///|
fn sun_test_align2(value : Int) -> Int {
  if value % 2 == 0 {
    value
  } else {
    value + 1
  }
}

///|
fn sun_test_string_from_codepoints(codepoints : Array[Int]) -> String {
  let out = StringBuilder(size_hint=codepoints.length())
  for codepoint in codepoints {
    out.write_char(codepoint.unsafe_to_char())
  }
  out.to_string()
}

///|
fn sun_test_dark_pixel_count(
  frame : SunPixelFrame,
  row_start~ : Int,
  row_end~ : Int,
) -> Int {
  let start = row_start.max(0).min(frame.height)
  let end = row_end.max(start).min(frame.height)
  let mut count = 0
  for row in start..<end {
    for column in 0..<frame.width {
      let offset = (row * frame.width + column) * 4
      let red = frame.pixels[offset].to_int()
      let green = frame.pixels[offset + 1].to_int()
      let blue = frame.pixels[offset + 2].to_int()
      if red < 220 && green < 220 && blue < 220 {
        count += 1
      }
    }
  }
  count
}

///|
fn sun_text_test_region_has_dark_pixel(
  frame : SunPixelFrame,
  rect : @core.Rect,
) -> Bool {
  let start_x = rect.origin.x.floor().max(0.0).to_int()
  let start_y = rect.origin.y.floor().max(0.0).to_int()
  let end_x = (rect.origin.x + rect.size.width)
    .ceil()
    .min(frame.width.to_double())
    .to_int()
  let end_y = (rect.origin.y + rect.size.height)
    .ceil()
    .min(frame.height.to_double())
    .to_int()
  for row in start_y..<end_y {
    for column in start_x..<end_x {
      let offset = (row * frame.width + column) * 4
      let red = frame.pixels[offset].to_int()
      let green = frame.pixels[offset + 1].to_int()
      let blue = frame.pixels[offset + 2].to_int()
      if red < 220 && green < 220 && blue < 220 {
        return true
      }
    }
  }
  false
}

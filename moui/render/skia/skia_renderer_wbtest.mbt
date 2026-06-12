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
    matrix.map_point(@moui_skia.Point::new(17.0, 19.0)) ==
    @moui_skia.Point::new(140.0, 197.0),
  )
}

test "skia raster surface preflight consumes moui_skia resource descriptors" {
  let preflight = raster_surface_preflight(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=12.0, height=8.0),
      scale_factor=2.0,
    ),
  )
  inspect(preflight.physical_width, content="24")
  inspect(preflight.physical_height, content="16")
  assert_true(preflight.target_ready)
  assert_true(preflight.frame_ready)
  assert_true(preflight.finalization_ready)
  assert_true(preflight.submission_ready)
  inspect(preflight.resource_count, content="2")
  inspect(preflight.cacheable_resource_count, content="1")
  inspect(preflight.uncacheable_resource_count, content="1")
  inspect(preflight.gpu_backed_resource_count, content="0")
  inspect(preflight.surface_resource_count, content="2")
  assert_true(preflight.byte_size > 0L)
}

///|
test "skia raster surface preflight clamps empty physical targets" {
  let preflight = raster_surface_preflight(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=0.0, height=8.0),
      scale_factor=2.0,
    ),
  )
  inspect(preflight.physical_width, content="1")
  inspect(preflight.physical_height, content="16")
  assert_true(preflight.target_ready)
  assert_true(preflight.frame_ready)
  assert_true(preflight.finalization_ready)
  inspect(preflight.resource_count, content="2")
}

///|
test "skia text descriptor preflight consumes fallback and shaping resource plans" {
  let preflight = skia_text_descriptor_preflight(
    @core.FontSpec::new(size=18.0, weight=600, style=@core.FontStyle::Italic),
    "MoUI",
  )
  assert_true(preflight.family_count > 0)
  inspect(preflight.fallback_character, content="77")
  assert_true(preflight.fallback_ready)
  inspect(preflight.fallback_resource_count, content="2")
  assert_true(preflight.measurement_ready)
  inspect(preflight.measurement_resource_count, content="4")
  assert_true(preflight.shaping_ready)
  inspect(preflight.shaping_resource_count, content="4")
  assert_true(preflight.shaped_run_ready)
  inspect(preflight.shaped_run_resource_count, content="5")
  assert_true(preflight.glyph_run_ready)
  inspect(preflight.glyph_run_resource_count, content="6")
}

///|
test "skia font fallback request prefers emoji and non-ascii representative characters" {
  inspect(skia_representative_fallback_codepoint(""), content="0")
  inspect(skia_representative_fallback_codepoint("MoUI"), content="77")
  inspect(skia_representative_fallback_codepoint("A你B"), content="20320")
  inspect(
    skia_representative_fallback_codepoint("A\u{1F642}B"),
    content="128578",
  )
  inspect(
    skia_representative_fallback_codepoint("A\u{2615}\u{FE0F}B"),
    content="9749",
  )
  inspect(
    skia_representative_fallback_codepoint("A\u{1F469}\u{200D}\u{1F373}B"),
    content="128105",
  )
}

///|
fn assert_skia_fallback_languages(
  text : String,
  expected : Array[Bytes],
) -> Unit raise {
  let request = skia_font_fallback_request(@core.FontSpec::new(size=18.0), text)
  inspect(request.language_count(), content="\{expected.length()}")
  for index in 0..<expected.length() {
    assert_true(request.language_at(index) == Some(expected[index]))
  }
  assert_true(request.language_at(expected.length()) is None)
}

///|
test "skia font fallback request records script language tags" {
  assert_skia_fallback_languages("", [])
  assert_skia_fallback_languages("MoUI", [b"en"])
  assert_skia_fallback_languages("A你B", [b"zh-Hans", b"en"])
  assert_skia_fallback_languages("A\u{3042}B", [b"ja", b"en"])
  assert_skia_fallback_languages("A\u{D55C}B", [b"ko", b"en"])
  assert_skia_fallback_languages("A\u{05D0}B", [b"he", b"en"])
  assert_skia_fallback_languages("A\u{0628}B", [b"ar", b"en"])
  assert_skia_fallback_languages("A\u{0915}B", [b"hi", b"en"])
  assert_skia_fallback_languages("A\u{0E01}B", [b"th", b"en"])
  assert_skia_fallback_languages("A\u{0E81}B", [b"lo", b"en"])
  assert_skia_fallback_languages("A\u{0D9A}B", [b"si", b"en"])
  assert_skia_fallback_languages("A\u{1780}B", [b"km", b"en"])
  assert_skia_fallback_languages("A\u{1000}B", [b"my", b"en"])
  assert_skia_fallback_languages("A\u{1F642}B", [b"und-Zsye", b"en"])
}

///|
test "skia emoji glyph key records source script count and format metadata" {
  inspect(
    skia_emoji_glyph_key(
      "skia-empty-typeface",
      "skia-raster-empty-typeface-text-system",
      "fallback-glyph-run",
      "und-Zsye",
      ["und-Zsye", "en"],
      2,
      0x1F469,
      "rgba",
    ),
    content="skia-empty-typeface|skia-raster-empty-typeface-text-system|fallback-glyph-run|script=und-Zsye|langs=2|lang-tags=und-Zsye+en|emoji-u+128105|rgba",
  )
  inspect(skia_fallback_script_tag(["und-Zsye", "en"]), content="und-Zsye")
  inspect(skia_fallback_script_tag([]), content="")
}

///|
test "skia text visual order diagnostic records rtl glyph layout observation" {
  guard skia_available() else { return () }
  guard skia_text_visual_order_diagnostic("ABC \u{05D0}\u{05D1}\u{05D2} 123")
    is Some(diagnostic) else {
    fail("expected Skia visual order diagnostic")
  }
  inspect(diagnostic.logical_text, content="ABC \u{05D0}\u{05D1}\u{05D2} 123")
  inspect(diagnostic.visual_text, content="ABC \u{05D2}\u{05D1}\u{05D0} 123")
  assert_true(diagnostic.visual_order_differs)
  assert_true(diagnostic.logical_cluster_count == diagnostic.visual_cluster_count)
  assert_true(diagnostic.segment_count >= 3)
  assert_true(diagnostic.glyph_count >= 6)
  assert_true(diagnostic.width > 0.0)
}

///|
test "skia font fallback request preserves family chain style and coverage character" {
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::system_ui().with_fallback(
      @core.FontFamily::Emoji,
    ),
    size=18.0,
    weight=650,
    style=@core.FontStyle::Italic,
  )
  let request = skia_font_fallback_request(font, "A\u{1F642}B")
  inspect(request.character, content="128578")
  assert_true(request.has_character())
  inspect(request.language_count(), content="2")
  assert_true(request.language_at(0) == Some(b"und-Zsye"))
  assert_true(request.language_at(1) == Some(b"en"))
  assert_true(request.families.length() >= 2)
  assert_true(request.families.family_at(0) == Some(b"Helvetica Neue"))
  assert_true(request.families.contains_family(b"Apple Color Emoji"))
  inspect(request.style.weight, content="650")
  inspect(request.style.width, content="5")
  inspect(request.style.slant, content="1")
  assert_true(request.resource_key().kind == @moui_skia.TypefaceResource)
  assert_true(
    request.font_descriptor(size=18.0).resource_key().kind ==
    @moui_skia.FontResource,
  )
}

///|
test "skia text descriptor preflight keeps empty text cacheable" {
  let preflight = skia_text_descriptor_preflight(
    @core.FontSpec::new(size=12.0, weight=400),
    "",
  )
  assert_true(preflight.fallback_ready)
  assert_true(preflight.measurement_ready)
  assert_true(preflight.shaping_ready)
  assert_true(preflight.shaped_run_ready)
  assert_true(preflight.glyph_run_ready)
}

///|
test "skia text maturity preflight separates covered baseline from gaps" {
  let preflight = skia_text_maturity_preflight()
  assert_true(preflight.descriptor_ready)
  assert_true(preflight.fallback_request_ready)
  assert_true(preflight.shaped_cluster_caret_ready)
  assert_true(preflight.fallback_cluster_caret_ready)
  assert_true(preflight.emoji_hint_ready)
  assert_true(preflight.empty_typeface_emoji_retry_disabled)
  assert_true(preflight.missing_glyph_recovery_ready)
  assert_false(preflight.bidi_reordering_ready)
  assert_false(preflight.paragraph_line_breaking_ready)
  assert_true(preflight.mixed_run_font_fallback_ready)
  assert_false(preflight.deterministic_color_emoji_ready)
  assert_true(preflight.unicode_17_grapheme_boundary_ready)
  inspect(preflight.ready_count, content="9")
  inspect(preflight.gap_count, content="3")
  assert_true(preflight.summary().contains("text maturity audit partial"))
  assert_true(preflight.summary().contains("mixed-run fallback ready"))
  assert_true(preflight.summary().contains("missing-glyph recovery ready"))
  assert_true(
    preflight.summary().contains("Unicode 17 grapheme boundary contract ready"),
  )
  assert_true(preflight.summary().contains("bidi"))
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
test "skia brush shader maps radial gradients when native Skia is linked" {
  let radial = @core.Brush::radial_gradient(
    center=@core.Point::new(x=12.0, y=10.0),
    radius=8.0,
    center_color=@core.Color::blue(),
    edge_color=@core.Color::gray(),
  )
  assert_true(
    skia_brush_shader(@core.Brush::solid(@core.Color::blue())) is None,
  )
  if skia_available() {
    assert_true(skia_brush_shader(radial) is Some(_))
  } else {
    assert_true(skia_brush_shader(radial) is None)
  }
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

test "skia empty typeface resolution avoids system font manager" {
  let font_spec = @core.FontSpec::new(size=14.0, weight=400)
  match
    skia_font_with_resolution_for_text(
      font_spec,
      "",
      SkiaFontResolution::EmptyTypeface,
    ) {
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
  ignore(renderer)
  match
    skia_draw_text_payload_for_resolution(
      @core.FontSpec::new(size=18.0, weight=400),
      "Slim",
      SkiaFontResolution::EmptyTypeface,
    ) {
    Some((font, run)) => {
      assert_true(font.size() == 18.0)
      assert_true(skia_glyph_run_has_visible_glyphs(run))
    }
    None => assert_false(skia_test_native_text_available())
  }
}

///|
test "skia text drawing clips glyphs to the TextRun frame" {
  guard skia_test_native_text_available() else { return () }
  let target = SkiaPresentTarget::new(description="test", present=_ => true)
  let renderer = create_with_present_target(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=96.0, height=36.0),
    ),
    target,
  ) catch {
    err => fail("expected Skia renderer creation: \{err.message()}")
  }
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="MMMMMMMM",
        frame=@core.Rect::new(x=0.0, y=0.0, width=4.0, height=36.0),
        font=@core.FontSpec::new(size=18.0, weight=400),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
  ]) catch {
    err => fail("expected Skia text render: \{err.message()}")
  }
  guard renderer.last_frame() is Some(frame) else {
    fail("expected rendered frame")
  }
  assert_false(
    skia_test_region_has_dark_pixel(
      frame,
      @core.Rect::new(x=8.0, y=0.0, width=84.0, height=36.0),
    ),
  )
}

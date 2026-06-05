///|
#cfg(platform="windows")
test "cosmic text fallback profile follows windows" {
  let profile = cosmic_text_platform_fallback_profile()
  inspect(profile == @moon_cosmic.FallbackProfile::Windows, content="true")
}

///|
#cfg(platform="macos")
test "cosmic text fallback profile follows macos" {
  let profile = cosmic_text_platform_fallback_profile()
  inspect(profile == @moon_cosmic.FallbackProfile::MacOS, content="true")
}

///|
#cfg(platform="linux")
test "cosmic text fallback profile follows linux" {
  let profile = cosmic_text_platform_fallback_profile()
  inspect(profile == @moon_cosmic.FallbackProfile::Unix, content="true")
}

///|
test "cosmic text font path selects platform font weight" {
  let regular = cosmic_text_font_path_for_spec(@core.FontSpec::new(weight=500))
  let bold = cosmic_text_font_path_for_spec(@core.FontSpec::new(weight=600))
  inspect(@fs.path_exists(regular), content="true")
  inspect(@fs.path_exists(bold), content="true")
}

///|
#cfg(platform="macos")
test "cosmic text macos primary font avoids sf small glyph variants" {
  let regular = macos_regular_font_path()
  if @fs.path_exists("/System/Library/Fonts/SFNSRounded.ttf") {
    inspect(regular, content="/System/Library/Fonts/SFNSRounded.ttf")
  } else {
    inspect(@fs.path_exists(regular), content="true")
  }
}

///|
test "cosmic text fallback font path covers cjk when available" {
  let cjk = cosmic_cjk_font_path()
  if @fs.path_exists(cjk) {
    let cache = CosmicTextCache::new()
    let font = @core.FontSpec::new(size=16.0, weight=500)
    cache.ensure_fonts_for_font(font)
    inspect(cache.loaded_paths.get(cjk) is Some(true), content="true")
    inspect(
      cache.font_system.resolve_for_codepoint(
        cosmic_text_attrs_for_font(font),
        0x4F60U,
      )
      is Some(_),
      content="true",
    )
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text fallback font path covers emoji when available" {
  let emoji = cosmic_emoji_font_path()
  if @fs.path_exists(emoji) {
    let cache = CosmicTextCache::new()
    let font = @core.FontSpec::new(size=16.0, weight=500)
    cache.ensure_fonts_for_font(font)
    inspect(cache.loaded_paths.get(emoji) is Some(true), content="true")
    inspect(
      cache.font_system.resolve_for_codepoint(
        cosmic_text_attrs_for_font(font),
        0x1F642U,
      )
      is Some(_),
      content="true",
    )
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text maps default font stack to ui fallback family" {
  inspect(
    cosmic_text_family_for_font(@core.FontSpec::new()),
    content="SystemUi",
  )
  inspect(
    cosmic_text_family_for_font(
      @core.FontSpec::new(
        families=@core.FontFamilyStack::new([
          @core.FontFamily::UiSansSerif,
          @core.FontFamily::SansSerif,
        ]),
      ),
    ),
    content="UiSansSerif",
  )
}

///|
test "cosmic text replaces missing glyph cache key with cjk fallback" {
  if @fs.path_exists(cosmic_regular_font_path()) &&
    @fs.path_exists(cosmic_cjk_font_path()) {
    let cache = CosmicTextCache::new()
    let run = @core.TextRun::new(
      text="你",
      frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=40.0),
      font=@core.FontSpec::new(size=18.0, weight=500),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    cache.ensure_fonts_for_font(run.font)
    let (missing_key, _, _) = @moon_cosmic.CacheKey::new(
      0,
      0,
      18.0F,
      (0.0F, 0.0F),
      500,
      0U,
    )
    let glyph = @moon_cosmic.LayoutGlyph::new(
      0, 1, 18.0F, 0, 500, 0, 0.0F, 0.0F, 18.0F, 0,
    )
    let fallback_key = cosmic_text_cache_key_with_fallback(
      cache, run, glyph, missing_key,
    )
    inspect(fallback_key.to_string() != missing_key.to_string(), content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text resolves cjk glyph from fallback face" {
  if @fs.path_exists(cosmic_regular_font_path()) &&
    @fs.path_exists(cosmic_cjk_font_path()) {
    let cache = CosmicTextCache::new()
    let run = @core.TextRun::new(
      text="你",
      frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=40.0),
      font=@core.FontSpec::new(size=18.0, weight=500),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    let runs = cosmic_text_layout_runs(cache, run)
    inspect(cache.has_loaded_fonts(), content="true")
    inspect(runs.length() > 0, content="true")
    inspect(runs.any(run => run.glyphs.length() > 0), content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text shaping produces glyphs when platform font is available" {
  if @fs.path_exists(cosmic_regular_font_path()) {
    let cache = CosmicTextCache::new()
    let run = @core.TextRun::new(
      text="Increment",
      frame=@core.Rect::new(x=0.0, y=0.0, width=160.0, height=32.0),
      font=@core.FontSpec::new(size=16.0, weight=500),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    let runs = cosmic_text_layout_runs(cache, run)
    inspect(cache.has_loaded_fonts(), content="true")
    inspect(runs.length() > 0, content="true")
    inspect(runs.any(run => run.glyphs.length() > 0), content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text provider skips whitespace glyphs without dropping words" {
  if @fs.path_exists(cosmic_regular_font_path()) {
    let cache = CosmicTextCache::new()
    let run = @core.TextRun::new(
      text="Layered card with image",
      frame=@core.Rect::new(x=0.0, y=0.0, width=260.0, height=32.0),
      font=@core.FontSpec::new(size=16.0, weight=500),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    let raw_runs = cosmic_text_layout_runs(cache, run)
    let mut raw_glyph_count = 0
    let mut whitespace_glyph_count = 0
    for raw_run in raw_runs {
      for glyph in raw_run.glyphs {
        raw_glyph_count = raw_glyph_count + 1
        if cosmic_text_glyph_is_whitespace(run, glyph) {
          whitespace_glyph_count = whitespace_glyph_count + 1
        }
      }
    }
    match cache.layout_for_run(run, 1.0) {
      Some(layout) => {
        inspect(whitespace_glyph_count > 0, content="true")
        inspect(layout.glyphs.length() > 0, content="true")
        inspect(layout.glyphs.length() < raw_glyph_count, content="true")
      }
      None => fail("expected cosmic layout for text with spaces")
    }
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text rasterizes lowercase and digits with valid glyph bitmaps" {
  if @fs.path_exists(cosmic_regular_font_path()) {
    let cache = CosmicTextCache::new()
    let run = @core.TextRun::new(
      text="Aa1",
      frame=@core.Rect::new(x=0.0, y=0.0, width=260.0, height=32.0),
      font=@core.FontSpec::new(size=16.0, weight=500),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    let mut upper_height = 0
    let mut letter_height = 0
    let mut digit_height = 0
    for layout_run in cosmic_text_layout_runs(cache, run) {
      for glyph in layout_run.glyphs {
        let physical = glyph.physical((0.0F, layout_run.line_y), 1.0F)
        let fallback = cosmic_text_cache_key_with_fallback(
          cache,
          run,
          glyph,
          physical.cache_key,
        )
        match cache.raster_cosmic_glyph(fallback) {
          Some(raster) => {
            assert_true(
              raster.format == @wgpu_renderer.NativeRasterGlyphFormat::AlphaMask,
            )
            match cosmic_text_char_at(run.text, glyph.start) {
              Some('A') => upper_height = raster.height
              Some('a') => letter_height = raster.height
              Some('1') => digit_height = raster.height
              _ => ()
            }
          }
          None => ()
        }
      }
    }
    inspect(upper_height > 0, content="true")
    inspect(letter_height > 0, content="true")
    inspect(digit_height > 0, content="true")
    inspect(
      letter_height.to_double() / upper_height.to_double() >= 0.7,
      content="true",
    )
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text keeps cjk glyphs near requested font size" {
  if @fs.path_exists(cosmic_regular_font_path()) &&
    @fs.path_exists(cosmic_cjk_font_path()) {
    let cache = CosmicTextCache::new()
    let run = @core.TextRun::new(
      text="你",
      frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=40.0),
      font=@core.FontSpec::new(size=16.0, weight=500),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    let mut cjk_height = 0
    for layout_run in cosmic_text_layout_runs(cache, run) {
      for glyph in layout_run.glyphs {
        let physical = glyph.physical((0.0F, layout_run.line_y), 1.0F)
        let fallback = cosmic_text_cache_key_with_fallback(
          cache,
          run,
          glyph,
          physical.cache_key,
        )
        match cache.raster_cosmic_glyph(fallback) {
          Some(raster) => cjk_height = raster.height
          None => ()
        }
      }
    }
    inspect(cjk_height >= 12, content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text shaping handles multibyte punctuation" {
  if @fs.path_exists(cosmic_regular_font_path()) {
    let cache = CosmicTextCache::new()
    let run = @core.TextRun::new(
      text="native supported · web supported",
      frame=@core.Rect::new(x=0.0, y=0.0, width=112.0, height=32.0),
      font=@core.FontSpec::new(size=16.0, weight=500),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    let runs = cosmic_text_layout_runs(cache, run)
    inspect(cache.has_loaded_fonts(), content="true")
    inspect(runs.length() > 0, content="true")
    inspect(runs.any(run => run.glyphs.length() > 0), content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text shaping handles built-in control symbols" {
  if @fs.path_exists(cosmic_regular_font_path()) {
    let cache = CosmicTextCache::new()
    let symbols = [
      "✓", "▲", "▼", "◀", "▶", "🔍", "✕", "• ", "☑ ", "☐ ",
    ]
    for symbol in symbols {
      let run = @core.TextRun::new(
        text=symbol,
        frame=@core.Rect::new(x=0.0, y=0.0, width=60.0, height=32.0),
        font=@core.FontSpec::new(size=16.0, weight=500),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      )
      ignore(cosmic_text_layout_runs(cache, run))
    }
    inspect(cache.has_loaded_fonts(), content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text maps control symbols before layout" {
  inspect(
    cosmic_text_safe_text("✓ ▲ ▼ ◀ ▶ 🔍 ✕ • ☑ ☐ ·"),
    content="v ▲ ▼ ◀ ▶ ? x * x o /",
  )
  inspect(cosmic_text_safe_text("🙂"), content=":")
  inspect(cosmic_text_safe_text("☕️"), content="o/")
  inspect(cosmic_text_safe_text("\u{1F469}\u{200D}\u{1F373}"), content="w/c")
  inspect(cosmic_text_safe_text("你好abc"), content="你好abc")
}

///|
test "cosmic text preserves source emoji for explicit emoji family" {
  let emoji_font = @core.FontSpec::new(
    families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
  )
  inspect(cosmic_text_layout_text("🙂", emoji_font), content="🙂")
  inspect(cosmic_text_layout_text("🙂", @core.FontSpec::new()), content=":")
}

///|
test "cosmic zwj caret folder moves cluster interiors to end" {
  let carets = [0.0, 0.0, 0.0, 39.0]
  cosmic_fold_zwj_caret_positions("\u{1F469}\u{200D}\u{1F4BB}", carets)
  inspect(
    carets[1] == 39.0 && carets[2] == 39.0 && carets[3] == 39.0,
    content="true",
  )
}

///|
test "cosmic explicit emoji measure folds zwj interior carets" {
  if @fs.path_exists(cosmic_emoji_font_path()) {
    let cache = CosmicTextCache::new()
    let font = @core.FontSpec::new(
      families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
      size=26.0,
      weight=400,
    )
    match
      cache.measure(
        @core.TextLayoutInput::new(text="\u{1F469}\u{200D}\u{1F4BB}", font~),
      ) {
      Some(layout) => {
        inspect(layout.caret_positions.length(), content="4")
        inspect(
          layout.caret_positions[1] == layout.caret_positions[2] &&
          layout.caret_positions[2] == layout.caret_positions[3],
          content="true",
        )
      }
      None => fail("expected explicit emoji measure")
    }
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic explicit emoji layout keeps source glyphs when available" {
  if @fs.path_exists(cosmic_emoji_font_path()) {
    let cache = CosmicTextCache::new()
    let run = @core.TextRun::new(
      text="🙂",
      frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=48.0),
      font=@core.FontSpec::new(
        families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
        size=26.0,
        weight=400,
      ),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    let mut glyphs = 0
    for layout_run in cosmic_text_layout_runs(cache, run) {
      glyphs += layout_run.glyphs.length()
    }
    inspect(glyphs >= 1, content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
fn cosmic_test_carets_are_monotonic(carets : Array[Double]) -> Bool {
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
fn assert_cosmic_text_contract_sample(text : String) -> Unit raise {
  let system = @wgpu_renderer.native_text_system_with_engine(
    cosmic_text_engine(),
  )
  let font = @core.FontSpec::new(size=16.0, weight=500)
  let measured = system.measure_text(@core.TextLayoutInput::new(text~, font~))
  inspect(measured.size.width > 0.0, content="true")
  inspect(measured.size.height > 0.0, content="true")
  inspect(measured.baseline > 0.0, content="true")
  inspect(measured.baseline <= measured.size.height, content="true")
  inspect(
    measured.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    cosmic_test_carets_are_monotonic(measured.caret_positions),
    content="true",
  )
  let clamped = system.measure_text(
    @core.TextLayoutInput::new(text~, font~, max_width=32.0),
  )
  inspect(clamped.size.width <= 32.0, content="true")
  inspect(
    clamped.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    cosmic_test_carets_are_monotonic(clamped.caret_positions),
    content="true",
  )
  for caret in clamped.caret_positions {
    inspect(caret <= 32.0, content="true")
  }
}

///|
fn assert_cosmic_run_layout_contract_sample(text : String) -> Unit raise {
  let cache = CosmicTextCache::new()
  let font = @core.FontSpec::new(size=18.0, weight=500)
  let run = @core.TextRun::new(
    text~,
    frame=@core.Rect::new(x=0.0, y=0.0, width=120.0, height=40.0),
    font~,
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  match cache.layout_for_run(run, 1.0) {
    Some(layout) => {
      inspect(layout.size.width > 0.0, content="true")
      inspect(layout.size.height > 0.0, content="true")
      inspect(layout.baseline > 0.0, content="true")
      inspect(layout.glyphs.length() > 0, content="true")
      inspect(
        layout.caret_positions.length(),
        content="\{text.to_array().length() + 1}",
      )
      inspect(
        cosmic_test_carets_are_monotonic(layout.caret_positions),
        content="true",
      )
    }
    None => fail("expected cosmic run layout for diagnostic sample")
  }
}

///|
test "cosmic run layout carries caret coverage for emoji clusters" {
  if @fs.path_exists(cosmic_regular_font_path()) {
    assert_cosmic_run_layout_contract_sample("\u{1F642}")
    assert_cosmic_run_layout_contract_sample("\u{2615}\u{FE0F}")
    assert_cosmic_run_layout_contract_sample("\u{1F469}\u{200D}\u{1F373}")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "cosmic text system satisfies core unicode measure contract" {
  assert_cosmic_text_contract_sample("abc")
  assert_cosmic_text_contract_sample("你好")
  assert_cosmic_text_contract_sample("🙂")
  assert_cosmic_text_contract_sample("☕️")
  assert_cosmic_text_contract_sample("👩‍💻")
  assert_cosmic_text_contract_sample("a你🙂b")
  assert_cosmic_text_contract_sample("abc אבג def")
}

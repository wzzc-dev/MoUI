///|
test "native text font path selects platform font weight" {
  let regular = native_text_font_path_for_spec(@core.FontSpec::new(weight=500))
  let bold = native_text_font_path_for_spec(@core.FontSpec::new(weight=600))
  inspect(@fs.path_exists(regular), content="true")
  inspect(@fs.path_exists(bold), content="true")
}

///|
test "native text fallback font path covers cjk when available" {
  let cjk = native_cjk_font_path()
  if @fs.path_exists(cjk) {
    let cache = NativeFontCache::new()
    let font = @core.FontSpec::new(size=16.0, weight=500)
    cache.ensure_fonts_for_font(font)
    inspect(cache.loaded_paths.get(cjk) is Some(true), content="true")
    inspect(
      cache.font_system.resolve_for_codepoint(
        native_text_attrs_for_font(font),
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
test "native text resolves cjk glyph from fallback face" {
  if @fs.path_exists(native_regular_font_path()) &&
    @fs.path_exists(native_cjk_font_path()) {
    let cache = NativeFontCache::new()
    let run = @core.TextRun::new(
      text="你",
      frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=40.0),
      font=@core.FontSpec::new(size=18.0, weight=500),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    let runs = native_text_layout_runs(cache, run)
    inspect(cache.has_loaded_fonts(), content="true")
    inspect(runs.length() > 0, content="true")
    inspect(runs.any(run => run.glyphs.length() > 0), content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native text shaping produces glyphs when platform font is available" {
  if @fs.path_exists(native_regular_font_path()) {
    let cache = NativeFontCache::new()
    let run = @core.TextRun::new(
      text="Increment",
      frame=@core.Rect::new(x=0.0, y=0.0, width=160.0, height=32.0),
      font=@core.FontSpec::new(size=16.0, weight=500),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    let runs = native_text_layout_runs(cache, run)
    inspect(cache.has_loaded_fonts(), content="true")
    inspect(runs.length() > 0, content="true")
    inspect(runs.any(run => run.glyphs.length() > 0), content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native text shaping handles multibyte punctuation" {
  if @fs.path_exists(native_regular_font_path()) {
    let cache = NativeFontCache::new()
    let run = @core.TextRun::new(
      text="native supported · web supported",
      frame=@core.Rect::new(x=0.0, y=0.0, width=112.0, height=32.0),
      font=@core.FontSpec::new(size=16.0, weight=500),
      color=@core.Color::black(),
      align=@core.TextAlign::TextStart,
    )
    let runs = native_text_layout_runs(cache, run)
    inspect(cache.has_loaded_fonts(), content="true")
    inspect(runs.length() > 0, content="true")
    inspect(runs.any(run => run.glyphs.length() > 0), content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native text shaping handles built-in control symbols" {
  if @fs.path_exists(native_regular_font_path()) {
    let cache = NativeFontCache::new()
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
      ignore(native_text_layout_runs(cache, run))
    }
    inspect(cache.has_loaded_fonts(), content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native text maps control symbols before cosmic layout" {
  inspect(
    native_text_cosmic_safe_text("✓ ▲ ▼ ◀ ▶ 🔍 ✕ • ☑ ☐ ·"),
    content="v ▲ ▼ ◀ ▶ ? x * x o /",
  )
  inspect(native_text_cosmic_safe_text("你好abc"), content="你好abc")
}

///|
fn glyph_atlas_entry_count(atlas : GlyphAtlas) -> Int {
  atlas.entries.length() + atlas.coretext_entries.length()
}

///|
fn caret_positions_are_monotonic(carets : Array[Double]) -> Bool {
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
fn bytes_has_nonzero(bytes : Bytes) -> Bool {
  for byte in bytes {
    if byte != b'\x00' {
      return true
    }
  }
  false
}

///|
fn text_vertices_have_visible_position(vertices : Array[TextVertex]) -> Bool {
  for vertex in vertices {
    if vertex.x >= -1.0 &&
      vertex.x <= 1.0 &&
      vertex.y >= -1.0 &&
      vertex.y <= 1.0 {
      return true
    }
  }
  false
}

///|
test "native signed i32 decoding handles negative bearings" {
  inspect(
    native_i32_le(Bytes::from_array([b'\xff', b'\xff', b'\xff', b'\xff']), 0),
    content="-1",
  )
  inspect(
    native_i32_le(Bytes::from_array([b'\xfe', b'\xff', b'\xff', b'\xff']), 0),
    content="-2",
  )
}

///|
test "coretext text engine measures mixed system text" {
  let input = @core.TextLayoutInput::new(
    text="aM你🙂",
    font=@core.FontSpec::new(size=17.0, weight=600),
  )
  match coretext_measure_layout(input) {
    Some(layout) => {
      inspect(layout.size.width > 0.0, content="true")
      inspect(layout.size.height > 0.0, content="true")
      inspect(layout.baseline > 0.0, content="true")
      inspect(layout.caret_positions.length(), content="5")
      inspect(
        caret_positions_are_monotonic(layout.caret_positions),
        content="true",
      )
    }
    None => inspect("missing", content="available")
  }
}

///|
test "coretext text engine rasterizes system glyphs" {
  let key = {
    codepoint: 'a'.to_int(),
    size_key: native_coretext_size_key(18.0),
    weight: 400,
    style: @core.FontStyle::Italic,
    scale_key: native_coretext_scale_key(1.0),
  }
  match coretext_raster_glyph(key) {
    Some(glyph) => {
      inspect(glyph.width > 0, content="true")
      inspect(glyph.height > 0, content="true")
      inspect(glyph.pixels.length() > 0, content="true")
      inspect(bytes_has_nonzero(glyph.pixels), content="true")
      inspect(glyph.bearing_x > -128 && glyph.bearing_x < 128, content="true")
      inspect(glyph.bearing_y > -128 && glyph.bearing_y < 128, content="true")
    }
    None => inspect("missing", content="available")
  }
}

///|
test "native renderer builds text vertices and atlas entries" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawText({
      text: "MoUI Counter",
      frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
      font: @core.FontSpec::new(size=16.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextCenter,
    }),
  ])
  inspect(renderer.text_vertices.length() > 0, content="true")
  inspect(
    text_vertices_have_visible_position(renderer.text_vertices),
    content="true",
  )
  inspect(glyph_atlas_entry_count(renderer.glyph_atlas) > 0, content="true")
}

///|
test "native renderer builds cjk text vertices with fallback font" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawText({
      text: "你",
      frame: @core.Rect::new(x=0.0, y=0.0, width=80.0, height=40.0),
      font: @core.FontSpec::new(size=18.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextStart,
    }),
  ])
  inspect(renderer.text_vertices.length() > 0, content="true")
  inspect(glyph_atlas_entry_count(renderer.glyph_atlas) > 0, content="true")
}

///|
test "native renderer keeps text in draw item order" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawText({
      text: "A",
      frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
      font: @core.FontSpec::new(size=16.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextCenter,
    }),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=20.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::DrawText({
      text: "B",
      frame: @core.Rect::new(x=0.0, y=40.0, width=40.0, height=20.0),
      font: @core.FontSpec::new(size=16.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextCenter,
    }),
  ])
  inspect(renderer.draw_items.length(), content="3")
  assert_true(renderer.draw_items[0] is NativeDrawItem::NativeText(_, _, _))
  assert_true(renderer.draw_items[1] is NativeDrawItem::NativeVisual(_, _, _))
  assert_true(renderer.draw_items[2] is NativeDrawItem::NativeText(_, _, _))
}

///|
test "native renderer applies text alignment" {
  if @fs.path_exists(native_regular_font_path()) {
    let font = @core.FontSpec::new(size=16.0, weight=500)
    let frame = @core.Rect::new(x=10.0, y=0.0, width=160.0, height=24.0)
    let left = new_test_renderer_handle()
    left.resize(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=320.0, height=120.0),
      ),
    )
    left.render([
      @core.DrawCommand::DrawText({
        text: "Align",
        frame,
        font,
        color: @core.Color::black(),
        align: @core.TextAlign::TextStart,
      }),
    ])
    let centered = new_test_renderer_handle()
    centered.resize(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=320.0, height=120.0),
      ),
    )
    centered.render([
      @core.DrawCommand::DrawText({
        text: "Align",
        frame,
        font,
        color: @core.Color::black(),
        align: @core.TextAlign::TextCenter,
      }),
    ])
    assert_true(left.text_vertices.length() > 0)
    assert_true(centered.text_vertices.length() > 0)
    assert_true(centered.text_vertices[0].x > left.text_vertices[0].x)
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native renderer vertically centers text in taller frames" {
  let command = @core.DrawCommand::DrawText({
    text: "Center",
    frame: @core.Rect::new(x=0.0, y=20.0, width=160.0, height=44.0),
    font: @core.FontSpec::new(size=16.0, weight=500),
    color: @core.Color::black(),
    align: @core.TextAlign::TextStart,
  })
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
    ),
  )
  renderer.render([command])
  assert_true(renderer.text_vertices.length() > 0)
  let top = text_vertex_min_y(renderer.text_vertices, 120.0)
  assert_true(top > 20.0)
}

///|
test "native renderer keeps text logical vertices stable across dpr" {
  let command = @core.DrawCommand::DrawText({
    text: "DPR",
    frame: @core.Rect::new(x=20.0, y=10.0, width=160.0, height=32.0),
    font: @core.FontSpec::new(size=18.0, weight=500),
    color: @core.Color::black(),
    align: @core.TextAlign::TextStart,
  })
  let scale_one = new_test_renderer_handle()
  scale_one.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
      scale_factor=1.0,
    ),
  )
  scale_one.render([command])
  let scale_two = new_test_renderer_handle()
  scale_two.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
      scale_factor=2.0,
    ),
  )
  scale_two.render([command])
  assert_true(scale_one.text_vertices.length() > 0)
  assert_true(scale_two.text_vertices.length() > 0)
  assert_true(
    scale_two.glyph_atlas.shelf_height > scale_one.glyph_atlas.shelf_height,
  )
}

///|
fn text_vertex_min_y(vertices : Array[TextVertex], height : Double) -> Double {
  let mut min_y = height
  for vertex in vertices {
    let y = (1.0 - vertex.y) * height / 2.0
    if y < min_y {
      min_y = y
    }
  }
  min_y
}

///|
test "native renderer clears glyph atlas when dpr changes" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
      scale_factor=1.0,
    ),
  )
  renderer.render([
    @core.DrawCommand::DrawText({
      text: "Scale",
      frame: @core.Rect::new(x=0.0, y=0.0, width=120.0, height=32.0),
      font: @core.FontSpec::new(size=16.0, weight=500),
      color: @core.Color::black(),
      align: @core.TextAlign::TextStart,
    }),
  ])
  assert_true(glyph_atlas_entry_count(renderer.glyph_atlas) > 0)
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=120.0),
      scale_factor=2.0,
    ),
  )
  inspect(glyph_atlas_entry_count(renderer.glyph_atlas), content="0")
}

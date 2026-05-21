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
test "native renderer builds text vertices and atlas entries" {
  if @fs.path_exists(native_regular_font_path()) {
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
    inspect(renderer.glyph_atlas.entries.length() > 0, content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native renderer builds cjk text vertices with fallback font" {
  if @fs.path_exists(native_cjk_font_path()) {
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
    inspect(renderer.glyph_atlas.entries.length() > 0, content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native renderer keeps text in draw item order" {
  if @fs.path_exists(native_regular_font_path()) {
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
  } else {
    inspect("skipped", content="skipped")
  }
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
  if @fs.path_exists(native_regular_font_path()) {
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
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native renderer keeps text logical vertices stable across dpr" {
  if @fs.path_exists(native_regular_font_path()) {
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
    let delta = ((scale_one.text_vertices[0].x - scale_two.text_vertices[0].x) *
    10000.0).to_int()
    assert_true(delta >= -1 && delta <= 1)
    assert_true(
      scale_two.glyph_atlas.shelf_height > scale_one.glyph_atlas.shelf_height,
    )
  } else {
    inspect("skipped", content="skipped")
  }
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
  if @fs.path_exists(native_regular_font_path()) {
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
    assert_true(renderer.glyph_atlas.entries.length() > 0)
    renderer.resize(
      @render.RendererSurfaceMetrics::from_logical(
        size=@core.Size::new(width=320.0, height=120.0),
        scale_factor=2.0,
      ),
    )
    inspect(renderer.glyph_atlas.entries.length(), content="0")
  } else {
    inspect("skipped", content="skipped")
  }
}

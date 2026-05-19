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
    let faces = cache.faces_for_font(@core.FontSpec::new(size=16.0, weight=500))
    inspect(faces.any(face => face.path == cjk), content="true")
    inspect(
      faces.any(face => face_supports_codepoint(face, 0x4F60U)),
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
    let faces = cache.faces_for_font(@core.FontSpec::new(size=18.0, weight=500))
    match faces {
      [primary, ..] => {
        let shaped = shape_text(primary, "你", 18)
        inspect(shaped.length(), content="1")
        let font = @core.FontSpec::new(size=18.0, weight=500)
        let resolved = resolve_shaped_glyphs(faces, primary, shaped, 18, font)
        inspect(resolved.length(), content="1")
        let glyph = resolved[0]
        inspect(glyph.glyph_id != 0U, content="true")
        inspect(!same_native_font_face(glyph.face, primary), content="true")
      }
      [] => inspect("font missing", content="font missing")
    }
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native text shaping produces glyphs when platform font is available" {
  if @fs.path_exists(native_regular_font_path()) {
    let cache = NativeFontCache::new()
    match cache.faces_for_font(@core.FontSpec::new(size=16.0, weight=500)) {
      [face, ..] => {
        let glyphs = shape_text(face, "Increment", 16)
        inspect(glyphs.length() > 0, content="true")
      }
      [] => inspect("font missing", content="font missing")
    }
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native renderer builds text vertices and atlas entries" {
  if @fs.path_exists(native_regular_font_path()) {
    let renderer = new_test_renderer_handle()
    renderer.resize(@core.Size::new(width=320.0, height=200.0))
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
    renderer.resize(@core.Size::new(width=320.0, height=200.0))
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
    renderer.resize(@core.Size::new(width=320.0, height=200.0))
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
    left.resize(@core.Size::new(width=320.0, height=120.0))
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
    centered.resize(@core.Size::new(width=320.0, height=120.0))
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

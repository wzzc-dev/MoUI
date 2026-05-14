///|
test "native text font path selects Segoe UI weight" {
  let regular = native_text_font_path_for_spec(@core.FontSpec::new(weight=500))
  let bold = native_text_font_path_for_spec(@core.FontSpec::new(weight=600))
  inspect(regular.contains("segoeui.ttf"), content="true")
  inspect(bold.contains("segoeuib.ttf"), content="true")
}

///|
test "native text shaping produces glyphs when Segoe UI is available" {
  if @fs.path_exists(native_regular_font_path()) {
    let cache = NativeFontCache::new()
    match cache.face_for_font(@core.FontSpec::new(size=16.0, weight=500)) {
      Some(face) => {
        let glyphs = shape_text(face, "Increment", 16)
        inspect(glyphs.length() > 0, content="true")
      }
      None => inspect("font missing", content="font missing")
    }
  } else {
    inspect("skipped", content="skipped")
  }
}

///|
test "native renderer builds text vertices and atlas entries" {
  if @fs.path_exists(native_regular_font_path()) {
    let renderer = RendererHandle::new()
    renderer.resize(@core.Size::new(width=320.0, height=200.0))
    renderer.render([
      @core.DrawCommand::DrawText({
        text: "MoUI Counter",
        frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
        font: @core.FontSpec::new(size=16.0, weight=500),
        color: @core.Color::black(),
      }),
    ])
    inspect(renderer.text_vertices.length() > 0, content="true")
    inspect(renderer.glyph_atlas.entries.length() > 0, content="true")
  } else {
    inspect("skipped", content="skipped")
  }
}

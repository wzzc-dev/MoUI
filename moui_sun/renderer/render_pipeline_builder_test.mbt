///|
test "RenderPipeline::get_commands returns an isolated command array" {
  let red = @graphics.Color::red()
  let blue = @graphics.Color::blue()
  let pipeline = RenderPipeline::new()
    .clear_canvas(red)
    .fill_rect(1.0, 2.0, 3.0, 4.0, @graphics.Paint::new())

  let commands = pipeline.get_commands()
  let replacement = RenderPipeline::new().clear_canvas(blue).get_commands()[0]
  assert_eq(commands.length(), 2)
  commands[0] = replacement
  commands.push(replacement)

  assert_eq(pipeline.len(), 2)
  let fresh = pipeline.get_commands()
  assert_eq(fresh.length(), 2)
  match fresh[0] {
    RenderCommand::Clear(color) => assert_eq(color, red)
    _ => abort("expected original clear command")
  }
}

///|
test "RenderPipeline::get_commands isolates fallback command arrays" {
  let config = @text.LayoutConfig::new(
    max_width=100.0,
    font_size=10.0,
    line_height=12.0,
  )
  let paint = @graphics.Paint::new()
  let pipeline = RenderPipeline::new()
    .draw_font_bytes_fallback_keyed(
      [
        FontBytesFallbackSource::new("primary", b"font-a"),
        FontBytesFallbackSource::new("fallback", b"font-b"),
      ],
      "text",
      "AB",
      0.0,
      0.0,
      config,
      paint,
    )
    .draw_loaded_font_fallback_keyed(
      ["primary", "fallback"],
      "loaded",
      "AB",
      0.0,
      0.0,
      config,
      paint,
    )

  let commands = pipeline.get_commands()
  match commands[0] {
    RenderCommand::DrawFontBytesFallbackKeyed(sources, _, _, _, _, _, _) => {
      sources[0] = FontBytesFallbackSource::new("mutated", b"bad")
      sources.push(FontBytesFallbackSource::new("extra", b"bad"))
    }
    _ => abort("expected font-bytes fallback command")
  }
  match commands[1] {
    RenderCommand::DrawLoadedFontFallbackKeyed(font_keys, _, _, _, _, _, _) => {
      font_keys[0] = "mutated"
      font_keys.push("extra")
    }
    _ => abort("expected loaded-font fallback command")
  }

  let fresh = pipeline.get_commands()
  match fresh[0] {
    RenderCommand::DrawFontBytesFallbackKeyed(sources, _, _, _, _, _, _) => {
      assert_eq(sources.length(), 2)
      assert_eq(sources[0].get_font_key(), "primary")
      assert_eq(sources[1].get_font_key(), "fallback")
    }
    _ => abort("expected fresh font-bytes fallback command")
  }
  match fresh[1] {
    RenderCommand::DrawLoadedFontFallbackKeyed(font_keys, _, _, _, _, _, _) => {
      assert_eq(font_keys.length(), 2)
      assert_eq(font_keys[0], "primary")
      assert_eq(font_keys[1], "fallback")
    }
    _ => abort("expected fresh loaded-font fallback command")
  }
}

///|
test "RenderPipeline replay_result reports image decode errors" {
  let renderer = Renderer::new(@graphics.Canvas::new(2, 2))
  let paint = @graphics.Paint::new()
  match
    RenderPipeline::new()
    .draw_bmp_bytes_keyed("bad-bmp", Bytes::from_array([66, 77]), 0, 0, paint)
    .replay_result(renderer) {
    Err(
      RenderPipelineReplayError::ImageDecodeFailed(
        "bad-bmp",
        @graphics.PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)
      )
    ) => ()
    _ => abort("expected checked BMP decode error")
  }
  assert_eq(
    renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::transparent(),
  )

  match
    RenderPipeline::new()
    .draw_png_bytes_keyed("bad-png", Bytes::from_array([137, 80]), 0, 0, paint)
    .replay_result(renderer) {
    Err(
      RenderPipelineReplayError::ImageDecodeFailed(
        "bad-png",
        @graphics.PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)
      )
    ) => ()
    _ => abort("expected checked PNG decode error")
  }

  match
    RenderPipeline::new()
    .draw_rgba_bytes_keyed(
      "bad-rgba",
      Bytes::from_array([1, 2, 3, 4]),
      2,
      1,
      0,
      0,
      paint,
    )
    .replay_result(renderer) {
    Err(
      RenderPipelineReplayError::ImageDecodeFailed(
        "bad-rgba",
        @graphics.PixmapDecodeError::RgbaByteLengthMismatch(8, 4)
      )
    ) => ()
    _ => abort("expected checked RGBA decode error")
  }
}

///|
test "RenderPipeline replay_result reports font parse errors" {
  let renderer = Renderer::new(@graphics.Canvas::new(12, 12))
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  match
    RenderPipeline::new()
    .draw_font_bytes_keyed(
      "bad-font", b"not a font", "label", "A", 1.0, 1.0, config, paint,
    )
    .replay_result(renderer) {
    Err(
      RenderPipelineReplayError::FontParseFailed(
        "bad-font",
        @text.FontParseError::UnexpectedEndOfData(0, 12, 10)
      )
    ) => ()
    _ => abort("expected checked font parser error")
  }

  match
    RenderPipeline::new()
    .draw_font_bytes_fallback_keyed(
      [
        FontBytesFallbackSource::new("primary", make_ttf_for_codes([65])),
        FontBytesFallbackSource::new("bad-fallback", b"not a font"),
      ],
      "fallback-label",
      "AB",
      1.0,
      1.0,
      config,
      paint,
    )
    .replay_result(renderer) {
    Err(
      RenderPipelineReplayError::FontParseFailed(
        "bad-fallback",
        @text.FontParseError::UnexpectedEndOfData(0, 12, 10)
      )
    ) => ()
    _ => abort("expected checked fallback font parser error")
  }
}

///|
test "Renderer draw_pipeline_result reports missing font loaders" {
  let renderer = Renderer::new(@graphics.Canvas::new(12, 12))
  let config = @text.LayoutConfig::new(
    max_width=20.0,
    font_size=10.0,
    line_height=10.0,
  )
  let paint = @graphics.Paint::new().set_color(@graphics.Color::black())
  match
    renderer.draw_pipeline_result(
      RenderPipeline::new().draw_loaded_font_keyed(
        "ui-font", "label", "A", 1.0, 1.0, config, paint,
      ),
    ) {
    Err(RenderPipelineReplayError::FontLoaderRequired("ui-font")) => ()
    _ => abort("expected loader-required replay error")
  }
}

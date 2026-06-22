///|
test "RenderPipeline renderer-resource replay reports image decode errors" {
  let paint = @graphics.Paint::new()

  let bmp_renderer = Renderer::new(@graphics.Canvas::new(2, 2))
  let bmp_resources = RendererResources::new(16, 16)
  match
    bmp_renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new().draw_bmp_bytes_keyed(
        "bad-bmp",
        Bytes::from_array([66, 77]),
        0,
        0,
        paint,
      ),
      bmp_resources,
    ) {
    Err(
      RenderPipelineResourceReplayError::ImageDecodeFailed(
        "bad-bmp",
        @graphics.PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)
      )
    ) => ()
    _ => abort("expected checked renderer-resource BMP decode error")
  }
  assert_true(bmp_resources.get_image_cache().is_empty())
  assert_eq(
    bmp_renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::transparent(),
  )

  let png_renderer = Renderer::new(@graphics.Canvas::new(2, 2))
  let png_resources = RendererResources::new(16, 16)
  match
    png_renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new().draw_png_bytes_keyed(
        "bad-png",
        Bytes::from_array([137, 80]),
        0,
        0,
        paint,
      ),
      png_resources,
    ) {
    Err(
      RenderPipelineResourceReplayError::ImageDecodeFailed(
        "bad-png",
        @graphics.PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)
      )
    ) => ()
    _ => abort("expected checked renderer-resource PNG decode error")
  }
  assert_true(png_resources.get_image_cache().is_empty())

  let rgba_renderer = Renderer::new(@graphics.Canvas::new(2, 2))
  let rgba_resources = RendererResources::new(16, 16)
  match
    rgba_renderer.draw_pipeline_with_renderer_resources_result(
      RenderPipeline::new().draw_rgba_bytes_keyed(
        "bad-rgba",
        Bytes::from_array([1, 2, 3, 4]),
        2,
        1,
        0,
        0,
        paint,
      ),
      rgba_resources,
    ) {
    Err(
      RenderPipelineResourceReplayError::ImageDecodeFailed(
        "bad-rgba",
        @graphics.PixmapDecodeError::RgbaByteLengthMismatch(8, 4)
      )
    ) => ()
    _ => abort("expected checked renderer-resource RGBA decode error")
  }
  assert_true(rgba_resources.get_image_cache().is_empty())
}

///|
test "RenderPipeline font-loader resource replay reports image decode errors" {
  let paint = @graphics.Paint::new()
  let loader = @text.MemoryFontLoader::new()

  let bmp_renderer = Renderer::new(@graphics.Canvas::new(2, 2))
  let bmp_resources = RendererResources::new(16, 16)
  match
    bmp_renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new().draw_bmp_bytes_keyed(
        "bad-bmp",
        Bytes::from_array([66, 77]),
        0,
        0,
        paint,
      ),
      bmp_resources,
      loader,
    ) {
    Err(
      RenderPipelineResourceReplayError::ImageDecodeFailed(
        "bad-bmp",
        @graphics.PixmapDecodeError::UnexpectedEndOfData(0, 54, 2)
      )
    ) => ()
    _ => abort("expected checked font-loader-resource BMP decode error")
  }
  assert_true(bmp_resources.get_image_cache().is_empty())
  assert_eq(
    bmp_renderer.get_canvas().get_pixmap().get_pixel(0, 0),
    @graphics.Color::transparent(),
  )

  let png_renderer = Renderer::new(@graphics.Canvas::new(2, 2))
  let png_resources = RendererResources::new(16, 16)
  match
    png_renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new().draw_png_bytes_keyed(
        "bad-png",
        Bytes::from_array([137, 80]),
        0,
        0,
        paint,
      ),
      png_resources,
      loader,
    ) {
    Err(
      RenderPipelineResourceReplayError::ImageDecodeFailed(
        "bad-png",
        @graphics.PixmapDecodeError::UnexpectedEndOfData(0, 8, 2)
      )
    ) => ()
    _ => abort("expected checked font-loader-resource PNG decode error")
  }
  assert_true(png_resources.get_image_cache().is_empty())

  let rgba_renderer = Renderer::new(@graphics.Canvas::new(2, 2))
  let rgba_resources = RendererResources::new(16, 16)
  match
    rgba_renderer.draw_pipeline_with_font_loader_resources_result(
      RenderPipeline::new().draw_rgba_bytes_keyed(
        "bad-rgba",
        Bytes::from_array([1, 2, 3, 4]),
        2,
        1,
        0,
        0,
        paint,
      ),
      rgba_resources,
      loader,
    ) {
    Err(
      RenderPipelineResourceReplayError::ImageDecodeFailed(
        "bad-rgba",
        @graphics.PixmapDecodeError::RgbaByteLengthMismatch(8, 4)
      )
    ) => ()
    _ => abort("expected checked font-loader-resource RGBA decode error")
  }
  assert_true(rgba_resources.get_image_cache().is_empty())
}

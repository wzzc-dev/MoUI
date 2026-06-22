///|
fn render_pipeline_make_image_dependency(
  command_index : Int,
  resource_key : String?,
  source_width : Int,
  source_height : Int,
) -> RenderPipelineImageDependency {
  {
    command_index,
    resource_key,
    source_width,
    source_height,
    source_pixel_count: source_width * source_height,
  }
}

///|
fn render_pipeline_make_rect_image_dependency(
  command_index : Int,
  resource_key : String?,
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
) -> RenderPipelineImageDependency {
  let src_bounds = @graphics.PixelRect::new(
    x=0,
    y=0,
    width=pixmap.get_width(),
    height=pixmap.get_height(),
  )
  match src_rect.clip_to(src_bounds) {
    Some(clipped) =>
      render_pipeline_make_image_dependency(
        command_index,
        resource_key,
        clipped.width,
        clipped.height,
      )
    None =>
      render_pipeline_make_image_dependency(command_index, resource_key, 0, 0)
  }
}

///|
fn render_pipeline_make_decoded_image_dependency(
  command_index : Int,
  resource_key : String,
  decoded : Result[@graphics.Pixmap, @graphics.PixmapDecodeError],
) -> RenderPipelineImageDependency {
  match decoded {
    Ok(pixmap) =>
      render_pipeline_make_image_dependency(
        command_index,
        Some(resource_key),
        pixmap.get_width(),
        pixmap.get_height(),
      )
    Err(_) =>
      render_pipeline_make_image_dependency(
        command_index,
        Some(resource_key),
        0,
        0,
      )
  }
}

///|
fn render_pipeline_make_bmp_bytes_image_dependency(
  command_index : Int,
  resource_key : String,
  image_data : Bytes,
) -> RenderPipelineImageDependency {
  render_pipeline_make_image_bytes_dependency(
    command_index,
    resource_key,
    RenderPipelineImageBytes::Bmp(image_data),
  )
}

///|
fn render_pipeline_make_png_bytes_image_dependency(
  command_index : Int,
  resource_key : String,
  image_data : Bytes,
) -> RenderPipelineImageDependency {
  render_pipeline_make_image_bytes_dependency(
    command_index,
    resource_key,
    RenderPipelineImageBytes::Png(image_data),
  )
}

///|
fn render_pipeline_make_rgba_bytes_image_dependency(
  command_index : Int,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
) -> RenderPipelineImageDependency {
  render_pipeline_make_image_bytes_dependency(
    command_index,
    resource_key,
    RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
  )
}

///|
fn render_pipeline_make_bmp_bytes_rect_image_dependency(
  command_index : Int,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
) -> RenderPipelineImageDependency {
  render_pipeline_make_image_bytes_rect_dependency(
    command_index,
    resource_key,
    RenderPipelineImageBytes::Bmp(image_data),
    src_rect,
  )
}

///|
fn render_pipeline_make_png_bytes_rect_image_dependency(
  command_index : Int,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
) -> RenderPipelineImageDependency {
  render_pipeline_make_image_bytes_rect_dependency(
    command_index,
    resource_key,
    RenderPipelineImageBytes::Png(image_data),
    src_rect,
  )
}

///|
fn render_pipeline_make_rgba_bytes_rect_image_dependency(
  command_index : Int,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
) -> RenderPipelineImageDependency {
  render_pipeline_make_image_bytes_rect_dependency(
    command_index,
    resource_key,
    RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
    src_rect,
  )
}

///|
fn render_pipeline_make_font_dependency(
  command_index : Int,
  font_key : String,
  font_data : Bytes,
) -> RenderPipelineFontDependency {
  { command_index, font_key, font_byte_count: font_data.length() }
}

///|
fn render_pipeline_make_loaded_font_dependency(
  command_index : Int,
  font_key : String,
) -> RenderPipelineFontDependency {
  { command_index, font_key, font_byte_count: 0 }
}

///|
fn render_pipeline_make_text_dependency(
  command_index : Int,
  resource_key : String?,
  face : @text.FontFace,
  text : String,
  config : @text.LayoutConfig,
) -> RenderPipelineTextDependency {
  let mut run_count = 0
  let mut glyph_count = 0
  let mut layout_width = 0.0
  let mut layout_height = 0.0
  if text.length() > 0 {
    let layout = @text.TextLayout::layout(face, text, config)
    run_count = layout.run_count()
    layout_width = layout.get_width()
    layout_height = layout.get_height()
    for run in layout.get_runs() {
      glyph_count += run.glyph_count()
    }
  }
  {
    command_index,
    resource_key,
    text_byte_count: text.length(),
    run_count,
    glyph_count,
    layout_width,
    layout_height,
  }
}

///|
fn render_pipeline_make_font_bytes_text_dependency(
  command_index : Int,
  resource_key : String,
  font_data : Bytes,
  text : String,
  config : @text.LayoutConfig,
) -> RenderPipelineTextDependency {
  match @text.FontFace::from_bytes(font_data) {
    Ok(face) =>
      render_pipeline_make_text_dependency(
        command_index,
        Some(resource_key),
        face,
        text,
        config,
      )
    Err(_) =>
      render_pipeline_make_unresolved_text_dependency(
        command_index,
        Some(resource_key),
        text,
      )
  }
}

///|
fn render_pipeline_make_unresolved_text_dependency(
  command_index : Int,
  resource_key : String?,
  text : String,
) -> RenderPipelineTextDependency {
  {
    command_index,
    resource_key,
    text_byte_count: text.length(),
    run_count: 0,
    glyph_count: 0,
    layout_width: 0.0,
    layout_height: 0.0,
  }
}

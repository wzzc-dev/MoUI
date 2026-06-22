///|
fn render_command_estimated_dirty_rect(
  command : RenderCommand,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  match command {
    RenderCommand::Clear(_) =>
      non_empty_pixel_rect(@graphics.PixelRect::new(x=0, y=0, width~, height~))
    RenderCommand::FillRect(x, y, rect_width, rect_height, _) =>
      pixel_rect_from_double_bounds(x, y, x + rect_width, y + rect_height)
    RenderCommand::StrokeRect(x, y, rect_width, rect_height, paint) => {
      let expand = paint.stroke_width.max(0.0) / 2.0
      pixel_rect_from_double_bounds(
        x - expand,
        y - expand,
        x + rect_width + expand,
        y + rect_height + expand,
      )
    }
    RenderCommand::FillPath(path, _) =>
      render_path_estimated_dirty_rect(path, 0.0)
    RenderCommand::StrokePath(path, paint) =>
      render_path_estimated_dirty_rect(path, paint.stroke_width.max(0.0) / 2.0)
    RenderCommand::DrawPixmap(pixmap, x, y, _) =>
      render_pixmap_estimated_dirty_rect(pixmap, x, y)
    RenderCommand::DrawPixmapKeyed(_, pixmap, x, y, _) =>
      render_pixmap_estimated_dirty_rect(pixmap, x, y)
    RenderCommand::DrawBmpBytesKeyed(_, image_data, x, y, _) =>
      render_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawPngBytesKeyed(_, image_data, x, y, _) =>
      render_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawRgbaBytesKeyed(
      _,
      image_data,
      image_width,
      image_height,
      x,
      y,
      _
    ) =>
      render_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawSampledBmpBytesKeyed(
      _,
      image_data,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawSampledPngBytesKeyed(
      _,
      image_data,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawSampledRgbaBytesKeyed(
      _,
      image_data,
      image_width,
      image_height,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawQualityBmpBytesKeyed(
      _,
      image_data,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawQualityBmpBytesRectKeyed(
      _,
      image_data,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawQualityPngBytesKeyed(
      _,
      image_data,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawQualityPngBytesRectKeyed(
      _,
      image_data,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawQualityRgbaBytesKeyed(
      _,
      image_data,
      image_width,
      image_height,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawQualityRgbaBytesRectKeyed(
      _,
      image_data,
      image_width,
      image_height,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedSampledBmpBytesKeyed(
      _,
      image_data,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedSampledBmpBytesRectKeyed(
      _,
      image_data,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedQualityBmpBytesKeyed(
      _,
      image_data,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedQualityBmpBytesRectKeyed(
      _,
      image_data,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedSampledPngBytesKeyed(
      _,
      image_data,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedSampledPngBytesRectKeyed(
      _,
      image_data,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedQualityPngBytesKeyed(
      _,
      image_data,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedQualityPngBytesRectKeyed(
      _,
      image_data,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedSampledRgbaBytesKeyed(
      _,
      image_data,
      image_width,
      image_height,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedSampledRgbaBytesRectKeyed(
      _,
      image_data,
      image_width,
      image_height,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedQualityRgbaBytesKeyed(
      _,
      image_data,
      image_width,
      image_height,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTransformedQualityRgbaBytesRectKeyed(
      _,
      image_data,
      image_width,
      image_height,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_transformed_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawSampledBmpBytesRectKeyed(
      _,
      image_data,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawSampledPngBytesRectKeyed(
      _,
      image_data,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawSampledRgbaBytesRectKeyed(
      _,
      image_data,
      image_width,
      image_height,
      src_rect,
      x,
      y,
      width,
      height,
      _,
      _
    ) =>
      render_scaled_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawBmpBytesRectKeyed(_, image_data, src_rect, x, y, _) =>
      render_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        src_rect,
        x,
        y,
      )
    RenderCommand::DrawPngBytesRectKeyed(_, image_data, src_rect, x, y, _) =>
      render_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        src_rect,
        x,
        y,
      )
    RenderCommand::DrawRgbaBytesRectKeyed(
      _,
      image_data,
      image_width,
      image_height,
      src_rect,
      x,
      y,
      _
    ) =>
      render_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        src_rect,
        x,
        y,
      )
    RenderCommand::DrawTiledBmpBytesRectKeyed(
      _,
      image_data,
      src_rect,
      x,
      y,
      width,
      height,
      _
    ) =>
      render_tiled_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTiledPngBytesRectKeyed(
      _,
      image_data,
      src_rect,
      x,
      y,
      width,
      height,
      _
    ) =>
      render_tiled_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawTiledRgbaBytesRectKeyed(
      _,
      image_data,
      image_width,
      image_height,
      src_rect,
      x,
      y,
      width,
      height,
      _
    ) =>
      render_tiled_image_bytes_rect_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        src_rect,
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawNinePatchBmpBytesKeyed(
      _,
      image_data,
      x,
      y,
      width,
      height,
      _,
      _,
      _
    ) =>
      render_nine_patch_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Bmp(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawNinePatchPngBytesKeyed(
      _,
      image_data,
      x,
      y,
      width,
      height,
      _,
      _,
      _
    ) =>
      render_nine_patch_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Png(image_data),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawNinePatchRgbaBytesKeyed(
      _,
      image_data,
      image_width,
      image_height,
      x,
      y,
      width,
      height,
      _,
      _,
      _
    ) =>
      render_nine_patch_image_bytes_estimated_dirty_rect(
        RenderPipelineImageBytes::Rgba(image_data, image_width, image_height),
        x,
        y,
        width,
        height,
      )
    RenderCommand::DrawPixmapRect(pixmap, src_rect, x, y, _) =>
      render_pixmap_rect_estimated_dirty_rect(pixmap, src_rect, x, y)
    RenderCommand::DrawPixmapRectKeyed(_, pixmap, src_rect, x, y, _) =>
      render_pixmap_rect_estimated_dirty_rect(pixmap, src_rect, x, y)
    RenderCommand::DrawTextFace(face, text, x, y, config, _) => {
      guard text.length() > 0 else { return None }
      let layout = @text.TextLayout::layout(face, text, config)
      pixel_rect_from_double_bounds(
        x,
        y,
        x + layout.get_width(),
        y + layout.get_height(),
      )
    }
    RenderCommand::DrawTextFaceKeyed(_, face, text, x, y, config, _) => {
      guard text.length() > 0 else { return None }
      let layout = @text.TextLayout::layout(face, text, config)
      pixel_rect_from_double_bounds(
        x,
        y,
        x + layout.get_width(),
        y + layout.get_height(),
      )
    }
    RenderCommand::DrawFontBytesKeyed(_, font_data, _, text, x, y, config, _) => {
      guard text.length() > 0 else { return None }
      match @text.FontFace::from_bytes(font_data) {
        Ok(face) => {
          let layout = @text.TextLayout::layout(face, text, config)
          pixel_rect_from_double_bounds(
            x,
            y,
            x + layout.get_width(),
            y + layout.get_height(),
          )
        }
        Err(_) =>
          pixel_rect_from_double_bounds(
            x,
            y,
            x + render_pipeline_fallback_text_width(text, config),
            y + config.line_height.max(config.font_size),
          )
      }
    }
    RenderCommand::DrawFontBytesAtlasKeyed(
      _,
      font_data,
      _,
      text,
      x,
      y,
      config,
      _
    ) => {
      guard text.length() > 0 else { return None }
      match @text.FontFace::from_bytes(font_data) {
        Ok(face) => {
          let layout = @text.TextLayout::layout(face, text, config)
          pixel_rect_from_double_bounds(
            x,
            y,
            x + layout.get_width(),
            y + layout.get_height(),
          )
        }
        Err(_) =>
          pixel_rect_from_double_bounds(
            x,
            y,
            x + render_pipeline_fallback_text_width(text, config),
            y + config.line_height.max(config.font_size),
          )
      }
    }
    RenderCommand::DrawFontBytesFallbackKeyed(_, _, text, x, y, config, _) => {
      guard text.length() > 0 else { return None }
      pixel_rect_from_double_bounds(
        x,
        y,
        x + render_pipeline_fallback_text_width(text, config),
        y + config.line_height.max(config.font_size),
      )
    }
    RenderCommand::DrawFontBytesFallbackAtlasKeyed(_, _, text, x, y, config, _) => {
      guard text.length() > 0 else { return None }
      pixel_rect_from_double_bounds(
        x,
        y,
        x + render_pipeline_fallback_text_width(text, config),
        y + config.line_height.max(config.font_size),
      )
    }
    RenderCommand::DrawLoadedFontKeyed(_, _, text, x, y, config, _) => {
      guard text.length() > 0 else { return None }
      pixel_rect_from_double_bounds(
        x,
        y,
        x + render_pipeline_fallback_text_width(text, config),
        y + config.line_height.max(config.font_size),
      )
    }
    RenderCommand::DrawLoadedFontFallbackKeyed(_, _, text, x, y, config, _) => {
      guard text.length() > 0 else { return None }
      pixel_rect_from_double_bounds(
        x,
        y,
        x + render_pipeline_fallback_text_width(text, config),
        y + config.line_height.max(config.font_size),
      )
    }
    RenderCommand::DrawLoadedFontFallbackAtlasKeyed(_, _, text, x, y, config, _) => {
      guard text.length() > 0 else { return None }
      pixel_rect_from_double_bounds(
        x,
        y,
        x + render_pipeline_fallback_text_width(text, config),
        y + config.line_height.max(config.font_size),
      )
    }
    RenderCommand::DrawLoadedFontAtlasKeyed(_, _, text, x, y, config, _) => {
      guard text.length() > 0 else { return None }
      pixel_rect_from_double_bounds(
        x,
        y,
        x + render_pipeline_fallback_text_width(text, config),
        y + config.line_height.max(config.font_size),
      )
    }
  }
}

///|
fn render_pixmap_estimated_dirty_rect(
  pixmap : @graphics.Pixmap,
  x : Int,
  y : Int,
) -> @graphics.PixelRect? {
  non_empty_pixel_rect(
    @graphics.PixelRect::new(
      x~,
      y~,
      width=pixmap.get_width(),
      height=pixmap.get_height(),
    ),
  )
}

///|
fn render_scaled_pixmap_estimated_dirty_rect(
  pixmap : @graphics.Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  guard width > 0 && height > 0 else { return None }
  guard pixmap.get_width() > 0 && pixmap.get_height() > 0 else { return None }
  non_empty_pixel_rect(@graphics.PixelRect::new(x~, y~, width~, height~))
}

///|
fn render_transformed_pixmap_estimated_dirty_rect(
  pixmap : @graphics.Pixmap,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @graphics.PixelRect? {
  guard width > 0.0 && height > 0.0 else { return None }
  guard pixmap.get_width() > 0 && pixmap.get_height() > 0 else { return None }
  pixel_rect_from_double_bounds(x, y, x + width, y + height)
}

///|
fn render_transformed_pixmap_rect_estimated_dirty_rect(
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @graphics.PixelRect? {
  guard width > 0.0 && height > 0.0 else { return None }
  let src_bounds = @graphics.PixelRect::new(
    x=0,
    y=0,
    width=pixmap.get_width(),
    height=pixmap.get_height(),
  )
  match src_rect.clip_to(src_bounds) {
    Some(clipped_src) =>
      if clipped_src.is_empty() {
        None
      } else {
        pixel_rect_from_double_bounds(x, y, x + width, y + height)
      }
    None => None
  }
}

///|
fn render_scaled_pixmap_rect_estimated_dirty_rect(
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  guard width > 0 && height > 0 else { return None }
  let src_bounds = @graphics.PixelRect::new(
    x=0,
    y=0,
    width=pixmap.get_width(),
    height=pixmap.get_height(),
  )
  match src_rect.clip_to(src_bounds) {
    Some(clipped_src) =>
      if clipped_src.is_empty() {
        None
      } else {
        non_empty_pixel_rect(@graphics.PixelRect::new(x~, y~, width~, height~))
      }
    None => None
  }
}

///|
fn render_nine_patch_pixmap_estimated_dirty_rect(
  pixmap : @graphics.Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  guard width > 0 && height > 0 else { return None }
  guard pixmap.get_width() > 0 && pixmap.get_height() > 0 else { return None }
  non_empty_pixel_rect(@graphics.PixelRect::new(x~, y~, width~, height~))
}

///|
fn render_tiled_pixmap_rect_estimated_dirty_rect(
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  guard width > 0 && height > 0 else { return None }
  let src_bounds = @graphics.PixelRect::new(
    x=0,
    y=0,
    width=pixmap.get_width(),
    height=pixmap.get_height(),
  )
  match src_rect.clip_to(src_bounds) {
    Some(clipped_src) =>
      if clipped_src.is_empty() {
        None
      } else {
        non_empty_pixel_rect(@graphics.PixelRect::new(x~, y~, width~, height~))
      }
    None => None
  }
}

///|
fn render_pixmap_rect_estimated_dirty_rect(
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
) -> @graphics.PixelRect? {
  let src_bounds = @graphics.PixelRect::new(
    x=0,
    y=0,
    width=pixmap.get_width(),
    height=pixmap.get_height(),
  )
  match src_rect.clip_to(src_bounds) {
    Some(clipped_src) =>
      non_empty_pixel_rect(
        @graphics.PixelRect::new(
          x=x + clipped_src.x - src_rect.x,
          y=y + clipped_src.y - src_rect.y,
          width=clipped_src.width,
          height=clipped_src.height,
        ),
      )
    None => None
  }
}

///|
fn render_path_estimated_dirty_rect(
  path : @graphics.Path,
  expand : Double,
) -> @graphics.PixelRect? {
  match path.control_bounds() {
    Some(bounds) =>
      pixel_rect_from_double_bounds(
        bounds.x - expand,
        bounds.y - expand,
        bounds.right() + expand,
        bounds.bottom() + expand,
      )
    None => None
  }
}

///|
fn pixel_rect_from_double_bounds(
  left : Double,
  top : Double,
  right : Double,
  bottom : Double,
) -> @graphics.PixelRect? {
  guard right > left && bottom > top else { return None }
  let x0 = floor_to_int(left)
  let y0 = floor_to_int(top)
  let x1 = ceil_to_int(right)
  let y1 = ceil_to_int(bottom)
  non_empty_pixel_rect(
    @graphics.PixelRect::new(x=x0, y=y0, width=x1 - x0, height=y1 - y0),
  )
}

///|
fn non_empty_pixel_rect(rect : @graphics.PixelRect) -> @graphics.PixelRect? {
  if rect.is_empty() {
    None
  } else {
    Some(rect)
  }
}

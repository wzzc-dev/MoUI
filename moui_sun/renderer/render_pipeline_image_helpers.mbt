///|
priv enum RenderPipelineImageBytes {
  Bmp(Bytes)
  Png(Bytes)
  Rgba(Bytes, Int, Int)
}

///|
fn RenderPipelineImageBytes::decode(
  self : RenderPipelineImageBytes,
) -> Result[@graphics.Pixmap, @graphics.PixmapDecodeError] {
  match self {
    RenderPipelineImageBytes::Bmp(image_data) =>
      @graphics.Pixmap::from_bmp_bytes(image_data)
    RenderPipelineImageBytes::Png(image_data) =>
      @graphics.Pixmap::from_png_bytes(image_data)
    RenderPipelineImageBytes::Rgba(image_data, image_width, image_height) =>
      @graphics.Pixmap::from_rgba_bytes(image_width, image_height, image_data)
  }
}

///|
fn render_pipeline_make_declared_image_dependency(
  command_index : Int,
  resource_key : String,
  source_width : Int,
  source_height : Int,
) -> RenderPipelineImageDependency {
  if source_width > 0 && source_height > 0 {
    render_pipeline_make_image_dependency(
      command_index,
      Some(resource_key),
      source_width,
      source_height,
    )
  } else {
    render_pipeline_make_image_dependency(
      command_index,
      Some(resource_key),
      0,
      0,
    )
  }
}

///|
fn render_pipeline_make_declared_rect_image_dependency(
  command_index : Int,
  resource_key : String,
  source_width : Int,
  source_height : Int,
  src_rect : @graphics.PixelRect,
) -> RenderPipelineImageDependency {
  let src_bounds = @graphics.PixelRect::new(
    x=0,
    y=0,
    width=source_width,
    height=source_height,
  )
  match src_rect.clip_to(src_bounds) {
    Some(clipped) =>
      render_pipeline_make_image_dependency(
        command_index,
        Some(resource_key),
        clipped.width,
        clipped.height,
      )
    None =>
      render_pipeline_make_image_dependency(
        command_index,
        Some(resource_key),
        0,
        0,
      )
  }
}

///|
fn render_pipeline_make_requested_rect_image_dependency(
  command_index : Int,
  resource_key : String,
  src_rect : @graphics.PixelRect,
) -> RenderPipelineImageDependency {
  if src_rect.is_empty() {
    render_pipeline_make_image_dependency(
      command_index,
      Some(resource_key),
      0,
      0,
    )
  } else {
    render_pipeline_make_image_dependency(
      command_index,
      Some(resource_key),
      src_rect.width,
      src_rect.height,
    )
  }
}

///|
fn render_pipeline_make_image_bytes_dependency(
  command_index : Int,
  resource_key : String,
  image : RenderPipelineImageBytes,
) -> RenderPipelineImageDependency {
  match image {
    RenderPipelineImageBytes::Rgba(_, image_width, image_height) =>
      render_pipeline_make_declared_image_dependency(
        command_index, resource_key, image_width, image_height,
      )
    _ =>
      render_pipeline_make_decoded_image_dependency(
        command_index,
        resource_key,
        image.decode(),
      )
  }
}

///|
fn render_pipeline_make_image_bytes_rect_dependency(
  command_index : Int,
  resource_key : String,
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
) -> RenderPipelineImageDependency {
  match image {
    RenderPipelineImageBytes::Rgba(_, image_width, image_height) =>
      render_pipeline_make_declared_rect_image_dependency(
        command_index, resource_key, image_width, image_height, src_rect,
      )
    _ =>
      match image.decode() {
        Ok(pixmap) =>
          render_pipeline_make_rect_image_dependency(
            command_index,
            Some(resource_key),
            pixmap,
            src_rect,
          )
        Err(_) =>
          render_pipeline_make_requested_rect_image_dependency(
            command_index, resource_key, src_rect,
          )
      }
  }
}

///|
fn render_pipeline_decode_image_bytes(
  resource_key : String,
  image : RenderPipelineImageBytes,
) -> Result[@graphics.Pixmap, RenderPipelineReplayError] {
  match image.decode() {
    Ok(pixmap) => Ok(pixmap)
    Err(error) =>
      Err(RenderPipelineReplayError::ImageDecodeFailed(resource_key, error))
  }
}

///|
fn render_pipeline_draw_image_bytes_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_pixmap(pixmap, x, y, paint)
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_image_bytes_rect_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_pixmap_rect(pixmap, src_rect, x, y, paint)
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_sampled_image_bytes_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_sampled_pixmap(pixmap, x, y, width, height, paint, sampling)
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_sampled_image_bytes_rect_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_sampled_pixmap_rect(
        pixmap, src_rect, x, y, width, height, paint, sampling,
      )
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_quality_image_bytes_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_quality_pixmap(pixmap, x, y, width, height, paint, quality)
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_quality_image_bytes_rect_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_quality_pixmap_rect(
        pixmap, src_rect, x, y, width, height, paint, quality,
      )
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_transformed_sampled_image_bytes_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_transformed_sampled_pixmap(
        pixmap, x, y, width, height, paint, sampling,
      )
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_transformed_sampled_image_bytes_rect_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_transformed_sampled_pixmap_rect(
        pixmap, src_rect, x, y, width, height, paint, sampling,
      )
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_transformed_quality_image_bytes_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_transformed_quality_pixmap(
        pixmap, x, y, width, height, paint, quality,
      )
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_transformed_quality_image_bytes_rect_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_transformed_quality_pixmap_rect(
        pixmap, src_rect, x, y, width, height, paint, quality,
      )
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_tiled_image_bytes_rect_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_tiled_pixmap_rect(
        pixmap, src_rect, x, y, width, height, paint,
      )
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_pipeline_draw_nine_patch_image_bytes_result(
  canvas : @graphics.Canvas,
  resource_key : String,
  image : RenderPipelineImageBytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[Unit, RenderPipelineReplayError] {
  match render_pipeline_decode_image_bytes(resource_key, image) {
    Ok(pixmap) => {
      canvas.draw_nine_patch_pixmap(
        pixmap, x, y, width, height, insets, paint, sampling,
      )
      Ok(())
    }
    Err(error) => Err(error)
  }
}

///|
fn render_image_bytes_estimated_dirty_rect(
  image : RenderPipelineImageBytes,
  x : Int,
  y : Int,
  canvas_width : Int,
  canvas_height : Int,
) -> @graphics.PixelRect? {
  match image.decode() {
    Ok(pixmap) => render_pixmap_estimated_dirty_rect(pixmap, x, y)
    Err(_) =>
      render_image_bytes_fallback_dirty_rect(
        image, x, y, canvas_width, canvas_height,
      )
  }
}

///|
fn render_image_bytes_rect_estimated_dirty_rect(
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
) -> @graphics.PixelRect? {
  match image.decode() {
    Ok(pixmap) =>
      render_pixmap_rect_estimated_dirty_rect(pixmap, src_rect, x, y)
    Err(_) => render_point_source_target_dirty_rect(src_rect, x, y)
  }
}

///|
fn render_scaled_image_bytes_estimated_dirty_rect(
  image : RenderPipelineImageBytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  match image.decode() {
    Ok(pixmap) =>
      render_scaled_pixmap_estimated_dirty_rect(pixmap, x, y, width, height)
    Err(_) => render_pixel_target_dirty_rect(x, y, width, height)
  }
}

///|
fn render_scaled_image_bytes_rect_estimated_dirty_rect(
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  match image.decode() {
    Ok(pixmap) =>
      render_scaled_pixmap_rect_estimated_dirty_rect(
        pixmap, src_rect, x, y, width, height,
      )
    Err(_) =>
      render_pixel_source_target_dirty_rect(src_rect, x, y, width, height)
  }
}

///|
fn render_transformed_image_bytes_estimated_dirty_rect(
  image : RenderPipelineImageBytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @graphics.PixelRect? {
  match image.decode() {
    Ok(pixmap) =>
      render_transformed_pixmap_estimated_dirty_rect(
        pixmap, x, y, width, height,
      )
    Err(_) => render_transformed_target_dirty_rect(x, y, width, height)
  }
}

///|
fn render_transformed_image_bytes_rect_estimated_dirty_rect(
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @graphics.PixelRect? {
  match image.decode() {
    Ok(pixmap) =>
      render_transformed_pixmap_rect_estimated_dirty_rect(
        pixmap, src_rect, x, y, width, height,
      )
    Err(_) =>
      render_transformed_source_target_dirty_rect(src_rect, x, y, width, height)
  }
}

///|
fn render_tiled_image_bytes_rect_estimated_dirty_rect(
  image : RenderPipelineImageBytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  match image.decode() {
    Ok(pixmap) =>
      render_tiled_pixmap_rect_estimated_dirty_rect(
        pixmap, src_rect, x, y, width, height,
      )
    Err(_) =>
      render_pixel_source_target_dirty_rect(src_rect, x, y, width, height)
  }
}

///|
fn render_nine_patch_image_bytes_estimated_dirty_rect(
  image : RenderPipelineImageBytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  match image.decode() {
    Ok(pixmap) =>
      render_nine_patch_pixmap_estimated_dirty_rect(pixmap, x, y, width, height)
    Err(_) => render_pixel_target_dirty_rect(x, y, width, height)
  }
}

///|
fn render_image_bytes_fallback_dirty_rect(
  image : RenderPipelineImageBytes,
  x : Int,
  y : Int,
  canvas_width : Int,
  canvas_height : Int,
) -> @graphics.PixelRect? {
  match image {
    RenderPipelineImageBytes::Rgba(_, image_width, image_height) =>
      render_pixel_target_dirty_rect(x, y, image_width, image_height)
    _ => render_canvas_dirty_rect(canvas_width, canvas_height)
  }
}

///|
fn render_canvas_dirty_rect(
  canvas_width : Int,
  canvas_height : Int,
) -> @graphics.PixelRect? {
  non_empty_pixel_rect(
    @graphics.PixelRect::new(x=0, y=0, width=canvas_width, height=canvas_height),
  )
}

///|
fn render_pixel_target_dirty_rect(
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  non_empty_pixel_rect(@graphics.PixelRect::new(x~, y~, width~, height~))
}

///|
fn render_point_source_target_dirty_rect(
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
) -> @graphics.PixelRect? {
  guard !src_rect.is_empty() else { return None }
  render_pixel_target_dirty_rect(x, y, src_rect.width, src_rect.height)
}

///|
fn render_pixel_source_target_dirty_rect(
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @graphics.PixelRect? {
  guard !src_rect.is_empty() else { return None }
  render_pixel_target_dirty_rect(x, y, width, height)
}

///|
fn render_transformed_target_dirty_rect(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @graphics.PixelRect? {
  pixel_rect_from_double_bounds(x, y, x + width, y + height)
}

///|
fn render_transformed_source_target_dirty_rect(
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> @graphics.PixelRect? {
  guard !src_rect.is_empty() else { return None }
  render_transformed_target_dirty_rect(x, y, width, height)
}

///|
/// Create an empty render pipeline.
pub fn RenderPipeline::new() -> RenderPipeline {
  { commands: [], }
}

///|
/// Return the number of queued commands.
pub fn RenderPipeline::len(self : RenderPipeline) -> Int {
  self.commands.length()
}

///|
/// Return whether this pipeline has no queued commands.
pub fn RenderPipeline::is_empty(self : RenderPipeline) -> Bool {
  self.len() is 0
}

///|
/// Return the queued commands.
pub fn RenderPipeline::get_commands(
  self : RenderPipeline,
) -> Array[RenderCommand] {
  copy_render_commands(self.commands)
}

///|
fn copy_render_commands(
  commands : Array[RenderCommand],
) -> Array[RenderCommand] {
  let copied = []
  for command in commands {
    copied.push(copy_render_command(command))
  }
  copied
}

///|
fn copy_render_command(command : RenderCommand) -> RenderCommand {
  match command {
    DrawFontBytesFallbackKeyed(
      sources,
      text_key_prefix,
      text,
      x,
      y,
      config,
      paint
    ) =>
      DrawFontBytesFallbackKeyed(
        copy_font_bytes_fallback_sources(sources),
        text_key_prefix,
        text,
        x,
        y,
        config,
        paint,
      )
    DrawFontBytesFallbackAtlasKeyed(
      sources,
      glyph_key_prefix,
      text,
      x,
      y,
      config,
      paint
    ) =>
      DrawFontBytesFallbackAtlasKeyed(
        copy_font_bytes_fallback_sources(sources),
        glyph_key_prefix,
        text,
        x,
        y,
        config,
        paint,
      )
    DrawLoadedFontFallbackKeyed(
      font_keys,
      text_key_prefix,
      text,
      x,
      y,
      config,
      paint
    ) =>
      DrawLoadedFontFallbackKeyed(
        copy_string_array(font_keys),
        text_key_prefix,
        text,
        x,
        y,
        config,
        paint,
      )
    DrawLoadedFontFallbackAtlasKeyed(
      font_keys,
      glyph_key_prefix,
      text,
      x,
      y,
      config,
      paint
    ) =>
      DrawLoadedFontFallbackAtlasKeyed(
        copy_string_array(font_keys),
        glyph_key_prefix,
        text,
        x,
        y,
        config,
        paint,
      )
    _ => command
  }
}

///|
fn copy_font_bytes_fallback_sources(
  sources : Array[FontBytesFallbackSource],
) -> Array[FontBytesFallbackSource] {
  let copied = []
  for source in sources {
    copied.push(source)
  }
  copied
}

///|
fn copy_string_array(values : Array[String]) -> Array[String] {
  let copied = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
/// Drop all queued commands.
pub fn RenderPipeline::clear_commands(self : RenderPipeline) -> Unit {
  self.commands.clear()
}

///|
/// Append an already constructed command.
pub fn RenderPipeline::push(
  self : RenderPipeline,
  command : RenderCommand,
) -> RenderPipeline {
  self.commands.push(command)
  self
}

///|
/// Queue a canvas clear command.
pub fn RenderPipeline::clear_canvas(
  self : RenderPipeline,
  color : @graphics.Color,
) -> RenderPipeline {
  self.push(Clear(color))
}

///|
/// Queue a filled rectangle command.
pub fn RenderPipeline::fill_rect(
  self : RenderPipeline,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(FillRect(x, y, width, height, paint))
}

///|
/// Queue a stroked rectangle command.
pub fn RenderPipeline::stroke_rect(
  self : RenderPipeline,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(StrokeRect(x, y, width, height, paint))
}

///|
/// Queue a filled path command.
pub fn RenderPipeline::fill_path(
  self : RenderPipeline,
  path : @graphics.Path,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(FillPath(path, paint))
}

///|
/// Queue a stroked path command.
pub fn RenderPipeline::stroke_path(
  self : RenderPipeline,
  path : @graphics.Path,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(StrokePath(path, paint))
}

///|
/// Queue a pixmap draw command.
pub fn RenderPipeline::draw_pixmap(
  self : RenderPipeline,
  pixmap : @graphics.Pixmap,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(DrawPixmap(pixmap, x, y, paint))
}

///|
/// Queue a keyed pixmap draw command for stable resource identity.
pub fn RenderPipeline::draw_pixmap_keyed(
  self : RenderPipeline,
  resource_key : String,
  pixmap : @graphics.Pixmap,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(DrawPixmapKeyed(resource_key, pixmap, x, y, paint))
}

///|
/// Queue a keyed BMP-bytes image command for RendererResources replay.
pub fn RenderPipeline::draw_bmp_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(DrawBmpBytesKeyed(resource_key, image_data, x, y, paint))
}

///|
/// Queue a keyed PNG-bytes image command for RendererResources replay.
pub fn RenderPipeline::draw_png_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(DrawPngBytesKeyed(resource_key, image_data, x, y, paint))
}

///|
/// Queue a keyed raw RGBA-bytes image command for RendererResources replay.
pub fn RenderPipeline::draw_rgba_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawRgbaBytesKeyed(
      resource_key, image_data, image_width, image_height, x, y, paint,
    ),
  )
}

///|
/// Queue a keyed sampled BMP-bytes image command.
pub fn RenderPipeline::draw_sampled_bmp_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawSampledBmpBytesKeyed(
      resource_key, image_data, x, y, width, height, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed sampled PNG-bytes image command.
pub fn RenderPipeline::draw_sampled_png_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawSampledPngBytesKeyed(
      resource_key, image_data, x, y, width, height, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed sampled raw RGBA-bytes image command.
pub fn RenderPipeline::draw_sampled_rgba_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawSampledRgbaBytesKeyed(
      resource_key, image_data, image_width, image_height, x, y, width, height, paint,
      sampling,
    ),
  )
}

///|
/// Queue a keyed quality-scaled BMP-bytes image command.
pub fn RenderPipeline::draw_quality_bmp_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawQualityBmpBytesKeyed(
      resource_key, image_data, x, y, width, height, paint, quality,
    ),
  )
}

///|
/// Queue a keyed quality-scaled BMP-bytes source-rectangle command.
pub fn RenderPipeline::draw_quality_bmp_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawQualityBmpBytesRectKeyed(
      resource_key, image_data, src_rect, x, y, width, height, paint, quality,
    ),
  )
}

///|
/// Queue a keyed quality-scaled PNG-bytes image command.
pub fn RenderPipeline::draw_quality_png_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawQualityPngBytesKeyed(
      resource_key, image_data, x, y, width, height, paint, quality,
    ),
  )
}

///|
/// Queue a keyed quality-scaled PNG-bytes source-rectangle command.
pub fn RenderPipeline::draw_quality_png_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawQualityPngBytesRectKeyed(
      resource_key, image_data, src_rect, x, y, width, height, paint, quality,
    ),
  )
}

///|
/// Queue a keyed quality-scaled raw RGBA-bytes image command.
pub fn RenderPipeline::draw_quality_rgba_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawQualityRgbaBytesKeyed(
      resource_key, image_data, image_width, image_height, x, y, width, height, paint,
      quality,
    ),
  )
}

///|
/// Queue a keyed quality-scaled raw RGBA-bytes source-rectangle command.
pub fn RenderPipeline::draw_quality_rgba_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawQualityRgbaBytesRectKeyed(
      resource_key, image_data, image_width, image_height, src_rect, x, y, width,
      height, paint, quality,
    ),
  )
}

///|
/// Queue a keyed transformed sampled BMP-bytes image command.
pub fn RenderPipeline::draw_transformed_sampled_bmp_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawTransformedSampledBmpBytesKeyed(
      resource_key, image_data, x, y, width, height, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed transformed sampled BMP-bytes source-rectangle command.
pub fn RenderPipeline::draw_transformed_sampled_bmp_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawTransformedSampledBmpBytesRectKeyed(
      resource_key, image_data, src_rect, x, y, width, height, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed transformed quality BMP-bytes image command.
pub fn RenderPipeline::draw_transformed_quality_bmp_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawTransformedQualityBmpBytesKeyed(
      resource_key, image_data, x, y, width, height, paint, quality,
    ),
  )
}

///|
/// Queue a keyed transformed quality BMP-bytes source-rectangle command.
pub fn RenderPipeline::draw_transformed_quality_bmp_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawTransformedQualityBmpBytesRectKeyed(
      resource_key, image_data, src_rect, x, y, width, height, paint, quality,
    ),
  )
}

///|
/// Queue a keyed transformed sampled PNG-bytes image command.
pub fn RenderPipeline::draw_transformed_sampled_png_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawTransformedSampledPngBytesKeyed(
      resource_key, image_data, x, y, width, height, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed transformed sampled PNG-bytes source-rectangle command.
pub fn RenderPipeline::draw_transformed_sampled_png_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawTransformedSampledPngBytesRectKeyed(
      resource_key, image_data, src_rect, x, y, width, height, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed transformed quality PNG-bytes image command.
pub fn RenderPipeline::draw_transformed_quality_png_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawTransformedQualityPngBytesKeyed(
      resource_key, image_data, x, y, width, height, paint, quality,
    ),
  )
}

///|
/// Queue a keyed transformed quality PNG-bytes source-rectangle command.
pub fn RenderPipeline::draw_transformed_quality_png_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawTransformedQualityPngBytesRectKeyed(
      resource_key, image_data, src_rect, x, y, width, height, paint, quality,
    ),
  )
}

///|
/// Queue a keyed transformed sampled raw RGBA-bytes image command.
pub fn RenderPipeline::draw_transformed_sampled_rgba_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawTransformedSampledRgbaBytesKeyed(
      resource_key, image_data, image_width, image_height, x, y, width, height, paint,
      sampling,
    ),
  )
}

///|
/// Queue a keyed transformed sampled raw RGBA-bytes source-rectangle command.
pub fn RenderPipeline::draw_transformed_sampled_rgba_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawTransformedSampledRgbaBytesRectKeyed(
      resource_key, image_data, image_width, image_height, src_rect, x, y, width,
      height, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed transformed quality raw RGBA-bytes image command.
pub fn RenderPipeline::draw_transformed_quality_rgba_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawTransformedQualityRgbaBytesKeyed(
      resource_key, image_data, image_width, image_height, x, y, width, height, paint,
      quality,
    ),
  )
}

///|
/// Queue a keyed transformed quality raw RGBA-bytes source-rectangle command.
pub fn RenderPipeline::draw_transformed_quality_rgba_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  paint : @graphics.Paint,
  quality : @graphics.ImageQuality,
) -> RenderPipeline {
  self.push(
    DrawTransformedQualityRgbaBytesRectKeyed(
      resource_key, image_data, image_width, image_height, src_rect, x, y, width,
      height, paint, quality,
    ),
  )
}

///|
/// Queue a keyed sampled BMP-bytes source-rectangle command.
pub fn RenderPipeline::draw_sampled_bmp_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawSampledBmpBytesRectKeyed(
      resource_key, image_data, src_rect, x, y, width, height, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed sampled PNG-bytes source-rectangle command.
pub fn RenderPipeline::draw_sampled_png_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawSampledPngBytesRectKeyed(
      resource_key, image_data, src_rect, x, y, width, height, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed sampled raw RGBA-bytes source-rectangle command.
pub fn RenderPipeline::draw_sampled_rgba_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawSampledRgbaBytesRectKeyed(
      resource_key, image_data, image_width, image_height, src_rect, x, y, width,
      height, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed BMP-bytes source-rectangle command for RendererResources replay.
pub fn RenderPipeline::draw_bmp_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawBmpBytesRectKeyed(resource_key, image_data, src_rect, x, y, paint),
  )
}

///|
/// Queue a keyed PNG-bytes source-rectangle command for RendererResources replay.
pub fn RenderPipeline::draw_png_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawPngBytesRectKeyed(resource_key, image_data, src_rect, x, y, paint),
  )
}

///|
/// Queue a keyed raw RGBA-bytes source-rectangle command.
pub fn RenderPipeline::draw_rgba_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawRgbaBytesRectKeyed(
      resource_key, image_data, image_width, image_height, src_rect, x, y, paint,
    ),
  )
}

///|
/// Queue a keyed tiled BMP-bytes source-rectangle command.
pub fn RenderPipeline::draw_tiled_bmp_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawTiledBmpBytesRectKeyed(
      resource_key, image_data, src_rect, x, y, width, height, paint,
    ),
  )
}

///|
/// Queue a keyed tiled PNG-bytes source-rectangle command.
pub fn RenderPipeline::draw_tiled_png_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawTiledPngBytesRectKeyed(
      resource_key, image_data, src_rect, x, y, width, height, paint,
    ),
  )
}

///|
/// Queue a keyed tiled raw RGBA-bytes source-rectangle command.
pub fn RenderPipeline::draw_tiled_rgba_bytes_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawTiledRgbaBytesRectKeyed(
      resource_key, image_data, image_width, image_height, src_rect, x, y, width,
      height, paint,
    ),
  )
}

///|
/// Queue a keyed BMP-bytes nine-patch command.
pub fn RenderPipeline::draw_nine_patch_bmp_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawNinePatchBmpBytesKeyed(
      resource_key, image_data, x, y, width, height, insets, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed PNG-bytes nine-patch command.
pub fn RenderPipeline::draw_nine_patch_png_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawNinePatchPngBytesKeyed(
      resource_key, image_data, x, y, width, height, insets, paint, sampling,
    ),
  )
}

///|
/// Queue a keyed raw RGBA-bytes nine-patch command.
pub fn RenderPipeline::draw_nine_patch_rgba_bytes_keyed(
  self : RenderPipeline,
  resource_key : String,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> RenderPipeline {
  self.push(
    DrawNinePatchRgbaBytesKeyed(
      resource_key, image_data, image_width, image_height, x, y, width, height, insets,
      paint, sampling,
    ),
  )
}

///|
/// Queue a source-rectangle pixmap draw command.
pub fn RenderPipeline::draw_pixmap_rect(
  self : RenderPipeline,
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(DrawPixmapRect(pixmap, src_rect, x, y, paint))
}

///|
/// Queue a keyed source-rectangle pixmap command for stable resource identity.
pub fn RenderPipeline::draw_pixmap_rect_keyed(
  self : RenderPipeline,
  resource_key : String,
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(DrawPixmapRectKeyed(resource_key, pixmap, src_rect, x, y, paint))
}

///|
/// Queue a text draw command using an already parsed font face.
pub fn RenderPipeline::draw_text_face(
  self : RenderPipeline,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(DrawTextFace(face, text, x, y, config, paint))
}

///|
/// Queue a keyed parsed-font text command for stable resource identity.
pub fn RenderPipeline::draw_text_face_keyed(
  self : RenderPipeline,
  resource_key : String,
  face : @text.FontFace,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(DrawTextFaceKeyed(resource_key, face, text, x, y, config, paint))
}

///|
/// Queue a keyed font-byte text command for RendererResources-backed replay.
pub fn RenderPipeline::draw_font_bytes_keyed(
  self : RenderPipeline,
  font_key : String,
  font_data : Bytes,
  text_key : String,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawFontBytesKeyed(font_key, font_data, text_key, text, x, y, config, paint),
  )
}

///|
/// Queue a keyed font-byte atlas text command for RendererResources replay.
pub fn RenderPipeline::draw_font_bytes_atlas_keyed(
  self : RenderPipeline,
  font_key : String,
  font_data : Bytes,
  glyph_key_prefix : String,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawFontBytesAtlasKeyed(
      font_key, font_data, glyph_key_prefix, text, x, y, config, paint,
    ),
  )
}

///|
/// Queue a keyed font-byte fallback text command for RendererResources replay.
pub fn RenderPipeline::draw_font_bytes_fallback_keyed(
  self : RenderPipeline,
  sources : Array[FontBytesFallbackSource],
  text_key_prefix : String,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawFontBytesFallbackKeyed(
      sources, text_key_prefix, text, x, y, config, paint,
    ),
  )
}

///|
/// Queue a keyed font-byte fallback atlas command for RendererResources replay.
pub fn RenderPipeline::draw_font_bytes_fallback_atlas_keyed(
  self : RenderPipeline,
  sources : Array[FontBytesFallbackSource],
  glyph_key_prefix : String,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawFontBytesFallbackAtlasKeyed(
      sources, glyph_key_prefix, text, x, y, config, paint,
    ),
  )
}

///|
/// Queue a keyed loader-backed text command for font-loader replay.
pub fn RenderPipeline::draw_loaded_font_keyed(
  self : RenderPipeline,
  font_key : String,
  text_key : String,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(DrawLoadedFontKeyed(font_key, text_key, text, x, y, config, paint))
}

///|
/// Queue a keyed loader-backed fallback text command for font-loader replay.
pub fn RenderPipeline::draw_loaded_font_fallback_keyed(
  self : RenderPipeline,
  font_keys : Array[String],
  text_key_prefix : String,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawLoadedFontFallbackKeyed(
      font_keys, text_key_prefix, text, x, y, config, paint,
    ),
  )
}

///|
/// Queue a keyed loader-backed fallback atlas command for font-loader replay.
pub fn RenderPipeline::draw_loaded_font_fallback_atlas_keyed(
  self : RenderPipeline,
  font_keys : Array[String],
  glyph_key_prefix : String,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawLoadedFontFallbackAtlasKeyed(
      font_keys, glyph_key_prefix, text, x, y, config, paint,
    ),
  )
}

///|
/// Queue a keyed loader-backed atlas text command for font-loader replay.
pub fn RenderPipeline::draw_loaded_font_atlas_keyed(
  self : RenderPipeline,
  font_key : String,
  glyph_key_prefix : String,
  text : String,
  x : Double,
  y : Double,
  config : @text.LayoutConfig,
  paint : @graphics.Paint,
) -> RenderPipeline {
  self.push(
    DrawLoadedFontAtlasKeyed(
      font_key, glyph_key_prefix, text, x, y, config, paint,
    ),
  )
}

///|
/// Draw an image through a caller-owned pixmap cache.
pub fn Renderer::draw_pixmap_cached(
  self : Renderer,
  pixmap : @graphics.Pixmap,
  x : Int,
  y : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> CachedPixmapDrawResult {
  let result = image_cache.get_or_insert_result(image_key, pixmap)
  self.canvas.draw_pixmap(result.get_pixmap(), x, y, paint)
  { did_insert_pixmap: result.did_insert() }
}

///|
/// Draw an image through renderer-owned resources and the pixmap cache.
pub fn Renderer::draw_pixmap_cached_with_renderer_resources(
  self : Renderer,
  pixmap : @graphics.Pixmap,
  x : Int,
  y : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> CachedPixmapDrawResult {
  self.draw_pixmap_cached(
    pixmap,
    x,
    y,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Draw a source rectangle from an image through a caller-owned pixmap cache.
pub fn Renderer::draw_pixmap_rect_cached(
  self : Renderer,
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> CachedPixmapDrawResult {
  let result = image_cache.get_or_insert_result(image_key, pixmap)
  self.canvas.draw_pixmap_rect(result.get_pixmap(), src_rect, x, y, paint)
  { did_insert_pixmap: result.did_insert() }
}

///|
/// Draw a source rectangle from an image through renderer-owned resources.
pub fn Renderer::draw_pixmap_rect_cached_with_renderer_resources(
  self : Renderer,
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> CachedPixmapDrawResult {
  self.draw_pixmap_rect_cached(
    pixmap,
    src_rect,
    x,
    y,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Draw a tiled source rectangle from an image through a caller-owned pixmap
/// cache.
pub fn Renderer::draw_tiled_pixmap_rect_cached(
  self : Renderer,
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> CachedPixmapDrawResult {
  let result = image_cache.get_or_insert_result(image_key, pixmap)
  self.canvas.draw_tiled_pixmap_rect(
    result.get_pixmap(),
    src_rect,
    x,
    y,
    width,
    height,
    paint,
  )
  { did_insert_pixmap: result.did_insert() }
}

///|
/// Draw a tiled source rectangle from an image through renderer-owned
/// resources.
pub fn Renderer::draw_tiled_pixmap_rect_cached_with_renderer_resources(
  self : Renderer,
  pixmap : @graphics.Pixmap,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> CachedPixmapDrawResult {
  self.draw_tiled_pixmap_rect_cached(
    pixmap,
    src_rect,
    x,
    y,
    width,
    height,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Draw an image through a pixmap cache using nine-patch scaling.
pub fn Renderer::draw_nine_patch_pixmap_cached(
  self : Renderer,
  pixmap : @graphics.Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> CachedPixmapDrawResult {
  let result = image_cache.get_or_insert_result(image_key, pixmap)
  self.canvas.draw_nine_patch_pixmap(
    result.get_pixmap(),
    x,
    y,
    width,
    height,
    insets,
    paint,
    sampling,
  )
  { did_insert_pixmap: result.did_insert() }
}

///|
/// Draw an image through renderer-owned resources using nine-patch scaling.
pub fn Renderer::draw_nine_patch_pixmap_cached_with_renderer_resources(
  self : Renderer,
  pixmap : @graphics.Pixmap,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> CachedPixmapDrawResult {
  self.draw_nine_patch_pixmap_cached(
    pixmap,
    x,
    y,
    width,
    height,
    insets,
    resources.get_image_cache(),
    image_key,
    paint,
    sampling,
  )
}

///|
/// Decode BMP bytes through a caller-owned pixmap cache and draw the image.
pub fn Renderer::draw_bmp_bytes_cached(
  self : Renderer,
  image_data : Bytes,
  x : Int,
  y : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedBmpPixmapDrawResult, @graphics.PixmapDecodeError] {
  match image_cache.get_or_decode_bmp_result(image_key, image_data) {
    Ok(result) => {
      self.canvas.draw_pixmap(result.get_pixmap(), x, y, paint)
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode BMP bytes through renderer-owned resources and draw the image.
pub fn Renderer::draw_bmp_bytes_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  x : Int,
  y : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedBmpPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_bmp_bytes_cached(
    image_data,
    x,
    y,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Decode PNG bytes through a caller-owned pixmap cache and draw the image.
pub fn Renderer::draw_png_bytes_cached(
  self : Renderer,
  image_data : Bytes,
  x : Int,
  y : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedPngPixmapDrawResult, @graphics.PixmapDecodeError] {
  match image_cache.get_or_decode_png_result(image_key, image_data) {
    Ok(result) => {
      self.canvas.draw_pixmap(result.get_pixmap(), x, y, paint)
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode PNG bytes through renderer-owned resources and draw the image.
pub fn Renderer::draw_png_bytes_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  x : Int,
  y : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedPngPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_png_bytes_cached(
    image_data,
    x,
    y,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Decode raw RGBA bytes through a caller-owned pixmap cache and draw the image.
pub fn Renderer::draw_rgba_bytes_cached(
  self : Renderer,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  x : Int,
  y : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedRgbaPixmapDrawResult, @graphics.PixmapDecodeError] {
  match
    image_cache.get_or_decode_rgba_result(
      image_key, image_width, image_height, image_data,
    ) {
    Ok(result) => {
      self.canvas.draw_pixmap(result.get_pixmap(), x, y, paint)
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode raw RGBA bytes through renderer-owned resources and draw the image.
pub fn Renderer::draw_rgba_bytes_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  x : Int,
  y : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedRgbaPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_rgba_bytes_cached(
    image_data,
    image_width,
    image_height,
    x,
    y,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Decode raw RGBA bytes through a pixmap cache and draw a source rectangle.
pub fn Renderer::draw_rgba_bytes_rect_cached(
  self : Renderer,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedRgbaPixmapDrawResult, @graphics.PixmapDecodeError] {
  match
    image_cache.get_or_decode_rgba_result(
      image_key, image_width, image_height, image_data,
    ) {
    Ok(result) => {
      self.canvas.draw_pixmap_rect(result.get_pixmap(), src_rect, x, y, paint)
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode raw RGBA bytes through renderer-owned resources and draw a source
/// rectangle.
pub fn Renderer::draw_rgba_bytes_rect_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedRgbaPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_rgba_bytes_rect_cached(
    image_data,
    image_width,
    image_height,
    src_rect,
    x,
    y,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Decode BMP bytes through a pixmap cache and draw a source rectangle.
pub fn Renderer::draw_bmp_bytes_rect_cached(
  self : Renderer,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedBmpPixmapDrawResult, @graphics.PixmapDecodeError] {
  match image_cache.get_or_decode_bmp_result(image_key, image_data) {
    Ok(result) => {
      self.canvas.draw_pixmap_rect(result.get_pixmap(), src_rect, x, y, paint)
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode BMP bytes through renderer-owned resources and draw a source rectangle.
pub fn Renderer::draw_bmp_bytes_rect_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedBmpPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_bmp_bytes_rect_cached(
    image_data,
    src_rect,
    x,
    y,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Decode PNG bytes through a pixmap cache and draw a source rectangle.
pub fn Renderer::draw_png_bytes_rect_cached(
  self : Renderer,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedPngPixmapDrawResult, @graphics.PixmapDecodeError] {
  match image_cache.get_or_decode_png_result(image_key, image_data) {
    Ok(result) => {
      self.canvas.draw_pixmap_rect(result.get_pixmap(), src_rect, x, y, paint)
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode PNG bytes through renderer-owned resources and draw a source rectangle.
pub fn Renderer::draw_png_bytes_rect_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedPngPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_png_bytes_rect_cached(
    image_data,
    src_rect,
    x,
    y,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Decode BMP bytes through a pixmap cache and draw a tiled source rectangle.
pub fn Renderer::draw_tiled_bmp_bytes_rect_cached(
  self : Renderer,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedBmpPixmapDrawResult, @graphics.PixmapDecodeError] {
  match image_cache.get_or_decode_bmp_result(image_key, image_data) {
    Ok(result) => {
      self.canvas.draw_tiled_pixmap_rect(
        result.get_pixmap(),
        src_rect,
        x,
        y,
        width,
        height,
        paint,
      )
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode BMP bytes through renderer-owned resources and draw a tiled source
/// rectangle.
pub fn Renderer::draw_tiled_bmp_bytes_rect_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedBmpPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_tiled_bmp_bytes_rect_cached(
    image_data,
    src_rect,
    x,
    y,
    width,
    height,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Decode PNG bytes through a pixmap cache and draw a tiled source rectangle.
pub fn Renderer::draw_tiled_png_bytes_rect_cached(
  self : Renderer,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedPngPixmapDrawResult, @graphics.PixmapDecodeError] {
  match image_cache.get_or_decode_png_result(image_key, image_data) {
    Ok(result) => {
      self.canvas.draw_tiled_pixmap_rect(
        result.get_pixmap(),
        src_rect,
        x,
        y,
        width,
        height,
        paint,
      )
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode PNG bytes through renderer-owned resources and draw a tiled source
/// rectangle.
pub fn Renderer::draw_tiled_png_bytes_rect_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedPngPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_tiled_png_bytes_rect_cached(
    image_data,
    src_rect,
    x,
    y,
    width,
    height,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Decode raw RGBA bytes through a pixmap cache and draw a tiled source
/// rectangle.
pub fn Renderer::draw_tiled_rgba_bytes_rect_cached(
  self : Renderer,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedRgbaPixmapDrawResult, @graphics.PixmapDecodeError] {
  match
    image_cache.get_or_decode_rgba_result(
      image_key, image_width, image_height, image_data,
    ) {
    Ok(result) => {
      self.canvas.draw_tiled_pixmap_rect(
        result.get_pixmap(),
        src_rect,
        x,
        y,
        width,
        height,
        paint,
      )
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode raw RGBA bytes through renderer-owned resources and draw a tiled
/// source rectangle.
pub fn Renderer::draw_tiled_rgba_bytes_rect_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  src_rect : @graphics.PixelRect,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
) -> Result[CachedRgbaPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_tiled_rgba_bytes_rect_cached(
    image_data,
    image_width,
    image_height,
    src_rect,
    x,
    y,
    width,
    height,
    resources.get_image_cache(),
    image_key,
    paint,
  )
}

///|
/// Decode BMP bytes through a pixmap cache and draw with nine-patch scaling.
pub fn Renderer::draw_nine_patch_bmp_bytes_cached(
  self : Renderer,
  image_data : Bytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[CachedBmpPixmapDrawResult, @graphics.PixmapDecodeError] {
  match image_cache.get_or_decode_bmp_result(image_key, image_data) {
    Ok(result) => {
      self.canvas.draw_nine_patch_pixmap(
        result.get_pixmap(),
        x,
        y,
        width,
        height,
        insets,
        paint,
        sampling,
      )
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode BMP bytes through renderer-owned resources and draw with nine-patch
/// scaling.
pub fn Renderer::draw_nine_patch_bmp_bytes_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[CachedBmpPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_nine_patch_bmp_bytes_cached(
    image_data,
    x,
    y,
    width,
    height,
    insets,
    resources.get_image_cache(),
    image_key,
    paint,
    sampling,
  )
}

///|
/// Decode PNG bytes through a pixmap cache and draw with nine-patch scaling.
pub fn Renderer::draw_nine_patch_png_bytes_cached(
  self : Renderer,
  image_data : Bytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[CachedPngPixmapDrawResult, @graphics.PixmapDecodeError] {
  match image_cache.get_or_decode_png_result(image_key, image_data) {
    Ok(result) => {
      self.canvas.draw_nine_patch_pixmap(
        result.get_pixmap(),
        x,
        y,
        width,
        height,
        insets,
        paint,
        sampling,
      )
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode PNG bytes through renderer-owned resources and draw with nine-patch
/// scaling.
pub fn Renderer::draw_nine_patch_png_bytes_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[CachedPngPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_nine_patch_png_bytes_cached(
    image_data,
    x,
    y,
    width,
    height,
    insets,
    resources.get_image_cache(),
    image_key,
    paint,
    sampling,
  )
}

///|
/// Decode raw RGBA bytes through a pixmap cache and draw with nine-patch
/// scaling.
pub fn Renderer::draw_nine_patch_rgba_bytes_cached(
  self : Renderer,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  image_cache : @graphics.PixmapCache,
  image_key : String,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[CachedRgbaPixmapDrawResult, @graphics.PixmapDecodeError] {
  match
    image_cache.get_or_decode_rgba_result(
      image_key, image_width, image_height, image_data,
    ) {
    Ok(result) => {
      self.canvas.draw_nine_patch_pixmap(
        result.get_pixmap(),
        x,
        y,
        width,
        height,
        insets,
        paint,
        sampling,
      )
      Ok({ did_decode_pixmap: result.did_decode() })
    }
    Err(error) => Err(error)
  }
}

///|
/// Decode raw RGBA bytes through renderer-owned resources and draw with
/// nine-patch scaling.
pub fn Renderer::draw_nine_patch_rgba_bytes_cached_with_renderer_resources(
  self : Renderer,
  image_data : Bytes,
  image_width : Int,
  image_height : Int,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  insets : @graphics.NinePatchInsets,
  resources : RendererResources,
  image_key : String,
  paint : @graphics.Paint,
  sampling : @graphics.ImageSampling,
) -> Result[CachedRgbaPixmapDrawResult, @graphics.PixmapDecodeError] {
  self.draw_nine_patch_rgba_bytes_cached(
    image_data,
    image_width,
    image_height,
    x,
    y,
    width,
    height,
    insets,
    resources.get_image_cache(),
    image_key,
    paint,
    sampling,
  )
}

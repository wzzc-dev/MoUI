///|
fn SunRasterRenderer::draw_image(
  self : SunRasterRenderer,
  image : @core.ImageRun,
  opacity : Double,
) -> Unit {
  guard image.frame.size.width > 0.0 && image.frame.size.height > 0.0 else {
    return
  }
  match self.sun_image_for_source(image.source) {
    Some(pixmap) => self.draw_image_pixmap(image, pixmap, opacity)
    None => self.draw_image_placeholder(image, opacity)
  }
}

///|
fn SunRasterRenderer::sun_image_for_source(
  self : SunRasterRenderer,
  source : String,
) -> @sun_graphics.Pixmap? {
  match self.resources.get_image_cache().get(source) {
    Some(pixmap) => Some(pixmap)
    None =>
      if self.async_image_loading {
        self.sun_async_image_for_source(source)
      } else {
        self.sun_sync_image_for_source(source)
      }
  }
}

///|
fn SunRasterRenderer::sun_sync_image_for_source(
  self : SunRasterRenderer,
  source : String,
) -> @sun_graphics.Pixmap? {
  match self.image_lifecycle.lookup(source) {
    Some({ status: @render.ImageResourceStatus::ImageFailed, .. }) =>
      if !sun_image_failed_record_can_retry(source) {
        return None
      }
    _ => ()
  }
  match sun_image_source_bytes(source) {
    Some(_) => self.mark_sun_image_loading_if_needed(source)
    None => ()
  }
  match self.decode_image_source_with_cache(source) {
    Ok(pixmap) => {
      self.mark_sun_image_ready_if_needed(source, pixmap)
      Some(pixmap)
    }
    Err(diagnostic) => {
      self.mark_sun_image_failed_if_needed(source, diagnostic)
      self.record_unsupported_command("DrawImage", diagnostic)
      None
    }
  }
}

///|
fn SunRasterRenderer::sun_async_image_for_source(
  self : SunRasterRenderer,
  source : String,
) -> @sun_graphics.Pixmap? {
  match self.image_lifecycle.lookup(source) {
    Some({ status: @render.ImageResourceStatus::ImageLoading, .. }) => None
    Some({ status: @render.ImageResourceStatus::ImageReady, .. }) =>
      match self.decode_image_source_with_cache(source) {
        Ok(pixmap) => Some(pixmap)
        Err(diagnostic) => {
          self.mark_sun_image_failed_if_needed(source, diagnostic)
          self.record_unsupported_command("DrawImage", diagnostic)
          None
        }
      }
    Some({ status: @render.ImageResourceStatus::ImageFailed, .. }) =>
      if sun_image_failed_record_can_retry(source) {
        self.mark_sun_image_loading_if_needed(source)
        None
      } else {
        None
      }
    _ => {
      self.mark_sun_image_loading_if_needed(source)
      None
    }
  }
}

///|
fn SunRasterRenderer::mark_sun_image_loading_if_needed(
  self : SunRasterRenderer,
  source : String,
) -> Unit {
  match self.image_lifecycle.lookup(source) {
    Some({ status: @render.ImageResourceStatus::ImageLoading, .. }) => ()
    _ => {
      let previous_revision = self.image_lifecycle.revision()
      ignore(self.image_lifecycle.mark_loading(source))
      self.notify_image_resource_change_if_needed(previous_revision)
    }
  }
}

///|
fn SunRasterRenderer::mark_sun_image_ready_if_needed(
  self : SunRasterRenderer,
  source : String,
  pixmap : @sun_graphics.Pixmap,
) -> Unit {
  if sun_image_record_needs_ready_update(
      self.image_lifecycle.lookup(source),
      pixmap.get_width(),
      pixmap.get_height(),
    ) {
    let previous_revision = self.image_lifecycle.revision()
    ignore(
      self.image_lifecycle.mark_ready(
        source,
        width=pixmap.get_width(),
        height=pixmap.get_height(),
      ),
    )
    self.notify_image_resource_change_if_needed(previous_revision)
  }
}

///|
fn SunRasterRenderer::mark_sun_image_failed_if_needed(
  self : SunRasterRenderer,
  source : String,
  diagnostic : String,
) -> Unit {
  if sun_image_record_needs_failed_update(
      self.image_lifecycle.lookup(source),
      diagnostic,
    ) {
    let previous_revision = self.image_lifecycle.revision()
    ignore(self.image_lifecycle.mark_failed(source, diagnostic~))
    self.notify_image_resource_change_if_needed(previous_revision)
  }
}

///|
fn SunRasterRenderer::draw_image_pixmap(
  self : SunRasterRenderer,
  image : @core.ImageRun,
  pixmap : @sun_graphics.Pixmap,
  opacity : Double,
) -> Unit {
  let placement = sun_image_placement(
    image.frame,
    @core.Size::new(
      width=pixmap.get_width().to_double(),
      height=pixmap.get_height().to_double(),
    ),
    image.fit,
  )
  let paint = @sun_graphics.Paint::new().set_opacity(image.opacity * opacity)
  let dst_x = sun_dim_to_int(placement.frame.origin.x)
  let dst_y = sun_dim_to_int(placement.frame.origin.y)
  let dst_w = sun_dim_to_int(placement.frame.size.width)
  let dst_h = sun_dim_to_int(placement.frame.size.height)
  guard dst_w > 0 && dst_h > 0 else { return }
  match placement.src_rect {
    Some(src_rect) =>
      self.canvas.draw_quality_pixmap_rect(
        pixmap,
        src_rect,
        dst_x,
        dst_y,
        dst_w,
        dst_h,
        paint,
        @sun_graphics.ImageQuality::Balanced,
      )
    None =>
      self.canvas.draw_quality_pixmap(
        pixmap,
        dst_x,
        dst_y,
        dst_w,
        dst_h,
        paint,
        @sun_graphics.ImageQuality::Balanced,
      )
  }
}

///|
fn SunRasterRenderer::draw_image_placeholder(
  self : SunRasterRenderer,
  image : @core.ImageRun,
  opacity : Double,
) -> Unit {
  self.canvas.fill_rect(
    image.frame.origin.x,
    image.frame.origin.y,
    image.frame.size.width,
    image.frame.size.height,
    sun_brush_paint(sun_image_placeholder_brush(image), opacity),
  )
}

///|
fn SunRasterRenderer::decode_image_source_with_cache(
  self : SunRasterRenderer,
  source : String,
) -> Result[@sun_graphics.Pixmap, String] {
  sun_decode_image_source_with_cache(self.resources.get_image_cache(), source)
}

///|
fn sun_decode_image_source_with_cache(
  cache : @sun_graphics.PixmapCache,
  source : String,
) -> Result[@sun_graphics.Pixmap, String] {
  match cache.get(source) {
    Some(pixmap) => Ok(pixmap)
    None =>
      match sun_image_source_bytes(source) {
        Some({ format, data }) =>
          sun_decode_image_data_with_fallback(
            cache,
            source,
            data,
            Some(format),
            "source",
            "Sun renderer could not decode image source: \{source}",
          )
        None => Err("Sun renderer could not decode image source: \{source}")
      }
  }
}

///|
fn sun_decode_image_bytes_with_cache(
  cache : @sun_graphics.PixmapCache,
  source : String,
  data : Bytes,
) -> Result[@sun_graphics.Pixmap, String] {
  sun_decode_image_data_with_fallback(
    cache,
    source,
    data,
    sun_image_format_for_source(source, sun_image_media_type(source)),
    "bytes",
    "Sun renderer could not infer image format: \{source}",
  )
}

///|
fn sun_decode_image_data_with_fallback(
  cache : @sun_graphics.PixmapCache,
  source : String,
  data : Bytes,
  source_format : SunImageFormat?,
  failure_kind : String,
  infer_diagnostic : String,
) -> Result[@sun_graphics.Pixmap, String] {
  let byte_format = sun_image_format_for_bytes(data)
  let format = match source_format {
    Some(format) => Some(format)
    None => byte_format
  }
  match format {
    Some(format) =>
      match
        sun_decode_image_data_as_format(
          cache, source, data, format, failure_kind,
        ) {
        Ok(pixmap) => Ok(pixmap)
        Err(diagnostic) =>
          match byte_format {
            Some(fallback_format) =>
              if !sun_image_format_is_same(fallback_format, format) {
                sun_decode_image_data_as_format(
                  cache, source, data, fallback_format, failure_kind,
                )
              } else {
                Err(diagnostic)
              }
            None => Err(diagnostic)
          }
      }
    None => Err(infer_diagnostic)
  }
}

///|
fn sun_decode_image_data_as_format(
  cache : @sun_graphics.PixmapCache,
  source : String,
  data : Bytes,
  format : SunImageFormat,
  failure_kind : String,
) -> Result[@sun_graphics.Pixmap, String] {
  match format {
    SunImageFormat::Png =>
      match cache.get_or_decode_png_result(source, data) {
        Ok(result) => Ok(result.get_pixmap())
        Err(_) =>
          Err(
            "Sun renderer could not decode PNG image \{failure_kind}: \{source}",
          )
      }
    SunImageFormat::Bmp =>
      match cache.get_or_decode_bmp_result(source, data) {
        Ok(result) => Ok(result.get_pixmap())
        Err(_) =>
          Err(
            "Sun renderer could not decode BMP image \{failure_kind}: \{source}",
          )
      }
    SunImageFormat::Jpeg =>
      sun_decode_jpeg_image_with_cache(
        cache,
        source,
        data,
        failure_kind="bytes",
      )
  }
}

///|
fn sun_decode_jpeg_image_with_cache(
  cache : @sun_graphics.PixmapCache,
  source : String,
  data : Bytes,
  failure_kind~ : String,
) -> Result[@sun_graphics.Pixmap, String] {
  match cache.get(source) {
    Some(pixmap) => Ok(pixmap)
    None => {
      let decoded = @image.decode_jpeg(data) catch {
        _ =>
          return Err(
            "Sun renderer could not decode JPEG image \{failure_kind}: \{source}",
          )
      }
      match
        cache.get_or_decode_rgba_result(
          source,
          decoded.width,
          decoded.height,
          decoded.data,
        ) {
        Ok(result) => Ok(result.get_pixmap())
        Err(_) =>
          Err(
            "Sun renderer could not decode JPEG image \{failure_kind}: \{source}",
          )
      }
    }
  }
}

///|
pub fn sun_image_load_completion(
  source : String,
) -> @render.ImageResourceLoadCompletion {
  let cache = @sun_graphics.PixmapCache::with_capacity(1)
  match sun_decode_image_source_with_cache(cache, source) {
    Ok(pixmap) =>
      @render.ImageResourceLoadCompletion::ready(
        source,
        width=pixmap.get_width(),
        height=pixmap.get_height(),
      )
    Err(diagnostic) =>
      @render.ImageResourceLoadCompletion::failed(source, diagnostic~)
  }
}

///|
pub fn sun_image_load_completion_from_bytes(
  source : String,
  data : Bytes,
  background_io? : Bool = false,
) -> @render.ImageResourceLoadCompletion {
  let cache = @sun_graphics.PixmapCache::with_capacity(1)
  match sun_decode_image_bytes_with_cache(cache, source, data) {
    Ok(pixmap) =>
      @render.ImageResourceLoadCompletion::ready(
        source,
        width=pixmap.get_width(),
        height=pixmap.get_height(),
        background_io~,
      )
    Err(diagnostic) =>
      @render.ImageResourceLoadCompletion::failed(
        source,
        diagnostic~,
        background_io~,
      )
  }
}

///|
priv enum SunImageFormat {
  Png
  Bmp
  Jpeg
}

///|
priv struct SunImageSourceBytes {
  format : SunImageFormat
  data : Bytes
}

///|
priv struct SunImagePlacement {
  frame : @core.Rect
  src_rect : @sun_graphics.PixelRect?
}

///|
fn sun_image_source_bytes(source : String) -> SunImageSourceBytes? {
  if source.has_prefix("data:") {
    sun_parse_data_uri(source)
  } else if @fs.path_exists(source) {
    let data = Some(@fs.read_file_to_bytes(source)) catch { _ => None }
    match data {
      Some(bytes) =>
        match sun_image_format_for_source_or_bytes(source, "", bytes) {
          Some(format) => Some({ format, data: bytes })
          None => None
        }
      None => None
    }
  } else {
    None
  }
}

///|
fn sun_image_failed_record_can_retry(source : String) -> Bool {
  !source.has_prefix("data:") && @fs.path_exists(source)
}

///|
fn sun_parse_data_uri(uri : String) -> SunImageSourceBytes? {
  let semicolon_pos = uri.find(";")
  let comma_pos = uri.find(",")
  guard semicolon_pos is Some(semi_idx) else { return None }
  guard comma_pos is Some(comma_idx) else { return None }
  guard comma_idx > semi_idx else { return None }
  let chars = uri.to_array()
  let meta = sun_image_media_type(uri)
  let encoding = String::from_array(chars[semi_idx + 1:comma_idx])
  guard encoding == "base64" else { return None }
  let data_part = String::from_array(chars[comma_idx + 1:])
  let decoded : Bytes? = Some(@base64.decode(data_part, ignore_whitespace=true)) catch {
    _ => None
  }
  match decoded {
    Some(data) =>
      match sun_image_format_for_source_or_bytes("", meta, data) {
        Some(format) => Some({ format, data })
        None => None
      }
    None => None
  }
}

///|
fn sun_image_media_type(source : String) -> String {
  guard source.has_prefix("data:") else { return "" }
  let semicolon_pos = source.find(";")
  guard semicolon_pos is Some(semi_idx) else { return "" }
  let chars = source.to_array()
  String::from_array(chars[5:semi_idx])
}

///|
fn sun_image_format_for_source(
  source : String,
  media_type : String,
) -> SunImageFormat? {
  let normalized_media_type = media_type.to_lower()
  let normalized_source = source.to_lower()
  if normalized_media_type.contains("png") ||
    normalized_source.has_suffix(".png") {
    Some(SunImageFormat::Png)
  } else if normalized_media_type.contains("bmp") ||
    normalized_source.has_suffix(".bmp") {
    Some(SunImageFormat::Bmp)
  } else if normalized_media_type.contains("jpeg") ||
    normalized_media_type.contains("jpg") ||
    normalized_source.has_suffix(".jpg") ||
    normalized_source.has_suffix(".jpeg") {
    Some(SunImageFormat::Jpeg)
  } else {
    None
  }
}

///|
fn sun_image_format_for_source_or_bytes(
  source : String,
  media_type : String,
  data : Bytes,
) -> SunImageFormat? {
  match sun_image_format_for_source(source, media_type) {
    Some(format) => Some(format)
    None => sun_image_format_for_bytes(data)
  }
}

///|
fn sun_image_format_is_same(
  left : SunImageFormat,
  right : SunImageFormat,
) -> Bool {
  match left {
    SunImageFormat::Png =>
      match right {
        SunImageFormat::Png => true
        _ => false
      }
    SunImageFormat::Bmp =>
      match right {
        SunImageFormat::Bmp => true
        _ => false
      }
    SunImageFormat::Jpeg =>
      match right {
        SunImageFormat::Jpeg => true
        _ => false
      }
  }
}

///|
fn sun_image_format_for_bytes(data : Bytes) -> SunImageFormat? {
  if data.length() >= 8 &&
    data[0] == 137 &&
    data[1] == 80 &&
    data[2] == 78 &&
    data[3] == 71 &&
    data[4] == 13 &&
    data[5] == 10 &&
    data[6] == 26 &&
    data[7] == 10 {
    Some(SunImageFormat::Png)
  } else if data.length() >= 2 && data[0] == 66 && data[1] == 77 {
    Some(SunImageFormat::Bmp)
  } else if data.length() >= 2 && data[0] == 255 && data[1] == 216 {
    Some(SunImageFormat::Jpeg)
  } else {
    None
  }
}

///|
fn sun_image_placeholder_brush(run : @core.ImageRun) -> @core.Brush {
  @core.Brush::linear_gradient(
    start=run.frame.origin,
    end=@core.Point::new(
      x=run.frame.origin.x + run.frame.size.width,
      y=run.frame.origin.y + run.frame.size.height,
    ),
    start_color=@core.Color::rgba(r=0.72, g=0.78, b=0.86, a=run.opacity),
    end_color=@core.Color::rgba(r=0.42, g=0.50, b=0.62, a=run.opacity),
  )
}

///|
fn sun_image_placement(
  frame : @core.Rect,
  image_size : @core.Size,
  fit : @core.ImageFit,
) -> SunImagePlacement {
  let placement = @render.image_placement(frame, image_size, fit)
  match placement.crop_axis {
    @render.ImageCropAxis::None => { frame: placement.frame, src_rect: None }
    @render.ImageCropAxis::Horizontal => {
      let crop_width = (image_size.width * placement.visible)
        .round()
        .to_int()
      let left = ((image_size.width - crop_width.to_double()) * 0.5)
        .round()
        .to_int()
      {
        frame: placement.frame,
        src_rect: Some(
          @sun_graphics.PixelRect::new(
            x=left,
            y=0,
            width=crop_width,
            height=image_size.height.round().to_int(),
          ),
        ),
      }
    }
    @render.ImageCropAxis::Vertical => {
      let crop_height = (image_size.height * placement.visible)
        .round()
        .to_int()
      let top = ((image_size.height - crop_height.to_double()) * 0.5)
        .round()
        .to_int()
      {
        frame: placement.frame,
        src_rect: Some(
          @sun_graphics.PixelRect::new(
            x=0,
            y=top,
            width=image_size.width.round().to_int(),
            height=crop_height,
          ),
        ),
      }
    }
  }
}
///|
fn sun_image_record_needs_ready_update(
  record : @render.ImageResourceRecord?,
  width : Int,
  height : Int,
) -> Bool {
  match record {
    Some(existing) =>
      existing.status != @render.ImageResourceStatus::ImageReady ||
      existing.width != width ||
      existing.height != height
    None => true
  }
}

///|
fn sun_image_record_needs_failed_update(
  record : @render.ImageResourceRecord?,
  diagnostic : String,
) -> Bool {
  match record {
    Some(existing) =>
      existing.status != @render.ImageResourceStatus::ImageFailed ||
      existing.diagnostic != diagnostic
    None => true
  }
}

///|
fn SunRasterRenderer::notify_image_resource_change_if_needed(
  self : SunRasterRenderer,
  previous_revision : Int,
) -> Unit {
  if self.image_lifecycle.revision() > previous_revision {
    match self.on_image_resource_change {
      Some(notify) => notify(self.image_lifecycle.snapshot_with_revision())
      None => ()
    }
  }
}

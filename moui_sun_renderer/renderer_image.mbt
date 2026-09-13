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
    _ => ignore(self.image_lifecycle.mark_loading(source))
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
    ignore(
      self.image_lifecycle.mark_ready(
        source,
        width=pixmap.get_width(),
        height=pixmap.get_height(),
      ),
    )
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
    ignore(self.image_lifecycle.mark_failed(source, diagnostic~))
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
/// Placeholder for an image that is not on screen yet. Same design as the Skia
/// renderer's (see `moui_skia_renderer/renderer_image.mbt`): a near-transparent
/// neutral card with a hairline border and a centered "picture" glyph, instead
/// of a full-frame opaque gradient. Only the primitives differ — this canvas
/// paints through `@sun_graphics`, which has its own rounded-rect, circle,
/// polygon and line calls.
fn SunRasterRenderer::draw_image_placeholder(
  self : SunRasterRenderer,
  image : @core.ImageRun,
  opacity : Double,
) -> Unit {
  let frame = image.frame
  guard frame.size.width > 0.0 && frame.size.height > 0.0 else { return }
  let failed = self.sun_image_placeholder_failed(image.source)
  let radius = sun_image_placeholder_radius(frame)
  self.canvas.fill_rounded_rect(
    frame.origin.x,
    frame.origin.y,
    frame.size.width,
    frame.size.height,
    radius,
    sun_brush_paint(sun_image_placeholder_fill(image), opacity),
  )
  self.canvas.stroke_rounded_rect(
    frame.origin.x,
    frame.origin.y,
    frame.size.width,
    frame.size.height,
    radius,
    sun_brush_paint(sun_image_placeholder_border(image, failed), opacity).set_stroke_width(
      sun_image_placeholder_border_width,
    ),
  )
  match sun_image_placeholder_glyph_box(frame) {
    Some(box) => self.draw_image_placeholder_glyph(box, image, opacity, failed)
    None => ()
  }
}

///|
/// Card corner radius, clamped so a box shorter than the radius still gets a
/// sensible quarter-round instead of an over-rounded pill.
let sun_image_placeholder_radius_max : Double = 8.0

///|
fn sun_image_placeholder_radius(frame : @core.Rect) -> Double {
  let half = sun_image_placeholder_min(frame.size.width, frame.size.height) /
    2.0
  if half < sun_image_placeholder_radius_max {
    half
  } else {
    sun_image_placeholder_radius_max
  }
}

///|
fn sun_image_placeholder_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn sun_image_placeholder_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
let sun_image_placeholder_border_width : Double = 1.0

///|
/// Shortest side that still fits a legible glyph; below this the card stands
/// alone (badges and inline thumbnails are too small to draw into).
let sun_image_placeholder_glyph_min_side : Double = 48.0

///|
let sun_image_placeholder_glyph_stroke : Double = 1.5

///|
fn sun_image_placeholder_fill(run : @core.ImageRun) -> @core.Brush {
  @core.Brush::solid(
    @core.Color::rgba(r=0.42, g=0.47, b=0.55, a=0.07 * run.opacity),
  )
}

///|
fn sun_image_placeholder_border(
  run : @core.ImageRun,
  failed : Bool,
) -> @core.Brush {
  let alpha = if failed { 0.34 } else { 0.18 }
  @core.Brush::solid(
    @core.Color::rgba(r=0.42, g=0.47, b=0.55, a=alpha * run.opacity),
  )
}

///|
fn sun_image_placeholder_glyph_brush(
  run : @core.ImageRun,
  failed : Bool,
) -> @core.Brush {
  let alpha = if failed { 0.62 } else { 0.45 }
  @core.Brush::solid(
    @core.Color::rgba(r=0.38, g=0.44, b=0.54, a=alpha * run.opacity),
  )
}

///|
/// True when the source is known to have failed, read from the same lifecycle
/// record `sun_image_for_source` writes.
fn SunRasterRenderer::sun_image_placeholder_failed(
  self : SunRasterRenderer,
  source : String,
) -> Bool {
  match self.image_lifecycle.lookup(source) {
    Some({ status: @render.ImageResourceStatus::ImageFailed, .. }) => true
    _ => false
  }
}

///|
/// Square glyph box centered in the card, or `None` when the card is too small.
fn sun_image_placeholder_glyph_box(frame : @core.Rect) -> @core.Rect? {
  let short = sun_image_placeholder_min(frame.size.width, frame.size.height)
  if short < sun_image_placeholder_glyph_min_side {
    return None
  }
  let side = sun_image_placeholder_max(
    short * 0.34,
    sun_image_placeholder_glyph_min_side * 0.34,
  )
  let side = sun_image_placeholder_min(side, 40.0)
  Some(
    @core.Rect::new(
      x=frame.origin.x + (frame.size.width - side) / 2.0,
      y=frame.origin.y + (frame.size.height - side) / 2.0,
      width=side,
      height=side,
    ),
  )
}

///|
/// The "picture" glyph: rounded frame, sun, peak, plus a slash when the load
/// failed. Fractions of `box`, so one geometry serves every size.
fn SunRasterRenderer::draw_image_placeholder_glyph(
  self : SunRasterRenderer,
  box : @core.Rect,
  run : @core.ImageRun,
  opacity : Double,
  failed : Bool,
) -> Unit {
  let paint = sun_brush_paint(
    sun_image_placeholder_glyph_brush(run, failed),
    opacity,
  )
  let stroke = sun_image_placeholder_glyph_stroke
  let at = (fx : Double, fy : Double) => {
    @sun_graphics.Point::new(
      x=box.origin.x + box.size.width * fx,
      y=box.origin.y + box.size.height * fy,
    )
  }
  let side = sun_image_placeholder_min(box.size.width, box.size.height)
  let inset = stroke / 2.0
  self.canvas.stroke_rounded_rect(
    box.origin.x + inset,
    box.origin.y + inset,
    box.size.width - stroke,
    box.size.height - stroke,
    side * 0.18,
    paint.set_stroke_width(stroke),
  )
  let sun_center = at(0.33, 0.34)
  self.canvas.fill_circle(sun_center.x, sun_center.y, side * 0.085, paint)
  self.canvas.fill_polygon(
    [at(0.16, 0.76), at(0.45, 0.44), at(0.74, 0.76)],
    paint,
  )
  if failed {
    // Slash across the frame, past both corners so it cannot be mistaken for
    // part of the picture.
    let from = at(0.06, 0.06)
    let to = at(0.94, 0.94)
    self.canvas.stroke_line(
      from.x,
      from.y,
      to.x,
      to.y,
      paint.set_stroke_width(stroke),
    )
  }
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
  match sun_image_source_bytes(source) {
    Some({ data, .. }) => sun_image_load_completion_from_bytes(source, data)
    None =>
      @render.ImageResourceLoadCompletion::failed(
        source,
        diagnostic="Sun renderer could not decode image source: \{source}",
      )
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
      @render.ImageResourceLoadCompletion::ready_decoded_rgba(
        source,
        width=pixmap.get_width(),
        height=pixmap.get_height(),
        row_bytes=pixmap.get_width() * 4,
        pixmap.to_rgba_bytes(),
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
  } else {
    None
  }
}

///|
fn sun_image_failed_record_can_retry(source : String) -> Bool {
  let _ = source
  false
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
fn sun_image_placement(
  frame : @core.Rect,
  image_size : @core.Size,
  fit : @core.ImageFit,
) -> SunImagePlacement {
  let placement = @render_common.image_placement(frame, image_size, fit)
  match placement.crop_axis {
    @render_common.ImageCropAxis::None =>
      { frame: placement.frame, src_rect: None }
    @render_common.ImageCropAxis::Horizontal => {
      let crop_width = (image_size.width * placement.visible).round().to_int()
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
    @render_common.ImageCropAxis::Vertical => {
      let crop_height = (image_size.height * placement.visible).round().to_int()
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

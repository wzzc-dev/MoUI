///|
fn SunRasterRenderer::draw_image(
  self : SunRasterRenderer,
  image : @core.ImageRun,
  opacity : Double,
) -> Unit {
  guard image.frame.size.width > 0.0 && image.frame.size.height > 0.0 else {
    return
  }
  let previous_revision = self.image_lifecycle.revision()
  let cache = self.resources.get_image_cache()
  let had_cached_pixmap = cache.contains(image.source)
  let decode = self.decode_image_source_with_cache(image.source)
  match decode {
    Ok(pixmap) => {
      if !had_cached_pixmap ||
        sun_image_record_needs_ready_update(
          self.image_lifecycle.lookup(image.source),
          pixmap.get_width(),
          pixmap.get_height(),
        ) {
        ignore(
          self.image_lifecycle.mark_ready(
            image.source,
            width=pixmap.get_width(),
            height=pixmap.get_height(),
          ),
        )
      }
      let placement = sun_image_placement(
        image.frame,
        @core.Size::new(
          width=pixmap.get_width().to_double(),
          height=pixmap.get_height().to_double(),
        ),
        image.fit,
      )
      let paint = @sun_graphics.Paint::new().set_opacity(
        image.opacity * opacity,
      )
      let dst_x = sun_dim_to_int(placement.frame.origin.x)
      let dst_y = sun_dim_to_int(placement.frame.origin.y)
      let dst_w = sun_dim_to_int(placement.frame.size.width)
      let dst_h = sun_dim_to_int(placement.frame.size.height)
      if dst_w <= 0 || dst_h <= 0 {
        self.notify_image_resource_change_if_needed(previous_revision)
        return
      }
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
    Err(diagnostic) => {
      if sun_image_record_needs_failed_update(
          self.image_lifecycle.lookup(image.source),
          diagnostic,
        ) {
        ignore(self.image_lifecycle.mark_failed(image.source, diagnostic~))
      }
      self.record_unsupported_command("DrawImage", diagnostic)
    }
  }
  self.notify_image_resource_change_if_needed(previous_revision)
}

///|
fn SunRasterRenderer::decode_image_source_with_cache(
  self : SunRasterRenderer,
  source : String,
) -> Result[@sun_graphics.Pixmap, String] {
  match self.resources.get_image_cache().get(source) {
    Some(pixmap) => Ok(pixmap)
    None =>
      match sun_image_source_bytes(source) {
        Some({ format: SunImageFormat::Png, data }) =>
          match
            self.resources
            .get_image_cache()
            .get_or_decode_png_result(source, data) {
            Ok(result) => Ok(result.get_pixmap())
            Err(_) =>
              Err("Sun renderer could not decode PNG image source: \{source}")
          }
        Some({ format: SunImageFormat::Bmp, data }) =>
          match
            self.resources
            .get_image_cache()
            .get_or_decode_bmp_result(source, data) {
            Ok(result) => Ok(result.get_pixmap())
            Err(_) =>
              Err("Sun renderer could not decode BMP image source: \{source}")
          }
        None => Err("Sun renderer could not decode image source: \{source}")
      }
  }
}

///|
priv enum SunImageFormat {
  Png
  Bmp
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
        match sun_image_format_for_source(source, "") {
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
fn sun_parse_data_uri(uri : String) -> SunImageSourceBytes? {
  let semicolon_pos = uri.find(";")
  let comma_pos = uri.find(",")
  guard semicolon_pos is Some(semi_idx) else { return None }
  guard comma_pos is Some(comma_idx) else { return None }
  guard comma_idx > semi_idx else { return None }
  let chars = uri.to_array()
  let meta = String::from_array(chars[5:semi_idx])
  let encoding = String::from_array(chars[semi_idx + 1:comma_idx])
  guard encoding == "base64" else { return None }
  let data_part = String::from_array(chars[comma_idx + 1:])
  match sun_image_format_for_source("", meta) {
    Some(format) =>
      Some({ format, data: @base64.decode(data_part, ignore_whitespace=true) }) catch {
        _ => None
      }
    None => None
  }
}

///|
fn sun_image_format_for_source(
  source : String,
  media_type : String,
) -> SunImageFormat? {
  if media_type.contains("png") || source.has_suffix(".png") {
    Some(SunImageFormat::Png)
  } else if media_type.contains("bmp") || source.has_suffix(".bmp") {
    Some(SunImageFormat::Bmp)
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
  if image_size.width <= 0.0 ||
    image_size.height <= 0.0 ||
    frame.size.width <= 0.0 ||
    frame.size.height <= 0.0 {
    return { frame, src_rect: None }
  }
  let image_ratio = image_size.width / image_size.height
  let frame_ratio = frame.size.width / frame.size.height
  match fit {
    @core.ImageFit::Stretch => { frame, src_rect: None }
    @core.ImageFit::ScaleDown =>
      if image_size.width <= frame.size.width &&
        image_size.height <= frame.size.height {
        {
          frame: @core.Rect::new(
            x=frame.origin.x + (frame.size.width - image_size.width) / 2.0,
            y=frame.origin.y + (frame.size.height - image_size.height) / 2.0,
            width=image_size.width,
            height=image_size.height,
          ),
          src_rect: None,
        }
      } else {
        sun_contain_image_placement(frame, image_size)
      }
    @core.ImageFit::FitWidth => {
      let height = frame.size.width / image_ratio
      {
        frame: @core.Rect::new(
          x=frame.origin.x,
          y=frame.origin.y + (frame.size.height - height) / 2.0,
          width=frame.size.width,
          height~,
        ),
        src_rect: None,
      }
    }
    @core.ImageFit::FitHeight => {
      let width = frame.size.height * image_ratio
      {
        frame: @core.Rect::new(
          x=frame.origin.x + (frame.size.width - width) / 2.0,
          y=frame.origin.y,
          width~,
          height=frame.size.height,
        ),
        src_rect: None,
      }
    }
    @core.ImageFit::Contain => sun_contain_image_placement(frame, image_size)
    @core.ImageFit::Cover =>
      if image_ratio > frame_ratio {
        let visible = frame_ratio / image_ratio
        let crop_width = (image_size.width * visible).round().to_int()
        let left = ((image_size.width - crop_width.to_double()) * 0.5)
          .round()
          .to_int()
        {
          frame,
          src_rect: Some(
            @sun_graphics.PixelRect::new(
              x=left,
              y=0,
              width=crop_width,
              height=image_size.height.round().to_int(),
            ),
          ),
        }
      } else {
        let visible = image_ratio / frame_ratio
        let crop_height = (image_size.height * visible).round().to_int()
        let top = ((image_size.height - crop_height.to_double()) * 0.5)
          .round()
          .to_int()
        {
          frame,
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
fn sun_contain_image_placement(
  frame : @core.Rect,
  image_size : @core.Size,
) -> SunImagePlacement {
  let scale = (frame.size.width / image_size.width).min(
    frame.size.height / image_size.height,
  )
  let width = image_size.width * scale
  let height = image_size.height * scale
  {
    frame: @core.Rect::new(
      x=frame.origin.x + (frame.size.width - width) / 2.0,
      y=frame.origin.y + (frame.size.height - height) / 2.0,
      width~,
      height~,
    ),
    src_rect: None,
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

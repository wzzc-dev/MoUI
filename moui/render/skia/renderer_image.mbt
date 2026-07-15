///|
fn SkiaRasterRenderer::draw_image(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  run : @core.ImageRun,
) -> Unit {
  match self.skia_image_for_source(run.source) {
    Some(image) => {
      let placement = skia_image_placement(
        run.frame,
        @core.Size::new(
          width=image.width().to_double(),
          height=image.height().to_double(),
        ),
        run.fit,
      )
      canvas.draw_image_rect(
        image,
        @moui_skia.Rect::from_xywh(
          Float::from_double(placement.u0 * image.width().to_double()),
          Float::from_double(placement.v0 * image.height().to_double()),
          Float::from_double(
            (placement.u1 - placement.u0) * image.width().to_double(),
          ),
          Float::from_double(
            (placement.v1 - placement.v0) * image.height().to_double(),
          ),
        ),
        skia_rect(placement.frame),
        skia_opacity_paint(run.opacity),
        sampling=@moui_skia.SamplingOptions::linear(),
      )
    }
    None => self.draw_image_placeholder(canvas, run)
  }
}

///|
fn SkiaRasterRenderer::draw_image_placeholder(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  run : @core.ImageRun,
) -> Unit {
  self.draw_brush_rect(canvas, run.frame, skia_image_placeholder_brush(run))
}

///|
fn SkiaRasterRenderer::skia_image_for_source(
  self : SkiaRasterRenderer,
  source : String,
) -> @skia_native.Image? {
  match self.image_cache.get(source) {
    Some(image) => Some(image)
    None => {
      match self.failed_images.get(source) {
        Some(diagnostic) =>
          if skia_image_failed_cache_can_retry(source) {
            self.failed_images.remove(source)
          } else {
            self.mark_image_failed(source, diagnostic~)
            return None
          }
        None => ()
      }
      if self.async_image_loading {
        match self.image_lifecycle.lookup(source) {
          Some({ status: @render.ImageResourceStatus::ImageLoading, .. }) =>
            return None
          Some({ status: @render.ImageResourceStatus::ImageReady, .. }) =>
            return self.decode_and_cache_image_source(
              source,
              mark_loading=false,
            )
          Some(
            { status: @render.ImageResourceStatus::ImageFailed, diagnostic, .. }
          ) => {
            self.failed_images[source] = diagnostic
            return None
          }
          _ => {
            self.mark_image_loading(source)
            return None
          }
        }
      }
      self.decode_and_cache_image_source(source, mark_loading=true)
    }
  }
}

///|
fn SkiaRasterRenderer::decode_and_cache_image_source(
  self : SkiaRasterRenderer,
  source : String,
  mark_loading~ : Bool,
) -> @skia_native.Image? {
  match skia_image_source_bytes(source) {
    Some(bytes) => {
      if mark_loading {
        self.mark_image_loading(source)
      }
      match @skia_native.Image::from_encoded_bytes(bytes) {
        Some(image) => {
          self.failed_images.remove(source)
          self.image_cache[source] = image
          self.mark_image_ready(
            source,
            width=image.width(),
            height=image.height(),
          )
          Some(image)
        }
        None => {
          self.failed_images[source] = "Skia image decode failed"
          self.mark_image_failed(source, diagnostic="Skia image decode failed")
          None
        }
      }
    }
    None => {
      self.failed_images[source] = "Skia image source bytes are unavailable"
      self.mark_image_failed(
        source,
        diagnostic="Skia image source bytes are unavailable",
      )
      None
    }
  }
}

///|
fn SkiaRasterRenderer::mark_image_loading(
  self : SkiaRasterRenderer,
  source : String,
) -> Unit {
  let previous_revision = self.image_lifecycle.revision()
  ignore(self.image_lifecycle.mark_loading(source))
  self.notify_image_resource_change_if_needed(previous_revision)
}

///|
fn SkiaRasterRenderer::mark_image_ready(
  self : SkiaRasterRenderer,
  source : String,
  width~ : Int,
  height~ : Int,
) -> Unit {
  let previous_revision = self.image_lifecycle.revision()
  ignore(self.image_lifecycle.mark_ready(source, width~, height~))
  self.notify_image_resource_change_if_needed(previous_revision)
}

///|
fn SkiaRasterRenderer::mark_image_failed(
  self : SkiaRasterRenderer,
  source : String,
  diagnostic~ : String,
) -> Unit {
  let previous_revision = self.image_lifecycle.revision()
  ignore(self.image_lifecycle.mark_failed(source, diagnostic~))
  self.notify_image_resource_change_if_needed(previous_revision)
}

///|
fn SkiaRasterRenderer::dispose_image_resource(
  self : SkiaRasterRenderer,
  source : String,
) -> Unit {
  let previous_revision = self.image_lifecycle.revision()
  ignore(self.image_lifecycle.dispose(source))
  self.notify_image_resource_change_if_needed(previous_revision)
}

///|
fn SkiaRasterRenderer::notify_image_resource_change_if_needed(
  self : SkiaRasterRenderer,
  previous_revision : Int,
) -> Unit {
  if self.image_lifecycle.revision() > previous_revision {
    match self.on_image_resource_change {
      Some(notify) => notify(self.image_lifecycle.snapshot_with_revision())
      None => ()
    }
  }
}

///|
fn skia_image_failed_cache_can_retry(source : String) -> Bool {
  !source.has_prefix("data:") && @fs.path_exists(source)
}

///|
pub fn skia_image_load_completion(
  source : String,
) -> @render.ImageResourceLoadCompletion {
  match skia_image_source_bytes(source) {
    Some(bytes) => skia_image_load_completion_from_bytes(source, bytes)
    None =>
      @render.ImageResourceLoadCompletion::failed(
        source,
        diagnostic="Skia image source bytes are unavailable",
      )
  }
}

///|
pub fn skia_image_load_completion_from_bytes(
  source : String,
  bytes : Bytes,
  background_io? : Bool = false,
  background_decode? : Bool = false,
) -> @render.ImageResourceLoadCompletion {
  match @skia_native.Codec::from_bytes(bytes) {
    Some(codec) =>
      match codec.decode_n32_premul() {
        Some(bitmap) =>
          @render.ImageResourceLoadCompletion::ready_decoded_rgba(
            source,
            width=bitmap.width(),
            height=bitmap.height(),
            row_bytes=bitmap.row_bytes(),
            bitmap.to_bytes(),
            background_io~,
            background_decode~,
          )
        None =>
          @render.ImageResourceLoadCompletion::failed(
            source,
            diagnostic="Skia image decode failed",
            background_io~,
          )
      }
    None =>
      @render.ImageResourceLoadCompletion::failed(
        source,
        diagnostic="Skia image decode failed",
        background_io~,
      )
  }
}

///|
fn skia_image_source_bytes(source : String) -> Bytes? {
  if source.has_prefix("data:") {
    skia_image_data_uri_bytes(source)
  } else if @fs.path_exists(source) {
    Some(@fs.read_file_to_bytes(source)) catch {
      _ => None
    }
  } else {
    None
  }
}

///|
fn skia_image_data_uri_bytes(source : String) -> Bytes? {
  let parts = source.split(",").to_array()
  if parts.length() < 2 {
    return None
  }
  let meta = parts[0]
  if !meta.has_prefix("data:") || !meta.contains(";base64") {
    return None
  }
  Some(@base64.decode(parts[1], ignore_whitespace=true)) catch {
    _ => None
  }
}

///|
fn skia_image_placeholder_brush(run : @core.ImageRun) -> @core.Brush {
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
priv struct SkiaImagePlacement {
  frame : @core.Rect
  u0 : Double
  v0 : Double
  u1 : Double
  v1 : Double
}

///|
fn skia_image_placement(
  frame : @core.Rect,
  image_size : @core.Size,
  fit : @core.ImageFit,
) -> SkiaImagePlacement {
  if image_size.width <= 0.0 ||
    image_size.height <= 0.0 ||
    frame.size.width <= 0.0 ||
    frame.size.height <= 0.0 {
    return { frame, u0: 0.0, v0: 0.0, u1: 1.0, v1: 1.0 }
  }
  let image_ratio = image_size.width / image_size.height
  let frame_ratio = frame.size.width / frame.size.height
  match fit {
    @core.ImageFit::Stretch => { frame, u0: 0.0, v0: 0.0, u1: 1.0, v1: 1.0 }
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
          u0: 0.0,
          v0: 0.0,
          u1: 1.0,
          v1: 1.0,
        }
      } else {
        skia_contain_image_placement(frame, image_ratio, frame_ratio)
      }
    @core.ImageFit::FitWidth =>
      skia_fit_width_image_placement(frame, image_ratio)
    @core.ImageFit::FitHeight =>
      skia_fit_height_image_placement(frame, image_ratio)
    @core.ImageFit::Contain =>
      skia_contain_image_placement(frame, image_ratio, frame_ratio)
    @core.ImageFit::Cover =>
      if image_ratio > frame_ratio {
        let visible = frame_ratio / image_ratio
        let inset = (1.0 - visible) / 2.0
        { frame, u0: inset, v0: 0.0, u1: 1.0 - inset, v1: 1.0 }
      } else {
        let visible = image_ratio / frame_ratio
        let inset = (1.0 - visible) / 2.0
        { frame, u0: 0.0, v0: inset, u1: 1.0, v1: 1.0 - inset }
      }
  }
}

///|
fn skia_fit_width_image_placement(
  frame : @core.Rect,
  image_ratio : Double,
) -> SkiaImagePlacement {
  let scaled_height = frame.size.width / image_ratio
  if scaled_height <= frame.size.height {
    {
      frame: @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + (frame.size.height - scaled_height) / 2.0,
        width=frame.size.width,
        height=scaled_height,
      ),
      u0: 0.0,
      v0: 0.0,
      u1: 1.0,
      v1: 1.0,
    }
  } else {
    let visible = frame.size.height / scaled_height
    let inset = (1.0 - visible) / 2.0
    { frame, u0: 0.0, v0: inset, u1: 1.0, v1: 1.0 - inset }
  }
}

///|
fn skia_fit_height_image_placement(
  frame : @core.Rect,
  image_ratio : Double,
) -> SkiaImagePlacement {
  let scaled_width = frame.size.height * image_ratio
  if scaled_width <= frame.size.width {
    {
      frame: @core.Rect::new(
        x=frame.origin.x + (frame.size.width - scaled_width) / 2.0,
        y=frame.origin.y,
        width=scaled_width,
        height=frame.size.height,
      ),
      u0: 0.0,
      v0: 0.0,
      u1: 1.0,
      v1: 1.0,
    }
  } else {
    let visible = frame.size.width / scaled_width
    let inset = (1.0 - visible) / 2.0
    { frame, u0: inset, v0: 0.0, u1: 1.0 - inset, v1: 1.0 }
  }
}

///|
fn skia_contain_image_placement(
  frame : @core.Rect,
  image_ratio : Double,
  frame_ratio : Double,
) -> SkiaImagePlacement {
  if image_ratio > frame_ratio {
    let scaled_height = frame.size.width / image_ratio
    let offset_y = (frame.size.height - scaled_height) / 2.0
    {
      frame: @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y + offset_y,
        width=frame.size.width,
        height=scaled_height,
      ),
      u0: 0.0,
      v0: 0.0,
      u1: 1.0,
      v1: 1.0,
    }
  } else {
    let scaled_width = frame.size.height * image_ratio
    let offset_x = (frame.size.width - scaled_width) / 2.0
    {
      frame: @core.Rect::new(
        x=frame.origin.x + offset_x,
        y=frame.origin.y,
        width=scaled_width,
        height=frame.size.height,
      ),
      u0: 0.0,
      v0: 0.0,
      u1: 1.0,
      v1: 1.0,
    }
  }
}

///|
pub fn SkiaRasterRenderer::image_resources(
  self : SkiaRasterRenderer,
) -> Array[@render.ImageResourceRecord] {
  self.image_lifecycle.snapshot()
}

///|
pub fn SkiaRasterRenderer::image_resource_snapshot(
  self : SkiaRasterRenderer,
) -> @render.ImageResourceSnapshot {
  self.image_lifecycle.snapshot_with_revision()
}

///|
pub fn SkiaRasterRenderer::apply_image_resource_load_completion(
  self : SkiaRasterRenderer,
  completion : @render.ImageResourceLoadCompletion,
) -> @render.ImageResourceSnapshot {
  let previous_revision = self.image_lifecycle.revision()
  let decoded_image = skia_image_from_decoded_completion(completion)
  let completion_to_apply = if completion.has_decoded_rgba_payload() &&
    decoded_image is None {
    @render.ImageResourceLoadCompletion::failed(
      completion.source,
      diagnostic="Skia decoded image payload invalid",
      background_io=completion.background_io,
    )
  } else {
    completion
  }
  let snapshot = self.image_lifecycle.apply_load_completion(completion_to_apply)
  if snapshot.revision > previous_revision {
    match completion_to_apply.status {
      @render.ImageResourceLoadCompletionStatus::ImageLoadReady => {
        self.failed_images.remove(completion.source)
        match decoded_image {
          Some(image) => self.image_cache[completion.source] = image
          None => ()
        }
      }
      @render.ImageResourceLoadCompletionStatus::ImageLoadFailed =>
        self.failed_images[completion.source] = completion_to_apply.diagnostic
    }
    self.notify_image_resource_change_if_needed(previous_revision)
  }
  snapshot
}

///|
fn skia_image_from_decoded_completion(
  completion : @render.ImageResourceLoadCompletion,
) -> @skia_native.Image? {
  if !completion.has_decoded_rgba_payload() {
    return None
  }
  match
    @skia_native.Bitmap::from_pixels(
      completion.decoded_pixels,
      completion.width,
      completion.height,
      completion.decoded_row_bytes,
    ) {
    Some(bitmap) => @skia_native.Image::from_bitmap(bitmap)
    None => None
  }
}

///|
pub fn SkiaRasterRenderer::dispose(self : SkiaRasterRenderer) -> Unit {
  for source, _ in self.image_cache {
    self.dispose_image_resource(source)
  }
  self.image_cache.clear()
  self.failed_images.clear()
  self.clear_layer_cache()
  // HostGpu EGL surfaces own the platform window. Replace with a tiny raster
  // placeholder so the old surface finalizer can destroy the EGL window before
  // sticky raster present reuses the same OHNativeWindow / ANativeWindow.
  if self.gpu_target is Some(_) {
    match
      @skia_native.Surface::raster_n32_premul(@moui_skia.ISize::new(1, 1)) {
      Some(placeholder) => {
        self.surface = placeholder
        self.gpu_surface_attached = false
      }
      None => ()
    }
  }
}

///|
pub fn SkiaRasterRenderer::set_image_resource_change_callback(
  self : SkiaRasterRenderer,
  callback : ((@render.ImageResourceSnapshot) -> Unit)?,
) -> Unit {
  self.on_image_resource_change = callback
}

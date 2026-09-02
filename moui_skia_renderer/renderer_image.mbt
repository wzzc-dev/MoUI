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
  ignore(self.image_lifecycle.mark_loading(source))
}

///|
fn SkiaRasterRenderer::mark_image_ready(
  self : SkiaRasterRenderer,
  source : String,
  width~ : Int,
  height~ : Int,
) -> Unit {
  ignore(self.image_lifecycle.mark_ready(source, width~, height~))
}

///|
fn SkiaRasterRenderer::mark_image_failed(
  self : SkiaRasterRenderer,
  source : String,
  diagnostic~ : String,
) -> Unit {
  ignore(self.image_lifecycle.mark_failed(source, diagnostic~))
}

///|
fn SkiaRasterRenderer::dispose_image_resource(
  self : SkiaRasterRenderer,
  source : String,
) -> Unit {
  ignore(self.image_lifecycle.dispose(source))
}

///|
fn skia_image_failed_cache_can_retry(source : String) -> Bool {
  let _ = source
  false
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
  let placement = @render_common.image_placement(frame, image_size, fit)
  match placement.crop_axis {
    @render_common.ImageCropAxis::None =>
      { frame: placement.frame, u0: 0.0, v0: 0.0, u1: 1.0, v1: 1.0 }
    @render_common.ImageCropAxis::Horizontal => {
      let inset = (1.0 - placement.visible) / 2.0
      { frame: placement.frame, u0: inset, v0: 0.0, u1: 1.0 - inset, v1: 1.0 }
    }
    @render_common.ImageCropAxis::Vertical => {
      let inset = (1.0 - placement.visible) / 2.0
      { frame: placement.frame, u0: 0.0, v0: inset, u1: 1.0, v1: 1.0 - inset }
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
pub fn SkiaRasterRenderer::apply_image_resource_load_completion(
  self : SkiaRasterRenderer,
  completion : @render.ImageResourceLoadCompletion,
) -> Bool {
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
  let changed = self.image_lifecycle.apply_load_completion(completion_to_apply)
  if changed {
    // Retained layers contain rasterized command output, including image
    // placeholders. Image completion changes renderer-owned pixels without
    // changing the runtime render tree/content revision. Advance a renderer
    // generation consumed by retained-layer keys so the next redraw rebuilds
    // the affected pixels instead of replaying the placeholder.
    self.image_cache_generation = self.image_cache_generation + 1
    // Drop old raster/picture entries and admission streaks as well. A
    // document gallery can complete several images back-to-back; retaining
    // old generations would consume the layer budget and classify otherwise
    // stable chrome as churn-without-hit.
    self.clear_layer_cache()
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
  }
  changed
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
    match @skia_native.Surface::raster_n32_premul(@moui_skia.ISize::new(1, 1)) {
      Some(placeholder) => {
        self.surface = placeholder
        self.gpu_surface_attached = false
      }
      None => ()
    }
  }
}

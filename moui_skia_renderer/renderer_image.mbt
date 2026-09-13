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
/// Draw the placeholder that stands in for an image that is not on screen yet.
///
/// Replaces a full-frame diagonal gradient (`(0.72,0.78,0.86)` →
/// `(0.42,0.50,0.62)`, opaque) that read as a broken render: a large,
/// high-contrast block in the middle of a document pulls the eye away from the
/// text and says nothing about the image it stands for.
///
/// The card is built from three cheap parts:
///
/// 1. A near-transparent neutral fill (alpha 0.07). Low enough that the tinted
///    rounded rect the rich-text painter already emits before `DrawImage`
///    (`moui_richtext`'s `rgba(0.18,0.4,0.7,0.08)`) shows through, so the card
///    picks up the application's own image tint without the renderer needing a
///    theme it does not have — and stays legible on both a white and a dark
///    page.
/// 2. A hairline border, one notch stronger for a failed image than for one
///    still loading, so the two states differ without a second layout.
/// 3. A centered "picture" glyph (frame + sun + peak, plus a slash when the
///    load failed). Drawn only when the short side is at least
///    [`skia_image_placeholder_glyph_min_side`] — in a 32 px badge row a glyph
///    is mud, so those boxes keep just the card.
///
/// Cost is a constant handful of Skia calls (one rounded fill, one rounded
/// stroke, one or two paths). No text shaping, no font lookup, no per-pixel
/// work: a failed image can be repainted every frame without entering the hot
/// path, which is what keeps placeholder rendering off the load-time budget.
fn SkiaRasterRenderer::draw_image_placeholder(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  run : @core.ImageRun,
) -> Unit {
  let frame = run.frame
  if frame.size.width <= 0.0 || frame.size.height <= 0.0 {
    return
  }
  let failed = self.skia_image_placeholder_failed(run.source)
  let rounded = @core.RoundedRect::new(
    rect=frame,
    radius=skia_image_placeholder_radius(frame),
  )
  self.draw_brush_rounded_rect(
    canvas,
    rounded,
    skia_image_placeholder_fill(run),
    stroke_width=None,
  )
  self.draw_brush_rounded_rect(
    canvas,
    rounded,
    skia_image_placeholder_border(run, failed),
    stroke_width=Some(skia_image_placeholder_border_width),
  )
  match skia_image_placeholder_glyph_box(frame) {
    Some(box) => self.draw_image_placeholder_glyph(canvas, box, run, failed)
    None => ()
  }
}

///|
/// Card corner radius, clamped so a box shorter than the radius still gets a
/// sensible quarter-round instead of an over-rounded pill.
let skia_image_placeholder_radius_max : Double = 8.0

///|
fn skia_image_placeholder_radius(frame : @core.Rect) -> Double {
  let half = frame.size.width.min(frame.size.height) / 2.0
  if half < skia_image_placeholder_radius_max {
    half
  } else {
    skia_image_placeholder_radius_max
  }
}

///|
let skia_image_placeholder_border_width : Double = 1.0

///|
/// Shortest side that still fits a legible glyph. Below this the card stands
/// alone: badges and inline thumbnails are simply too small to draw into.
let skia_image_placeholder_glyph_min_side : Double = 48.0

///|
/// Card fill: a neutral cool gray at very low alpha, scaled by the run's own
/// opacity so a faded image fades its placeholder with it.
fn skia_image_placeholder_fill(run : @core.ImageRun) -> @core.Brush {
  @core.Brush::solid(
    @core.Color::rgba(r=0.42, g=0.47, b=0.55, a=0.07 * run.opacity),
  )
}

///|
/// Card border: the same hue as the fill, three steps up in alpha. A failed
/// load is drawn firmer than a pending one — "still coming" and "will never
/// come" should not look identical.
fn skia_image_placeholder_border(
  run : @core.ImageRun,
  failed : Bool,
) -> @core.Brush {
  let alpha = if failed { 0.34 } else { 0.18 }
  @core.Brush::solid(
    @core.Color::rgba(r=0.42, g=0.47, b=0.55, a=alpha * run.opacity),
  )
}

///|
/// Glyph color: a muted ink one step darker than the border.
fn skia_image_placeholder_glyph_brush(
  run : @core.ImageRun,
  failed : Bool,
) -> @core.Brush {
  let alpha = if failed { 0.62 } else { 0.45 }
  @core.Brush::solid(
    @core.Color::rgba(r=0.38, g=0.44, b=0.54, a=alpha * run.opacity),
  )
}

///|
/// True when this source is known to have failed: either the decoded-image
/// failure cache or the lifecycle record. Both are already consulted by
/// `skia_image_for_source`, so the placeholder reuses the same verdict rather
/// than inventing a second one.
fn SkiaRasterRenderer::skia_image_placeholder_failed(
  self : SkiaRasterRenderer,
  source : String,
) -> Bool {
  if self.failed_images.get(source) is Some(_) {
    return true
  }
  match self.image_lifecycle.lookup(source) {
    Some({ status: @render.ImageResourceStatus::ImageFailed, .. }) => true
    _ => false
  }
}

///|
/// Square glyph box centered in the card, or `None` when the card is too small
/// to draw into. The glyph is sized off the short side so it never touches the
/// border, and capped so a poster-sized image does not get a giant icon.
fn skia_image_placeholder_glyph_box(frame : @core.Rect) -> @core.Rect? {
  let short = frame.size.width.min(frame.size.height)
  if short < skia_image_placeholder_glyph_min_side {
    return None
  }
  let side = (short * 0.34).max(skia_image_placeholder_glyph_min_side * 0.34)
  let side = side.min(40.0)
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
/// The "picture" glyph: a rounded frame, a sun, a peak — and a slash across it
/// when the load failed. Coordinates are fractions of `box` so one geometry
/// serves every size.
fn SkiaRasterRenderer::draw_image_placeholder_glyph(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  box : @core.Rect,
  run : @core.ImageRun,
  failed : Bool,
) -> Unit {
  let brush = skia_image_placeholder_glyph_brush(run, failed)
  let stroke = skia_image_placeholder_glyph_stroke
  let at = (fx : Double, fy : Double) => {
    @core.Point::new(
      x=box.origin.x + box.size.width * fx,
      y=box.origin.y + box.size.height * fy,
    )
  }
  let side = box.size.width.min(box.size.height)
  // Frame: the outer rounded rectangle, inset by half the stroke so the line
  // stays inside the glyph box.
  let inset = stroke / 2.0
  self.draw_brush_rounded_rect(
    canvas,
    @core.RoundedRect::new(
      rect=@core.Rect::new(
        x=box.origin.x + inset,
        y=box.origin.y + inset,
        width=box.size.width - stroke,
        height=box.size.height - stroke,
      ),
      radius=side * 0.18,
    ),
    brush,
    stroke_width=Some(stroke),
  )
  // Sun + peak travel as one filled path: two closed subpaths, so a single
  // Skia draw fills both.
  let sun_radius = side * 0.085
  let sun_center = at(0.33, 0.34)
  self.draw_path(
    canvas,
    @core.PathSpec::new(
      verbs=skia_image_placeholder_sun_and_peak(at, sun_center, sun_radius),
      fill=Some(brush),
      stroke=None,
      stroke_width=0.0,
    ),
  )
  if failed {
    // Slash: the one universally read "this did not load" mark. Drawn corner to
    // corner across the frame, past it at both ends so it cannot be mistaken
    // for part of the picture.
    self.draw_path(
      canvas,
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(at(0.06, 0.06)),
          @core.PathVerb::LineTo(at(0.94, 0.94)),
        ],
        fill=None,
        stroke=Some(brush),
        stroke_width=stroke,
      ),
    )
  }
}

///|
let skia_image_placeholder_glyph_stroke : Double = 1.5

///|
/// Sun and peak as one vertex list: the sun is four cubic Béziers (control
/// offset `r * 0.5523`, the standard circle approximation — `PathVerb` has no
/// arc primitive), then a closed triangle for the mountain.
fn skia_image_placeholder_sun_and_peak(
  at : (Double, Double) -> @core.Point,
  center : @core.Point,
  radius : Double,
) -> Array[@core.PathVerb] {
  let k = radius * 0.5523
  let p = (dx : Double, dy : Double) => {
    @core.Point::new(x=center.x + dx, y=center.y + dy)
  }
  [
    @core.PathVerb::MoveTo(p(0.0, -radius)),
    @core.PathVerb::CubicTo(p(k, -radius), p(radius, -k), p(radius, 0.0)),
    @core.PathVerb::CubicTo(p(radius, k), p(k, radius), p(0.0, radius)),
    @core.PathVerb::CubicTo(p(-k, radius), p(-radius, k), p(-radius, 0.0)),
    @core.PathVerb::CubicTo(p(-radius, -k), p(-k, -radius), p(0.0, -radius)),
    @core.PathVerb::Close,
    @core.PathVerb::MoveTo(at(0.16, 0.76)),
    @core.PathVerb::LineTo(at(0.45, 0.44)),
    @core.PathVerb::LineTo(at(0.74, 0.76)),
    @core.PathVerb::Close,
  ]
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
  self.invalidate_gpu_backing_surface()
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

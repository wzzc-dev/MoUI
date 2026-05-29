///|
pub(all) suberror SkiaRendererError {
  SkiaUnavailable
  SurfaceUnavailable
  CanvasUnavailable
  ReadPixelsUnavailable
  PresentFailed(String)
} derive(Eq, Debug, ToJson)

///|
pub fn SkiaRendererError::message(self : SkiaRendererError) -> String {
  match self {
    SkiaUnavailable => "skia_mbt/native is unavailable"
    SurfaceUnavailable => "failed to create Skia raster surface"
    CanvasUnavailable => "failed to acquire Skia canvas"
    ReadPixelsUnavailable => "failed to read Skia surface pixels"
    PresentFailed(description) => "Skia presenter failed: \{description}"
  }
}

///|
pub(all) struct SkiaPixelFrame {
  width : Int
  height : Int
  row_bytes : Int
  scale_factor : Double
  pixels : Bytes
} derive(Eq, Debug)

///|
pub(all) struct SkiaPresentTarget {
  description : String
  present : (SkiaPixelFrame) -> Bool
}

///|
pub(all) struct SkiaRasterRenderer {
  mut metrics : @render.RendererSurfaceMetrics
  target : SkiaPresentTarget
  mut surface : @skia_native.Surface
  image_cache : Map[String, @skia_native.Image]
  image_lifecycle : @render.ImageResourceLifecycle
  mut present_count : Int
  mut unsupported_command_count : Int
  mut last_frame : SkiaPixelFrame?
}

///|
priv struct SkiaTextMetrics {
  baseline : Double
  height : Double
}

///|
priv struct SkiaGlyphRun {
  glyphs : Array[@skia_native.GlyphId]
  positions : Array[@skia_mbt.Point]
  width : Double
}

///|
pub fn skia_available() -> Bool {
  @skia_native.skia_available()
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  let available = skia_available()
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::SkiaRasterNative,
    status=if available {
      @render.RendererCapabilityStatus::Ready
    } else {
      @render.RendererCapabilityStatus::Unavailable
    },
    can_render=available,
    can_resize=available,
    owns_surface=true,
    description="Native Skia raster renderer using skia_mbt/native CPU surfaces and platform pixel presenters.",
  )
}

///|
pub fn renderer_spec() -> @render.RendererSpec {
  skia_raster_native_spec()
}

///|
pub fn skia_raster_native_spec() -> @render.RendererSpec {
  @render.RendererSpec::new(
    backend=@render.RendererBackendKind::SkiaRasterNative,
    family=@render.RendererFamily::Skia,
    presentation=@render.RendererPresentationModel::CpuPixelFrame,
    supported_targets=[@render.RendererTarget::Native],
    capabilities=@render.renderer_backend_capabilities(
      @render.RendererBackendKind::SkiaRasterNative,
    ),
    description="Native Skia raster renderer that presents copied RGBA premultiplied pixel frames to the host.",
  )
}

///|
pub fn SkiaPresentTarget::new(
  description~ : String,
  present~ : (SkiaPixelFrame) -> Bool,
) -> SkiaPresentTarget {
  { description, present }
}

///|
pub fn create_with_present_target(
  metrics : @render.RendererSurfaceMetrics,
  target : SkiaPresentTarget,
) -> SkiaRasterRenderer raise SkiaRendererError {
  if !skia_available() {
    raise SkiaRendererError::SkiaUnavailable
  }
  let surface = create_surface(metrics)
  {
    metrics,
    target,
    surface,
    image_cache: {},
    image_lifecycle: @render.ImageResourceLifecycle::new(),
    present_count: 0,
    unsupported_command_count: 0,
    last_frame: None,
  }
}

///|
fn create_surface(
  metrics : @render.RendererSurfaceMetrics,
) -> @skia_native.Surface raise SkiaRendererError {
  let width = skia_dim_to_int(metrics.physical_size.width)
  let height = skia_dim_to_int(metrics.physical_size.height)
  match
    @skia_native.Surface::raster_n32_premul(@skia_mbt.ISize::new(width, height)) {
    Some(surface) => surface
    None => raise SkiaRendererError::SurfaceUnavailable
  }
}

///|
pub fn SkiaRasterRenderer::resize(
  self : SkiaRasterRenderer,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit raise SkiaRendererError {
  self.metrics = metrics
  self.surface = create_surface(metrics)
}

///|
pub fn SkiaRasterRenderer::render(
  self : SkiaRasterRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit raise SkiaRendererError {
  match self.surface.canvas() {
    Some(canvas) => {
      canvas.clear(skia_color(@render.first_clear_color(commands)))
      let saved = canvas.save()
      canvas.scale(
        @skia_mbt.Size::new(
          Float::from_double(self.metrics.scale_factor),
          Float::from_double(self.metrics.scale_factor),
        ),
      )
      self.unsupported_command_count = 0
      for command in commands {
        self.render_command(canvas, command)
      }
      canvas.restore_to_count(saved)
      let frame = self.read_frame()
      self.last_frame = Some(frame)
      if (self.target.present)(frame) {
        self.present_count = self.present_count + 1
      } else {
        raise SkiaRendererError::PresentFailed(self.target.description)
      }
    }
    None => raise SkiaRendererError::CanvasUnavailable
  }
}

///|
fn SkiaRasterRenderer::render_command(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  command : @core.DrawCommand,
) -> Unit {
  match command {
    @core.DrawCommand::Clear(color) => canvas.clear(skia_color(color))
    @core.DrawCommand::FillRect(rect, color) =>
      canvas.draw_rect(skia_rect(rect), skia_paint(color))
    @core.DrawCommand::StrokeRect(rect, color, width) =>
      canvas.draw_rect(skia_rect(rect), skia_stroke_paint(color, width))
    @core.DrawCommand::FillRoundedRect(rounded, color) =>
      canvas.draw_round_rect(
        skia_rect(rounded.rect),
        Float::from_double(rounded.radius),
        Float::from_double(rounded.radius),
        skia_paint(color),
      )
    @core.DrawCommand::StrokeRoundedRect(rounded, color, width) =>
      canvas.draw_round_rect(
        skia_rect(rounded.rect),
        Float::from_double(rounded.radius),
        Float::from_double(rounded.radius),
        skia_stroke_paint(color, width),
      )
    @core.DrawCommand::FillRoundedRectBrush(rounded, brush) =>
      self.draw_brush_rounded_rect(canvas, rounded, brush, stroke_width=None)
    @core.DrawCommand::StrokeRoundedRectBrush(rounded, brush, width) =>
      self.draw_brush_rounded_rect(
        canvas,
        rounded,
        brush,
        stroke_width=Some(width),
      )
    @core.DrawCommand::DrawShadow(shadow) => self.draw_shadow(canvas, shadow)
    @core.DrawCommand::DrawText(run) => self.draw_text(canvas, run)
    @core.DrawCommand::DrawImage(run) => self.draw_image(canvas, run)
    @core.DrawCommand::PushClip(rect) => {
      ignore(canvas.save())
      canvas.clip_rect(skia_rect(rect), anti_alias=true)
    }
    @core.DrawCommand::PopClip => canvas.restore()
    @core.DrawCommand::PushRoundedClip(rounded) => {
      ignore(canvas.save())
      canvas.clip_rrect(skia_rrect(rounded), anti_alias=true)
    }
    @core.DrawCommand::PopRoundedClip => canvas.restore()
    @core.DrawCommand::PushTransform(transform) => {
      ignore(canvas.save())
      canvas.concat(skia_matrix(transform))
    }
    @core.DrawCommand::PopTransform => canvas.restore()
    @core.DrawCommand::PushOpacity(opacity) =>
      ignore(canvas.save_layer(paint=skia_opacity_paint(opacity)))
    @core.DrawCommand::PopOpacity => canvas.restore()
    @core.DrawCommand::PushLayer(layer) => self.push_layer(canvas, layer)
    @core.DrawCommand::PopLayer => canvas.restore()
    @core.DrawCommand::PushFilter(filter) => self.push_filter(canvas, filter)
    @core.DrawCommand::PopFilter => canvas.restore()
    @core.DrawCommand::DrawPath(path) => self.draw_path(canvas, path)
    @core.DrawCommand::DrawShaderEffect(spec) =>
      self.draw_shader_effect(canvas, spec)
  }
}

///|
fn SkiaRasterRenderer::push_filter(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  filter : @core.FilterEffect,
) -> Unit {
  match filter {
    @core.FilterEffect::Blur(radius) =>
      match
        @skia_native.ImageFilter::blur(
          Float::from_double(radius.max(0.0)),
          Float::from_double(radius.max(0.0)),
        ) {
        Some(image_filter) =>
          ignore(canvas.save_layer(image_filter=Some(image_filter)))
        None => {
          ignore(canvas.save_layer())
          self.unsupported_command_count = self.unsupported_command_count + 1
        }
      }
    @core.FilterEffect::Saturate(amount) =>
      self.push_color_filter(
        canvas,
        @skia_native.ColorFilter::saturation(Float::from_double(amount)),
      )
    @core.FilterEffect::Brightness(amount) =>
      self.push_color_filter(
        canvas,
        @skia_native.ColorFilter::brightness(Float::from_double(amount)),
      )
    @core.FilterEffect::Contrast(amount) =>
      self.push_color_filter(
        canvas,
        @skia_native.ColorFilter::contrast(Float::from_double(amount)),
      )
    @core.FilterEffect::ColorMatrix(values) =>
      self.push_color_filter(canvas, skia_color_filter_matrix(values))
  }
}

///|
fn SkiaRasterRenderer::push_color_filter(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  color_filter : @skia_native.ColorFilter?,
) -> Unit {
  match color_filter {
    Some(color_filter) =>
      ignore(canvas.save_layer(color_filter=Some(color_filter)))
    None => {
      ignore(canvas.save_layer())
      self.unsupported_command_count = self.unsupported_command_count + 1
    }
  }
}

///|
fn SkiaRasterRenderer::draw_shadow(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  shadow : @core.ShadowSpec,
) -> Unit {
  let blur = shadow.blur_radius.max(0.0)
  let spread = shadow.spread.max(0.0)
  let expanded = skia_shadow_rect(shadow, grow=spread)
  let radius = (shadow.rect.radius + spread).max(0.0)
  if blur > 0.0 {
    match @skia_native.MaskFilter::blur(Float::from_double(blur)) {
      Some(mask_filter) => {
        let saved = canvas.save_layer(
          bounds=Some(
            skia_rect(skia_shadow_rect(shadow, grow=spread + blur * 3.0)),
          ),
          mask_filter=Some(mask_filter),
        )
        canvas.draw_round_rect(
          skia_rect(expanded),
          Float::from_double(radius),
          Float::from_double(radius),
          skia_paint(shadow.color),
        )
        canvas.restore_to_count(saved)
      }
      None => {
        canvas.draw_round_rect(
          skia_rect(expanded),
          Float::from_double(radius),
          Float::from_double(radius),
          skia_paint(shadow.color),
        )
        self.unsupported_command_count = self.unsupported_command_count + 1
      }
    }
    return ()
  }
  canvas.draw_round_rect(
    skia_rect(expanded),
    Float::from_double(radius),
    Float::from_double(radius),
    skia_paint(shadow.color),
  )
}

///|
fn skia_shadow_rect(shadow : @core.ShadowSpec, grow~ : Double) -> @core.Rect {
  let rect = shadow.rect.rect
  @core.Rect::new(
    x=rect.origin.x + shadow.offset.x - grow,
    y=rect.origin.y + shadow.offset.y - grow,
    width=rect.size.width + grow * 2.0,
    height=rect.size.height + grow * 2.0,
  )
}

///|
fn SkiaRasterRenderer::draw_brush_rounded_rect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  stroke_width~ : Double?,
) -> Unit {
  match brush {
    @core.Brush::Solid(color) =>
      match stroke_width {
        Some(width) =>
          canvas.draw_round_rect(
            skia_rect(rounded.rect),
            Float::from_double(rounded.radius),
            Float::from_double(rounded.radius),
            skia_stroke_paint(color, width),
          )
        None =>
          canvas.draw_round_rect(
            skia_rect(rounded.rect),
            Float::from_double(rounded.radius),
            Float::from_double(rounded.radius),
            skia_paint(color),
          )
      }
    @core.Brush::LinearGradient(gradient) =>
      match
        @skia_native.Shader::linear_gradient(
          skia_point(gradient.start),
          skia_point(gradient.end),
          skia_color(gradient.start_color),
          skia_color(gradient.end_color),
        ) {
        Some(shader) =>
          match stroke_width {
            Some(width) =>
              canvas.draw_round_rect_shader(
                skia_rect(rounded.rect),
                Float::from_double(rounded.radius),
                Float::from_double(rounded.radius),
                shader,
                skia_stroke_paint(gradient.start_color, width),
              )
            None => {
              ignore(canvas.save())
              canvas.clip_rrect(skia_rrect(rounded), anti_alias=true)
              canvas.draw_rect_shader(
                skia_rect(rounded.rect),
                shader,
                @skia_mbt.Paint::new(anti_alias=true),
              )
              canvas.restore()
            }
          }
        None => {
          canvas.draw_round_rect(
            skia_rect(rounded.rect),
            Float::from_double(rounded.radius),
            Float::from_double(rounded.radius),
            skia_paint(gradient.start_color),
          )
          self.unsupported_command_count = self.unsupported_command_count + 1
        }
      }
  }
}

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
        @skia_mbt.Rect::from_xywh(
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
        sampling=@skia_mbt.SamplingOptions::linear(),
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
    None =>
      match skia_image_source_bytes(source) {
        Some(bytes) => {
          ignore(self.image_lifecycle.mark_loading(source))
          match @skia_native.Image::from_encoded_bytes(bytes) {
            Some(image) => {
              self.image_cache[source] = image
              ignore(
                self.image_lifecycle.mark_ready(
                  source,
                  width=image.width(),
                  height=image.height(),
                ),
              )
              Some(image)
            }
            None => {
              ignore(
                self.image_lifecycle.mark_failed(
                  source,
                  diagnostic="Skia image decode failed",
                ),
              )
              None
            }
          }
        }
        None => {
          ignore(
            self.image_lifecycle.mark_failed(
              source,
              diagnostic="Skia image source bytes are unavailable",
            ),
          )
          None
        }
      }
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
    @core.ImageFit::Contain =>
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
fn SkiaRasterRenderer::push_layer(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  layer : @core.LayerSpec,
) -> Unit {
  let paint = skia_opacity_paint(layer.opacity).set_blend_mode(
    skia_blend_mode(layer.blend_mode),
  )
  match layer.mask {
    @core.LayerMask::NoMask => ignore(canvas.save_layer(paint~))
    @core.LayerMask::RectMask(rect) => {
      ignore(canvas.save_layer(bounds=Some(skia_rect(rect)), paint~))
      canvas.clip_rect(skia_rect(rect), anti_alias=true)
    }
    @core.LayerMask::RoundedMask(rounded) => {
      ignore(canvas.save_layer(bounds=Some(skia_rect(rounded.rect)), paint~))
      canvas.clip_rrect(skia_rrect(rounded), anti_alias=true)
    }
  }
  if layer.offscreen {
    ignore(layer.offscreen)
  }
  let _ = self
}

///|
fn SkiaRasterRenderer::draw_text(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  run : @core.TextRun,
) -> Unit {
  match skia_font(run.font) {
    Some(font) => {
      let glyph_run = skia_basic_glyph_run(font, run.text)
      let x = match run.align {
        @core.TextAlign::TextStart => run.frame.origin.x
        @core.TextAlign::TextCenter =>
          run.frame.origin.x + (run.frame.size.width - glyph_run.width) / 2.0
        @core.TextAlign::TextEnd =>
          run.frame.origin.x + run.frame.size.width - glyph_run.width
      }
      let metrics = skia_text_metrics(
        font,
        fallback_baseline=run.font.size,
        fallback_height=run.font.size * 1.25,
      )
      let y = run.frame.origin.y + metrics.baseline
      canvas.draw_glyphs(
        glyph_run.glyphs,
        glyph_run.positions,
        font,
        skia_paint(run.color),
        origin=@skia_mbt.Point::new(
          Float::from_double(x),
          Float::from_double(y),
        ),
      )
    }
    None => self.unsupported_command_count = self.unsupported_command_count + 1
  }
}

///|
fn SkiaRasterRenderer::draw_path(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.PathSpec,
) -> Unit {
  match skia_path(spec) {
    Some(path) => {
      match spec.fill {
        Some(@core.Brush::Solid(color)) =>
          canvas.draw_path(path, skia_paint(color))
        Some(@core.Brush::LinearGradient(gradient)) =>
          self.draw_path_gradient(canvas, path, gradient, stroke_width=None)
        None => ()
      }
      match spec.stroke {
        Some(@core.Brush::Solid(color)) =>
          canvas.draw_path(path, skia_stroke_paint(color, spec.stroke_width))
        Some(@core.Brush::LinearGradient(gradient)) =>
          self.draw_path_gradient(
            canvas,
            path,
            gradient,
            stroke_width=Some(spec.stroke_width),
          )
        None => ()
      }
    }
    None => self.unsupported_command_count = self.unsupported_command_count + 1
  }
}

///|
fn SkiaRasterRenderer::draw_path_gradient(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  path : @skia_native.Path,
  gradient : @core.LinearGradientSpec,
  stroke_width~ : Double?,
) -> Unit {
  match
    @skia_native.Shader::linear_gradient(
      skia_point(gradient.start),
      skia_point(gradient.end),
      skia_color(gradient.start_color),
      skia_color(gradient.end_color),
    ) {
    Some(shader) =>
      match stroke_width {
        Some(width) =>
          canvas.draw_path_shader(
            path,
            shader,
            skia_stroke_paint(gradient.start_color, width),
          )
        None =>
          match path.bounds() {
            Some(bounds) => {
              ignore(canvas.save())
              canvas.clip_path(path, anti_alias=true)
              canvas.draw_rect_shader(
                bounds,
                shader,
                @skia_mbt.Paint::new(anti_alias=true),
              )
              canvas.restore()
            }
            None => ()
          }
      }
    None => {
      let paint = match stroke_width {
        Some(width) => skia_stroke_paint(gradient.start_color, width)
        None => skia_paint(gradient.start_color)
      }
      canvas.draw_path(path, paint)
      self.unsupported_command_count = self.unsupported_command_count + 1
    }
  }
}

///|
fn SkiaRasterRenderer::draw_shader_effect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  match spec.name {
    "solid" => self.draw_brush_rect(canvas, spec.frame, spec.fallback)
    "checker" => self.draw_checker_effect(canvas, spec)
    "linear-gradient-debug" => self.draw_linear_gradient_debug(canvas, spec)
    "vignette" => self.draw_vignette_effect(canvas, spec)
    _ => {
      self.draw_brush_rect(canvas, spec.frame, spec.fallback)
      self.unsupported_command_count = self.unsupported_command_count + 1
    }
  }
}

///|
fn SkiaRasterRenderer::draw_brush_rect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  frame : @core.Rect,
  brush : @core.Brush,
) -> Unit {
  match brush {
    @core.Brush::Solid(color) =>
      canvas.draw_rect(skia_rect(frame), skia_paint(color))
    @core.Brush::LinearGradient(gradient) =>
      match
        @skia_native.Shader::linear_gradient(
          skia_point(gradient.start),
          skia_point(gradient.end),
          skia_color(gradient.start_color),
          skia_color(gradient.end_color),
        ) {
        Some(shader) =>
          canvas.draw_rect_shader(
            skia_rect(frame),
            shader,
            @skia_mbt.Paint::new(anti_alias=true),
          )
        None => {
          canvas.draw_rect(skia_rect(frame), skia_paint(gradient.start_color))
          self.unsupported_command_count = self.unsupported_command_count + 1
        }
      }
  }
}

///|
fn SkiaRasterRenderer::draw_checker_effect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  let amount = match spec.uniforms.get(0) {
    Some(value) => value.max(1.0)
    None => 8.0
  }
  let (color_a, color_b) = skia_shader_effect_colors(spec.fallback)
  let cell = (spec.frame.size.width.min(spec.frame.size.height) / amount).max(
    1.0,
  )
  let columns = (spec.frame.size.width / cell).ceil().to_int().max(1)
  let rows = (spec.frame.size.height / cell).ceil().to_int().max(1)
  for row in 0..<rows {
    for column in 0..<columns {
      let color = if (row + column) % 2 == 0 { color_a } else { color_b }
      let x = spec.frame.origin.x + column.to_double() * cell
      let y = spec.frame.origin.y + row.to_double() * cell
      canvas.draw_rect(
        skia_rect(
          @core.Rect::new(
            x~,
            y~,
            width=cell.min(spec.frame.origin.x + spec.frame.size.width - x),
            height=cell.min(spec.frame.origin.y + spec.frame.size.height - y),
          ),
        ),
        skia_paint(color),
      )
    }
  }
  let _ = self
}

///|
fn SkiaRasterRenderer::draw_linear_gradient_debug(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  let (start_color, end_color) = skia_shader_effect_colors(spec.fallback)
  let gradient = @core.LinearGradientSpec::new(
    start=spec.frame.origin,
    end=@core.Point::new(
      x=spec.frame.origin.x + spec.frame.size.width,
      y=spec.frame.origin.y,
    ),
    start_color~,
    end_color~,
  )
  self.draw_brush_rect(
    canvas,
    spec.frame,
    @core.Brush::LinearGradient(gradient),
  )
}

///|
fn SkiaRasterRenderer::draw_vignette_effect(
  self : SkiaRasterRenderer,
  canvas : @skia_native.Canvas,
  spec : @core.ShaderEffectSpec,
) -> Unit {
  let (color, _) = skia_shader_effect_colors(spec.fallback)
  let center = @core.Point::new(
    x=spec.frame.origin.x + spec.frame.size.width / 2.0,
    y=spec.frame.origin.y + spec.frame.size.height / 2.0,
  )
  let radius = spec.frame.size.width.max(spec.frame.size.height) /
    2.0 *
    skia_vignette_radius_scale(spec)
  let outer_color = @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=color.a)
  match
    @skia_native.Shader::radial_gradient(
      skia_point(center),
      Float::from_double(radius),
      skia_color(color),
      skia_color(outer_color),
    ) {
    Some(shader) =>
      canvas.draw_rect_shader(
        skia_rect(spec.frame),
        shader,
        @skia_mbt.Paint::new(anti_alias=true),
      )
    None => {
      self.draw_brush_rect(canvas, spec.frame, spec.fallback)
      self.unsupported_command_count = self.unsupported_command_count + 1
    }
  }
}

///|
fn skia_vignette_radius_scale(spec : @core.ShaderEffectSpec) -> Double {
  match spec.uniforms.get(0) {
    Some(amount) => amount.max(0.8)
    None => 0.8
  }
}

///|
fn SkiaRasterRenderer::read_frame(
  self : SkiaRasterRenderer,
) -> SkiaPixelFrame raise SkiaRendererError {
  match self.surface.read_pixels() {
    Some(pixmap) =>
      {
        width: pixmap.width(),
        height: pixmap.height(),
        row_bytes: pixmap.row_bytes(),
        scale_factor: self.metrics.scale_factor,
        pixels: pixmap.pixels,
      }
    None => raise SkiaRendererError::ReadPixelsUnavailable
  }
}

///|
pub fn SkiaRasterRenderer::text_system(
  self : SkiaRasterRenderer,
) -> @core.TextSystem {
  let _ = self
  skia_text_system()
}

///|
pub fn SkiaRasterRenderer::image_resources(
  self : SkiaRasterRenderer,
) -> Array[@render.ImageResourceRecord] {
  self.image_lifecycle.snapshot()
}

///|
pub fn SkiaRasterRenderer::dispose(self : SkiaRasterRenderer) -> Unit {
  let _ = self
}

///|
pub fn SkiaRasterRenderer::backend_kind(
  self : SkiaRasterRenderer,
) -> @render.RendererBackendKind {
  let _ = self
  @render.RendererBackendKind::SkiaRasterNative
}

///|
pub fn SkiaRasterRenderer::backend_info(
  self : SkiaRasterRenderer,
) -> @render.RendererBackendInfo {
  let _ = self
  backend_info()
}

///|
pub fn SkiaRasterRenderer::present_count(self : SkiaRasterRenderer) -> Int {
  self.present_count
}

///|
pub fn SkiaRasterRenderer::unsupported_command_count(
  self : SkiaRasterRenderer,
) -> Int {
  self.unsupported_command_count
}

///|
pub fn SkiaRasterRenderer::last_frame(
  self : SkiaRasterRenderer,
) -> SkiaPixelFrame? {
  self.last_frame
}

///|
fn skia_text_system() -> @core.TextSystem {
  @core.TextSystem::new(id="skia-raster-text-system", measure=input => {
    match skia_font(input.font) {
      Some(font) => {
        let fallback = @core.TextSystem::fallback().measure_text(input)
        skia_text_layout_result(font, input, fallback)
      }
      None => @core.TextSystem::fallback().measure_text(input)
    }
  })
}

///|
fn skia_text_layout_result(
  font : @skia_native.Font,
  input : @core.TextLayoutInput,
  fallback : @core.TextLayoutResult,
) -> @core.TextLayoutResult {
  let measured = skia_measure_text_width(font, input.text)
  let carets = skia_caret_positions(font, input.text)
  let metrics = skia_text_metrics(
    font,
    fallback_baseline=fallback.baseline,
    fallback_height=fallback.size.height,
  )
  match input.max_width {
    Some(max_width) => {
      let clamped : Array[Double] = []
      for caret in carets {
        clamped.push(caret.min(max_width))
      }
      {
        size: @core.Size::new(
          width=measured.min(max_width),
          height=metrics.height,
        ),
        baseline: metrics.baseline,
        caret_positions: clamped,
      }
    }
    None =>
      {
        size: @core.Size::new(width=measured, height=metrics.height),
        baseline: metrics.baseline,
        caret_positions: carets,
      }
  }
}

///|
fn skia_text_metrics(
  font : @skia_native.Font,
  fallback_baseline~ : Double,
  fallback_height~ : Double,
) -> SkiaTextMetrics {
  let metrics = font.metrics()
  let ascent = metrics.ascent.to_double()
  let descent = metrics.descent.to_double()
  let leading = metrics.leading.to_double()
  let measured_baseline = (0.0 - ascent).max(0.0)
  let measured_height = (descent - ascent + leading)
    .max(descent - ascent)
    .max(0.0)
  let baseline = if measured_baseline > 0.0 {
    measured_baseline
  } else {
    fallback_baseline
  }
  let height = if measured_height > 0.0 {
    measured_height
  } else {
    fallback_height
  }
  { baseline, height: height.max(baseline) }
}

///|
fn skia_caret_positions(
  font : @skia_native.Font,
  text : String,
) -> Array[Double] {
  let chars = text.to_array()
  let carets : Array[Double] = [0.0]
  for index in 1..<(chars.length() + 1) {
    let prefix = String::from_array(chars[:index])
    carets.push(skia_measure_text_width(font, prefix))
  }
  carets
}

///|
fn skia_measure_text_width(font : @skia_native.Font, text : String) -> Double {
  font.measure_text_utf8(@utf8.encode(text[:], bom=false)).to_double()
}

///|
fn skia_basic_glyph_run(
  font : @skia_native.Font,
  text : String,
) -> SkiaGlyphRun {
  let bytes = @utf8.encode(text[:], bom=false)
  let glyphs = font.text_to_glyphs_utf8(bytes)
  {
    glyphs,
    positions: font.glyph_positions(glyphs),
    width: font.measure_text_utf8(bytes).to_double(),
  }
}

///|
fn skia_font(font : @core.FontSpec) -> @skia_native.Font? {
  match skia_typeface(font) {
    Some(typeface) =>
      @skia_native.Font::from_typeface(
        typeface,
        size=Float::from_double(font.size),
      )
    None => @skia_native.Font::default(size=Float::from_double(font.size))
  }
}

///|
fn skia_typeface(font : @core.FontSpec) -> @skia_native.Typeface? {
  match @skia_native.FontMgr::default() {
    Some(font_mgr) => skia_typeface_from_font_mgr(font_mgr, font)
    None => None
  }
}

///|
fn skia_typeface_from_font_mgr(
  font_mgr : @skia_native.FontMgr,
  font : @core.FontSpec,
) -> @skia_native.Typeface? {
  for family in font.families.families {
    for family_name in skia_font_family_candidates(family) {
      match
        font_mgr.match_family_style(
          @utf8.encode(family_name[:], bom=false),
          weight=font.weight,
          width=5,
          slant=skia_font_slant(font.style),
        ) {
        Some(typeface) => return Some(typeface)
        None => ()
      }
    }
  }
  None
}

///|
fn skia_font_family_candidates(family : @core.FontFamily) -> Array[String] {
  match family {
    Name(name) => [name]
    SystemUi | UiSansSerif | SansSerif => skia_system_sans_families()
    UiSerif | Serif => skia_serif_families()
    UiMonospace | Monospace => skia_monospace_families()
    Emoji => skia_emoji_families()
    Math => skia_serif_families()
    FangSong => skia_fangsong_families()
  }
}

///|
fn skia_system_sans_families() -> Array[String] {
  [
    "Helvetica Neue", "Segoe UI", "Arial", "DejaVu Sans", "Noto Sans", "Liberation Sans",
  ]
}

///|
fn skia_serif_families() -> Array[String] {
  [
    "Times New Roman", "Georgia", "DejaVu Serif", "Noto Serif", "Liberation Serif",
  ]
}

///|
fn skia_monospace_families() -> Array[String] {
  [
    "Menlo", "Consolas", "Courier New", "DejaVu Sans Mono", "Noto Sans Mono", "Liberation Mono",
  ]
}

///|
fn skia_emoji_families() -> Array[String] {
  ["Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji"]
}

///|
fn skia_fangsong_families() -> Array[String] {
  ["STFangsong", "FangSong", "FangSong SC", "SimSun"]
}

///|
fn skia_font_slant(style : @core.FontStyle) -> Int {
  match style {
    Normal => 0
    Italic => 1
  }
}

///|
fn skia_dim_to_int(value : Double) -> Int {
  value.ceil().max(1.0).to_int()
}

///|
fn skia_color(color : @core.Color) -> @skia_mbt.Color {
  @skia_mbt.Color::from_argb(
    color_component_byte(color.a),
    color_component_byte(color.r),
    color_component_byte(color.g),
    color_component_byte(color.b),
  )
}

///|
fn color_component_byte(value : Double) -> Byte {
  (value.max(0.0).min(1.0) * 255.0).round().to_int().to_byte()
}

///|
fn skia_paint(color : @core.Color) -> @skia_mbt.Paint {
  @skia_mbt.Paint::new(color=skia_color(color), anti_alias=true)
}

///|
fn skia_opacity_paint(opacity : Double) -> @skia_mbt.Paint {
  @skia_mbt.Paint::new(
    color=@skia_mbt.Color::white().with_alpha(color_component_byte(opacity)),
    anti_alias=true,
  )
}

///|
fn skia_stroke_paint(color : @core.Color, width : Double) -> @skia_mbt.Paint {
  @skia_mbt.Paint::new(color=skia_color(color), anti_alias=true)
  .set_stroke(true)
  .set_stroke_width(Float::from_double(width.max(0.0)))
}

///|
fn skia_blend_mode(mode : @core.BlendMode) -> @skia_mbt.BlendMode {
  match mode {
    @core.BlendMode::SourceOver => @skia_mbt.BlendMode::SrcOver
    @core.BlendMode::Multiply => @skia_mbt.BlendMode::Multiply
    @core.BlendMode::Screen => @skia_mbt.BlendMode::Screen
    @core.BlendMode::Overlay => @skia_mbt.BlendMode::Overlay
    @core.BlendMode::Darken => @skia_mbt.BlendMode::Darken
    @core.BlendMode::Lighten => @skia_mbt.BlendMode::Lighten
  }
}

///|
fn skia_shader_effect_colors(
  fallback : @core.Brush,
) -> (@core.Color, @core.Color) {
  match fallback {
    @core.Brush::Solid(color) => (color, color)
    @core.Brush::LinearGradient(gradient) =>
      (gradient.start_color, gradient.end_color)
  }
}

///|
fn skia_color_filter_matrix(
  values : Array[Double],
) -> @skia_native.ColorFilter? {
  let matrix : Array[Float] = []
  let count = values.length().min(20)
  for index in 0..<count {
    matrix.push(Float::from_double(values[index]))
  }
  for _ in count..<20 {
    matrix.push(0.0)
  }
  @skia_native.ColorFilter::matrix(matrix)
}

///|
fn skia_rect(rect : @core.Rect) -> @skia_mbt.Rect {
  @skia_mbt.Rect::from_xywh(
    Float::from_double(rect.origin.x),
    Float::from_double(rect.origin.y),
    Float::from_double(rect.size.width),
    Float::from_double(rect.size.height),
  )
}

///|
fn skia_point(point : @core.Point) -> @skia_mbt.Point {
  @skia_mbt.Point::new(Float::from_double(point.x), Float::from_double(point.y))
}

///|
fn skia_rrect(rounded : @core.RoundedRect) -> @skia_mbt.RRect {
  @skia_mbt.RRect::from_rect_xy(
    skia_rect(rounded.rect),
    Float::from_double(rounded.radius),
    Float::from_double(rounded.radius),
  )
}

///|
fn skia_matrix(transform : @core.Transform2D) -> @skia_mbt.Matrix {
  @skia_mbt.Matrix::from_affine([
    Float::from_double(transform.a),
    Float::from_double(transform.c),
    Float::from_double(transform.tx),
    Float::from_double(transform.b),
    Float::from_double(transform.d),
    Float::from_double(transform.ty),
  ]).unwrap_or(@skia_mbt.Matrix::identity())
}

///|
fn skia_path(spec : @core.PathSpec) -> @skia_native.Path? {
  match @skia_native.Path::new() {
    Some(path) => {
      for verb in spec.verbs {
        match verb {
          @core.PathVerb::MoveTo(point) => path.move_to(skia_point(point))
          @core.PathVerb::LineTo(point) => path.line_to(skia_point(point))
          @core.PathVerb::QuadTo(control, end) =>
            path.quad_to(skia_point(control), skia_point(end))
          @core.PathVerb::CubicTo(c1, c2, end) =>
            path.cubic_to(skia_point(c1), skia_point(c2), skia_point(end))
          @core.PathVerb::Close => path.close()
        }
      }
      Some(path)
    }
    None => None
  }
}

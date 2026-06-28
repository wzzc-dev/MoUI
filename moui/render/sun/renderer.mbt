///|
pub(all) suberror SunRendererError {
  InvalidSurfaceSize(Int, Int)
  PresentFailed(String)
} derive(Eq, Debug, ToJson)

///|
pub fn SunRendererError::message(self : SunRendererError) -> String {
  match self {
    InvalidSurfaceSize(width, height) =>
      "invalid Sun raster surface size \{width}x\{height}"
    PresentFailed(description) => "Sun presenter failed: \{description}"
  }
}

///|
pub(all) struct SunPixelFrame {
  width : Int
  height : Int
  row_bytes : Int
  scale_factor : Double
  pixels : FixedArray[Byte]
  bytes : Bytes
} derive(Debug)

///|
pub(all) struct SunPresentTarget {
  description : String
  present : (SunPixelFrame) -> Bool
}

///|
pub(all) struct SunUnsupportedCommandDiagnostic {
  command : String
  reason : String
} derive(Eq, Debug, ToJson)

///|
priv enum SunCanvasScopeKind {
  Clip
  RoundedClip
  Transform
  Opacity
  Layer
  Filter
} derive(Eq)

///|
pub(all) struct SunRasterRenderer {
  mut metrics : @render.RendererSurfaceMetrics
  target : SunPresentTarget
  mut canvas : @sun_graphics.Canvas
  mut present_count : Int
  mut unsupported_command_count : Int
  unsupported_command_diagnostics : Array[SunUnsupportedCommandDiagnostic]
  mut last_frame : SunPixelFrame?
  text_system : @sun_text.TextSystem
  resources : @sun_renderer.RendererResources
  image_lifecycle : @render.ImageResourceLifecycle
  async_image_loading : Bool
  mut on_image_resource_change : ((@render.ImageResourceSnapshot) -> Unit)?
  mut canvas_stack : Array[@sun_graphics.Canvas]
  mut filter_stack : Array[@sun_graphics.PaintFilter]
  mut cached_layer_pixmaps : Map[String, @sun_graphics.Pixmap]
  mut cached_layer_revisions : Map[String, Int]
  mut cached_layer_scales : Map[String, Double]
  mut cached_layer_order : Array[String]
  mut cached_layer_hit_count : Int
  mut cached_layer_miss_count : Int
  mut blur_radius_stack : Array[Double]
  mut rounded_clip_stack : Array[@core.RoundedRect]
}

///|
pub fn SunPresentTarget::new(
  description~ : String,
  present~ : (SunPixelFrame) -> Bool,
) -> SunPresentTarget {
  { description, present }
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::SunRasterNative,
    status=@render.RendererCapabilityStatus::Supported,
    can_render=true,
    can_resize=true,
    owns_surface=true,
    description="Native Sun CPU raster renderer over moui_sun graphics/text primitives with structured unsupported-command diagnostics.",
  )
}

///|
pub fn renderer_descriptor() -> @render.RendererDescriptor {
  sun_raster_native_descriptor()
}

///|
pub fn sun_raster_native_descriptor() -> @render.RendererDescriptor {
  @render.RendererDescriptor::new(
    backend=@render.RendererBackendKind::SunRasterNative,
    family=@render.RendererFamily::Sun,
    presentation=@render.RendererPresentationModel::CpuPixelFrame,
    supported_targets=[@render.RendererTarget::Native],
    capabilities=@render.renderer_backend_capabilities(
      @render.RendererBackendKind::SunRasterNative,
    ),
    description="Native Sun CPU raster renderer that presents copied RGBA pixel frames to host providers.",
  )
}

///|
pub fn create_with_present_target(
  metrics : @render.RendererSurfaceMetrics,
  target : SunPresentTarget,
  async_image_loading? : Bool = false,
) -> SunRasterRenderer raise SunRendererError {
  let width = sun_dim_to_int(metrics.physical_size.width)
  let height = sun_dim_to_int(metrics.physical_size.height)
  guard width > 0 && height > 0 else {
    raise SunRendererError::InvalidSurfaceSize(width, height)
  }
  let renderer = {
    metrics,
    target,
    canvas: @sun_graphics.Canvas::new(width, height),
    present_count: 0,
    unsupported_command_count: 0,
    unsupported_command_diagnostics: [],
    last_frame: None,
    text_system: @sun_text.TextSystem::with_font_cache_capacity(64),
    resources: @sun_renderer.RendererResources::with_font_capacity(
      1024, 1024, 64, 256, 256, 128,
    ),
    image_lifecycle: @render.ImageResourceLifecycle::new(),
    async_image_loading,
    on_image_resource_change: None,
    canvas_stack: [],
    filter_stack: [],
    cached_layer_pixmaps: {},
    cached_layer_revisions: {},
    cached_layer_scales: {},
    cached_layer_order: [],
    cached_layer_hit_count: 0,
    cached_layer_miss_count: 0,
    blur_radius_stack: [],
    rounded_clip_stack: [],
  }
  renderer.register_default_platform_fonts()
  renderer
}

///|
pub fn SunRasterRenderer::resize(
  self : SunRasterRenderer,
  metrics : @render.RendererSurfaceMetrics,
) -> Unit raise SunRendererError {
  self.metrics = metrics
  self.canvas = new_canvas_for_metrics(metrics)
}

///|
pub fn SunRasterRenderer::render(
  self : SunRasterRenderer,
  commands : Array[@core.DrawCommand],
) -> Unit raise SunRendererError {
  self.canvas = new_canvas_for_metrics(self.metrics)
  self.canvas.clear(sun_color(@render.first_clear_color(commands)))
  self.canvas.scale(sx=self.metrics.scale_factor, sy=self.metrics.scale_factor)
  self.unsupported_command_count = 0
  self.unsupported_command_diagnostics.clear()
  let canvas_scopes : Array[SunCanvasScopeKind] = []
  let opacity_stack : Array[Double] = []
  let blend_mode_stack : Array[@sun_graphics.BlendMode] = []
  let layer_spec_stack : Array[SunLayerScope] = []
  let rounded_clip_transform_stack : Array[@sun_graphics.Transform] = []
  self.render_cached_command_range(
    commands,
    0,
    commands.length(),
    canvas_scopes,
    opacity_stack,
    blend_mode_stack,
    layer_spec_stack,
    rounded_clip_transform_stack,
  )
  if !canvas_scopes.is_empty() {
    for scope in canvas_scopes {
      self.record_unsupported_command(
        sun_scope_push_command(scope),
        "command stream ended with an open \{sun_scope_name(scope)} scope",
      )
    }
    while !self.canvas_stack.is_empty() {
      match self.canvas_stack.pop() {
        Some(parent_canvas) => self.canvas = parent_canvas
        None => ()
      }
    }
    self.filter_stack.clear()
    self.blur_radius_stack.clear()
    self.rounded_clip_stack.clear()
    rounded_clip_transform_stack.clear()
    while !blend_mode_stack.is_empty() {
      ignore(blend_mode_stack.pop())
    }
    while !layer_spec_stack.is_empty() {
      ignore(layer_spec_stack.pop())
    }
  }
  let frame = self.read_frame()
  self.last_frame = Some(frame)
  if (self.target.present)(frame) {
    self.present_count = self.present_count + 1
  } else {
    raise SunRendererError::PresentFailed(self.target.description)
  }
}

///|
pub fn SunRasterRenderer::text_system(
  self : SunRasterRenderer,
) -> @core.TextSystem {
  @core.TextSystem::new(
    id="sun-raster-text-system",
    measure=input => self.measure_text_layout(input),
    paragraph_layout=Some(input => self.paragraph_layout_result(input)),
    register_font_data=(family, data) => {
      self.register_font_family_data(family, data)
    },
  )
}

///|
pub fn SunRasterRenderer::present_count(self : SunRasterRenderer) -> Int {
  self.present_count
}

///|
pub fn SunRasterRenderer::unsupported_command_count(
  self : SunRasterRenderer,
) -> Int {
  self.unsupported_command_count
}

///|
pub fn SunRasterRenderer::unsupported_command_diagnostics(
  self : SunRasterRenderer,
) -> Array[SunUnsupportedCommandDiagnostic] {
  self.unsupported_command_diagnostics.copy()
}

///|
pub fn SunRasterRenderer::last_frame(
  self : SunRasterRenderer,
) -> SunPixelFrame? {
  self.last_frame
}

///|
pub fn SunRasterRenderer::cached_layer_hit_count(
  self : SunRasterRenderer,
) -> Int {
  self.cached_layer_hit_count
}

///|
pub fn SunRasterRenderer::cached_layer_miss_count(
  self : SunRasterRenderer,
) -> Int {
  self.cached_layer_miss_count
}

///|
pub fn SunRasterRenderer::dispose(self : SunRasterRenderer) -> Unit {
  let previous_revision = self.image_lifecycle.revision()
  let records = self.image_lifecycle.snapshot()
  for record in records {
    ignore(self.image_lifecycle.dispose(record.source))
  }
  self.notify_image_resource_change_if_needed(previous_revision)
  self.clear_cached_layers()
  self.rounded_clip_stack = []
  self.blur_radius_stack = []
}

///|
pub fn SunRasterRenderer::register_font_bytes(
  self : SunRasterRenderer,
  key : String,
  data : Bytes,
) -> Unit {
  ignore(self.text_system.register_font_bytes(key, data))
}

///|
pub fn SunRasterRenderer::image_resources(
  self : SunRasterRenderer,
) -> Array[@render.ImageResourceRecord] {
  self.image_lifecycle.snapshot()
}

///|
pub fn SunRasterRenderer::image_resource_snapshot(
  self : SunRasterRenderer,
) -> @render.ImageResourceSnapshot {
  self.image_lifecycle.snapshot_with_revision()
}

///|
pub fn SunRasterRenderer::apply_image_resource_load_completion(
  self : SunRasterRenderer,
  completion : @render.ImageResourceLoadCompletion,
) -> @render.ImageResourceSnapshot {
  let previous_revision = self.image_lifecycle.revision()
  let snapshot = self.image_lifecycle.apply_load_completion(completion)
  self.notify_image_resource_change_if_needed(previous_revision)
  snapshot
}

///|
pub fn SunRasterRenderer::set_image_resource_change_callback(
  self : SunRasterRenderer,
  callback : ((@render.ImageResourceSnapshot) -> Unit)?,
) -> Unit {
  self.on_image_resource_change = callback
}

///|
fn new_canvas_for_metrics(
  metrics : @render.RendererSurfaceMetrics,
) -> @sun_graphics.Canvas raise SunRendererError {
  let width = sun_dim_to_int(metrics.physical_size.width)
  let height = sun_dim_to_int(metrics.physical_size.height)
  guard width > 0 && height > 0 else {
    raise SunRendererError::InvalidSurfaceSize(width, height)
  }
  @sun_graphics.Canvas::new(width, height)
}

///|
fn SunRasterRenderer::read_frame(self : SunRasterRenderer) -> SunPixelFrame {
  let pixmap = self.canvas.get_pixmap()
  let width = pixmap.get_width()
  let height = pixmap.get_height()
  let pixels = copy_fixed_pixels(pixmap.get_pixels())
  SunPixelFrame::{
    width,
    height,
    row_bytes: width * 4,
    scale_factor: self.metrics.scale_factor,
    pixels,
    bytes: pixmap.to_rgba_bytes(),
  }
}

///|
fn copy_fixed_pixels(src : FixedArray[Byte]) -> FixedArray[Byte] {
  let dst : FixedArray[Byte] = FixedArray::make(src.length(), 0)
  for index in 0..<src.length() {
    dst[index] = src[index]
  }
  dst
}

///|
fn SunRasterRenderer::render_command(
  self : SunRasterRenderer,
  command : @core.DrawCommand,
  canvas_scopes : Array[SunCanvasScopeKind],
  opacity_stack : Array[Double],
  blend_mode_stack : Array[@sun_graphics.BlendMode],
  layer_spec_stack : Array[SunLayerScope],
  rounded_clip_transform_stack : Array[@sun_graphics.Transform],
) -> Unit {
  let opacity = sun_current_opacity(opacity_stack)
  match command {
    @core.DrawCommand::Clear(color) => self.canvas.clear(sun_color(color))
    @core.DrawCommand::FillRect(rect, color) =>
      self.canvas.fill_rect(
        rect.origin.x,
        rect.origin.y,
        rect.size.width,
        rect.size.height,
        sun_paint(color, opacity),
      )
    @core.DrawCommand::StrokeRect(rect, color, width) =>
      self.canvas.stroke_rect(
        rect.origin.x,
        rect.origin.y,
        rect.size.width,
        rect.size.height,
        sun_stroke_paint(color, width, opacity),
      )
    @core.DrawCommand::FillRoundedRect(rounded, color) =>
      self.fill_rounded_rect(rounded, @core.Brush::solid(color), opacity)
    @core.DrawCommand::StrokeRoundedRect(rounded, color, width) =>
      self.stroke_rounded_rect(
        rounded,
        @core.Brush::solid(color),
        width,
        opacity,
      )
    @core.DrawCommand::FillRoundedRectBrush(rounded, brush) =>
      self.fill_rounded_rect(rounded, brush, opacity)
    @core.DrawCommand::StrokeRoundedRectBrush(rounded, brush, width) =>
      self.stroke_rounded_rect(rounded, brush, width, opacity)
    @core.DrawCommand::DrawShadow(shadow) => self.draw_shadow(shadow, opacity)
    @core.DrawCommand::DrawText(run) => self.draw_text(run, opacity)
    @core.DrawCommand::DrawImage(image) => self.draw_image(image, opacity)
    @core.DrawCommand::PushClip(rect) => {
      self.canvas.save()
      canvas_scopes.push(SunCanvasScopeKind::Clip)
      self.canvas.intersect_clip_rect(
        sun_transformed_rect_bounds(self.canvas.get_transform(), rect),
      )
    }
    @core.DrawCommand::PopClip =>
      self.pop_canvas_scope(
        canvas_scopes,
        opacity_stack,
        SunCanvasScopeKind::Clip,
      )
    @core.DrawCommand::PushRoundedClip(rounded) => {
      self.rounded_clip_stack.push(rounded)
      rounded_clip_transform_stack.push(self.canvas.get_transform())
      self.push_transparent_offscreen_canvas()
      canvas_scopes.push(SunCanvasScopeKind::RoundedClip)
    }
    @core.DrawCommand::PopRoundedClip =>
      match canvas_scopes.pop() {
        Some(SunCanvasScopeKind::RoundedClip) => {
          let layer_pixmap = self.canvas.get_pixmap()
          match self.canvas_stack.pop() {
            Some(parent_canvas) =>
              match self.rounded_clip_stack.pop() {
                Some(rounded) => {
                  self.canvas = parent_canvas
                  let transform = match rounded_clip_transform_stack.pop() {
                    Some(value) => value
                    None => {
                      self.record_unsupported_command(
                        "PopRoundedClip", "PopRoundedClip has no matching rounded clip transform stack entry",
                      )
                      @sun_graphics.Transform::identity()
                    }
                  }
                  self.composite_rounded_clip(
                    layer_pixmap, rounded, transform, opacity,
                  )
                }
                None => {
                  self.canvas = parent_canvas
                  match rounded_clip_transform_stack.pop() {
                    Some(_) => ()
                    None => ()
                  }
                  self.record_unsupported_command(
                    "PopRoundedClip", "PopRoundedClip has no matching rounded clip stack entry",
                  )
                }
              }
            None =>
              self.record_unsupported_command(
                "PopRoundedClip", "PopRoundedClip has no matching canvas stack entry",
              )
          }
        }
        Some(other) => {
          canvas_scopes.push(other)
          self.record_unsupported_command(
            "PopRoundedClip",
            "pop did not match active \{sun_scope_name(other)} scope",
          )
        }
        None =>
          self.record_unsupported_command(
            "PopRoundedClip", "pop has no matching push scope",
          )
      }
    @core.DrawCommand::PushTransform(transform) => {
      self.canvas.save()
      canvas_scopes.push(SunCanvasScopeKind::Transform)
      self.canvas.concat_transform(sun_transform(transform))
    }
    @core.DrawCommand::PopTransform =>
      self.pop_canvas_scope(
        canvas_scopes,
        opacity_stack,
        SunCanvasScopeKind::Transform,
      )
    @core.DrawCommand::PushOpacity(opacity) => {
      canvas_scopes.push(SunCanvasScopeKind::Opacity)
      opacity_stack.push(sun_clamp_unit(opacity))
    }
    @core.DrawCommand::PopOpacity =>
      self.pop_canvas_scope(
        canvas_scopes,
        opacity_stack,
        SunCanvasScopeKind::Opacity,
      )
    @core.DrawCommand::PushLayer(spec) => {
      blend_mode_stack.push(sun_blend_mode(spec.blend_mode))
      layer_spec_stack.push({ spec, transform: self.canvas.get_transform() })
      self.push_transparent_offscreen_canvas()
      canvas_scopes.push(SunCanvasScopeKind::Layer)
    }
    @core.DrawCommand::PopLayer =>
      match canvas_scopes.pop() {
        Some(SunCanvasScopeKind::Layer) => {
          let layer_pixmap = self.canvas.get_pixmap()
          let layer_blend = match blend_mode_stack.pop() {
            Some(m) => m
            None => @sun_graphics.BlendMode::SourceOver
          }
          let layer_scope = match layer_spec_stack.pop() {
            Some(scope) => scope
            None => {
              self.record_unsupported_command(
                "PopLayer", "PopLayer has no matching layer spec stack entry",
              )
              {
                spec: @core.LayerSpec::new(),
                transform: @sun_graphics.Transform::identity(),
              }
            }
          }
          match self.canvas_stack.pop() {
            Some(parent_canvas) => {
              self.canvas = parent_canvas
              self.composite_layer_pixmap(
                layer_pixmap, layer_scope, opacity, layer_blend,
              )
            }
            None =>
              self.record_unsupported_command(
                "PopLayer", "PopLayer has no matching canvas stack entry",
              )
          }
        }
        Some(other) => {
          canvas_scopes.push(other)
          self.record_unsupported_command(
            "PopLayer",
            "pop did not match active \{sun_scope_name(other)} scope",
          )
        }
        None =>
          self.record_unsupported_command(
            "PopLayer", "pop has no matching push scope",
          )
      }
    @core.DrawCommand::PushFilter(effect) => {
      self.filter_stack.push(sun_filter_effect(effect))
      match effect {
        @core.FilterEffect::Blur(radius) =>
          self.blur_radius_stack.push(radius.max(0.0))
        _ => self.blur_radius_stack.push(0.0)
      }
      self.push_transparent_offscreen_canvas()
      canvas_scopes.push(SunCanvasScopeKind::Filter)
    }
    @core.DrawCommand::PopFilter => {
      let filter = self.filter_stack.pop()
      let blur_radius = match self.blur_radius_stack.pop() {
        Some(r) => r
        None => 0.0
      }
      match canvas_scopes.pop() {
        Some(SunCanvasScopeKind::Filter) => {
          let layer_pixmap = self.canvas.get_pixmap()
          let effective_pixmap = if blur_radius > 0.0 {
            sun_box_blur_pixmap(layer_pixmap, blur_radius)
          } else {
            layer_pixmap
          }
          match self.canvas_stack.pop() {
            Some(parent_canvas) => {
              self.canvas = parent_canvas
              // Apply color filter at the pixmap level instead of
              // per-pixel fill_rect calls to avoid w*h Paint allocations
              // and per-pixel clip/transform overhead.
              // Skip the pixmap copy when the filter is identity (common
              // for blur-only PushFilter scopes).
              let composited = match filter {
                Some(paint_filter) =>
                  if paint_filter.is_identity() {
                    effective_pixmap
                  } else {
                    sun_filter_pixmap(effective_pixmap, paint_filter)
                  }
                None => effective_pixmap
              }
              self.canvas.draw_pixmap(
                composited,
                0,
                0,
                @sun_graphics.Paint::new().set_opacity(opacity),
              )
            }
            None =>
              self.record_unsupported_command(
                "PopFilter", "PopFilter has no matching canvas stack entry",
              )
          }
        }
        Some(other) => {
          canvas_scopes.push(other)
          match filter {
            Some(f) => self.filter_stack.push(f)
            None => ()
          }
          self.blur_radius_stack.push(blur_radius)
          self.record_unsupported_command(
            "PopFilter",
            "pop did not match active \{sun_scope_name(other)} scope",
          )
        }
        None => {
          match filter {
            Some(f) => self.filter_stack.push(f)
            None => ()
          }
          self.blur_radius_stack.push(blur_radius)
          self.record_unsupported_command(
            "PopFilter", "pop has no matching push scope",
          )
        }
      }
    }
    @core.DrawCommand::DrawPath(path) => self.draw_path(path, opacity)
    @core.DrawCommand::DrawShaderEffect(spec) =>
      self.draw_shader_effect(spec, opacity)
    @core.DrawCommand::BeginCachedLayer(_) =>
      self.record_unsupported_command(
        "BeginCachedLayer", "cached layer scope not intercepted by render_cached_command_range",
      )
    @core.DrawCommand::EndCachedLayer(_) =>
      self.record_unsupported_command(
        "EndCachedLayer", "cached layer scope intercepted by render_cached_command_range",
      )
    @core.DrawCommand::DrawCachedLayer(_) =>
      self.record_unsupported_command(
        "DrawCachedLayer", "cached layer draw not intercepted by render_cached_command_range",
      )
  }
}

///|
fn SunRasterRenderer::fill_rounded_rect(
  self : SunRasterRenderer,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  opacity : Double,
) -> Unit {
  let rect = rounded.rect
  self.canvas.fill_rounded_rect(
    rect.origin.x,
    rect.origin.y,
    rect.size.width,
    rect.size.height,
    rounded.radius,
    sun_brush_paint(brush, opacity),
  )
}

///|
fn SunRasterRenderer::stroke_rounded_rect(
  self : SunRasterRenderer,
  rounded : @core.RoundedRect,
  brush : @core.Brush,
  width : Double,
  opacity : Double,
) -> Unit {
  let rect = rounded.rect
  self.canvas.stroke_rounded_rect(
    rect.origin.x,
    rect.origin.y,
    rect.size.width,
    rect.size.height,
    rounded.radius,
    sun_brush_stroke_paint(brush, width, opacity),
  )
}

///|
fn SunRasterRenderer::draw_path(
  self : SunRasterRenderer,
  path : @core.PathSpec,
  opacity : Double,
) -> Unit {
  let sun_path = sun_path(path)
  match path.fill {
    Some(brush) =>
      self.canvas.fill_path(sun_path, sun_brush_paint(brush, opacity))
    None => ()
  }
  match path.stroke {
    Some(brush) =>
      self.canvas.stroke_path(
        sun_path,
        sun_brush_stroke_paint(brush, path.stroke_width, opacity),
      )
    None => ()
  }
  if path.fill is None && path.stroke is None {
    self.record_unsupported_command(
      "DrawPath", "path command has neither fill nor stroke brush",
    )
  }
}

///|
fn SunRasterRenderer::draw_text_placeholder(
  self : SunRasterRenderer,
  run : @core.TextRun,
  opacity : Double,
) -> Unit {
  guard run.frame.size.width > 0.0 && run.frame.size.height > 0.0 else {
    return
  }
  guard run.text.length() > 0 else { return }
  let font_size = sun_text_placeholder_font_size(run.font.size)
  let unit = (font_size / 7.0).max(1.0)
  let advance = unit * 6.0
  let line_height = (font_size * 1.2).max(unit * 8.0)
  let paint = sun_paint(run.color, opacity)
  let lines = sun_text_placeholder_lines(run.text)
  let mut line_index = 0
  for line in lines {
    let line_top = run.frame.origin.y +
      line_index.to_double() * line_height +
      (line_height - unit * 7.0).max(0.0) * 0.5
    guard line_top < run.frame.origin.y + run.frame.size.height else { return }
    let line_width = line.length().to_double() * advance
    let start_x = sun_text_placeholder_start_x(run, line_width)
    self.draw_text_placeholder_line(
      line,
      start_x,
      line_top,
      unit,
      advance,
      run.frame,
      paint,
    )
    line_index = line_index + 1
  }
}

///|
fn SunRasterRenderer::draw_text_placeholder_line(
  self : SunRasterRenderer,
  line : Array[Char],
  start_x : Double,
  top : Double,
  unit : Double,
  advance : Double,
  frame : @core.Rect,
  paint : @sun_graphics.Paint,
) -> Unit {
  let left = frame.origin.x
  let top_bound = frame.origin.y
  let right = frame.origin.x + frame.size.width
  let bottom = frame.origin.y + frame.size.height
  let mut cursor_x = start_x
  for ch in line {
    if cursor_x >= right {
      return
    }
    let glyph = sun_debug_glyph_rows(ch)
    for row in 0..<glyph.length() {
      let row_bits = glyph[row]
      for col in 0..<5 {
        if row_bits.land(1 << (4 - col)) != 0 {
          let cell_x = cursor_x + col.to_double() * unit
          let cell_y = top + row.to_double() * unit
          let draw_left = cell_x.max(left)
          let draw_top = cell_y.max(top_bound)
          let draw_right = (cell_x + unit).min(right)
          let draw_bottom = (cell_y + unit).min(bottom)
          if draw_left < draw_right && draw_top < draw_bottom {
            self.canvas.fill_rect(
              draw_left,
              draw_top,
              draw_right - draw_left,
              draw_bottom - draw_top,
              paint,
            )
          }
        }
      }
    }
    cursor_x = cursor_x + advance
  }
}

///|
fn sun_text_placeholder_font_size(size : Double) -> Double {
  guard size == size && size > 0.0 else { return 12.0 }
  size.max(6.0).min(96.0)
}

///|
fn sun_text_placeholder_start_x(
  run : @core.TextRun,
  line_width : Double,
) -> Double {
  match run.align {
    @core.TextAlign::TextStart => run.frame.origin.x
    @core.TextAlign::TextCenter =>
      run.frame.origin.x + (run.frame.size.width - line_width) * 0.5
    @core.TextAlign::TextEnd =>
      run.frame.origin.x + run.frame.size.width - line_width
  }
}

///|
fn sun_text_placeholder_lines(text : String) -> Array[Array[Char]] {
  let lines : Array[Array[Char]] = []
  let current : Array[Char] = []
  for ch in text {
    if ch.to_int() == 10 {
      lines.push(current.copy())
      current.clear()
    } else {
      current.push(ch)
    }
  }
  lines.push(current.copy())
  lines
}

///|
fn sun_debug_glyph_rows(ch : Char) -> Array[Int] {
  let code = ch.to_int()
  let normalized = if code >= 97 && code <= 122 { code - 32 } else { code }
  match normalized {
    32 | 9 => [0, 0, 0, 0, 0, 0, 0]
    33 => [4, 4, 4, 4, 4, 0, 4]
    34 => [10, 10, 10, 0, 0, 0, 0]
    35 => [10, 31, 10, 10, 31, 10, 0]
    36 => [4, 15, 20, 14, 5, 30, 4]
    37 => [24, 25, 2, 4, 8, 19, 3]
    38 => [12, 18, 20, 8, 21, 18, 13]
    39 => [4, 4, 8, 0, 0, 0, 0]
    40 => [2, 4, 8, 8, 8, 4, 2]
    41 => [8, 4, 2, 2, 2, 4, 8]
    42 => [0, 4, 21, 14, 21, 4, 0]
    43 => [0, 4, 4, 31, 4, 4, 0]
    44 => [0, 0, 0, 0, 4, 4, 8]
    45 => [0, 0, 0, 31, 0, 0, 0]
    46 => [0, 0, 0, 0, 0, 12, 12]
    47 => [1, 2, 4, 8, 16, 0, 0]
    48 => [14, 17, 19, 21, 25, 17, 14]
    49 => [4, 12, 4, 4, 4, 4, 14]
    50 => [14, 17, 1, 2, 4, 8, 31]
    51 => [30, 1, 1, 14, 1, 1, 30]
    52 => [2, 6, 10, 18, 31, 2, 2]
    53 => [31, 16, 30, 1, 1, 17, 14]
    54 => [6, 8, 16, 30, 17, 17, 14]
    55 => [31, 1, 2, 4, 8, 8, 8]
    56 => [14, 17, 17, 14, 17, 17, 14]
    57 => [14, 17, 17, 15, 1, 2, 12]
    58 => [0, 12, 12, 0, 12, 12, 0]
    59 => [0, 12, 12, 0, 4, 4, 8]
    60 => [2, 4, 8, 16, 8, 4, 2]
    61 => [0, 0, 31, 0, 31, 0, 0]
    62 => [8, 4, 2, 1, 2, 4, 8]
    63 => [14, 17, 1, 2, 4, 0, 4]
    64 => [14, 17, 23, 21, 23, 16, 14]
    65 => [14, 17, 17, 31, 17, 17, 17]
    66 => [30, 17, 17, 30, 17, 17, 30]
    67 => [14, 17, 16, 16, 16, 17, 14]
    68 => [30, 17, 17, 17, 17, 17, 30]
    69 => [31, 16, 16, 30, 16, 16, 31]
    70 => [31, 16, 16, 30, 16, 16, 16]
    71 => [14, 17, 16, 23, 17, 17, 15]
    72 => [17, 17, 17, 31, 17, 17, 17]
    73 => [14, 4, 4, 4, 4, 4, 14]
    74 => [7, 2, 2, 2, 18, 18, 12]
    75 => [17, 18, 20, 24, 20, 18, 17]
    76 => [16, 16, 16, 16, 16, 16, 31]
    77 => [17, 27, 21, 21, 17, 17, 17]
    78 => [17, 25, 21, 19, 17, 17, 17]
    79 => [14, 17, 17, 17, 17, 17, 14]
    80 => [30, 17, 17, 30, 16, 16, 16]
    81 => [14, 17, 17, 17, 21, 18, 13]
    82 => [30, 17, 17, 30, 20, 18, 17]
    83 => [15, 16, 16, 14, 1, 1, 30]
    84 => [31, 4, 4, 4, 4, 4, 4]
    85 => [17, 17, 17, 17, 17, 17, 14]
    86 => [17, 17, 17, 17, 17, 10, 4]
    87 => [17, 17, 17, 21, 21, 21, 10]
    88 => [17, 17, 10, 4, 10, 17, 17]
    89 => [17, 17, 10, 4, 4, 4, 4]
    90 => [31, 1, 2, 4, 8, 16, 31]
    91 => [14, 8, 8, 8, 8, 8, 14]
    92 => [16, 8, 4, 2, 1, 0, 0]
    93 => [14, 2, 2, 2, 2, 2, 14]
    94 => [4, 10, 17, 0, 0, 0, 0]
    95 => [0, 0, 0, 0, 0, 0, 31]
    96 => [8, 4, 2, 0, 0, 0, 0]
    123 => [2, 4, 4, 8, 4, 4, 2]
    124 => [4, 4, 4, 0, 4, 4, 4]
    125 => [8, 4, 4, 2, 4, 4, 8]
    126 => [0, 8, 21, 2, 0, 0, 0]
    _ => [31, 17, 21, 17, 21, 17, 31]
  }
}

///|
fn SunRasterRenderer::pop_canvas_scope(
  self : SunRasterRenderer,
  canvas_scopes : Array[SunCanvasScopeKind],
  opacity_stack : Array[Double],
  expected : SunCanvasScopeKind,
) -> Unit {
  match canvas_scopes.pop() {
    Some(actual) =>
      if actual == expected {
        match actual {
          SunCanvasScopeKind::Opacity => ignore(opacity_stack.pop())
          _ => ignore(self.canvas.restore())
        }
      } else {
        canvas_scopes.push(actual)
        self.record_unsupported_command(
          sun_scope_pop_command(expected),
          "pop did not match active \{sun_scope_name(actual)} scope",
        )
      }
    None =>
      self.record_unsupported_command(
        sun_scope_pop_command(expected),
        "pop has no matching push scope",
      )
  }
}

///|
fn SunRasterRenderer::record_unsupported_command(
  self : SunRasterRenderer,
  command : String,
  reason : String,
) -> Unit {
  self.unsupported_command_count = self.unsupported_command_count + 1
  self.unsupported_command_diagnostics.push({ command, reason })
}

///|
fn sun_scope_name(scope : SunCanvasScopeKind) -> String {
  match scope {
    Clip => "clip"
    RoundedClip => "rounded-clip"
    Transform => "transform"
    Opacity => "opacity"
    Layer => "layer"
    Filter => "filter"
  }
}

///|
fn sun_scope_push_command(scope : SunCanvasScopeKind) -> String {
  match scope {
    Clip => "PushClip"
    RoundedClip => "PushRoundedClip"
    Transform => "PushTransform"
    Opacity => "PushOpacity"
    Layer => "PushLayer"
    Filter => "PushFilter"
  }
}

///|
fn sun_scope_pop_command(scope : SunCanvasScopeKind) -> String {
  match scope {
    Clip => "PopClip"
    RoundedClip => "PopRoundedClip"
    Transform => "PopTransform"
    Opacity => "PopOpacity"
    Layer => "PopLayer"
    Filter => "PopFilter"
  }
}

///|
fn sun_dim_to_int(value : Double) -> Int {
  value.ceil().max(1.0).to_int()
}

///|
fn sun_color(color : @core.Color) -> @sun_graphics.Color {
  @sun_graphics.Color::new(
    r=sun_channel(color.r),
    g=sun_channel(color.g),
    b=sun_channel(color.b),
    a=sun_channel(color.a),
  )
}

///|
fn sun_channel(value : Double) -> Byte {
  (sun_clamp_unit(value) * 255.0 + 0.5).to_int().max(0).min(255).to_byte()
}

///|
fn sun_clamp_unit(value : Double) -> Double {
  guard value == value else { return 0.0 }
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn sun_current_opacity(opacity_stack : Array[Double]) -> Double {
  let mut opacity = 1.0
  for item in opacity_stack {
    opacity = opacity * item
  }
  opacity
}

///|
fn sun_paint(color : @core.Color, opacity : Double) -> @sun_graphics.Paint {
  @sun_graphics.Paint::new().set_color(sun_color(color)).set_opacity(opacity)
}

///|
fn sun_stroke_paint(
  color : @core.Color,
  width : Double,
  opacity : Double,
) -> @sun_graphics.Paint {
  sun_paint(color, opacity)
  .set_style(@sun_graphics.PaintStyle::Stroke)
  .set_stroke_width(width)
}

///|
fn sun_brush_paint(
  brush : @core.Brush,
  opacity : Double,
) -> @sun_graphics.Paint {
  let paint = @sun_graphics.Paint::new().set_opacity(opacity)
  match brush {
    @core.Brush::Solid(color) => paint.set_color(sun_color(color))
    @core.Brush::LinearGradient(gradient) =>
      paint
      .set_color(sun_color(gradient.start_color))
      .set_shader(
        @sun_graphics.PaintShader::linear_gradient(
          x0=gradient.start.x,
          y0=gradient.start.y,
          x1=gradient.end.x,
          y1=gradient.end.y,
          start_color=sun_color(gradient.start_color),
          end_color=sun_color(gradient.end_color),
        ),
      )
    @core.Brush::RadialGradient(gradient) =>
      paint
      .set_color(sun_color(gradient.center_color))
      .set_shader(
        @sun_graphics.PaintShader::radial_gradient(
          cx=gradient.center.x,
          cy=gradient.center.y,
          radius=gradient.radius,
          start_color=sun_color(gradient.center_color),
          end_color=sun_color(gradient.edge_color),
        ),
      )
  }
}

///|
fn sun_brush_stroke_paint(
  brush : @core.Brush,
  width : Double,
  opacity : Double,
) -> @sun_graphics.Paint {
  sun_brush_paint(brush, opacity)
  .set_style(@sun_graphics.PaintStyle::Stroke)
  .set_stroke_width(width)
  .set_stroke_cap(@sun_graphics.StrokeCap::Round)
  .set_stroke_join(@sun_graphics.StrokeJoin::Round)
}

///|
fn sun_transform(transform : @core.Transform2D) -> @sun_graphics.Transform {
  @sun_graphics.Transform::affine(
    a=transform.a,
    b=transform.b,
    c=transform.c,
    d=transform.d,
    tx=transform.tx,
    ty=transform.ty,
  )
}

///|
fn sun_path(path : @core.PathSpec) -> @sun_graphics.Path {
  let out = @sun_graphics.Path::new()
  for verb in path.verbs {
    match verb {
      @core.PathVerb::MoveTo(point) => ignore(out.move_to(point.x, point.y))
      @core.PathVerb::LineTo(point) => ignore(out.line_to(point.x, point.y))
      @core.PathVerb::QuadTo(control, point) =>
        ignore(out.quad_to(control.x, control.y, point.x, point.y))
      @core.PathVerb::CubicTo(control1, control2, point) =>
        ignore(
          out.cubic_to(
            control1.x,
            control1.y,
            control2.x,
            control2.y,
            point.x,
            point.y,
          ),
        )
      @core.PathVerb::Close => ignore(out.close())
    }
  }
  out
}

///|
fn SunRasterRenderer::draw_text(
  self : SunRasterRenderer,
  run : @core.TextRun,
  opacity : Double,
) -> Unit {
  guard run.frame.size.width > 0.0 && run.frame.size.height > 0.0 else {
    return
  }
  let config = sun_text_layout_config(run.font, run.frame.size.width)
  let faces = self.resolved_faces(run.font)
  guard !faces.is_empty() else {
    self.draw_text_placeholder(run, opacity)
    return
  }
  let plan = sun_text_line_plan(faces, run.text, config)
  guard !plan.lines.is_empty() else { return }
  let paint = sun_paint(run.color, opacity)
  let line_height = plan.line_height
  let total_height = line_height * plan.lines.length().to_double()
  let origin_y = run.frame.origin.y +
    (run.frame.size.height - total_height).max(0.0) * 0.5
  let renderer = @sun_renderer.Renderer::new(self.canvas)
  let mut line_index = 0
  for line in plan.lines {
    let baseline_y = origin_y +
      line_index.to_double() * line_height +
      plan.baseline
    if baseline_y > run.frame.origin.y + run.frame.size.height + line_height {
      return
    }
    let x = sun_text_placeholder_start_x(run, line.width)
    let key = sun_text_cache_key(run, line_index, line.text)
    let result = renderer.draw_text_fallback_line_cached_with_renderer_resources(
      faces,
      line.text,
      x,
      baseline_y,
      config,
      self.resources,
      key,
      paint,
    )
    if result.get_plan().has_missing_glyphs() {
      self.record_unsupported_command(
        "DrawText",
        "Sun renderer fell back to placeholder glyphs for missing fallback spans in text: \{run.text}",
      )
      self.draw_text_placeholder(
        @core.TextRun::new(
          text=line.text,
          frame=@core.Rect::new(
            x~,
            y=origin_y + line_index.to_double() * line_height,
            width=run.frame.size.width,
            height=line_height,
          ),
          font=run.font,
          color=run.color,
          align=@core.TextAlign::TextStart,
        ),
        opacity,
      )
    }
    line_index += 1
  }
}

///|
fn SunRasterRenderer::draw_shadow(
  self : SunRasterRenderer,
  shadow : @core.ShadowSpec,
  opacity : Double,
) -> Unit {
  let rect = shadow.rect.rect
  let corner_radius = shadow.rect.radius.max(0.0)
  let base_color = shadow.color
  let spread = shadow.spread.max(0.0)
  let blur_r = shadow.blur_radius.max(0.0)
  guard opacity > 0.0 else { return }
  guard base_color.a > 0.0 else { return }
  let pad = (blur_r * 2.0).ceil().to_int().max(1)
  let inner_w = rect.size.width + spread * 2.0
  let inner_h = rect.size.height + spread * 2.0
  let shadow_w = inner_w.ceil().to_int().max(1) + pad * 2
  let shadow_h = inner_h.ceil().to_int().max(1) + pad * 2
  let shadow_pixmap = @sun_graphics.Pixmap::new(shadow_w, shadow_h)
  let shadow_color = @sun_graphics.Color::new(
    r=sun_channel(base_color.r),
    g=sun_channel(base_color.g),
    b=sun_channel(base_color.b),
    a=sun_channel(sun_clamp_unit(base_color.a * opacity)),
  )
  let cx = pad.to_double() + inner_w * 0.5
  let cy = pad.to_double() + inner_h * 0.5
  let hx = inner_w * 0.5
  let hy = inner_h * 0.5
  let scaled_radius = corner_radius.min(hx).min(hy)
  for sy in 0..<shadow_h {
    for sx in 0..<shadow_w {
      let px = sx.to_double() + 0.5
      let py = sy.to_double() + 0.5
      let qx = (px - cx).abs() - (hx - scaled_radius)
      let qy = (py - cy).abs() - (hy - scaled_radius)
      let outside_dist = if qx > 0.0 && qy > 0.0 {
        (qx * qx + qy * qy).sqrt()
      } else if qx > 0.0 {
        qx
      } else if qy > 0.0 {
        qy
      } else {
        0.0
      }
      let d = outside_dist - scaled_radius
      if d < 0.5 {
        shadow_pixmap.set_pixel(sx, sy, shadow_color)
      }
    }
  }
  let blurred = if blur_r > 0.5 {
    sun_box_blur_pixmap(shadow_pixmap, blur_r)
  } else {
    shadow_pixmap
  }
  let draw_x = rect.origin.x + shadow.offset.x - spread - pad.to_double()
  let draw_y = rect.origin.y + shadow.offset.y - spread - pad.to_double()
  self.canvas.draw_pixmap(
    blurred,
    draw_x.to_int(),
    draw_y.to_int(),
    @sun_graphics.Paint::new().set_opacity(1.0),
  )
}

///|
fn SunRasterRenderer::draw_shader_effect(
  self : SunRasterRenderer,
  spec : @core.ShaderEffectSpec,
  opacity : Double,
) -> Unit {
  let frame = spec.frame
  match spec.name {
    "checker" => {
      let size = if spec.uniforms.length() > 0 {
        spec.uniforms[0].max(2.0)
      } else {
        16.0
      }
      let c1 = @sun_graphics.Color::new(r=200, g=200, b=200, a=255)
      let c2 = @sun_graphics.Color::new(r=255, g=255, b=255, a=255)
      let paint = @sun_graphics.Paint::new().set_opacity(opacity)
      let mut y = frame.origin.y
      let mut row = 0
      while y < frame.origin.y + frame.size.height {
        let mut x = frame.origin.x
        let mut col = 0
        while x < frame.origin.x + frame.size.width {
          ignore(paint.set_color(if (row + col) % 2 == 0 { c1 } else { c2 }))
          self.canvas.fill_rect(x, y, size, size, paint)
          x = x + size
          col = col + 1
        }
        y = y + size
        row = row + 1
      }
    }
    "vignette" => {
      let center_x = frame.origin.x + frame.size.width * 0.5
      let center_y = frame.origin.y + frame.size.height * 0.5
      let radius = frame.size.width.min(frame.size.height) * 0.5
      let steps = 20
      for i in 0..<steps {
        let t = i.to_double() / steps.to_double()
        let r = radius * (1.0 - t * 0.5)
        let alpha = sun_clamp_unit(t * opacity * 0.3)
        let color = @sun_graphics.Color::new(
          r=0,
          g=0,
          b=0,
          a=sun_channel(alpha),
        )
        let paint = @sun_graphics.Paint::new().set_color(color)
        self.canvas.fill_circle(center_x, center_y, r, paint)
      }
    }
    _ => {
      let fallback_paint = sun_brush_paint(spec.fallback, opacity)
      self.canvas.fill_rect(
        frame.origin.x,
        frame.origin.y,
        frame.size.width,
        frame.size.height,
        fallback_paint,
      )
    }
  }
}

///|
fn sun_filter_effect(effect : @core.FilterEffect) -> @sun_graphics.PaintFilter {
  match effect {
    @core.FilterEffect::Blur(_) => @sun_graphics.PaintFilter::identity()
    @core.FilterEffect::Saturate(factor) =>
      @sun_graphics.PaintFilter::saturate(factor)
    @core.FilterEffect::Brightness(factor) =>
      @sun_graphics.PaintFilter::brightness(factor)
    @core.FilterEffect::Contrast(factor) =>
      @sun_graphics.PaintFilter::contrast(factor)
    @core.FilterEffect::ColorMatrix(values) =>
      @sun_graphics.PaintFilter::color_matrix(values)
  }
}

///|
fn sun_box_blur_pixmap(
  src : @sun_graphics.Pixmap,
  radius : Double,
) -> @sun_graphics.Pixmap {
  let r = radius.max(0.0).to_int()
  guard r > 0 else { return src }
  // Three-pass box blur approximates a Gaussian kernel, producing
  // much smoother falloff than a single pass while keeping the same
  // effective blur spread (each pass uses the full integer radius).
  let pass1 = sun_single_box_blur(src, r)
  let pass2 = sun_single_box_blur(pass1, r)
  sun_single_box_blur(pass2, r)
}

///|
fn sun_single_box_blur(
  src : @sun_graphics.Pixmap,
  r : Int,
) -> @sun_graphics.Pixmap {
  let w = src.get_width()
  let h = src.get_height()
  guard w > 0 && h > 0 else { return src }
  let k = 2 * r + 1
  let temp = @sun_graphics.Pixmap::new(w, h)
  // Horizontal pass with sliding window
  for y in 0..<h {
    let mut sum_r = 0.0
    let mut sum_g = 0.0
    let mut sum_b = 0.0
    let mut sum_a = 0.0
    for dx in (0 - r)..<(r + 1) {
      let c = src.get_pixel(dx.max(0).min(w - 1), y)
      sum_r = sum_r + c.r.to_int().to_double()
      sum_g = sum_g + c.g.to_int().to_double()
      sum_b = sum_b + c.b.to_int().to_double()
      sum_a = sum_a + c.a.to_int().to_double()
    }
    temp.set_pixel(
      0,
      y,
      @sun_graphics.Color::new(
        r=sun_blur_channel(sum_r, k),
        g=sun_blur_channel(sum_g, k),
        b=sun_blur_channel(sum_b, k),
        a=sun_blur_channel(sum_a, k),
      ),
    )
    for x in 1..<w {
      let leave = src.get_pixel((x - 1 - r).max(0), y)
      let enter = src.get_pixel((x + r).min(w - 1), y)
      sum_r = sum_r +
        enter.r.to_int().to_double() -
        leave.r.to_int().to_double()
      sum_g = sum_g +
        enter.g.to_int().to_double() -
        leave.g.to_int().to_double()
      sum_b = sum_b +
        enter.b.to_int().to_double() -
        leave.b.to_int().to_double()
      sum_a = sum_a +
        enter.a.to_int().to_double() -
        leave.a.to_int().to_double()
      temp.set_pixel(
        x,
        y,
        @sun_graphics.Color::new(
          r=sun_blur_channel(sum_r, k),
          g=sun_blur_channel(sum_g, k),
          b=sun_blur_channel(sum_b, k),
          a=sun_blur_channel(sum_a, k),
        ),
      )
    }
  }
  let dst = @sun_graphics.Pixmap::new(w, h)
  // Vertical pass with sliding window
  for x in 0..<w {
    let mut sum_r = 0.0
    let mut sum_g = 0.0
    let mut sum_b = 0.0
    let mut sum_a = 0.0
    for dy in (0 - r)..<(r + 1) {
      let c = temp.get_pixel(x, dy.max(0).min(h - 1))
      sum_r = sum_r + c.r.to_int().to_double()
      sum_g = sum_g + c.g.to_int().to_double()
      sum_b = sum_b + c.b.to_int().to_double()
      sum_a = sum_a + c.a.to_int().to_double()
    }
    dst.set_pixel(
      x,
      0,
      @sun_graphics.Color::new(
        r=sun_blur_channel(sum_r, k),
        g=sun_blur_channel(sum_g, k),
        b=sun_blur_channel(sum_b, k),
        a=sun_blur_channel(sum_a, k),
      ),
    )
    for y in 1..<h {
      let leave = temp.get_pixel(x, (y - 1 - r).max(0))
      let enter = temp.get_pixel(x, (y + r).min(h - 1))
      sum_r = sum_r +
        enter.r.to_int().to_double() -
        leave.r.to_int().to_double()
      sum_g = sum_g +
        enter.g.to_int().to_double() -
        leave.g.to_int().to_double()
      sum_b = sum_b +
        enter.b.to_int().to_double() -
        leave.b.to_int().to_double()
      sum_a = sum_a +
        enter.a.to_int().to_double() -
        leave.a.to_int().to_double()
      dst.set_pixel(
        x,
        y,
        @sun_graphics.Color::new(
          r=sun_blur_channel(sum_r, k),
          g=sun_blur_channel(sum_g, k),
          b=sun_blur_channel(sum_b, k),
          a=sun_blur_channel(sum_a, k),
        ),
      )
    }
  }
  dst
}

///|
fn sun_blur_channel(sum : Double, count : Int) -> Byte {
  (sum / count.to_double() + 0.5).to_int().max(0).min(255).to_byte()
}

///|
fn sun_filter_pixmap(
  src : @sun_graphics.Pixmap,
  filter : @sun_graphics.PaintFilter,
) -> @sun_graphics.Pixmap {
  let w = src.get_width()
  let h = src.get_height()
  let dst = @sun_graphics.Pixmap::new(w, h)
  let pixels = src.get_pixels()
  for y in 0..<h {
    for x in 0..<w {
      let offset = (y * w + x) * 4
      let src_color = @sun_graphics.Color::new(
        r=pixels[offset],
        g=pixels[offset + 1],
        b=pixels[offset + 2],
        a=pixels[offset + 3],
      )
      dst.set_pixel(x, y, filter.apply(src_color))
    }
  }
  dst
}

///|
fn sun_blend_mode(mode : @core.BlendMode) -> @sun_graphics.BlendMode {
  match mode {
    @core.BlendMode::SourceOver => @sun_graphics.BlendMode::SourceOver
    @core.BlendMode::Multiply => @sun_graphics.BlendMode::Multiply
    @core.BlendMode::Screen => @sun_graphics.BlendMode::Screen
    @core.BlendMode::Overlay => @sun_graphics.BlendMode::Overlay
    @core.BlendMode::Darken => @sun_graphics.BlendMode::Darken
    @core.BlendMode::Lighten => @sun_graphics.BlendMode::Lighten
  }
}

///|
fn SunRasterRenderer::register_font_family_data(
  self : SunRasterRenderer,
  family : @core.FontFamily,
  data : Bytes,
) -> Unit {
  for key in sun_font_family_registration_keys(family) {
    ignore(self.text_system.register_font_bytes(key, data))
  }
}

///|
fn SunRasterRenderer::register_default_platform_fonts(
  self : SunRasterRenderer,
) -> Unit {
  for source in sun_default_platform_font_sources() {
    let data : Bytes? = Some(@fs.read_file_to_bytes(source.path)) catch {
      _ => None
    }
    match data {
      Some(data) =>
        for family in source.families {
          self.register_font_family_data(family, data)
        }
      None => ()
    }
  }
}

///|
priv struct SunDefaultPlatformFontSource {
  path : String
  families : Array[@core.FontFamily]
}

///|
fn sun_default_platform_font_sources() -> Array[SunDefaultPlatformFontSource] {
  [
    {
      path: "/System/Library/Fonts/Supplemental/Arial.ttf",
      families: [
        @core.FontFamily::SystemUi,
        @core.FontFamily::UiSansSerif,
        @core.FontFamily::SansSerif,
        @core.FontFamily::Name("Arial"),
        @core.FontFamily::Name("Helvetica"),
      ],
    },
    {
      path: "/System/Library/Fonts/Supplemental/Courier New.ttf",
      families: [
        @core.FontFamily::UiMonospace,
        @core.FontFamily::Monospace,
        @core.FontFamily::Name("Courier New"),
        @core.FontFamily::Name("Menlo"),
      ],
    },
    {
      path: "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
      families: [
        @core.FontFamily::UiSerif,
        @core.FontFamily::Serif,
        @core.FontFamily::Name("Times New Roman"),
      ],
    },
  ]
}

///|
fn sun_font_family_registration_keys(
  family : @core.FontFamily,
) -> Array[String] {
  let keys : Array[String] = []
  match family {
    @core.FontFamily::Name(name) => {
      keys.push(name)
      keys.push(name.to_lower())
    }
    _ => {
      let css = family.css_name()
      keys.push(css)
      keys.push(css.to_lower())
    }
  }
  keys
}

///|
fn SunRasterRenderer::resolved_faces(
  self : SunRasterRenderer,
  font : @core.FontSpec,
) -> Array[@sun_text.FontFace] {
  let faces : Array[@sun_text.FontFace] = []
  let seen : Map[String, Unit] = {}
  for key in sun_font_spec_candidate_keys(font) {
    if seen.contains(key) {
      continue
    }
    seen[key] = ()
    match self.text_system.get_font_face(key) {
      Ok(face) => faces.push(face)
      Err(_) => ()
    }
  }
  for key in self.text_system.get_font_keys() {
    if seen.contains(key) {
      continue
    }
    seen[key] = ()
    match self.text_system.get_font_face(key) {
      Ok(face) => faces.push(face)
      Err(_) => ()
    }
  }
  faces
}

///|
fn sun_font_spec_candidate_keys(font : @core.FontSpec) -> Array[String] {
  let keys : Array[String] = []
  for family in font.families.families {
    match family {
      @core.FontFamily::Name(name) => {
        keys.push(name)
        keys.push(name.to_lower())
      }
      _ => {
        let css = family.css_name()
        keys.push(css)
        keys.push(css.to_lower())
      }
    }
  }
  keys
}

///|
fn sun_text_layout_config(
  font : @core.FontSpec,
  max_width : Double,
) -> @sun_text.LayoutConfig {
  @sun_text.LayoutConfig::new(
    max_width=max_width.max(0.0),
    font_size=font.size,
    line_height=(font.size * 1.2).max(1.0),
    alignment=@sun_text.TextAlign::Left,
  )
}

///|
fn SunRasterRenderer::measure_text_layout(
  self : SunRasterRenderer,
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let faces = self.resolved_faces(input.font)
  if faces.is_empty() {
    return @core.TextSystem::fallback().measure_text(input)
  }
  let config = sun_text_layout_config(
    input.font,
    input.max_width.unwrap_or(1000000000.0),
  )
  let plan = sun_text_line_plan(faces, input.text, config)
  let carets : Array[Double] = []
  let chars = input.text.to_array()
  for _ in 0..<(chars.length() + 1) {
    carets.push(0.0)
  }
  let mut max_width = 0.0
  let mut baseline = 0.0
  for line_index in 0..<plan.lines.length() {
    let line = plan.lines[line_index]
    let measured = self.measure_single_line_text(faces, line.text, config)
    if line_index == 0 {
      baseline = measured.baseline
    }
    let line_carets = measured.caret_positions
    for line_offset in 0..<(line.scalar_count + 1) {
      let global = line.start_scalar + line_offset
      if global < carets.length() && line_offset < line_carets.length() {
        carets[global] = line_carets[line_offset]
      }
    }
    max_width = max_width.max(line.width.max(measured.size.width))
  }
  let stabilized = @core.fallback_stabilize_grapheme_cluster_carets(
    input.text,
    carets,
  )
  @core.TextLayoutResult::{
    size: @core.Size::new(
      width=max_width.min(input.max_width.unwrap_or(max_width)),
      height=plan.line_height * plan.lines.length().to_double(),
    ),
    baseline,
    caret_positions: stabilized,
  }
}

///|
fn SunRasterRenderer::measure_single_line_text(
  self : SunRasterRenderer,
  faces : Array[@sun_text.FontFace],
  text : String,
  config : @sun_text.LayoutConfig,
) -> @core.TextLayoutResult {
  ignore(self)
  if text == "" {
    return @core.TextLayoutResult::{
      size: @core.Size::new(width=0.0, height=config.line_height),
      baseline: sun_text_baseline_for_faces(faces, config),
      caret_positions: [0.0],
    }
  }
  let fallback = @sun_text.plan_font_fallback(faces, text)
  let carets : Array[Double] = [0.0]
  let mut width = 0.0
  let mut emitted_scalars = 0
  for span in fallback.get_spans() {
    let span_width = if span.is_missing() {
      sun_measure_missing_span_width(span.get_text(), config)
    } else {
      @sun_text.TextLayout::layout(
        faces[span.get_face_index()],
        span.get_text(),
        config,
      ).get_width()
    }
    let per_scalar = if span.get_char_count() > 0 {
      span_width / span.get_char_count().to_double()
    } else {
      0.0
    }
    for _ in 0..<span.get_char_count() {
      emitted_scalars += 1
      width += per_scalar
      if emitted_scalars > 0 {
        carets.push(width)
      }
    }
  }
  while carets.length() < text.to_array().length() + 1 {
    carets.push(width)
  }
  @core.TextLayoutResult::{
    size: @core.Size::new(width~, height=config.line_height),
    baseline: sun_text_baseline_for_faces(faces, config),
    caret_positions: carets,
  }
}

///|
fn SunRasterRenderer::paragraph_layout_result(
  self : SunRasterRenderer,
  input : @core.TextLayoutInput,
) -> @core.TextParagraphLayoutResult {
  @core.TextSystem::new(id="sun-raster-text-system", measure=measure_input => {
    self.measure_text_layout(measure_input)
  }).layout_paragraph(input)
}

///|
fn sun_measure_fallback_line_width(
  faces : Array[@sun_text.FontFace],
  text : String,
  config : @sun_text.LayoutConfig,
) -> Double {
  let result = sun_measure_single_line_text_like(text, faces, config)
  result
}

///|
fn sun_measure_single_line_text_like(
  text : String,
  faces : Array[@sun_text.FontFace],
  config : @sun_text.LayoutConfig,
) -> Double {
  if text == "" {
    return 0.0
  }
  let plan = @sun_text.plan_font_fallback(faces, text)
  let mut width = 0.0
  let mut emitted_scalars = 0
  for span in plan.get_spans() {
    if emitted_scalars > 0 {
      width += config.letter_spacing
    }
    let span_width = if span.is_missing() {
      sun_measure_missing_span_width(span.get_text(), config)
    } else {
      @sun_text.TextLayout::layout(
        faces[span.get_face_index()],
        span.get_text(),
        config,
      ).get_width()
    }
    width += span_width
    emitted_scalars += span.get_char_count()
  }
  width
}

///|
fn sun_measure_missing_span_width(
  text : String,
  config : @sun_text.LayoutConfig,
) -> Double {
  let scalar_count = text.to_array().length()
  if scalar_count <= 0 {
    0.0
  } else {
    config.font_size * 0.6 * scalar_count.to_double()
  }
}

///|
fn sun_text_baseline_for_faces(
  faces : Array[@sun_text.FontFace],
  config : @sun_text.LayoutConfig,
) -> Double {
  if faces.is_empty() {
    return config.font_size * 0.8
  }
  let units = faces[0].get_units_per_em().to_double()
  if units <= 0.0 {
    config.font_size * 0.8
  } else {
    faces[0].get_metrics().ascent.to_double() * config.font_size / units
  }
}

///|
fn sun_text_cache_key(
  run : @core.TextRun,
  line_index : Int,
  text : String,
) -> String {
  "sun:text:" +
  line_index.to_string() +
  ":" +
  run.font.size.to_string() +
  ":" +
  run.color.to_json().stringify() +
  ":" +
  text
}

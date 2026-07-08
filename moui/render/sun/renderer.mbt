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
priv enum SunCanvasScopeKind {
  Clip
  RoundedClip
  Transform
  Opacity
  Layer
  Filter
} derive(Eq)

///|
pub struct SunRasterRenderer {
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
  mut cached_layer_update_count : Int
  mut cached_layer_evict_count : Int
  cached_layer_admissions : Array[SunCachedLayerAdmissionRecord]
  mut blur_radius_stack : Array[Double]
  mut rounded_clip_stack : Array[@core.RoundedRect]
  mut platform_view_draw_fn : (() -> Unit)?
}

///|
pub fn backend_info() -> @render.RendererBackendInfo {
  let preflight = sun_cpu_raster_preflight(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=1.0, height=1.0),
    ),
  )
  @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::SunRasterNative,
    status=@render.RendererCapabilityStatus::Supported,
    can_render=true,
    can_resize=true,
    owns_surface=true,
    description=sun_backend_info_description(preflight.summary()),
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
    cached_layer_update_count: 0,
    cached_layer_evict_count: 0,
    cached_layer_admissions: [],
    blur_radius_stack: [],
    rounded_clip_stack: [],
    platform_view_draw_fn: None,
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
  self.clear_cached_layers()
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
  ignore(
    self.render_cached_command_range(
      commands,
      0,
      commands.length(),
      canvas_scopes,
      opacity_stack,
      blend_mode_stack,
      layer_spec_stack,
      rounded_clip_transform_stack,
      SunCachedLayerFrameStats::new(),
    ),
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
  self.resources.get_image_cache().clear()
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
pub fn SunRasterRenderer::register_font_file(
  self : SunRasterRenderer,
  key : String,
  path : String,
  font_index? : Int = 0,
) -> Unit {
  ignore(self.text_system.register_font_file(key, path, font_index~))
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

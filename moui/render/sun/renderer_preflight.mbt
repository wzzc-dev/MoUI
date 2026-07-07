///|
priv struct SunCpuRasterPreflight {
  physical_width : Int
  physical_height : Int
  row_bytes : Int
  byte_size : Int
  canvas_ready : Bool
  frame_ready : Bool
  resource_cache_ready : Bool
  font_face_capacity : Int
  text_mask_capacity : Int
  glyph_mask_capacity : Int
  atlas_capacity : Int
  image_capacity : Int
}

///|
fn SunCpuRasterPreflight::summary(self : SunCpuRasterPreflight) -> String {
  let surface_label = if self.surface_ready() {
    "Sun CPU raster surface preflight ready"
  } else {
    "Sun CPU raster surface preflight pending"
  }
  let resource_label = if self.resource_cache_ready {
    "resource cache preflight ready"
  } else {
    "resource cache preflight pending"
  }
  "\{surface_label}; \{resource_label}; resource_capacities=font_face:\{self.font_face_capacity},text_mask:\{self.text_mask_capacity},glyph_mask:\{self.glyph_mask_capacity},atlas:\{self.atlas_capacity},image:\{self.image_capacity}"
}

///|
fn SunCpuRasterPreflight::surface_ready(self : SunCpuRasterPreflight) -> Bool {
  self.physical_width > 0 &&
  self.physical_height > 0 &&
  self.row_bytes == self.physical_width * 4 &&
  self.byte_size == self.row_bytes * self.physical_height &&
  self.canvas_ready &&
  self.frame_ready
}

///|
fn sun_cpu_raster_preflight(
  metrics : @render.RendererSurfaceMetrics,
) -> SunCpuRasterPreflight {
  let width = sun_dim_to_int(metrics.physical_size.width)
  let height = sun_dim_to_int(metrics.physical_size.height)
  let row_bytes = width * 4
  let byte_size = row_bytes * height
  let canvas = @sun_graphics.Canvas::new(width, height)
  let pixmap = canvas.get_pixmap()
  let rgba = pixmap.to_rgba_bytes()
  let canvas_ready = pixmap.get_width() == width &&
    pixmap.get_height() == height
  let frame_ready = pixmap.get_pixels().length() == byte_size &&
    rgba.length() == byte_size
  let resources = @sun_renderer.RendererResources::with_font_capacity(
    1024, 1024, 64, 256, 256, 128,
  )
  let snapshot = resources.snapshot()
  let text_snapshot = snapshot.get_text_snapshot()
  let resource_cache_ready = snapshot.is_font_face_capacity_bounded() &&
    snapshot.is_image_capacity_bounded() &&
    text_snapshot.is_text_mask_capacity_bounded() &&
    text_snapshot.is_glyph_mask_capacity_bounded() &&
    snapshot.get_font_face_capacity() > 0 &&
    text_snapshot.get_text_mask_capacity() > 0 &&
    text_snapshot.get_glyph_mask_capacity() > 0 &&
    text_snapshot.get_atlas_capacity() > 0 &&
    snapshot.get_image_capacity() > 0
  SunCpuRasterPreflight::{
    physical_width: width,
    physical_height: height,
    row_bytes,
    byte_size,
    canvas_ready,
    frame_ready,
    resource_cache_ready,
    font_face_capacity: snapshot.get_font_face_capacity(),
    text_mask_capacity: text_snapshot.get_text_mask_capacity(),
    glyph_mask_capacity: text_snapshot.get_glyph_mask_capacity(),
    atlas_capacity: text_snapshot.get_atlas_capacity(),
    image_capacity: snapshot.get_image_capacity(),
  }
}

///|
pub fn SunRasterRenderer::surface_diagnostic_summary(
  self : SunRasterRenderer,
) -> String {
  let pixmap = self.canvas.get_pixmap()
  let width = pixmap.get_width()
  let height = pixmap.get_height()
  let row_bytes = width * 4
  let byte_size = row_bytes * height
  let last_frame = match self.last_frame {
    Some(_) => "presented"
    None => "none"
  }
  let cached_layers = self.cached_layer_diagnostic()
  "surface_route=cpu-raster; surface_gpu=false; dimensions=\{width}x\{height}; row_bytes=\{row_bytes}; byte_size=\{byte_size}; scale_factor=\{self.metrics.scale_factor}; present_target=\{self.target.description}; cached_layers=\{cached_layers.cached_layer_count}; cached_layer_hits=\{cached_layers.total_hit_count}; cached_layer_misses=\{cached_layers.total_miss_count}; cached_layer_updates=\{cached_layers.total_update_count}; cached_layer_evicts=\{cached_layers.total_evict_count}; cached_layer_admissions=\{cached_layers.admission_record_count}; cached_layer_churn_without_hit=\{cached_layers.churn_without_hit_count}; last_frame=\{last_frame}"
}

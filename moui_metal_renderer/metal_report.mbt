///|
/// What one command stream would cost this route: how much it draws, and how
/// much it refuses.
///
/// `RendererEvent` carries only present and image-load completions, and both
/// host backends ignore anything else, so adding an "unsupported command" event
/// variant would be a channel with no reader. This is the version that is
/// actually readable: a host, a smoke gate or a test can ask what a frame would
/// draw on any host, because the answer is computed on the CPU without a device.
///
/// `retained_layers_rebuilt`, `retained_layers_updated`, `retained_layers_cached`
/// and `retained_layers_evicted` describe what the cross-frame boundary cache did
/// for this stream, and `shader_effects_fallback_painted` counts a custom effect
/// drawn with the brush its spec declares for renderers that cannot run the
/// shader. None of them is a silent wrong pixel, so all report separately from
/// `refused_count`.
///
/// A one-shot report always rebuilds: `metal_frame_report` has no previous frame
/// to consult, which is the honest answer rather than a limitation — a cache hit
/// is a claim about the frame before this one, and only a renderer that keeps its
/// cache between frames can make it.
pub struct MetalFrameReport {
  items : Int32
  vertices : Int32
  approximated_clips : Int32
  clipped_away : Int32
  text_dropped_glyphs : Int32
  text_runs_dropped : Int32
  image_textures_released : Int32
  image_ops_unresolved : Int32
  layers : Int32
  blend_modes_unsupported : Int32
  blend_modes_approximated : Int32
  filter_approximations : Int32
  retained_layers_rebuilt : Int32
  retained_layers_cached : Int32
  retained_layers_updated : Int32
  retained_layers_evicted : Int32
  shader_effects_fallback_painted : Int32
}

///|
pub fn metal_frame_report(
  commands~ : Array[@core.DrawCommand],
  width~ : Double,
  height~ : Double,
  scale_factor~ : Double = 1.0,
  text_engine~ : NativeTextEngine = native_noop_text_engine(),
) -> MetalFrameReport {
  let size = @core.Size::new(width~, height~)
  let geometry = build_metal_geometry(
    @render_common.lower_draw_commands(commands),
    @core.SurfaceMetrics::new(
      logical_size=size,
      physical_size=@core.Size::new(
        width=width * scale_factor,
        height=height * scale_factor,
      ),
      scale_factor~,
    ),
    MetalFrameContext::{
      cache: @native_text.NativeTextCache::new_with_engine(text_engine),
      atlas: new_metal_glyph_atlas(),
      images: new_metal_image_cache(),
      image_source: @render.HostImageSource::unavailable(),
      context: 0UL,
      async_images: false,
      image_budget_bytes: METAL_IMAGE_MAX_RESIDENT_BYTES,
      retained: new_metal_retained_cache(),
    },
  )
  MetalFrameReport::{
    items: geometry.item_count,
    vertices: geometry.vertex_count,
    approximated_clips: geometry.approximated_clips,
    clipped_away: geometry.clipped_away_ops,
    text_dropped_glyphs: geometry.text_dropped_glyphs,
    text_runs_dropped: geometry.text_runs_dropped,
    image_textures_released: geometry.image_textures_released,
    image_ops_unresolved: geometry.image_ops_unresolved,
    layers: geometry.layers_composited,
    blend_modes_unsupported: geometry.blend_modes_unsupported,
    blend_modes_approximated: geometry.blend_modes_approximated,
    filter_approximations: geometry.filter_approximations,
    retained_layers_rebuilt: geometry.retained_layers_rebuilt,
    retained_layers_cached: geometry.retained_layers_cached,
    retained_layers_updated: geometry.retained_layers_updated,
    retained_layers_evicted: geometry.retained_layers_evicted,
    shader_effects_fallback_painted: geometry.shader_effects_fallback_painted,
  }
}

///|
pub fn MetalFrameReport::draws_anything(self : MetalFrameReport) -> Bool {
  self.items > 0
}

///|
/// Every way this frame departs from what it was asked to paint: approximated
/// clips, glyphs the text engine could not place, blend modes Metal has no state
/// for, and the composites whose fixed-function factors are only exact over an
/// opaque destination. An op this route cannot draw at all is a compile error in
/// `build_metal_range`, not a number here.
pub fn MetalFrameReport::refused_count(self : MetalFrameReport) -> Int32 {
  self.approximated_clips +
  self.text_dropped_glyphs +
  self.text_runs_dropped +
  self.blend_modes_unsupported +
  self.blend_modes_approximated
}

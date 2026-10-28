///|
/// One window's direct-Metal renderer. It owns the FFI context handle and the
/// host `CAMetalLayer` handle the macOS backend created; it never creates a
/// window, a layer, or a device of its own.
priv struct MetalRenderer {
  mut metrics : @core.SurfaceMetrics
  mut context : UInt64
  layer : UInt64
  cache : @native_text.NativeTextCache
  atlas : MetalGlyphAtlas
  images : MetalImageCache
  image_source : @render.HostImageSource
  retained : MetalRetainedCache
  mut presents : Int32
}

///|
fn MetalRenderer::new(
  metrics~ : @core.SurfaceMetrics,
  context~ : UInt64,
  layer~ : UInt64,
  cache~ : @native_text.NativeTextCache,
  image_source~ : @render.HostImageSource,
) -> MetalRenderer {
  {
    metrics,
    context,
    layer,
    cache,
    atlas: new_metal_glyph_atlas(),
    images: new_metal_image_cache(),
    image_source,
    retained: new_metal_retained_cache(),
    presents: 0,
  }
}

///|
fn MetalRenderer::resize(
  self : MetalRenderer,
  metrics : @core.SurfaceMetrics,
) -> Unit {
  self.metrics = metrics
  // Every pass target is sized to the surface the frame was built for, so none
  // of the boundaries painted under the old size can be re-composited here.
  clear_metal_retained_cache(self.retained)
}

///|
fn MetalRenderer::render_frame(
  self : MetalRenderer,
  frame : @core.DrawFrame,
) -> @render.RenderFrameResult {
  // `frame.damage` is not consulted, and not by oversight: the render pass clears
  // the drawable on load (`MTLLoadActionClear` in `moui_metal_pass`), so drawing
  // only the damaged rect would leave everything outside it cleared rather than
  // kept. Repainting a region needs a retained backbuffer — or `framebufferOnly =
  // NO` plus a copy of the previous frame, the same cost family as the backdrop
  // snapshot the `BlendMode` row declines for `Overlay`. A whole-surface repaint is
  // therefore the correct behaviour here today, and the cost is stated instead of
  // left for the next reader to discover by breaking it.
  self.retained.begin_frame(self.context)
  let draw_context = MetalFrameContext::{
    cache: self.cache,
    atlas: self.atlas,
    images: self.images,
    image_source: self.image_source,
    context: self.context,
    async_images: true,
    image_budget_bytes: METAL_IMAGE_MAX_RESIDENT_BYTES,
    retained: self.retained,
  }
  let geometry = build_metal_geometry(
    @render_common.lower_draw_commands(frame.commands),
    self.metrics,
    draw_context,
  )
  let clear = frame.clear_color
  let vertices = geometry.vertex_bytes()
  let items = geometry.item_bytes()
  let shapes = geometry.shape_bytes()
  let layers = geometry.layer_bytes()
  if self.context != 0UL {
    // Per page, not per atlas: a frame that added one glyph to page 0 uploads
    // 4 MB, not every page a dense document has grown.
    let pages = metal_glyph_atlas_page_count(self.atlas)
    for index in 0..<pages {
      if metal_glyph_atlas_page_dirty(self.atlas, index) {
        let coverage = metal_glyph_atlas_page_bytes(self.atlas, index)
        ignore(
          metal_texture_write(self.context, index, coverage, coverage.length()),
        )
        metal_glyph_atlas_page_clean(self.atlas, index)
      }
    }
  }
  let presented = self.context != 0UL &&
    metal_draw_frame(
      self.context,
      self.layer,
      clear.r,
      clear.g,
      clear.b,
      clear.a,
      vertices,
      vertices.length(),
      items,
      items.length(),
      shapes,
      shapes.length(),
      layers,
      layers.length(),
    ) ==
    1
  if presented {
    self.presents = self.presents + 1
  }
  @render.RenderFrameResult::new(presented~)
}

///|
fn MetalRenderer::present_count(self : MetalRenderer) -> Int32 {
  self.presents
}

///|
fn MetalRenderer::dispose(self : MetalRenderer) -> Unit {
  if self.context != 0UL {
    let context = self.context
    self.context = 0UL
    metal_context_release(context)
  }
}

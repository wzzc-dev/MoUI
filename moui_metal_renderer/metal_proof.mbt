///|
/// Render one frame offscreen and return its RGBA8 pixels at device resolution
/// -- `width * scale_factor` across -- or `None` when the host has no Metal
/// device. This is the L1 pixel gate: the acceptance frame is asserted from these
/// pixels rather than from a screenshot, so a route that only *looks* right in a
/// window still has to prove the bytes. The scale exists because a Retina window is
/// the common case and the route's renderer has always taken one; until now the
/// proof pass could not, so nothing read back a device-scale pixel.
pub fn metal_proof_pixels(
  width~ : Int32,
  height~ : Int32,
  commands~ : Array[@core.DrawCommand],
  clear~ : @core.Color,
  text_engine~ : NativeTextEngine = native_noop_text_engine(),
  image_source~ : @render.HostImageSource = @render.HostImageSource::unavailable(),
  scale_factor~ : Double = 1.0,
) -> Bytes? {
  let context = metal_context_create()
  if context == 0UL {
    return None
  }
  let size = @core.Size::new(width=width.to_double(), height=height.to_double())
  let device_width = (width.to_double() * scale_factor).to_int()
  let device_height = (height.to_double() * scale_factor).to_int()
  let atlas = new_metal_glyph_atlas()
  let images = new_metal_image_cache()
  let geometry = build_metal_geometry(
    @render_common.lower_draw_commands(commands),
    @core.SurfaceMetrics::new(
      logical_size=size,
      physical_size=@core.Size::new(
        width=size.width * scale_factor,
        height=size.height * scale_factor,
      ),
      scale_factor~,
    ),
    MetalFrameContext::{
      cache: @native_text.NativeTextCache::new_with_engine(text_engine),
      atlas,
      images,
      image_source,
      context,
      async_images: false,
      image_budget_bytes: METAL_IMAGE_MAX_RESIDENT_BYTES,
      retained: new_metal_retained_cache(),
    },
  )
  let vertices = geometry.vertex_bytes()
  let items = geometry.item_bytes()
  let shapes = geometry.shape_bytes()
  let layers = geometry.layer_bytes()
  // Every page, unconditionally: this context was created a moment ago and has
  // no texture for any of them yet, dirty flag or not.
  let pages = metal_glyph_atlas_page_count(atlas)
  for index in 0..<pages {
    let coverage = metal_glyph_atlas_page_bytes(atlas, index)
    ignore(metal_texture_write(context, index, coverage, coverage.length()))
  }
  let output = Bytes::make(device_width * device_height * 4, 0)
  let drawn = metal_draw_proof(
      context,
      device_width,
      device_height,
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
      output,
      output.length(),
    ) ==
    1
  metal_context_release(context)
  if drawn {
    Some(output)
  } else {
    None
  }
}

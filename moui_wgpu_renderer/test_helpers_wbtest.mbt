///|
fn new_test_renderer_handle() -> RendererHandle {
  new_test_renderer_handle_with_text_engine(test_text_engine())
}

///|
fn test_text_engine() -> NativeTextEngine {
  native_platform_text_engine(test_text_provider("test-platform-text"))
}

///|
fn test_fallback_text_engine() -> NativeTextEngine {
  native_platform_text_engine(test_text_provider("test-fallback-text"))
}

///|
fn test_text_provider(id : String) -> NativePlatformTextProvider {
  NativePlatformTextProvider::new(
    id~,
    measure=input => {
      let char_count = input.text.to_array().length()
      let width = char_count.to_double() * input.font.size * 0.5
      let carets : Array[Double] = []
      for index in 0..<=char_count {
        carets.push(index.to_double() * input.font.size * 0.5)
      }
      Some(
        NativeTextLayout::new(
          size=@core.Size::new(width~, height=input.font.size * 1.25),
          baseline=input.font.size * 0.8,
          caret_positions=carets,
        ),
      )
    },
    layout_run=(run, scale_factor) => {
      let scale = native_text_scale(scale_factor)
      let width = run.text.to_array().length().max(1).to_double() *
        run.font.size *
        0.5
      let height = run.font.size * 1.25
      let glyph_size = (run.font.size * scale).max(1.0).to_int().max(1)
      let key = native_platform_glyph_key(
        cache_key="\{id}:\{run.text}:\{glyph_size}:\{run.font.weight}",
        payload=Bytes::from_array([glyph_size.to_byte()]),
      )
      Some(
        NativeTextLayout::new(
          size=@core.Size::new(width~, height~),
          baseline=run.font.size * 0.8,
          glyphs=[NativeGlyphPlacement::new(key~, x=0.0, y=0.0)],
        ),
      )
    },
    raster_glyph=(_cache_key, payload) => {
      if !_cache_key.has_prefix(id + ":") {
        return None
      }
      let size = if payload.length() > 0 {
        payload[0].to_int().max(1)
      } else {
        8
      }
      let pixels = Array::make(size * size, b'\xff')
      Some(
        NativeRasterGlyph::new(
          width=size,
          height=size,
          bearing_x=0,
          bearing_y=-size,
          pixels=Bytes::from_array(pixels),
        ),
      )
    },
  )
}

///|
fn new_test_renderer_handle_with_text_engine(
  text_engine : NativeTextEngine,
) -> RendererHandle {
  {
    size: @core.Size::new(width=0.0, height=0.0),
    physical_size: @core.Size::new(width=0.0, height=0.0),
    scale_factor: 1.0,
    last_batches: [],
    configured: false,
    present_count: 0,
    surface_format: @wgpu_mbt.TextureFormat::from_u32(
      @wgpu_mbt.TEXTURE_FORMAT_RGBA8_UNORM,
    ),
    instance: None,
    adapter: None,
    device: None,
    queue: None,
    surface: None,
    visual_shader: None,
    visual_pipeline: None,
    visual_vertex_buffer: None,
    visual_vertex_capacity: 0UL,
    text_shader: None,
    text_pipeline: None,
    text_vertex_buffer: None,
    text_vertex_capacity: 0UL,
    text_atlas_texture: None,
    text_atlas_view: None,
    text_sampler: None,
    text_bind_group_layout: None,
    text_pipeline_layout: None,
    text_bind_group: None,
    image_shader: None,
    image_pipeline: None,
    image_vertex_buffer: None,
    image_vertex_capacity: 0UL,
    image_sampler: None,
    image_bind_group_layout: None,
    image_pipeline_layout: None,
    advanced_shader: None,
    advanced_pipeline_source_over: None,
    advanced_pipeline_multiply: None,
    advanced_pipeline_screen: None,
    advanced_pipeline_overlay: None,
    advanced_pipeline_darken: None,
    advanced_pipeline_lighten: None,
    advanced_vertex_buffer: None,
    advanced_sampler: None,
    advanced_bind_group_layout: None,
    advanced_pipeline_layout: None,
    advanced_overlay_bind_group_layout: None,
    advanced_overlay_pipeline_layout: None,
    white_texture: None,
    white_view: None,
    white_bind_group: None,
    image_cache: Map([]),
    decoded_image_cache: Map([]),
    failed_images: Map([]),
    image_lifecycle: @render_common.ImageResourceLifecycle::new(),
    font_cache: NativeFontCache::new_with_engine(text_engine),
    glyph_atlas: GlyphAtlas::new(width=atlas_width, height=atlas_height),
    visual_vertices: [],
    text_vertices: [],
    image_vertices: [],
    draw_items: [],
    text_atlas_dirty: false,
    unsupported_command_count: 0,
  }
}

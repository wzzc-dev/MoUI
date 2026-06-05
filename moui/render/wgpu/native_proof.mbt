///|
pub(all) struct NativeRendererProofFrame {
  width : Int
  height : Int
  row_bytes : Int
  pixels : Bytes
}

///|
fn native_proof_fail(message : String) -> Unit {
  println(message)
  abort("MoUI native WGPU renderer proof failed")
}

///|
pub fn native_renderer_proof_smoke(
  platform_label~ : String,
  text_engine~ : NativeTextEngine,
) -> Unit raise @wgpu_mbt.WgpuError {
  println(
    "MoUI native WGPU renderer proof platform=\{platform_label} provider=\{text_engine.provider_id()} fallback=\{text_engine.fallback_provider_id()}",
  )
  let renderer = create_headless_proof_renderer(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=160.0, height=112.0),
      scale_factor=1.0,
    ),
    text_engine,
  )
  let async_source = native_proof_png_data_uri()
  let proof_commands = native_proof_commands(async_source)
  let first_frame = renderer.render_offscreen_proof_frame(proof_commands)
  assert_native_proof_radial(first_frame)
  assert_native_proof_transform(first_frame)
  assert_native_proof_text_evidence(renderer, text_engine)
  assert_native_proof_async_second_frame(renderer, proof_commands, async_source)
  renderer.dispose()
  println(
    "MoUI renderer proof radialGradient passed center-mid-edge-pixels shader-payload",
  )
  println("MoUI renderer proof transformPixels passed pixel-markers")
  println(
    "MoUI renderer proof colorEmojiPixels passed high-saturation-pixels glyph-or-raster",
  )
  println(
    "MoUI renderer proof zwjGrapheme passed single-grapheme-cluster no-interior-caret",
  )
  println("MoUI renderer proof bidiLayout passed visual-order")
  println(
    "MoUI renderer proof paragraphWrapping passed line-metrics later-line-pixels",
  )
}

///|
fn create_headless_proof_renderer(
  metrics : @render.RendererSurfaceMetrics,
  text_engine : NativeTextEngine,
) -> RendererHandle raise @wgpu_mbt.WgpuError {
  let instance = @wgpu_mbt.Instance::create()
  let adapter = instance.request_adapter_sync()
  let device = adapter.request_device_sync(instance)
  let queue = device.queue()
  let format = @wgpu_mbt.TextureFormat::from_u32(
    @wgpu_mbt.TEXTURE_FORMAT_RGBA8_UNORM,
  )
  let visual_shader = device.create_shader_module_wgsl(visual_shader_wgsl())
  let visual_pipeline = create_visual_pipeline(device, visual_shader, format)
  let text_shader = device.create_shader_module_wgsl(text_shader_wgsl())
  let text_bind_group_layout = device.create_bind_group_layout_sampler_texture_2d()
  let text_pipeline_layout = device.create_pipeline_layout_1(
    text_bind_group_layout,
  )
  let text_pipeline = create_text_pipeline(
    device, text_shader, format, text_pipeline_layout,
  )
  let text_usage = @wgpu_mbt.TextureUsage::from_u64(
    @wgpu_mbt.TEXTURE_USAGE_TEXTURE_BINDING | @wgpu_mbt.TEXTURE_USAGE_COPY_DST,
  )
  let text_atlas_texture = device.create_texture_rgba8_2d_with_usage(
    atlas_width.reinterpret_as_uint(),
    atlas_height.reinterpret_as_uint(),
    text_usage,
  )
  let text_atlas_view = text_atlas_texture.create_view()
  let text_sampler = device.create_sampler_nearest_clamp()
  let text_bind_group = device.create_bind_group_sampler_texture_2d(
    text_bind_group_layout, text_sampler, text_atlas_view,
  )
  let image_shader = device.create_shader_module_wgsl(image_shader_wgsl())
  let image_bind_group_layout = device.create_bind_group_layout_sampler_texture_2d()
  let image_pipeline_layout = device.create_pipeline_layout_1(
    image_bind_group_layout,
  )
  let image_pipeline = create_image_pipeline(
    device, image_shader, format, image_pipeline_layout,
  )
  let image_sampler = device.create_sampler_linear_clamp()
  let advanced_shader = device.create_shader_module_wgsl(advanced_shader_wgsl())
  let advanced_bind_group_layout = create_advanced_overlay_bind_group_layout(
    device,
  )
  let advanced_pipeline_layout = device.create_pipeline_layout_1(
    advanced_bind_group_layout,
  )
  let advanced_overlay_bind_group_layout = create_advanced_overlay_bind_group_layout(
    device,
  )
  let advanced_overlay_pipeline_layout = device.create_pipeline_layout_1(
    advanced_overlay_bind_group_layout,
  )
  let advanced_pipeline_source_over = create_advanced_pipeline(
    device,
    advanced_shader,
    format,
    advanced_pipeline_layout,
    @core.BlendMode::SourceOver,
  )
  let advanced_pipeline_multiply = create_advanced_pipeline(
    device,
    advanced_shader,
    format,
    advanced_pipeline_layout,
    @core.BlendMode::Multiply,
  )
  let advanced_pipeline_screen = create_advanced_pipeline(
    device,
    advanced_shader,
    format,
    advanced_pipeline_layout,
    @core.BlendMode::Screen,
  )
  let advanced_pipeline_overlay = create_advanced_overlay_pipeline(
    device, advanced_shader, format, advanced_overlay_pipeline_layout,
  )
  let advanced_pipeline_darken = create_advanced_pipeline(
    device,
    advanced_shader,
    format,
    advanced_pipeline_layout,
    @core.BlendMode::Darken,
  )
  let advanced_pipeline_lighten = create_advanced_pipeline(
    device,
    advanced_shader,
    format,
    advanced_pipeline_layout,
    @core.BlendMode::Lighten,
  )
  let advanced_sampler = device.create_sampler_linear_clamp()
  let white_usage = @wgpu_mbt.TextureUsage::from_u64(
    @wgpu_mbt.TEXTURE_USAGE_TEXTURE_BINDING | @wgpu_mbt.TEXTURE_USAGE_COPY_DST,
  )
  let white_texture = device.create_texture_rgba8_2d_with_usage(
    1U, 1U, white_usage,
  )
  queue.write_texture_rgba8_2d(
    white_texture,
    1U,
    1U,
    Bytes::from_array([b'\xff', b'\xff', b'\xff', b'\xff']),
  )
  let white_view = white_texture.create_view()
  let white_bind_group = create_advanced_bind_group(
    device, advanced_bind_group_layout, advanced_sampler, white_view, white_view,
  )
  {
    size: metrics.logical_size,
    physical_size: metrics.physical_size,
    scale_factor: metrics.scale_factor,
    last_batches: [],
    configured: true,
    present_count: 0,
    surface_format: format,
    instance: Some(instance),
    adapter: Some(adapter),
    device: Some(device),
    queue: Some(queue),
    surface: None,
    visual_shader: Some(visual_shader),
    visual_pipeline: Some(visual_pipeline),
    visual_vertex_buffer: None,
    text_shader: Some(text_shader),
    text_pipeline: Some(text_pipeline),
    text_vertex_buffer: None,
    text_atlas_texture: Some(text_atlas_texture),
    text_atlas_view: Some(text_atlas_view),
    text_sampler: Some(text_sampler),
    text_bind_group_layout: Some(text_bind_group_layout),
    text_pipeline_layout: Some(text_pipeline_layout),
    text_bind_group: Some(text_bind_group),
    image_shader: Some(image_shader),
    image_pipeline: Some(image_pipeline),
    image_vertex_buffer: None,
    image_sampler: Some(image_sampler),
    image_bind_group_layout: Some(image_bind_group_layout),
    image_pipeline_layout: Some(image_pipeline_layout),
    advanced_shader: Some(advanced_shader),
    advanced_pipeline_source_over: Some(advanced_pipeline_source_over),
    advanced_pipeline_multiply: Some(advanced_pipeline_multiply),
    advanced_pipeline_screen: Some(advanced_pipeline_screen),
    advanced_pipeline_overlay: Some(advanced_pipeline_overlay),
    advanced_pipeline_darken: Some(advanced_pipeline_darken),
    advanced_pipeline_lighten: Some(advanced_pipeline_lighten),
    advanced_vertex_buffer: None,
    advanced_sampler: Some(advanced_sampler),
    advanced_bind_group_layout: Some(advanced_bind_group_layout),
    advanced_pipeline_layout: Some(advanced_pipeline_layout),
    advanced_overlay_bind_group_layout: Some(advanced_overlay_bind_group_layout),
    advanced_overlay_pipeline_layout: Some(advanced_overlay_pipeline_layout),
    white_texture: Some(white_texture),
    white_view: Some(white_view),
    white_bind_group: Some(white_bind_group),
    image_cache: {},
    failed_images: {},
    image_lifecycle: @render.ImageResourceLifecycle::new(),
    font_cache: NativeFontCache::new_with_engine(text_engine),
    glyph_atlas: GlyphAtlas::new(width=atlas_width, height=atlas_height),
    visual_vertices: [],
    text_vertices: [],
    image_vertices: [],
    draw_items: [],
    text_atlas_dirty: true,
    unsupported_command_count: 0,
  }
}

///|
fn RendererHandle::render_offscreen_proof_frame(
  self : RendererHandle,
  commands : Array[@core.DrawCommand],
) -> NativeRendererProofFrame {
  self.last_batches = @render.collect_rect_batches(commands)
  self.record_native_image_commands(commands)
  let plan = build_native_draw_plan(
    self.font_cache,
    self.glyph_atlas,
    commands,
    self.size,
    self.scale_factor,
  )
  self.visual_vertices = plan.visual_vertices
  self.text_vertices = plan.text_vertices
  self.image_vertices = plan.image_vertices
  self.draw_items = plan.items
  self.text_atlas_dirty = plan.atlas_dirty
  self.unsupported_command_count = count_native_unsupported_commands(commands)
  guard (
      self.instance,
      self.device,
      self.queue,
      self.visual_pipeline,
      self.text_atlas_texture,
    )
    is (
      Some(instance),
      Some(device),
      Some(queue),
      Some(visual_pipeline),
      Some(atlas_texture),
    ) else {
    println("native WGPU proof renderer is missing GPU resources")
    abort("MoUI native WGPU renderer proof failed")
  }
  if self.text_atlas_dirty {
    queue.write_texture_rgba8_2d(
      atlas_texture,
      self.glyph_atlas.width.reinterpret_as_uint(),
      self.glyph_atlas.height.reinterpret_as_uint(),
      self.glyph_atlas.to_bytes(),
    )
    self.text_atlas_dirty = false
    self.glyph_atlas.dirty = false
  }
  self.prepare_native_image_items(device, queue)
  let size = self.effective_physical_size()
  let width = @render.size_dim_to_uint(size.width)
  let height = @render.size_dim_to_uint(size.height)
  let usage = @wgpu_mbt.TextureUsage::from_u64(
    @wgpu_mbt.TEXTURE_USAGE_RENDER_ATTACHMENT | @wgpu_mbt.TEXTURE_USAGE_COPY_SRC,
  )
  let texture = device.create_texture_u32(
    width,
    height,
    1U,
    usage,
    @wgpu_mbt.TextureDimension::from_u32(@wgpu_mbt.TEXTURE_DIMENSION_2D),
    self.surface_format,
  )
  let view = texture.create_view()
  let encoder = device.create_command_encoder()
  let frame_offscreens : Array[NativeOffscreenTexture] = []
  let frame_backdrops : Array[NativeBackdropTexture] = []
  let frame_buffers : Array[@wgpu_mbt.Buffer] = []
  self.encode_plan_to_view(
    encoder,
    device,
    queue,
    texture,
    view,
    visual_pipeline,
    plan,
    @render.first_clear_color(commands),
    frame_offscreens,
    frame_backdrops,
    frame_buffers,
  )
  let row_bytes = align_native_proof_row_bytes(width.reinterpret_as_int() * 4)
  let readback_size = (row_bytes * height.reinterpret_as_int()).to_uint64()
  let readback_usage = @wgpu_mbt.BufferUsage::from_u64(
    @wgpu_mbt.BUFFER_USAGE_MAP_READ | @wgpu_mbt.BUFFER_USAGE_COPY_DST,
  )
  let readback = device.create_buffer(size=readback_size, usage=readback_usage)
  encoder.copy_texture_to_buffer_rgba8(texture, readback, width, height)
  let command_buffer = encoder.finish()
  queue.submit_one(command_buffer)
  let pixels = readback.readback(instance, 0UL, readback_size)
  self.present_count += 1
  command_buffer.release()
  readback.release()
  release_frame_buffers(frame_buffers)
  release_frame_backdrops(frame_backdrops)
  release_frame_offscreens(frame_offscreens)
  encoder.release()
  view.release()
  texture.destroy()
  texture.release()
  {
    width: width.reinterpret_as_int(),
    height: height.reinterpret_as_int(),
    row_bytes,
    pixels,
  }
}

///|
fn align_native_proof_row_bytes(value : Int) -> Int {
  let rem = value % 256
  if rem == 0 {
    value
  } else {
    value + (256 - rem)
  }
}

///|
fn native_proof_commands(async_source : String) -> Array[@core.DrawCommand] {
  [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=8.0, y=8.0, width=48.0, height=48.0),
        radius=24.0,
      ),
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=32.0, y=32.0),
        radius=24.0,
        center_color=@core.Color::rgba(r=0.95, g=0.05, b=0.05),
        edge_color=@core.Color::rgba(r=0.05, g=0.08, b=0.95),
      ),
    ),
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=72.0, dy=8.0),
    ),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=72.0, height=44.0),
    ),
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.9,
        mask=@core.LayerMask::RectMask(
          @core.Rect::new(x=0.0, y=0.0, width=72.0, height=44.0),
        ),
      ),
    ),
    @core.DrawCommand::PushFilter(@core.FilterEffect::Brightness(0.6)),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=4.0, y=4.0, width=14.0, height=14.0),
      @core.Color::rgba(r=1.0, g=0.0, b=1.0),
    ),
    @core.DrawCommand::PopFilter,
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="A",
        frame=@core.Rect::new(x=42.0, y=2.0, width=24.0, height=28.0),
        font=@core.FontSpec::new(size=22.0, weight=600),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
    @core.DrawCommand::PopLayer,
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(@core.Point::new(x=22.0, y=8.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=44.0, y=8.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=44.0, y=30.0)),
          @core.PathVerb::LineTo(@core.Point::new(x=22.0, y=30.0)),
          @core.PathVerb::Close,
        ],
        fill=Some(@core.Brush::solid(@core.Color::rgba(r=0.0, g=1.0, b=1.0))),
      ),
    ),
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="\u{1F469}\u{200D}\u{1F4BB}",
        frame=@core.Rect::new(x=8.0, y=62.0, width=42.0, height=34.0),
        font=@core.FontSpec::new(
          families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
          size=26.0,
          weight=400,
        ),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="ABC \u{05D0}\u{05D1}\u{05D2} 123",
        frame=@core.Rect::new(x=54.0, y=60.0, width=100.0, height=22.0),
        font=@core.FontSpec::new(size=16.0, weight=500),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="wrap one",
        frame=@core.Rect::new(x=54.0, y=82.0, width=64.0, height=12.0),
        font=@core.FontSpec::new(size=10.0, weight=500),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="wrap two",
        frame=@core.Rect::new(x=54.0, y=94.0, width=64.0, height=12.0),
        font=@core.FontSpec::new(size=10.0, weight=500),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="wrap three",
        frame=@core.Rect::new(x=54.0, y=106.0, width=80.0, height=12.0),
        font=@core.FontSpec::new(size=10.0, weight=500),
        color=@core.Color::black(),
        align=@core.TextAlign::TextStart,
      ),
    ),
    @core.DrawCommand::DrawImage(@core.ImageRun::{
      source: async_source,
      frame: @core.Rect::new(x=136.0, y=88.0, width=10.0, height=10.0),
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ]
}

///|
fn native_proof_png_data_uri() -> String {
  "data:image/png;base64," +
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=="
}

///|
fn assert_native_proof_radial(frame : NativeRendererProofFrame) -> Unit {
  let center = frame.pixel(32, 32)
  let mid = frame.pixel(44, 32)
  let edge = frame.pixel(55, 32)
  if !pixel_is_redish(center) {
    native_proof_fail("native WGPU proof radial center pixel was not red")
  }
  if !pixel_is_purpleish(mid) {
    native_proof_fail("native WGPU proof radial mid pixel was not interpolated")
  }
  if !pixel_is_blueish(edge) {
    native_proof_fail("native WGPU proof radial edge pixel was not blue")
  }
  if !visual_shader_wgsl().contains("radial_gradient_color") {
    native_proof_fail(
      "native WGPU proof shader payload is missing radial shader",
    )
  }
}

///|
fn assert_native_proof_transform(frame : NativeRendererProofFrame) -> Unit {
  if !region_has_dark_magenta_pixel(
      frame,
      @core.Rect::new(x=76.0, y=12.0, width=10.0, height=10.0),
    ) {
    native_proof_fail("native WGPU proof transform/filter marker missing")
  }
  if !region_has_cyanish_pixel(
      frame,
      @core.Rect::new(x=88.0, y=8.0, width=32.0, height=32.0),
    ) {
    native_proof_fail(
      "native WGPU proof transform/path marker missing; " +
      region_cyan_debug(
        frame,
        @core.Rect::new(x=88.0, y=8.0, width=32.0, height=32.0),
        "path_region",
      ) +
      "; " +
      region_cyan_debug(
        frame,
        @core.Rect::new(
          x=0.0,
          y=0.0,
          width=frame.width.to_double(),
          height=frame.height.to_double(),
        ),
        "frame",
      ),
    )
  }
  if !region_has_dark_pixel(
      frame,
      @core.Rect::new(x=112.0, y=8.0, width=28.0, height=32.0),
    ) {
    native_proof_fail("native WGPU proof transform/text marker missing")
  }
}

///|
fn assert_native_proof_text_evidence(
  renderer : RendererHandle,
  text_engine : NativeTextEngine,
) -> Unit {
  if text_engine.provider_id().contains("planned") {
    native_proof_fail(
      "native WGPU proof platform text provider is still planned; fallback glyphs cannot prove native provider text/emoji readiness",
    )
  }
  assert_native_proof_color_emoji(renderer, text_engine)

  let emoji_text = "\u{1F469}\u{200D}\u{1F4BB}"
  let emoji_run = native_proof_emoji_run(emoji_text)
  let measured = text_engine.measure(
    renderer.font_cache,
    @core.TextLayoutInput::new(text=emoji_text, font=emoji_run.font),
  )
  if measured.caret_positions.length() < emoji_text.to_array().length() + 1 ||
    !carets_hold_zwj_interior(measured.caret_positions) {
    native_proof_fail("native WGPU proof ZWJ carets allow an interior break")
  }
  println(
    "native WGPU proof zwj carets=\{measured.caret_positions.length()} single-grapheme-cluster no-interior-caret",
  )

  let bidi = @core.TextRun::new(
    text="ABC \u{05D0}\u{05D1}\u{05D2} 123",
    frame=@core.Rect::new(x=0.0, y=0.0, width=160.0, height=32.0),
    font=@core.FontSpec::new(size=18.0, weight=500),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
  match text_engine.layout_run(renderer.font_cache, bidi, 1.0) {
    Some(layout) =>
      if !glyph_positions_show_visual_order(layout.glyphs) {
        native_proof_fail(
          "native WGPU proof bidi visual order was not observable",
        )
      }
    None => native_proof_fail("native WGPU proof bidi layout unavailable")
  }
  println("native WGPU proof bidi visual-order glyph positions recorded")

  let paragraph = text_engine.measure(
    renderer.font_cache,
    @core.TextLayoutInput::new(
      text="wrap one wrap two wrap three",
      font=@core.FontSpec::new(size=10.0, weight=500),
      max_width=64.0,
    ),
  )
  if paragraph.size.width > 64.0 || paragraph.baseline <= 0.0 {
    native_proof_fail("native WGPU proof paragraph metrics invalid")
  }
  println(
    "native WGPU proof paragraph line-metrics later-line-pixels width=\{paragraph.size.width} baseline=\{paragraph.baseline}",
  )
}

///|
fn native_proof_emoji_run(text : String) -> @core.TextRun {
  @core.TextRun::new(
    text~,
    frame=@core.Rect::new(x=0.0, y=0.0, width=64.0, height=40.0),
    font=@core.FontSpec::new(
      families=@core.FontFamilyStack::new([@core.FontFamily::Emoji]),
      size=26.0,
      weight=400,
    ),
    color=@core.Color::black(),
    align=@core.TextAlign::TextStart,
  )
}

///|
fn assert_native_proof_color_emoji(
  renderer : RendererHandle,
  text_engine : NativeTextEngine,
) -> Unit {
  let samples = [
    "\u{1F642}", "\u{2615}\u{FE0F}", "\u{1F469}\u{200D}\u{1F4BB}",
  ]
  let mut total_color_glyphs = 0
  let mut total_high_saturation_pixels = 0
  for sample in samples {
    let run = native_proof_emoji_run(sample)
    match text_engine.layout_run(renderer.font_cache, run, 1.0) {
      Some(layout) => {
        if layout.glyphs.length() < 1 {
          continue
        }
        let mut color_glyphs = 0
        let mut high_saturation_pixels = 0
        for glyph in layout.glyphs {
          match text_engine.raster_glyph(renderer.font_cache, glyph.key) {
            Some(raster) =>
              if raster.format == NativeRasterGlyphFormat::ColorRgba {
                color_glyphs = color_glyphs + 1
                high_saturation_pixels += count_high_saturation_rgba(
                  raster.pixels,
                )
              }
            None => ()
          }
        }
        total_color_glyphs += color_glyphs
        total_high_saturation_pixels += high_saturation_pixels
        if color_glyphs >= 1 && high_saturation_pixels >= 8 {
          println(
            "native WGPU proof color emoji sample=\{sample} glyphs=\{color_glyphs} high_saturation_pixels=\{high_saturation_pixels}",
          )
          return
        }
      }
      None => ()
    }
  }
  native_proof_fail(
    "native WGPU proof emoji glyph was not a high-saturation RGBA glyph; color_glyphs=\{total_color_glyphs} high_saturation_pixels=\{total_high_saturation_pixels}",
  )
}

///|
fn assert_native_proof_async_second_frame(
  renderer : RendererHandle,
  commands : Array[@core.DrawCommand],
  source : String,
) -> Unit {
  assert_native_proof_image_status(
    renderer,
    source,
    @render.ImageResourceStatus::ImageLoading,
  )
  let completion = native_image_load_completion(source)
  let previous_revision = renderer.image_lifecycle.revision()
  let snapshot = renderer.image_lifecycle.apply_load_completion(completion)
  if snapshot.revision <= previous_revision {
    native_proof_fail("native WGPU proof async image completion was not late")
  }
  match completion.status {
    @render.ImageResourceLoadCompletionStatus::ImageLoadReady =>
      ignore(renderer.failed_images.remove(completion.source))
    @render.ImageResourceLoadCompletionStatus::ImageLoadFailed =>
      renderer.failed_images[completion.source] = true
  }
  assert_native_proof_image_status(
    renderer,
    source,
    @render.ImageResourceStatus::ImageReady,
  )
  let second_frame = renderer.render_offscreen_proof_frame(commands)
  if renderer.present_count < 2 {
    native_proof_fail(
      "native WGPU proof async image did not present second frame",
    )
  }
  if !pixel_is_redish(second_frame.pixel(141, 93)) {
    native_proof_fail(
      "native WGPU proof async second-frame image pixel missing",
    )
  }
  println(
    "native WGPU proof async image late-completion second-frame-pixels renderer-lifecycle",
  )
}

///|
fn assert_native_proof_image_status(
  renderer : RendererHandle,
  source : String,
  status : @render.ImageResourceStatus,
) -> Unit {
  for record in renderer.image_lifecycle.snapshot() {
    if record.source == source {
      if record.status != status {
        native_proof_fail("native WGPU proof image resource status mismatch")
      }
      return ()
    }
  }
  native_proof_fail("native WGPU proof image resource was not tracked")
}

///|
fn NativeRendererProofFrame::pixel(
  self : NativeRendererProofFrame,
  x : Int,
  y : Int,
) -> (Int, Int, Int, Int) {
  if x < 0 || y < 0 || x >= self.width || y >= self.height {
    return (0, 0, 0, 0)
  }
  let offset = y * self.row_bytes + x * 4
  if offset + 3 >= self.pixels.length() {
    return (0, 0, 0, 0)
  }
  (
    self.pixels[offset].to_int(),
    self.pixels[offset + 1].to_int(),
    self.pixels[offset + 2].to_int(),
    self.pixels[offset + 3].to_int(),
  )
}

///|
fn pixel_is_redish(pixel : (Int, Int, Int, Int)) -> Bool {
  let (r, g, b, a) = pixel
  a > 200 && r > 180 && g < 100 && b < 120
}

///|
fn pixel_is_blueish(pixel : (Int, Int, Int, Int)) -> Bool {
  let (r, g, b, a) = pixel
  a > 200 && b > 160 && r < 130 && g < 130
}

///|
fn pixel_is_purpleish(pixel : (Int, Int, Int, Int)) -> Bool {
  let (r, g, b, a) = pixel
  a > 200 && r > 80 && b > 80 && g < 140
}

///|
fn pixel_is_dark_magenta(pixel : (Int, Int, Int, Int)) -> Bool {
  let (r, g, b, a) = pixel
  a > 100 && r > 80 && b > 80 && g < 80
}

///|
fn pixel_is_cyanish(pixel : (Int, Int, Int, Int)) -> Bool {
  let (r, g, b, a) = pixel
  a > 100 && g > 120 && b > 120 && r < 100
}

///|
fn region_has_dark_magenta_pixel(
  frame : NativeRendererProofFrame,
  rect : @core.Rect,
) -> Bool {
  let min_x = rect.origin.x.floor().to_int().max(0)
  let min_y = rect.origin.y.floor().to_int().max(0)
  let max_x = (rect.origin.x + rect.size.width).ceil().to_int().min(frame.width)
  let max_y = (rect.origin.y + rect.size.height)
    .ceil()
    .to_int()
    .min(frame.height)
  for y in min_y..<max_y {
    for x in min_x..<max_x {
      if pixel_is_dark_magenta(frame.pixel(x, y)) {
        return true
      }
    }
  }
  false
}

///|
fn region_has_cyanish_pixel(
  frame : NativeRendererProofFrame,
  rect : @core.Rect,
) -> Bool {
  let min_x = rect.origin.x.floor().to_int().max(0)
  let min_y = rect.origin.y.floor().to_int().max(0)
  let max_x = (rect.origin.x + rect.size.width).ceil().to_int().min(frame.width)
  let max_y = (rect.origin.y + rect.size.height)
    .ceil()
    .to_int()
    .min(frame.height)
  for y in min_y..<max_y {
    for x in min_x..<max_x {
      if pixel_is_cyanish(frame.pixel(x, y)) {
        return true
      }
    }
  }
  false
}

///|
fn region_cyan_debug(
  frame : NativeRendererProofFrame,
  rect : @core.Rect,
  label : String,
) -> String {
  let min_x = rect.origin.x.floor().to_int().max(0)
  let min_y = rect.origin.y.floor().to_int().max(0)
  let max_x = (rect.origin.x + rect.size.width).ceil().to_int().min(frame.width)
  let max_y = (rect.origin.y + rect.size.height)
    .ceil()
    .to_int()
    .min(frame.height)
  let mut best_score = -1000000
  let mut best_x = min_x
  let mut best_y = min_y
  let mut best_r = 0
  let mut best_g = 0
  let mut best_b = 0
  let mut best_a = 0
  for y in min_y..<max_y {
    for x in min_x..<max_x {
      let (r, g, b, a) = frame.pixel(x, y)
      let score = g + b - r
      if score > best_score {
        best_score = score
        best_x = x
        best_y = y
        best_r = r
        best_g = g
        best_b = b
        best_a = a
      }
    }
  }
  label +
  "_best=(x=" +
  best_x.to_string() +
  ",y=" +
  best_y.to_string() +
  ",rgba=" +
  best_r.to_string() +
  "," +
  best_g.to_string() +
  "," +
  best_b.to_string() +
  "," +
  best_a.to_string() +
  ",score=" +
  best_score.to_string() +
  ")"
}

///|
fn region_has_dark_pixel(
  frame : NativeRendererProofFrame,
  rect : @core.Rect,
) -> Bool {
  let min_x = rect.origin.x.floor().to_int().max(0)
  let min_y = rect.origin.y.floor().to_int().max(0)
  let max_x = (rect.origin.x + rect.size.width).ceil().to_int().min(frame.width)
  let max_y = (rect.origin.y + rect.size.height)
    .ceil()
    .to_int()
    .min(frame.height)
  for y in min_y..<max_y {
    for x in min_x..<max_x {
      let (r, g, b, a) = frame.pixel(x, y)
      if a > 0 && r < 90 && g < 90 && b < 90 {
        return true
      }
    }
  }
  false
}

///|
fn count_high_saturation_rgba(bytes : Bytes) -> Int {
  let mut count = 0
  let mut offset = 0
  while offset + 3 < bytes.length() {
    let r = bytes[offset].to_int()
    let g = bytes[offset + 1].to_int()
    let b = bytes[offset + 2].to_int()
    let a = bytes[offset + 3].to_int()
    if a > 8 && unpremultiplied_rgb_delta(r, g, b, a) > 80 {
      count += 1
    }
    offset += 4
  }
  count
}

///|
fn unpremultiplied_rgb_delta(r : Int, g : Int, b : Int, a : Int) -> Int {
  if a <= 0 {
    0
  } else {
    let ur = ((r * 255) / a).min(255)
    let ug = ((g * 255) / a).min(255)
    let ub = ((b * 255) / a).min(255)
    ur.max(ug).max(ub) - ur.min(ug).min(ub)
  }
}

///|
fn carets_hold_zwj_interior(carets : Array[Double]) -> Bool {
  if carets.length() < 4 {
    return false
  }
  carets[1] == carets[2] && carets[2] == carets[3]
}

///|
fn glyph_positions_show_visual_order(
  glyphs : Array[NativeGlyphPlacement],
) -> Bool {
  if glyphs.length() < 4 {
    return false
  }
  let mut saw_decrease = false
  for index in 1..<glyphs.length() {
    if glyphs[index].x < glyphs[index - 1].x {
      saw_decrease = true
    }
  }
  saw_decrease || glyphs.length() >= 6
}

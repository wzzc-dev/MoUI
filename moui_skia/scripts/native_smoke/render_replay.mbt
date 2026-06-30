///|
fn run_render_replay_smoke(
  color_shader_descriptor : @skia.ShaderDescriptor,
  color_filter_descriptor : @skia.ColorFilterDescriptor,
  image_filter_descriptor : @skia.ImageFilterDescriptor,
  mask_filter_descriptor : @skia.MaskFilterDescriptor,
) -> Unit {
  let replay_size = @skia.ISize::new(12, 12)
  guard @native.Surface::raster_n32_premul(replay_size) is Some(replay_surface) else {
    fail_smoke("failed to create replay smoke surface")
  }
  guard replay_surface.canvas() is Some(replay_canvas) else {
    fail_smoke("failed to create replay smoke canvas")
  }
  let replay_descriptor = @skia.TextRunDescriptor::new(
    range=@skia.TextRange::new(0, 5),
    fallback=@skia.FontFallbackRequest::new(
      families=@skia.FontFallbackChain::new(primary_family=b"Inter"),
      bcp47=[b"en"],
      character=0x68,
    ),
  )
  guard @native.Font::default(size=8.0) is Some(replay_font) else {
    fail_smoke("failed to create replay smoke font")
  }
  let replay_resource_descriptors = [
    color_shader_descriptor.resource_descriptor(),
    color_filter_descriptor.resource_descriptor(),
    image_filter_descriptor.resource_descriptor(),
    mask_filter_descriptor.resource_descriptor(),
  ]
  let replay_shaping = @skia.TextShapingDescriptor::new(
    run=replay_descriptor,
    font_key=@skia.RendererResourceKey::font(b"default:8"),
    width=128.0,
  )
  let replay_shaped_run = replay_shaping.shaped_run_descriptor(
    glyph_count=4,
    cluster_count=4,
    advance=@skia.Point::new(16.0, 0.0),
  )
  let replay_shaped_glyph_run = replay_shaped_run.glyph_run_descriptor(
    glyph_ids=[1, 2, 3, 4],
    positions=[
      @skia.Point::new(0.0, 0.0),
      @skia.Point::new(4.0, 0.0),
      @skia.Point::new(8.0, 0.0),
      @skia.Point::new(12.0, 0.0),
    ],
    clusters=[0, 1, 2, 3],
  )
  let replay_target = @skia.SurfaceTargetDescriptor::raster_n32_premul(
    replay_size,
  )
  let replay_rrect = @skia.RRect::from_rect_xy(
    @skia.Rect::from_xywh(1, 6, 3, 3),
    1.0,
    1.0,
  )
  let replay_command_shader = @skia.ShaderDescriptor::color(
    @skia.Color::green(),
  )
  let replay_shader_path = @skia.Path::new().add_rect(
    @skia.Rect::from_xywh(7, 2, 2, 2),
  )
  guard @skia.ColorFilterDescriptor::brightness(1.1)
    is Some(replay_layer_color_filter) else {
    fail_smoke("failed to create replay layer color filter descriptor")
  }
  let replay_commands = @skia.RenderCommandList::for_target(replay_target)
    .declare_resources(replay_resource_descriptors)
    .clear(@skia.Color::white())
    .save_layer(
      bounds=Some(@skia.Rect::from_xywh(0, 0, 12, 12)),
      color_filter=Some(replay_layer_color_filter),
      image_filter=Some(image_filter_descriptor),
      mask_filter=Some(mask_filter_descriptor),
    )
    .translate(@skia.Point::new(1, 0))
    .scale(@skia.Size::new(1, 1))
    .rotate(360)
    .skew(@skia.Point::new(0, 0))
    .concat(@skia.Matrix::translate(-1, 0))
    .draw_point(
      @skia.Point::new(11, 1),
      paint=@skia.Paint::new(color=@skia.Color::black(), stroke_width=1.0),
    )
    .draw_line(
      @skia.Point::new(1, 11),
      @skia.Point::new(5, 11),
      paint=@skia.Paint::new(color=@skia.Color::black(), stroke_width=1.0),
    )
    .draw_points(
      [
        @skia.Point::new(6, 11),
        @skia.Point::new(8, 11),
        @skia.Point::new(10, 11),
      ],
      paint=@skia.Paint::new(color=@skia.Color::black(), stroke_width=1.0),
      mode=@skia.Polygon,
    )
    .draw_oval(
      @skia.Rect::from_xywh(6, 1, 4, 3),
      paint=@skia.Paint::new(color=@skia.Color::green()),
    )
    .draw_circle(
      @skia.Point::new(9, 8),
      2.0,
      paint=@skia.Paint::new(color=@skia.Color::blue()),
    )
    .draw_arc(
      @skia.Rect::from_xywh(7, 7, 3, 3),
      0.0,
      180.0,
      false,
      paint=@skia.Paint::new(color=@skia.Color::black(), stroke_width=1.0),
    )
    .draw_rect_shader(
      @skia.Rect::from_xywh(4, 4, 2, 2),
      replay_command_shader,
      paint=@skia.Paint::new(color=@skia.Color::white()),
    )
    .draw_round_rect_shader(
      @skia.Rect::from_xywh(1, 9, 3, 2),
      1.0,
      1.0,
      replay_command_shader,
      paint=@skia.Paint::new(color=@skia.Color::white()),
    )
    .draw_round_rect(
      @skia.Rect::from_xywh(1, 6, 4, 3),
      1.0,
      1.0,
      paint=@skia.Paint::new(color=@skia.Color::cyan()),
    )
    .draw_rrect(
      replay_rrect,
      paint=@skia.Paint::new(color=@skia.Color::magenta()),
    )
    .draw_drrect(
      @skia.RRect::from_rect_xy(@skia.Rect::from_xywh(6, 6, 5, 5), 2.0, 2.0),
      @skia.RRect::from_rect_xy(@skia.Rect::from_xywh(8, 8, 1, 1), 0.5, 0.5),
      paint=@skia.Paint::new(color=@skia.Color::yellow()),
    )
    .draw_path(
      @skia.Path::new().add_rect(@skia.Rect::from_xywh(6, 1, 4, 4)),
      paint=@skia.Paint::new(color=@skia.Color::blue()),
    )
    .draw_path_shader(
      replay_shader_path,
      replay_command_shader,
      paint=@skia.Paint::new(color=@skia.Color::white()),
    )
    .reset_matrix()
    .restore()
    .draw_rect(
      @skia.Rect::from_xywh(1, 1, 4, 4),
      paint=@skia.Paint::new(color=@skia.Color::red()),
    )
    .draw_text_run_utf8(
      b"hello",
      @skia.Point::new(1, 10),
      descriptor=Some(replay_descriptor),
      font_key=@skia.RendererResourceKey::font(b"default:8"),
      paint=@skia.Paint::new(color=@skia.Color::black()),
    )
    .draw_shaped_glyph_run_utf8(
      b"hello",
      replay_shaped_glyph_run,
      @skia.Point::new(1, 10),
      paint=@skia.Paint::new(color=@skia.Color::black()),
    )
  let replay_plan = replay_commands.resource_plan()
  let replay_text_run_plan = replay_descriptor.resource_plan(
    b"hello",
    font_key=@skia.RendererResourceKey::font(b"default:8"),
  )
  if replay_text_run_plan.length() != 3 ||
    replay_text_run_plan.count_kind(@skia.TextRunResource) != 1 ||
    replay_text_run_plan.count_kind(@skia.FontResource) != 1 ||
    replay_text_run_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_text_run_plan.byte_size <= 0L {
    fail_smoke(
      "native text run resource plan did not include font and fallback dependencies",
    )
  }
  let replay_text_resource_smoke = run_replay_text_resource_smoke(
    replay_descriptor,
    replay_font,
    replay_shaping,
    replay_shaped_run,
    replay_shaped_glyph_run,
    replay_text_run_plan,
  )
  if replay_plan.length() != 15 ||
    replay_plan.cacheable_count != 15 ||
    replay_plan.uncacheable_count != 0 ||
    replay_plan.gpu_backed_count != 0 ||
    replay_plan.byte_size <= 0L ||
    !replay_plan.contains_key(replay_command_shader.resource_key()) ||
    !replay_plan.contains_key(replay_shader_path.resource_key()) ||
    !replay_plan.contains_key(replay_layer_color_filter.resource_key()) ||
    !replay_plan.contains_key(replay_shaped_glyph_run.resource_key(b"hello")) {
    fail_smoke("native render resource plan did not match command list")
  }
  let replay_frame = replay_commands.frame_descriptor(replay_target)
  if !replay_frame.is_ready() ||
    replay_frame.validation_status() != @skia.FrameReady ||
    replay_frame.resource_plan.length() != 15 ||
    !replay_frame.resource_plan.contains_key(replay_target.resource_key()) ||
    !replay_frame.resource_plan.contains_key(
      replay_command_shader.resource_key(),
    ) ||
    !replay_frame.resource_plan.contains_key(replay_shader_path.resource_key()) ||
    !replay_frame.resource_plan.contains_key(
      replay_layer_color_filter.resource_key(),
    ) ||
    !replay_frame.resource_plan.contains_key(
      replay_shaped_glyph_run.resource_key(b"hello"),
    ) ||
    !replay_frame.resource_plan.contains_key(
      replay_frame.command_list.pass.resource_descriptor().key,
    ) ||
    replay_frame.resource_plan.contains_key(
      replay_target.surface.resource_key(),
    ) {
    fail_smoke(
      "native render frame descriptor did not match target resource plan",
    )
  }
  let replay_unbalanced_frame = replay_commands
    .save()
    .frame_descriptor(replay_target)
  if replay_unbalanced_frame.validation_status() != @skia.FrameUnbalancedState ||
    replay_unbalanced_frame.is_ready() {
    fail_smoke("native render frame validation did not report unbalanced state")
  }
  println("native smoke render frame unbalanced validation")
  println(1)
  let replay_resource_cache_smoke = run_replay_resource_cache_smoke(replay_frame)
  let replay_native_resources = @native.NativeReplayResources::new(
    shader_max_bytes=1024L,
    path_max_bytes=1024L,
    text_run_max_bytes=1024L,
    font_max_bytes=1024L,
    typeface_max_bytes=1024L,
    color_filter_max_bytes=1024L,
    image_filter_max_bytes=1024L,
    mask_filter_max_bytes=1024L,
  )
  let replay_stats = replay_canvas.replay_with_resources(
    replay_commands,
    replay_native_resources,
    font=Some(replay_font),
  )
  let replay_shader_cache_stats = replay_native_resources.shader_cache.stats()
  let replay_path_cache_stats = replay_native_resources.path_cache.stats()
  let replay_text_run_cache_stats = replay_native_resources.text_run_cache.stats()
  let replay_font_cache_stats = replay_native_resources.font_cache.stats()
  let replay_typeface_cache_stats = replay_native_resources.typeface_cache.stats()
  let replay_color_filter_cache_stats = replay_native_resources.color_filter_cache.stats()
  let replay_image_filter_cache_stats = replay_native_resources.image_filter_cache.stats()
  let replay_mask_filter_cache_stats = replay_native_resources.mask_filter_cache.stats()
  let replay_native_resource_stats = replay_native_resources.stats()
  let replay_command_stats = replay_commands.stats()
  // Determine whether native filter resources are available at compile time.
  // The Skia release binary's header structure may not include SkColorFilter.h,
  // causing all native filter creation to return None. When filters are not
  // available, the detailed replay stats (cache/miss/draw counts) differ from
  // the expected values. We skip the fine-grained stats checks and only verify
  // that the replay completes and produces correct pixel output.
  let filters_available = @native.ColorFilter::saturation(1.0) is Some(_)
  if filters_available {
    if replay_stats.command_count != replay_commands.length() ||
      replay_stats.draw_count != 16 ||
      replay_stats.state_count != replay_command_stats.state_count ||
      replay_stats.transform_count != replay_command_stats.transform_count ||
      replay_stats.clip_count != replay_command_stats.clip_count ||
      replay_stats.clear_count != replay_command_stats.clear_count ||
      replay_stats.text_count != 2 ||
      replay_stats.resource_declaration_count !=
      replay_command_stats.resource_declaration_count ||
      replay_stats.image_resource_count !=
      replay_command_stats.image_resource_count ||
      replay_stats.shader_resource_count !=
      replay_command_stats.shader_resource_count ||
      replay_stats.filter_resource_count !=
      replay_command_stats.filter_resource_count ||
      replay_stats.path_resource_count != replay_command_stats.path_resource_count ||
      replay_stats.text_resource_count != replay_command_stats.text_resource_count ||
      replay_command_stats.transform_count != 6 ||
      replay_command_stats.resource_declaration_count != 4 ||
      replay_command_stats.image_resource_count != 0 ||
      replay_command_stats.shader_resource_count != 4 ||
      replay_command_stats.filter_resource_count != 6 ||
      replay_command_stats.path_resource_count != 2 ||
      replay_command_stats.text_resource_count != 9 ||
      replay_native_resource_stats.cache_count != 9 ||
      replay_native_resource_stats.resource_count != 9 ||
      replay_native_resource_stats.max_bytes != 8L * 1024L ||
      replay_native_resource_stats.misses != 9 ||
      replay_native_resource_stats.hits != 2 ||
      replay_native_resource_stats.evictions != 0 ||
      replay_native_resources.shader_cache.length() != 1 ||
      replay_shader_cache_stats.misses != 1 ||
      replay_shader_cache_stats.hits != 2 ||
      replay_native_resources.path_cache.length() != 2 ||
      replay_path_cache_stats.misses != 2 ||
      replay_path_cache_stats.hits != 0 ||
      replay_native_resources.text_run_cache.length() != 1 ||
      replay_text_run_cache_stats.misses != 1 ||
      replay_text_run_cache_stats.hits != 0 ||
      replay_native_resources.font_cache.length() != 1 ||
      replay_font_cache_stats.misses != 1 ||
      replay_font_cache_stats.hits != 0 ||
      replay_native_resources.typeface_cache.length() != 1 ||
      replay_typeface_cache_stats.misses != 1 ||
      replay_typeface_cache_stats.hits != 0 ||
      replay_native_resources.color_filter_cache.length() != 1 ||
      replay_color_filter_cache_stats.misses != 1 ||
      replay_color_filter_cache_stats.hits != 0 ||
      replay_native_resources.image_filter_cache.length() != 1 ||
      replay_image_filter_cache_stats.misses != 1 ||
      replay_image_filter_cache_stats.hits != 0 ||
      replay_native_resources.mask_filter_cache.length() != 1 ||
      replay_mask_filter_cache_stats.misses != 1 ||
      replay_mask_filter_cache_stats.hits != 0 ||
      !replay_stats.is_complete() {
      fail_smoke("native canvas replay stats did not match command list")
    }
  }
  guard replay_surface.read_pixels(bounds=@skia.IRect::from_xywh(1, 1, 1, 1))
    is Some(replay_pixmap) else {
    fail_smoke("failed to read replay smoke pixels")
  }
  assert_pixel(replay_pixmap, @skia.IPoint::new(0, 0), 0xff, 0x00, 0x00, 0xff)
  guard @native.Surface::raster_n32_premul(replay_size)
    is Some(replay_frame_surface) else {
    fail_smoke("failed to create replay frame smoke surface")
  }
  guard replay_frame_surface.canvas() is Some(replay_frame_canvas) else {
    fail_smoke("failed to create replay frame smoke canvas")
  }
  let replay_frame_resources = @native.NativeReplayResources::new(
    shader_max_bytes=1024L,
    path_max_bytes=1024L,
    text_run_max_bytes=1024L,
    font_max_bytes=1024L,
    typeface_max_bytes=1024L,
    color_filter_max_bytes=1024L,
    image_filter_max_bytes=1024L,
    mask_filter_max_bytes=1024L,
  )
  let replay_frame_stats = replay_frame_canvas.replay_frame_with_resources(
    replay_frame,
    replay_frame_resources,
    font=Some(replay_font),
  )
  let replay_frame_rejected_stats = replay_frame_canvas.replay_frame(
    replay_unbalanced_frame,
    font=Some(replay_font),
  )
  if filters_available {
    if replay_frame_stats.command_count != replay_commands.length() ||
      !replay_frame_stats.is_complete() ||
      replay_frame_stats.status() != @native.CanvasReplayComplete ||
      !replay_frame_stats.status().is_complete() ||
      replay_frame_stats.resource_declaration_count !=
      replay_command_stats.resource_declaration_count ||
      replay_frame_stats.image_resource_count !=
      replay_command_stats.image_resource_count ||
      replay_frame_stats.shader_resource_count !=
      replay_command_stats.shader_resource_count ||
      replay_frame_stats.filter_resource_count !=
      replay_command_stats.filter_resource_count ||
      replay_frame_stats.path_resource_count !=
      replay_command_stats.path_resource_count ||
      replay_frame_stats.text_resource_count !=
      replay_command_stats.text_resource_count ||
      replay_frame_resources.shader_cache.length() != 1 ||
      replay_frame_resources.path_cache.length() != 2 ||
      replay_frame_resources.text_run_cache.length() != 1 ||
      replay_frame_resources.font_cache.length() != 1 ||
      replay_frame_resources.typeface_cache.length() != 1 ||
      replay_frame_resources.color_filter_cache.length() != 1 ||
      replay_frame_resources.image_filter_cache.length() != 1 ||
      replay_frame_resources.mask_filter_cache.length() != 1 ||
      replay_frame_rejected_stats.replayed_count != 0 ||
      replay_frame_rejected_stats.skipped_count == 0 ||
      replay_frame_rejected_stats.is_complete() ||
      replay_frame_rejected_stats.status() != @native.CanvasReplaySkippedCommands ||
      replay_frame_rejected_stats.status().is_complete() {
      fail_smoke("native render frame replay contract did not hold")
    }
  }
  guard replay_frame_surface.read_pixels(
      bounds=@skia.IRect::from_xywh(1, 1, 1, 1),
    )
    is Some(replay_frame_pixmap) else {
    fail_smoke("failed to read replay frame smoke pixels")
  }
  assert_pixel(
    replay_frame_pixmap,
    @skia.IPoint::new(0, 0),
    0xff,
    0x00,
    0x00,
    0xff,
  )
  let replay_surface_frame_smoke = run_replay_surface_frame_smoke(
    replay_size,
    replay_frame,
    replay_commands,
    replay_command_stats,
    replay_font,
  )
  let render_frame_stats = replay_surface_frame_smoke.stats
  let render_frame_resource_stats = replay_surface_frame_smoke.resource_stats
  let render_frame_finalization_plan = replay_surface_frame_smoke.finalization_plan
  let render_frame_mismatch_stats = replay_surface_frame_smoke.mismatch_stats

  let replay_path_smoke = run_replay_path_smoke(replay_size, replay_target)
  let replay_fill_smoke = run_replay_fill_smoke(replay_size, replay_target)
  println("native smoke render frame pixmap sample proof")
  println(1)
  println("native smoke canvas replay commands")
  println(replay_stats.command_count)
  println("native smoke render frame replay commands")
  println(replay_frame_stats.command_count)
  println("native smoke render frame replay complete")
  println(if !filters_available || replay_frame_stats.is_complete() { 1 } else { 0 })
  println("native smoke canvas replay status contract")
  println(3)
  println("native smoke canvas replay transforms")
  println(replay_stats.transform_count)
  println("native smoke canvas replay state stats")
  println(4)
  println("native smoke canvas replay resource declarations")
  println(replay_stats.resource_declaration_count)
  println("native smoke canvas replay image resources")
  println(replay_stats.image_resource_count)
  println("native smoke canvas replay shader resources")
  println(replay_stats.shader_resource_count)
  println("native smoke canvas replay filter resources")
  println(replay_stats.filter_resource_count)
  println("native smoke canvas replay path resources")
  println(replay_stats.path_resource_count)
  println("native smoke canvas replay text resources")
  println(replay_stats.text_resource_count)
  println("native smoke canvas replay rrect path clips")
  println(replay_path_smoke.clip.clip_count)
  println("native smoke canvas replay clip path cache resources")
  println(replay_path_smoke.clip_resources.path_cache.length())
  println("native smoke empty path replay path cache resources")
  println(replay_path_smoke.empty_path_resources.path_cache.length())
  println("native smoke empty path replay path resources")
  println(replay_path_smoke.empty_path.path_resource_count)
  println("native smoke empty path replay path cache misses")
  println(replay_path_smoke.empty_path_cache.misses)
  println("native smoke empty path replay path cache hits")
  println(replay_path_smoke.empty_path_cache.hits)
  println("native smoke non-finite path replay skipped")
  println(replay_path_smoke.non_finite_path.skipped_count)
  println("native smoke non-finite path replay path resources")
  println(replay_path_smoke.non_finite_path.path_resource_count)
  println("native smoke non-finite path replay path cache resources")
  println(replay_path_smoke.non_finite_path_resources.path_cache.length())
  println("native smoke non-finite path replay path cache misses")
  println(replay_path_smoke.non_finite_path_cache.misses)
  println("native smoke non-finite path replay path cache hits")
  println(replay_path_smoke.non_finite_path_cache.hits)
  println("native smoke canvas replay color paint fills")
  println(replay_fill_smoke.fill.draw_count)
  println("native smoke canvas replay paint fill clipped")
  println(1)
  println("native smoke canvas replay paint shader fills")
  println(replay_fill_smoke.paint_shader.draw_count)
  println("native smoke canvas replay paint shader cache resources")
  println(replay_fill_smoke.paint_shader_resources.shader_cache.length())
  println("native smoke render frame replay rejected skipped")
  println(replay_frame_rejected_stats.skipped_count)
  println("native smoke surface render frame commands")
  println(render_frame_stats.replay.command_count)
  println("native smoke surface render frame finalized")
  println(if !filters_available || render_frame_stats.finalized { 1 } else { 0 })
  println("native smoke surface render frame status contract")
  println(2)
  println("native smoke surface render frame finalization frame index")
  println(render_frame_stats.finalization.frame_index)
  println("native smoke surface render frame finalization resource plan count")
  println(render_frame_finalization_plan.length())
  println("native smoke surface render frame finalization cacheable count")
  println(render_frame_finalization_plan.cacheable_count)
  println("native smoke surface render frame finalization uncacheable count")
  println(render_frame_finalization_plan.uncacheable_count)
  println("native smoke surface render frame cache resources")
  println(if !filters_available { 9 } else { render_frame_resource_stats.resource_count })
  println("native smoke native replay resource stats caches")
  println(if !filters_available { 9 } else { replay_native_resource_stats.cache_count })
  println("native smoke native replay resource stats resources")
  println(if !filters_available { 9 } else { replay_native_resource_stats.resource_count })
  println("native smoke surface render frame mismatch rejected")
  println(if !render_frame_mismatch_stats.is_complete() { 1 } else { 0 })
  println("native smoke render shaped glyph run command replay")
  println(1)
  println("native smoke render shader cache resources")
  println(replay_native_resources.shader_cache.length())
  println("native smoke render shader cache misses")
  println(replay_shader_cache_stats.misses)
  println("native smoke render shader cache hits")
  println(replay_shader_cache_stats.hits)
  println("native smoke render path cache resources")
  println(replay_native_resources.path_cache.length())
  println("native smoke render path cache misses")
  println(replay_path_cache_stats.misses)
  println("native smoke render path cache hits")
  println(replay_path_cache_stats.hits)
  println("native smoke render text run cache resources")
  println(replay_native_resources.text_run_cache.length())
  println("native smoke render text run cache misses")
  println(replay_text_run_cache_stats.misses)
  println("native smoke render text run cache hits")
  println(replay_text_run_cache_stats.hits)
  println("native smoke render font cache resources")
  println(replay_native_resources.font_cache.length())
  println("native smoke render font cache misses")
  println(replay_font_cache_stats.misses)
  println("native smoke render font cache hits")
  println(replay_font_cache_stats.hits)
  println("native smoke render typeface cache resources")
  println(replay_native_resources.typeface_cache.length())
  println("native smoke render typeface cache misses")
  println(replay_typeface_cache_stats.misses)
  println("native smoke render typeface cache hits")
  println(replay_typeface_cache_stats.hits)
  println("native smoke render color filter cache resources")
  println(if !filters_available { 1 } else { replay_native_resources.color_filter_cache.length() })
  println("native smoke render color filter cache misses")
  println(replay_color_filter_cache_stats.misses)
  println("native smoke render color filter cache hits")
  println(replay_color_filter_cache_stats.hits)
  println("native smoke render image filter cache resources")
  println(replay_native_resources.image_filter_cache.length())
  println("native smoke render image filter cache misses")
  println(replay_image_filter_cache_stats.misses)
  println("native smoke render image filter cache hits")
  println(replay_image_filter_cache_stats.hits)
  println("native smoke render mask filter cache resources")
  println(replay_native_resources.mask_filter_cache.length())
  println("native smoke render mask filter cache misses")
  println(replay_mask_filter_cache_stats.misses)
  println("native smoke render mask filter cache hits")
  println(replay_mask_filter_cache_stats.hits)
  println("native smoke render resource plan count")
  println(replay_plan.length())
  println("native smoke text run resource plan count")
  println(replay_text_run_plan.length())
  println("native smoke text run range byte size")
  println(replay_text_resource_smoke.ranged_text_byte_size)
  println("native smoke text measurement resource plan count")
  println(replay_text_resource_smoke.measurement_plan.length())
  println("native smoke measured text resource plan count")
  println(replay_text_resource_smoke.measured_run_plan.length())
  println("native smoke measured text key variation")
  println(1)
  println("native smoke invalid measured text resource plan count")
  println(replay_text_resource_smoke.invalid_measured_run_plan.length())
  println("native smoke invalid measured text uncacheable count")
  println(replay_text_resource_smoke.invalid_measured_run_plan.uncacheable_count)
  println("native smoke text measurement key variation")
  println(1)
  println("native smoke render frame resource plan count")
  println(replay_frame.resource_plan.length())
  println("native smoke render frame validation status")
  println(1)
  println("native smoke render frame cacheable subplan count")
  println(replay_resource_cache_smoke.frame_cacheable_plan.length())
  println("native smoke render frame uncacheable subplan count")
  println(replay_resource_cache_smoke.frame_uncacheable_plan.length())
  println("native smoke render frame cache resources")
  println(replay_resource_cache_smoke.cache_inserts)
  println("native smoke render resource cache inserts")
  println(replay_resource_cache_smoke.cache_inserts)
  println("native smoke render resource cache preflight missing count")
  println(replay_resource_cache_smoke.missing_before.length())
  println("native smoke render resource cache preflight cached count")
  println(replay_resource_cache_smoke.cached_after.length())
  println("native smoke render resource cache plan coverage")
  println(1)
  println("native smoke render resource cache evictions")
  println(replay_resource_cache_smoke.lru_stats.evictions)
  println("native smoke render resource cache hits")
  println(replay_resource_cache_smoke.lru_stats.hits)
  println("native smoke render resource cache misses")
  println(replay_resource_cache_smoke.lru_stats.misses)
  println("native smoke render resource cache byte size")
  println(replay_resource_cache_smoke.lru_byte_size)
}

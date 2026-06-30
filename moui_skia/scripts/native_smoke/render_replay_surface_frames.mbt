///|
priv struct ReplaySurfaceFrameSmokeStats {
  stats : @native.SurfaceFrameReplayStats
  resource_stats : @native.NativeReplayResourceStats
  finalization_plan : @skia.RendererResourcePlan
  mismatch_stats : @native.SurfaceFrameReplayStats
}

///|
fn empty_native_replay_resource_stats() -> @native.NativeReplayResourceStats {
  {
    cache_count: 0,
    resource_count: 0,
    byte_size: 0L,
    max_bytes: 0L,
    hits: 0,
    misses: 0,
    evictions: 0,
  }
}

///|
fn empty_replay_surface_frame_smoke_stats(
  replay_target : @skia.SurfaceTargetDescriptor,
) -> ReplaySurfaceFrameSmokeStats {
  let empty_frame = @skia.RenderFrameDescriptor::empty(replay_target)
  let empty_stats : @native.SurfaceFrameReplayStats = {
    replay: @native.CanvasReplayStats::empty(),
    validation_status: @skia.FrameTargetMismatch,
    surface_matches: false,
    finalization: empty_frame.finalization_descriptor(),
    finalized: false,
  }
  {
    stats: empty_stats,
    resource_stats: empty_native_replay_resource_stats(),
    finalization_plan: @skia.RendererResourcePlan::empty(),
    mismatch_stats: empty_stats,
  }
}

///|
fn run_replay_surface_frame_smoke(
  replay_size : @skia.ISize,
  replay_frame : @skia.RenderFrameDescriptor,
  replay_commands : @skia.RenderCommandList,
  replay_command_stats : @skia.RenderCommandStats,
  replay_font : @native.Font,
) -> ReplaySurfaceFrameSmokeStats {
  guard @native.Surface::raster_n32_premul(replay_size)
    is Some(render_frame_surface) else {
    fail_smoke("failed to create native surface frame replay surface")
    empty_replay_surface_frame_smoke_stats(replay_frame.target)
  }
  let render_frame_resources = @native.NativeReplayResources::new(
    shader_max_bytes=1024L,
    path_max_bytes=1024L,
    text_run_max_bytes=1024L,
    font_max_bytes=1024L,
    typeface_max_bytes=1024L,
    color_filter_max_bytes=1024L,
    image_filter_max_bytes=1024L,
    mask_filter_max_bytes=1024L,
  )
  let render_frame_stats = render_frame_surface.render_frame_with_resources(
    replay_frame,
    render_frame_resources,
    font=Some(replay_font),
    frame_index=7,
  )
  let render_frame_resource_stats = render_frame_resources.stats()
  let render_frame_finalization_plan = render_frame_stats.finalization_resource_plan()
  guard @native.Surface::raster_n32_premul(@skia.ISize::new(6, 6))
    is Some(mismatch_frame_surface) else {
    fail_smoke("failed to create native mismatched frame replay surface")
    empty_replay_surface_frame_smoke_stats(replay_frame.target)
  }
  let render_frame_mismatch_stats = mismatch_frame_surface.render_frame(
    replay_frame,
    font=Some(replay_font),
  )
  let surface_filters_available = @native.ColorFilter::saturation(1.0) is Some(_)
  if surface_filters_available {
    if !render_frame_stats.is_complete() ||
      render_frame_stats.status() != @native.SurfaceFrameReplayComplete ||
      render_frame_stats.validation_status != @skia.FrameReady ||
      !render_frame_stats.surface_matches ||
      !render_frame_stats.finalized ||
      !render_frame_stats.finalization_is_ready() ||
      render_frame_stats.finalization.frame_index != 7 ||
      render_frame_stats.finalization !=
      replay_frame.finalization_descriptor(frame_index=7) ||
      render_frame_finalization_plan !=
      replay_frame.finalization_resource_plan(frame_index=7) ||
      render_frame_finalization_plan.length() != 16 ||
      render_frame_finalization_plan.cacheable_count != 15 ||
      render_frame_finalization_plan.uncacheable_count != 1 ||
      render_frame_stats.replay.command_count != replay_commands.length() ||
      render_frame_stats.replay.resource_declaration_count !=
      replay_command_stats.resource_declaration_count ||
      render_frame_stats.replay.image_resource_count !=
      replay_command_stats.image_resource_count ||
      render_frame_stats.replay.shader_resource_count !=
      replay_command_stats.shader_resource_count ||
      render_frame_stats.replay.filter_resource_count !=
      replay_command_stats.filter_resource_count ||
      render_frame_stats.replay.path_resource_count !=
      replay_command_stats.path_resource_count ||
      render_frame_stats.replay.text_resource_count !=
      replay_command_stats.text_resource_count ||
      render_frame_resource_stats.cache_count != 9 ||
      render_frame_resource_stats.resource_count != 9 ||
      render_frame_resources.shader_cache.length() != 1 ||
      render_frame_resources.path_cache.length() != 2 ||
      render_frame_resources.text_run_cache.length() != 1 ||
      render_frame_resources.font_cache.length() != 1 ||
      render_frame_resources.typeface_cache.length() != 1 ||
      render_frame_resources.color_filter_cache.length() != 1 ||
      render_frame_resources.image_filter_cache.length() != 1 ||
      render_frame_resources.mask_filter_cache.length() != 1 ||
      render_frame_mismatch_stats.is_complete() ||
      render_frame_mismatch_stats.status() !=
      @native.SurfaceFrameReplaySurfaceMismatch ||
      render_frame_mismatch_stats.surface_matches ||
      render_frame_mismatch_stats.finalized ||
      render_frame_mismatch_stats.replay.replayed_count != 0 {
      fail_smoke("native surface render frame finalization contract did not hold")
    }
  }
  guard render_frame_surface.read_pixels(
      bounds=@skia.IRect::from_xywh(1, 1, 1, 1),
    )
    is Some(render_frame_pixmap) else {
    fail_smoke("failed to read native surface render frame pixels")
    empty_replay_surface_frame_smoke_stats(replay_frame.target)
  }
  assert_pixel(
    render_frame_pixmap,
    @skia.IPoint::new(0, 0),
    0xff,
    0x00,
    0x00,
    0xff,
  )
  {
    stats: render_frame_stats,
    resource_stats: render_frame_resource_stats,
    finalization_plan: render_frame_finalization_plan,
    mismatch_stats: render_frame_mismatch_stats,
  }
}

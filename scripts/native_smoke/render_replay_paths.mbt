///|
priv struct ReplayPathSmokeStats {
  clip : @native.CanvasReplayStats
  clip_resources : @native.NativeReplayResources
  empty_path : @native.CanvasReplayStats
  empty_path_resources : @native.NativeReplayResources
  empty_path_cache : @skia.ResourceCacheStats
  non_finite_path : @native.CanvasReplayStats
  non_finite_path_resources : @native.NativeReplayResources
  non_finite_path_cache : @skia.ResourceCacheStats
}

///|
fn empty_replay_path_smoke_stats() -> ReplayPathSmokeStats {
  let empty_path_resources = @native.NativeReplayResources::new()
  let non_finite_path_resources = @native.NativeReplayResources::new()
  {
    clip: @native.CanvasReplayStats::empty(),
    clip_resources: @native.NativeReplayResources::new(),
    empty_path: @native.CanvasReplayStats::empty(),
    empty_path_resources,
    empty_path_cache: empty_path_resources.path_cache.stats(),
    non_finite_path: @native.CanvasReplayStats::empty(),
    non_finite_path_resources,
    non_finite_path_cache: non_finite_path_resources.path_cache.stats(),
  }
}

///|
fn run_replay_path_smoke(
  replay_size : @skia.ISize,
  replay_target : @skia.SurfaceTargetDescriptor,
) -> ReplayPathSmokeStats {
  let replay_clip_path = @skia.Path::new().add_rect(
    @skia.Rect::from_xywh(3, 3, 4, 4),
  )
  let replay_clip_commands = @skia.RenderCommandList::for_target(replay_target)
    .clip_rrect(
      @skia.RRect::from_rect_xy(@skia.Rect::from_xywh(2, 2, 7, 7), 1.0, 1.0),
    )
    .clip_path(replay_clip_path)
    .draw_rect(
      @skia.Rect::from_xywh(0, 0, 12, 12),
      paint=@skia.Paint::new(color=@skia.Color::red()),
    )
  guard @native.Surface::raster_n32_premul(replay_size)
    is Some(replay_clip_surface) else {
    fail_smoke("failed to create replay clip smoke surface")
    empty_replay_path_smoke_stats()
  }
  guard replay_clip_surface.canvas() is Some(replay_clip_canvas) else {
    fail_smoke("failed to create replay clip smoke canvas")
    empty_replay_path_smoke_stats()
  }
  replay_clip_canvas.clear(@skia.Color::white())
  let replay_clip_resources = @native.NativeReplayResources::new(
    path_max_bytes=1024L,
  )
  let replay_clip_stats = replay_clip_canvas.replay_with_resources(
    replay_clip_commands, replay_clip_resources,
  )
  if !replay_clip_stats.is_complete() ||
    replay_clip_stats.command_count != 3 ||
    replay_clip_stats.clip_count != 2 ||
    replay_clip_stats.clear_count != 0 ||
    replay_clip_stats.path_resource_count != 1 ||
    replay_clip_resources.path_cache.length() != 1 ||
    replay_clip_commands.touched_bounds() !=
    Some(@skia.Rect::from_xywh(3, 3, 4, 4)) {
    fail_smoke("native canvas replay did not apply rounded/path clips")
  }
  guard replay_clip_surface.read_pixels(
      bounds=@skia.IRect::from_xywh(3, 3, 1, 1),
    )
    is Some(replay_clip_inside) else {
    fail_smoke("failed to read replay clip inside pixel")
    empty_replay_path_smoke_stats()
  }
  assert_pixel(
    replay_clip_inside,
    @skia.IPoint::new(0, 0),
    0xff,
    0x00,
    0x00,
    0xff,
  )
  guard replay_clip_surface.read_pixels(
      bounds=@skia.IRect::from_xywh(1, 1, 1, 1),
    )
    is Some(replay_clip_outside) else {
    fail_smoke("failed to read replay clip outside pixel")
    empty_replay_path_smoke_stats()
  }
  assert_pixel(
    replay_clip_outside,
    @skia.IPoint::new(0, 0),
    0xff,
    0xff,
    0xff,
    0xff,
  )

  let empty_replay_path = @skia.Path::new()
  let empty_path_shader = @skia.ShaderDescriptor::color(@skia.Color::green())
  let empty_path_commands = @skia.RenderCommandList::for_target(replay_target)
    .clip_path(empty_replay_path)
    .draw_path(
      empty_replay_path,
      paint=@skia.Paint::new(color=@skia.Color::blue()),
    )
    .draw_path_shader(empty_replay_path, empty_path_shader)
  let empty_path_plan = empty_path_commands.resource_plan()
  if !empty_replay_path.resource_key().is_empty() ||
    empty_replay_path.resource_descriptor().is_cacheable() ||
    empty_path_plan.length() != 2 ||
    empty_path_plan.count_kind(@skia.SurfaceResource) != 1 ||
    empty_path_plan.count_kind(@skia.PathResource) != 0 ||
    empty_path_plan.count_kind(@skia.ShaderResource) != 1 {
    fail_smoke("empty path replay resource plan is not cache-safe")
  }
  guard @native.Surface::raster_n32_premul(replay_size)
    is Some(empty_path_surface) else {
    fail_smoke("failed to create empty path replay surface")
    empty_replay_path_smoke_stats()
  }
  guard empty_path_surface.canvas() is Some(empty_path_canvas) else {
    fail_smoke("failed to create empty path replay canvas")
    empty_replay_path_smoke_stats()
  }
  let empty_path_resources = @native.NativeReplayResources::new(
    shader_max_bytes=1024L,
    path_max_bytes=1024L,
  )
  let empty_path_stats = empty_path_canvas.replay_with_resources(
    empty_path_commands, empty_path_resources,
  )
  let empty_path_cache_stats = empty_path_resources.path_cache.stats()
  if !empty_path_stats.is_complete() ||
    empty_path_stats.command_count != empty_path_commands.length() ||
    empty_path_stats.replayed_count != empty_path_commands.length() ||
    empty_path_stats.skipped_count != 0 ||
    empty_path_stats.clip_count != 1 ||
    empty_path_stats.draw_count != 2 ||
    empty_path_stats.path_resource_count != 3 ||
    empty_path_resources.path_cache.length() != 0 ||
    empty_path_cache_stats.misses != 0 ||
    empty_path_cache_stats.hits != 0 ||
    empty_path_resources.shader_cache.length() != 1 {
    fail_smoke("empty path replay should not touch path cache")
  }

  let non_finite_replay_path = @skia.Path::new()
    .move_to(@skia.Point::new(0, 0))
    .line_to(@skia.Point::new(1.0 / 0.0, 1))
  let non_finite_path_commands = @skia.RenderCommandList::for_target(
      replay_target,
    )
    .clip_path(non_finite_replay_path)
    .draw_path(
      non_finite_replay_path,
      paint=@skia.Paint::new(color=@skia.Color::blue()),
    )
  let non_finite_path_plan = non_finite_path_commands.resource_plan()
  if non_finite_replay_path.is_finite() ||
    !non_finite_replay_path.resource_key().is_empty() ||
    non_finite_replay_path.resource_descriptor().is_cacheable() ||
    non_finite_path_plan.length() != 1 ||
    non_finite_path_plan.count_kind(@skia.SurfaceResource) != 1 ||
    non_finite_path_plan.count_kind(@skia.PathResource) != 0 {
    fail_smoke("non-finite path replay resource plan is not cache-safe")
  }
  guard @native.Surface::raster_n32_premul(replay_size)
    is Some(non_finite_path_surface) else {
    fail_smoke("failed to create non-finite path replay surface")
    empty_replay_path_smoke_stats()
  }
  guard non_finite_path_surface.canvas() is Some(non_finite_path_canvas) else {
    fail_smoke("failed to create non-finite path replay canvas")
    empty_replay_path_smoke_stats()
  }
  let non_finite_path_resources = @native.NativeReplayResources::new(
    path_max_bytes=1024L,
  )
  let non_finite_path_stats = non_finite_path_canvas.replay_with_resources(
    non_finite_path_commands, non_finite_path_resources,
  )
  let non_finite_path_cache_stats = non_finite_path_resources.path_cache.stats()
  if non_finite_path_stats.is_complete() ||
    non_finite_path_stats.command_count != non_finite_path_commands.length() ||
    non_finite_path_stats.replayed_count != 0 ||
    non_finite_path_stats.skipped_count != non_finite_path_commands.length() ||
    non_finite_path_stats.clip_count != 1 ||
    non_finite_path_stats.draw_count != 1 ||
    non_finite_path_stats.path_resource_count != 2 ||
    non_finite_path_resources.path_cache.length() != 0 ||
    non_finite_path_cache_stats.misses != 0 ||
    non_finite_path_cache_stats.hits != 0 {
    fail_smoke("non-finite path replay should skip without touching path cache")
  }
  {
    clip: replay_clip_stats,
    clip_resources: replay_clip_resources,
    empty_path: empty_path_stats,
    empty_path_resources,
    empty_path_cache: empty_path_cache_stats,
    non_finite_path: non_finite_path_stats,
    non_finite_path_resources,
    non_finite_path_cache: non_finite_path_cache_stats,
  }
}

///|
priv struct ReplayFillSmokeStats {
  fill : @native.CanvasReplayStats
  paint_shader : @native.CanvasReplayStats
  paint_shader_resources : @native.NativeReplayResources
}

///|
fn empty_replay_fill_smoke_stats() -> ReplayFillSmokeStats {
  {
    fill: @native.CanvasReplayStats::empty(),
    paint_shader: @native.CanvasReplayStats::empty(),
    paint_shader_resources: @native.NativeReplayResources::new(),
  }
}

///|
fn run_replay_fill_smoke(
  replay_size : @skia.ISize,
  replay_target : @skia.SurfaceTargetDescriptor,
) -> ReplayFillSmokeStats {
  let replay_fill_commands = @skia.RenderCommandList::for_target(replay_target)
    .draw_color(@skia.Color::red(), blend_mode=@skia.Src)
    .clip_rect(@skia.Rect::from_xywh(2, 2, 3, 3))
    .draw_paint(
      paint=@skia.Paint::new(color=@skia.Color::blue(), blend_mode=@skia.Src),
    )
  guard @native.Surface::raster_n32_premul(replay_size)
    is Some(replay_fill_surface) else {
    fail_smoke("failed to create replay fill smoke surface")
    empty_replay_fill_smoke_stats()
  }
  guard replay_fill_surface.canvas() is Some(replay_fill_canvas) else {
    fail_smoke("failed to create replay fill smoke canvas")
    empty_replay_fill_smoke_stats()
  }
  let replay_fill_stats = replay_fill_canvas.replay(replay_fill_commands)
  if !replay_fill_stats.is_complete() ||
    replay_fill_stats.command_count != 3 ||
    replay_fill_stats.draw_count != 2 ||
    replay_fill_stats.clip_count != 1 ||
    replay_fill_stats.clear_count != 0 ||
    replay_fill_commands.touched_bounds() !=
    Some(@skia.Rect::from_xywh(0, 0, 12, 12)) {
    fail_smoke("native canvas replay did not apply color/paint fill commands")
  }
  guard replay_fill_surface.read_pixels(
      bounds=@skia.IRect::from_xywh(0, 0, 1, 1),
    )
    is Some(replay_fill_outside) else {
    fail_smoke("failed to read replay fill outside pixel")
    empty_replay_fill_smoke_stats()
  }
  assert_pixel(
    replay_fill_outside,
    @skia.IPoint::new(0, 0),
    0xff,
    0x00,
    0x00,
    0xff,
  )
  guard replay_fill_surface.read_pixels(
      bounds=@skia.IRect::from_xywh(2, 2, 1, 1),
    )
    is Some(replay_fill_inside) else {
    fail_smoke("failed to read replay fill inside pixel")
    empty_replay_fill_smoke_stats()
  }
  assert_pixel(
    replay_fill_inside,
    @skia.IPoint::new(0, 0),
    0x00,
    0x00,
    0xff,
    0xff,
  )

  let replay_paint_shader = @skia.ShaderDescriptor::color(@skia.Color::cyan())
  let replay_paint_shader_commands = @skia.RenderCommandList::for_target(
      replay_target,
    )
    .clear(@skia.Color::white())
    .clip_rect(@skia.Rect::from_xywh(2, 2, 3, 3))
    .draw_paint_shader(replay_paint_shader)
  guard @native.Surface::raster_n32_premul(replay_size)
    is Some(replay_paint_shader_surface) else {
    fail_smoke("failed to create replay paint shader smoke surface")
    empty_replay_fill_smoke_stats()
  }
  guard replay_paint_shader_surface.canvas() is Some(replay_paint_shader_canvas) else {
    fail_smoke("failed to create replay paint shader smoke canvas")
    empty_replay_fill_smoke_stats()
  }
  let replay_paint_shader_resources = @native.NativeReplayResources::new(
    shader_max_bytes=1024L,
  )
  let replay_paint_shader_stats = replay_paint_shader_canvas.replay_with_resources(
    replay_paint_shader_commands, replay_paint_shader_resources,
  )
  if !replay_paint_shader_stats.is_complete() ||
    replay_paint_shader_stats.command_count != 3 ||
    replay_paint_shader_stats.draw_count != 1 ||
    replay_paint_shader_stats.clip_count != 1 ||
    replay_paint_shader_stats.clear_count != 1 ||
    replay_paint_shader_stats.shader_resource_count != 1 ||
    replay_paint_shader_resources.shader_cache.length() != 1 ||
    replay_paint_shader_commands
    .resource_plan()
    .count_kind(@skia.ShaderResource) !=
    1 {
    fail_smoke("native canvas replay did not apply paint shader fill commands")
  }
  guard replay_paint_shader_surface.read_pixels(
      bounds=@skia.IRect::from_xywh(0, 0, 1, 1),
    )
    is Some(replay_paint_shader_outside) else {
    fail_smoke("failed to read replay paint shader outside pixel")
    empty_replay_fill_smoke_stats()
  }
  assert_pixel(
    replay_paint_shader_outside,
    @skia.IPoint::new(0, 0),
    0xff,
    0xff,
    0xff,
    0xff,
  )
  guard replay_paint_shader_surface.read_pixels(
      bounds=@skia.IRect::from_xywh(2, 2, 1, 1),
    )
    is Some(replay_paint_shader_inside) else {
    fail_smoke("failed to read replay paint shader inside pixel")
    empty_replay_fill_smoke_stats()
  }
  assert_pixel(
    replay_paint_shader_inside,
    @skia.IPoint::new(0, 0),
    0x00,
    0xff,
    0xff,
    0xff,
  )
  {
    fill: replay_fill_stats,
    paint_shader: replay_paint_shader_stats,
    paint_shader_resources: replay_paint_shader_resources,
  }
}

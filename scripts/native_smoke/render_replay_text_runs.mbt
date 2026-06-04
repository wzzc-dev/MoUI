///|
fn run_empty_text_run_replay_smoke() -> Unit {
  let empty_text_run_descriptor = @skia.TextRunDescriptor::new(
    range=@skia.TextRange::new(1, 1),
  )
  let empty_text_run_commands = @skia.RenderCommandList::for_target(
      @skia.SurfaceTargetDescriptor::raster_n32_premul(@skia.ISize::new(16, 16)),
    )
    .clear(@skia.Color::white())
    .draw_text_run_utf8(
      b"abc",
      @skia.Point::new(1, 12),
      descriptor=Some(empty_text_run_descriptor),
      paint=@skia.Paint::new(color=@skia.Color::black()),
    )
  let empty_text_run_plan = empty_text_run_commands.resource_plan()
  if empty_text_run_plan.length() != 2 ||
    empty_text_run_plan.count_kind(@skia.SurfaceResource) != 1 ||
    empty_text_run_plan.count_kind(@skia.TextRunResource) != 1 {
    fail_smoke("empty text run replay resource plan is invalid")
  }
  guard @native.Surface::raster_n32_premul(@skia.ISize::new(16, 16))
    is Some(empty_text_run_surface) else {
    fail_smoke("failed to create empty text run replay surface")
  }
  guard empty_text_run_surface.canvas() is Some(empty_text_run_canvas) else {
    fail_smoke("failed to borrow empty text run replay canvas")
  }
  let empty_text_run_resources = @native.NativeReplayResources::new(
    text_run_max_bytes=1024L,
  )
  let empty_text_run_stats = empty_text_run_canvas.replay_with_resources(
    empty_text_run_commands, empty_text_run_resources,
  )
  let empty_text_run_cache_resources = empty_text_run_resources.text_run_cache.length() +
    empty_text_run_resources.font_cache.length() +
    empty_text_run_resources.typeface_cache.length()
  if empty_text_run_stats.is_complete() ||
    empty_text_run_stats.command_count != empty_text_run_commands.length() ||
    empty_text_run_stats.replayed_count != 1 ||
    empty_text_run_stats.skipped_count != 1 ||
    empty_text_run_stats.text_count != 1 ||
    empty_text_run_stats.text_resource_count != 1 ||
    empty_text_run_cache_resources != 0 {
    fail_smoke("empty text run replay should skip without caching")
  }
  println("native smoke text run empty range resource plan count")
  println(empty_text_run_plan.length())
  println("native smoke text run empty range skipped")
  println(empty_text_run_stats.skipped_count)
  println("native smoke text run empty range cache resources")
  println(empty_text_run_cache_resources)
}

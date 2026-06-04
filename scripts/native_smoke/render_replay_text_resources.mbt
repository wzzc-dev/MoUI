///|
priv struct ReplayTextResourceSmokeStats {
  measurement_plan : @skia.RendererResourcePlan
  measured_run_plan : @skia.RendererResourcePlan
  invalid_measured_run_plan : @skia.RendererResourcePlan
  ranged_text_byte_size : Int64
}

///|
fn empty_replay_text_resource_smoke_stats() -> ReplayTextResourceSmokeStats {
  {
    measurement_plan: @skia.RendererResourcePlan::empty(),
    measured_run_plan: @skia.RendererResourcePlan::empty(),
    invalid_measured_run_plan: @skia.RendererResourcePlan::empty(),
    ranged_text_byte_size: 0L,
  }
}

///|
fn run_replay_text_resource_smoke(
  replay_descriptor : @skia.TextRunDescriptor,
  replay_font : @native.Font,
  replay_shaping : @skia.TextShapingDescriptor,
  replay_shaped_run : @skia.ShapedTextRunDescriptor,
  replay_shaped_glyph_run : @skia.ShapedGlyphRunDescriptor,
  replay_text_run_plan : @skia.RendererResourcePlan,
) -> ReplayTextResourceSmokeStats {
  run_empty_text_run_replay_smoke()
  let replay_measurement = @skia.TextMeasurementDescriptor::new(
    run=replay_descriptor,
    font_key=@skia.RendererResourceKey::font(b"default:8"),
    width=128.0,
    shape=true,
  )
  let replay_measurement_plan = replay_measurement.resource_plan(b"hello")
  if replay_measurement_plan.length() != 4 ||
    replay_measurement_plan.count_kind(@skia.TextRunResource) != 2 ||
    replay_measurement_plan.count_kind(@skia.FontResource) != 1 ||
    replay_measurement_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_measurement_plan.byte_size <= replay_text_run_plan.byte_size {
    fail_smoke(
      "native text measurement resource plan did not include measured run dependencies",
    )
  }
  if replay_measurement.resource_key(b"hello") ==
    replay_measurement.with_width(64.0).resource_key(b"hello") ||
    replay_measurement.resource_key(b"hello") ==
    replay_measurement.with_shape(false).resource_key(b"hello") {
    fail_smoke(
      "native text measurement resource key did not encode measurement inputs",
    )
  }
  let replay_measured_advance = replay_font.measure_text_utf8(b"hello")
  let replay_measured_run = replay_measurement.measured_run_descriptor(
    advance=replay_measured_advance,
    bounds=replay_font.measure_text_bounds_utf8(b"hello"),
  )
  let replay_measured_run_plan = replay_measured_run.resource_plan(b"hello")
  if !replay_measured_run.is_valid() ||
    replay_measured_advance <= 0.0 ||
    replay_measured_run_plan.length() != 5 ||
    replay_measured_run_plan.count_kind(@skia.TextRunResource) != 3 ||
    replay_measured_run_plan.count_kind(@skia.FontResource) != 1 ||
    replay_measured_run_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_measured_run_plan.byte_size <= replay_measurement_plan.byte_size ||
    !replay_measured_run_plan.contains_key(
      replay_measured_run.resource_key(b"hello"),
    ) ||
    !replay_measured_run_plan.contains_key(
      replay_measurement.resource_key(b"hello"),
    ) {
    fail_smoke("native measured text run metadata resource plan is invalid")
  }
  if replay_measured_run.resource_key(b"hello") ==
    replay_measurement
    .measured_run_descriptor(
      advance=replay_measured_advance + 1.0,
      bounds=replay_measured_run.bounds,
    )
    .resource_key(b"hello") {
    fail_smoke(
      "native measured text run resource key did not encode result metadata",
    )
  }
  let invalid_measured_run : @skia.MeasuredTextRunDescriptor = {
    measurement: replay_measurement,
    advance: 0.0 / 0.0,
    bounds: None,
  }
  let invalid_measured_run_plan = invalid_measured_run.resource_plan(b"hello")
  if invalid_measured_run.is_valid() ||
    invalid_measured_run_plan.length() != 1 ||
    invalid_measured_run_plan.cacheable_count != 0 ||
    invalid_measured_run_plan.uncacheable_count != 1 ||
    invalid_measured_run_plan.count_kind(@skia.TextRunResource) != 1 {
    fail_smoke("invalid measured text run resource plan should be uncacheable")
  }

  let replay_shaping_plan = replay_shaping.resource_plan(b"hello")
  if replay_shaping_plan.length() != 4 ||
    replay_shaping_plan.count_kind(@skia.TextRunResource) != 2 ||
    replay_shaping_plan.count_kind(@skia.FontResource) != 1 ||
    replay_shaping_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_shaping_plan.byte_size <= replay_text_run_plan.byte_size {
    fail_smoke(
      "native text shaping resource plan did not include shaped run dependencies",
    )
  }
  if replay_shaping.resource_key(b"hello") ==
    replay_shaping.with_width(64.0).resource_key(b"hello") ||
    replay_shaping.resource_key(b"hello") ==
    replay_shaping
    .with_run(replay_descriptor.with_direction(@skia.RightToLeft))
    .resource_key(b"hello") {
    fail_smoke("native text shaping resource key did not encode shaping inputs")
  }
  let replay_shaped_run_plan = replay_shaped_run.resource_plan(b"hello")
  if !replay_shaped_run.is_valid() ||
    replay_shaped_run_plan.length() != 5 ||
    replay_shaped_run_plan.count_kind(@skia.TextRunResource) != 3 ||
    replay_shaped_run_plan.count_kind(@skia.FontResource) != 1 ||
    replay_shaped_run_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_shaped_run_plan.byte_size <= replay_shaping_plan.byte_size {
    fail_smoke("native shaped text run resource plan is invalid")
  }
  if replay_shaped_run.resource_key(b"hello") ==
    replay_shaped_run.shaping
    .shaped_run_descriptor(
      glyph_count=5,
      cluster_count=4,
      advance=@skia.Point::new(16.0, 0.0),
    )
    .resource_key(b"hello") {
    fail_smoke(
      "native shaped text run resource key did not encode result metadata",
    )
  }
  let replay_shaped_glyph_run_plan = replay_shaped_glyph_run.resource_plan(
    b"hello",
  )
  if !replay_shaped_glyph_run.is_valid() ||
    replay_shaped_glyph_run.glyph_count() != 4 ||
    replay_shaped_glyph_run.cluster_count() != 4 ||
    replay_shaped_glyph_run_plan.length() != 6 ||
    replay_shaped_glyph_run_plan.count_kind(@skia.TextRunResource) != 4 ||
    replay_shaped_glyph_run_plan.count_kind(@skia.FontResource) != 1 ||
    replay_shaped_glyph_run_plan.count_kind(@skia.TypefaceResource) != 1 ||
    replay_shaped_glyph_run_plan.byte_size <= replay_shaped_run_plan.byte_size ||
    !replay_shaped_glyph_run_plan.contains_key(
      replay_shaped_glyph_run.resource_key(b"hello"),
    ) ||
    !replay_shaped_glyph_run_plan.contains_key(
      replay_shaped_run.resource_key(b"hello"),
    ) {
    fail_smoke("native shaped glyph run resource plan is invalid")
  }
  if replay_shaped_glyph_run.resource_key(b"hello") ==
    replay_shaped_run
    .glyph_run_descriptor(
      glyph_ids=[1, 2, 3, 5],
      positions=replay_shaped_glyph_run.positions,
      clusters=replay_shaped_glyph_run.clusters,
    )
    .resource_key(b"hello") ||
    replay_shaped_glyph_run.resource_key(b"hello") ==
    replay_shaped_run
    .glyph_run_descriptor(
      glyph_ids=replay_shaped_glyph_run.glyph_ids,
      positions=[
        @skia.Point::new(0.0, 0.0),
        @skia.Point::new(5.0, 0.0),
        @skia.Point::new(8.0, 0.0),
        @skia.Point::new(12.0, 0.0),
      ],
      clusters=replay_shaped_glyph_run.clusters,
    )
    .resource_key(b"hello") {
    fail_smoke("native shaped glyph run key did not encode glyph metadata")
  }
  let invalid_shaped_glyph_run = replay_shaping
    .shaped_run_descriptor(glyph_count=0)
    .glyph_run_descriptor()
  let invalid_shaped_glyph_plan = invalid_shaped_glyph_run.resource_plan(
    b"hello",
  )
  if invalid_shaped_glyph_run.is_valid() ||
    invalid_shaped_glyph_plan.length() != 1 ||
    invalid_shaped_glyph_plan.cacheable_count != 0 ||
    invalid_shaped_glyph_plan.uncacheable_count != 1 ||
    invalid_shaped_glyph_plan.count_kind(@skia.TextRunResource) != 1 {
    fail_smoke("invalid shaped glyph run resource plan should be uncacheable")
  }
  let invalid_shaped_glyph_commands = @skia.RenderCommandList::for_target(
      @skia.SurfaceTargetDescriptor::raster_n32_premul(@skia.ISize::new(16, 16)),
    )
    .clear(@skia.Color::white())
    .draw_shaped_glyph_run_utf8(
      b"hello",
      invalid_shaped_glyph_run,
      @skia.Point::new(1, 12),
      paint=@skia.Paint::new(color=@skia.Color::black()),
    )
  let invalid_shaped_glyph_command_plan = invalid_shaped_glyph_commands.resource_plan()
  if invalid_shaped_glyph_command_plan.length() != 1 ||
    invalid_shaped_glyph_command_plan.count_kind(@skia.SurfaceResource) != 1 ||
    invalid_shaped_glyph_command_plan.count_kind(@skia.TextRunResource) != 0 {
    fail_smoke("invalid shaped glyph command resource plan is not cache-safe")
  }
  guard @native.Surface::raster_n32_premul(@skia.ISize::new(16, 16))
    is Some(invalid_shaped_glyph_surface) else {
    fail_smoke("failed to create invalid shaped glyph replay surface")
    empty_replay_text_resource_smoke_stats()
  }
  guard invalid_shaped_glyph_surface.canvas()
    is Some(invalid_shaped_glyph_canvas) else {
    fail_smoke("failed to borrow invalid shaped glyph replay canvas")
    empty_replay_text_resource_smoke_stats()
  }
  let invalid_shaped_glyph_stats = invalid_shaped_glyph_canvas.replay(
    invalid_shaped_glyph_commands,
  )
  if invalid_shaped_glyph_stats.is_complete() ||
    invalid_shaped_glyph_stats.command_count !=
    invalid_shaped_glyph_commands.length() ||
    invalid_shaped_glyph_stats.replayed_count != 1 ||
    invalid_shaped_glyph_stats.skipped_count != 1 ||
    invalid_shaped_glyph_stats.text_count != 1 ||
    invalid_shaped_glyph_stats.text_resource_count != 1 {
    fail_smoke("invalid shaped glyph replay should skip")
  }
  println("native smoke text shaping resource plan count")
  println(replay_shaping_plan.length())
  println("native smoke shaped text resource plan count")
  println(replay_shaped_run_plan.length())
  println("native smoke shaped glyph run resource plan count")
  println(replay_shaped_glyph_run_plan.length())
  println("native smoke shaped glyph run key variation")
  println(1)
  println("native smoke invalid shaped glyph resource plan count")
  println(invalid_shaped_glyph_plan.length())
  println("native smoke invalid shaped glyph command plan count")
  println(invalid_shaped_glyph_command_plan.length())
  println("native smoke invalid shaped glyph replay skipped")
  println(invalid_shaped_glyph_stats.skipped_count)

  let ranged_text_descriptor = @skia.TextRunDescriptor::new(
    range=@skia.TextRange::new(1, 5),
  )
  let ranged_text_key = ranged_text_descriptor.resource_key(
    b"xhelloz",
    font_key=@skia.RendererResourceKey::font(b"default:8"),
  )
  let same_ranged_text_key = ranged_text_descriptor.resource_key(
    b"yhelloq",
    font_key=@skia.RendererResourceKey::font(b"default:8"),
  )
  let ranged_text_resource = ranged_text_descriptor.resource_descriptor(
    b"xhelloz",
    font_key=@skia.RendererResourceKey::font(b"default:8"),
  )
  if ranged_text_key != same_ranged_text_key ||
    ranged_text_resource.byte_size != 4L {
    fail_smoke("native text run resource key was not scoped to byte range")
  }
  {
    measurement_plan: replay_measurement_plan,
    measured_run_plan: replay_measured_run_plan,
    invalid_measured_run_plan,
    ranged_text_byte_size: ranged_text_resource.byte_size,
  }
}

///|
extern "c" fn bench_now_ms() -> Double = "moui_skia_cached_layer_benchmark_now_ms"

///|
struct BenchRunResult {
  label : String
  frames : Int32
  elapsed_ms : Double
  draw_us : Double
  copy_us : Double
  present_us : Double
  effective_rect_frames : Int32
  effective_full_frames : Int32
  fallback_frames : Int32
  cache_hit_count : Int32
  cache_miss_count : Int32
  cache_update_count : Int32
  cache_evict_count : Int32
  present_count : Int32
}

///|
fn[T] fail_bench(message : String) -> T {
  println(message)
  abort("MoUI Skia cached layer benchmark failed")
}

///|
fn bench_parse_positive_int(value : String, fallback : Int32) -> Int32 {
  let chars = value.trim().to_array()
  if chars.length() == 0 {
    return fallback
  }
  let mut parsed = 0
  for ch in chars {
    if ch < '0' || ch > '9' {
      return fallback
    }
    parsed = parsed * 10 + ch.to_int() - '0'.to_int()
  }
  parsed.max(1)
}

///|
fn bench_env_int(name : String, fallback : Int32) -> Int32 {
  match @env.get_env_var(name) {
    Some(value) => bench_parse_positive_int(value, fallback)
    None => fallback
  }
}

///|
fn bench_metrics() -> @core.SurfaceMetrics {
  @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=900.0, height=640.0),
  )
}

///|
fn bench_surface_rect() -> @core.Rect {
  @core.Rect::new(x=0.0, y=0.0, width=900.0, height=640.0)
}

///|
fn bench_layer_frame() -> @core.Rect {
  @core.Rect::new(x=32.0, y=32.0, width=760.0, height=520.0)
}

///|
fn bench_layer_spec() -> @core.RetainedLayerSpec {
  @core.RetainedLayerSpec::new(
    key="skia-bench-static-dashboard-boundary",
    frame=bench_layer_frame(),
    content_revision=1,
  )
}

///|
fn bench_color(
  r : Double,
  g : Double,
  b : Double,
  a~ : Double = 1.0,
) -> @core.Color {
  @core.Color::rgba(r~, g~, b~, a~)
}

///|
fn bench_font(size : Double, weight~ : Int32 = 400) -> @core.FontSpec {
  @core.FontSpec::new(size~, weight~)
}

///|
fn bench_static_body_commands() -> Array[@core.DrawCommand] {
  let commands : Array[@core.DrawCommand] = []
  let layer = bench_layer_frame()
  commands.push(
    FillRoundedRectBrush(
      @core.RoundedRect::new(rect=layer, radius=16.0),
      @core.Brush::linear_gradient(
        start=@core.Point::new(x=layer.origin.x, y=layer.origin.y),
        end=@core.Point::new(
          x=layer.origin.x + layer.size.width,
          y=layer.origin.y + layer.size.height,
        ),
        start_color=bench_color(0.96, 0.97, 0.98),
        end_color=bench_color(0.87, 0.91, 0.94),
      ),
    ),
  )
  commands.push(
    StrokeRoundedRect(
      @core.RoundedRect::new(rect=layer, radius=16.0),
      bench_color(0.18, 0.24, 0.30, a=0.28),
      1.0,
    ),
  )
  commands.push(
    DrawText(
      @core.TextRun::new(
        text="MoUI renderer cache benchmark",
        frame=@core.Rect::new(x=56.0, y=54.0, width=430.0, height=32.0),
        font=bench_font(22.0, weight=700),
        color=bench_color(0.05, 0.08, 0.12),
        align=TextStart,
      ),
    ),
  )
  for row in 0..<10 {
    for col in 0..<4 {
      let x = 56.0 + col.to_double() * 178.0
      let y = 104.0 + row.to_double() * 40.0
      let tone = 0.18 + (row + col).to_double() * 0.018
      let rect = @core.Rect::new(x~, y~, width=150.0, height=30.0)
      commands.push(
        DrawShadow(
          @core.ShadowSpec::new(
            rect=@core.RoundedRect::new(rect~, radius=8.0),
            color=bench_color(0.0, 0.0, 0.0, a=0.08),
            offset=@core.Point::new(x=0.0, y=2.0),
            blur_radius=6.0,
          ),
        ),
      )
      commands.push(
        FillRoundedRectBrush(
          @core.RoundedRect::new(rect~, radius=8.0),
          @core.Brush::linear_gradient(
            start=@core.Point::new(x~, y~),
            end=@core.Point::new(x=x + 150.0, y=y + 30.0),
            start_color=bench_color(0.98, 0.99, 1.0),
            end_color=bench_color(tone, tone + 0.12, tone + 0.24, a=0.42),
          ),
        ),
      )
      commands.push(
        StrokeRoundedRect(
          @core.RoundedRect::new(rect~, radius=8.0),
          bench_color(0.17, 0.20, 0.24, a=0.16),
          1.0,
        ),
      )
      commands.push(
        DrawText(
          @core.TextRun::new(
            text="cell \{row}.\{col}  alpha beta gamma",
            frame=@core.Rect::new(
              x=x + 10.0,
              y=y + 6.0,
              width=128.0,
              height=18.0,
            ),
            font=bench_font(11.0, weight=500),
            color=bench_color(0.07, 0.10, 0.14),
            align=TextStart,
          ),
        ),
      )
    }
  }
  for index in 0..<24 {
    let x = 72.0 + (index % 12).to_double() * 56.0
    let y = 520.0 + (index / 12).to_double() * 18.0
    commands.push(
      DrawPath(
        @core.PathSpec::new(
          verbs=[
            MoveTo(@core.Point::new(x~, y~)),
            CubicTo(
              @core.Point::new(x=x + 10.0, y=y - 18.0),
              @core.Point::new(x=x + 28.0, y=y + 20.0),
              @core.Point::new(x=x + 42.0, y~),
            ),
          ],
          stroke=Some(@core.Brush::solid(bench_color(0.04, 0.35, 0.58, a=0.58))),
          stroke_width=2.0,
        ),
      ),
    )
  }
  commands
}

///|
fn bench_append_scoped_panel(commands : Array[@core.DrawCommand]) -> Unit {
  commands.push(
    PushLayer(
      @core.LayerSpec::new(
        opacity=0.64,
        mask=RoundedMask(
          @core.RoundedRect::new(
            rect=@core.Rect::new(x=548.0, y=66.0, width=190.0, height=86.0),
            radius=14.0,
          ),
        ),
        offscreen=true,
      ),
    ),
  )
  commands.push(PushFilter(Saturate(1.35)))
  commands.push(
    FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=548.0, y=66.0, width=190.0, height=86.0),
        radius=14.0,
      ),
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=612.0, y=98.0),
        radius=112.0,
        center_color=bench_color(0.14, 0.58, 0.88, a=0.86),
        edge_color=bench_color(0.92, 0.32, 0.40, a=0.68),
      ),
    ),
  )
  commands.push(PopFilter)
  commands.push(PopLayer)
}

///|
fn bench_static_layer_commands() -> Array[@core.DrawCommand] {
  let commands = bench_static_body_commands()
  bench_append_scoped_panel(commands)
  commands
}

///|
fn bench_append_static(
  commands : Array[@core.DrawCommand],
  static_commands : Array[@core.DrawCommand],
) -> Unit {
  for command in static_commands {
    commands.push(command)
  }
}

///|
fn bench_overlay_rect(frame_index : Int32) -> @core.Rect {
  let x = 70.0 + (frame_index * 13 % 620).to_double()
  @core.Rect::new(x~, y=458.0, width=28.0, height=28.0)
}

///|
fn bench_append_overlay(
  commands : Array[@core.DrawCommand],
  frame_index : Int32,
) -> Unit {
  let rect = bench_overlay_rect(frame_index)
  commands.push(
    FillRoundedRect(
      @core.RoundedRect::new(rect~, radius=7.0),
      bench_color(0.98, 0.18, 0.24, a=0.86),
    ),
  )
  commands.push(
    StrokeRoundedRect(
      @core.RoundedRect::new(rect~, radius=7.0),
      bench_color(0.10, 0.04, 0.05, a=0.62),
      1.0,
    ),
  )
}

///|
fn bench_overlay_damage(frame_index : Int32) -> @core.DamageRegion {
  @core.DamageRegion::from_rects(
    [bench_overlay_rect(frame_index).inflate(2.0)],
    bench_surface_rect(),
  )
}

///|
fn bench_overlay_pair_damage(
  previous_index : Int32,
  frame_index : Int32,
) -> @core.DamageRegion {
  @core.DamageRegion::from_rects(
    [
      bench_overlay_rect(previous_index).inflate(2.0),
      bench_overlay_rect(frame_index).inflate(2.0),
    ],
    bench_surface_rect(),
  )
}

///|
fn bench_partial_frames(
  static_commands : Array[@core.DrawCommand],
  start_index : Int32,
  frames : Int32,
) -> Array[@core.DrawFrame] {
  let result : Array[@core.DrawFrame] = []
  for offset in 0..<frames {
    let frame_index = start_index + offset
    let commands : Array[@core.DrawCommand] = []
    bench_append_static(commands, static_commands)
    bench_append_overlay(commands, frame_index)
    result.push(
      bench_draw_frame(
        commands,
        bench_overlay_pair_damage(frame_index - 1, frame_index),
      ),
    )
  }
  result
}

///|
fn bench_partial_reference_frame(
  static_commands : Array[@core.DrawCommand],
  frame_index : Int32,
) -> @core.DrawFrame {
  let commands : Array[@core.DrawCommand] = []
  bench_append_static(commands, static_commands)
  bench_append_overlay(commands, frame_index)
  bench_draw_frame(
    commands,
    @core.DamageRegion::full("benchmark partial reference"),
  )
}

///|
fn bench_draw_frame(
  commands : Array[@core.DrawCommand],
  damage : @core.DamageRegion,
) -> @core.DrawFrame {
  @core.DrawFrame::new(
    commands~,
    damage~,
    clear_color=bench_color(1.0, 1.0, 1.0),
  )
}

///|
fn bench_cached_update_frame(
  spec : @core.RetainedLayerSpec,
  static_commands : Array[@core.DrawCommand],
) -> @core.DrawFrame {
  let commands : Array[@core.DrawCommand] = [BeginRetainedLayer(spec)]
  bench_append_static(commands, static_commands)
  commands.push(EndRetainedLayer(spec.key))
  bench_append_overlay(commands, 0)
  bench_draw_frame(commands, @core.DamageRegion::full("benchmark cache update"))
}

///|
fn bench_cached_hit_frame(
  spec : @core.RetainedLayerSpec,
  static_commands : Array[@core.DrawCommand],
  frame_index : Int32,
) -> @core.DrawFrame {
  let commands : Array[@core.DrawCommand] = [BeginRetainedLayer(spec)]
  bench_append_static(commands, static_commands)
  commands.push(EndRetainedLayer(spec.key))
  bench_append_overlay(commands, frame_index)
  bench_draw_frame(commands, bench_overlay_damage(frame_index))
}

///|
fn bench_full_repaint_frame(
  static_commands : Array[@core.DrawCommand],
  frame_index : Int32,
) -> @core.DrawFrame {
  let commands : Array[@core.DrawCommand] = []
  bench_append_static(commands, static_commands)
  bench_append_overlay(commands, frame_index)
  bench_draw_frame(commands, @core.DamageRegion::full("benchmark full repaint"))
}

///|
fn bench_cached_hit_frames(
  spec : @core.RetainedLayerSpec,
  static_commands : Array[@core.DrawCommand],
  frames : Int32,
) -> Array[@core.DrawFrame] {
  let result : Array[@core.DrawFrame] = []
  for index in 0..<frames {
    result.push(bench_cached_hit_frame(spec, static_commands, index + 1))
  }
  result
}

///|
fn bench_full_repaint_frames(
  static_commands : Array[@core.DrawCommand],
  frames : Int32,
) -> Array[@core.DrawFrame] {
  let result : Array[@core.DrawFrame] = []
  for index in 0..<frames {
    result.push(bench_full_repaint_frame(static_commands, index + 1))
  }
  result
}

///|
fn bench_renderer(
  label : String,
  surface_damage~ : @render.SurfaceDamageCapability = @render.FullSurfaceOnly,
) -> @skia_renderer.SkiaRasterRenderer {
  let target = @skia_renderer.SkiaPresentTarget::new(description=label, present=_frame => {
    true
  })
  @skia_renderer.create_with_present_target(
    bench_metrics(),
    target,
    surface_damage~,
  ) catch {
    err => fail_bench("expected Skia renderer for benchmark: \{err.message()}")
  }
}

///|
fn bench_run_frames(
  renderer : @skia_renderer.SkiaRasterRenderer,
  label : String,
  frames : Array[@core.DrawFrame],
) -> BenchRunResult {
  let before_present = renderer.present_count()
  let start = bench_now_ms()
  let mut hits = 0
  let mut misses = 0
  let mut updates = 0
  let mut evicts = 0
  let mut draw_us = 0.0
  let mut copy_us = 0.0
  let mut present_us = 0.0
  let mut effective_rect_frames = 0
  let mut effective_full_frames = 0
  let mut fallback_frames = 0
  for frame in frames {
    let result = renderer.render_frame(frame)
    if !result.presented {
      fail_bench("\{label} produced an unpresented frame")
    }
    match renderer.last_damage_report() {
      Some(report) => {
        draw_us += report.draw_us()
        copy_us += report.copy_us()
        present_us += report.present_us()
        let effective_kind = report.effective().kind()
        if effective_kind == "rects" {
          effective_rect_frames += 1
        } else if effective_kind == "full" {
          effective_full_frames += 1
        } else {
          fail_bench("\{label} recorded an empty effective damage region")
        }
        if report.fallback_reason() is Some(_) {
          fallback_frames += 1
        }
      }
      None => fail_bench("\{label} did not record a damage report")
    }
    hits += result.cache_hit_count
    misses += result.cache_miss_count
    updates += result.cache_update_count
    evicts += result.cache_evict_count
  }
  let elapsed = bench_now_ms() - start
  if renderer.unsupported_command_count() != 0 {
    let diagnostics = renderer.unsupported_command_diagnostics()
    if diagnostics.length() > 0 {
      let diagnostic = diagnostics[0]
      fail_bench(
        "\{label} recorded unsupported Skia command: \{diagnostic.command()} \{diagnostic.reason()}",
      )
    }
    fail_bench("\{label} recorded unsupported Skia commands")
  }
  {
    label,
    frames: frames.length(),
    elapsed_ms: elapsed,
    draw_us,
    copy_us,
    present_us,
    effective_rect_frames,
    effective_full_frames,
    fallback_frames,
    cache_hit_count: hits,
    cache_miss_count: misses,
    cache_update_count: updates,
    cache_evict_count: evicts,
    present_count: renderer.present_count() - before_present,
  }
}

///|
fn bench_single_frame(
  renderer : @skia_renderer.SkiaRasterRenderer,
  label : String,
  frame : @core.DrawFrame,
) -> BenchRunResult {
  bench_run_frames(renderer, label, [frame])
}

///|
fn bench_avg_ms(result : BenchRunResult) -> Double {
  if result.frames == 0 {
    0.0
  } else {
    result.elapsed_ms / result.frames.to_double()
  }
}

///|
fn bench_speedup(full : BenchRunResult, cached : BenchRunResult) -> Double {
  let cached_avg = bench_avg_ms(cached)
  if cached_avg <= 0.0 {
    0.0
  } else {
    bench_avg_ms(full) / cached_avg
  }
}

///|
fn bench_avg_phase_ms(total_us : Double, frames : Int32) -> Double {
  if frames == 0 {
    0.0
  } else {
    total_us / frames.to_double() / 1000.0
  }
}

///|
fn bench_result_json(result : BenchRunResult) -> String {
  "{\"label\":\"\{result.label}\",\"frames\":\{result.frames},\"elapsed_ms\":\{result.elapsed_ms},\"avg_ms\":\{bench_avg_ms(result)},\"avg_draw_ms\":\{bench_avg_phase_ms(result.draw_us, result.frames)},\"avg_copy_ms\":\{bench_avg_phase_ms(result.copy_us, result.frames)},\"avg_present_ms\":\{bench_avg_phase_ms(result.present_us, result.frames)},\"effective_rect_frames\":\{result.effective_rect_frames},\"effective_full_frames\":\{result.effective_full_frames},\"fallback_frames\":\{result.fallback_frames},\"cache_hit_count\":\{result.cache_hit_count},\"cache_miss_count\":\{result.cache_miss_count},\"cache_update_count\":\{result.cache_update_count},\"cache_evict_count\":\{result.cache_evict_count},\"present_count\":\{result.present_count}}"
}

///|
fn bench_validate_cached_result(cached : BenchRunResult) -> Unit {
  if cached.cache_hit_count != cached.frames {
    fail_bench(
      "expected one cached-layer hit per measured frame, got \{cached.cache_hit_count} hits for \{cached.frames} frames",
    )
  }
  if cached.cache_miss_count != 0 {
    fail_bench("expected no cached-layer misses during measured hit frames")
  }
}

///|
fn bench_validate_partial_result(partial : BenchRunResult) -> Unit {
  if partial.effective_rect_frames != partial.frames {
    fail_bench(
      "expected one sub-rect effective frame per measured partial frame, got \{partial.effective_rect_frames} for \{partial.frames} frames",
    )
  }
  if partial.effective_full_frames != 0 {
    fail_bench(
      "partial benchmark fell back to full damage during measured frames",
    )
  }
  if partial.fallback_frames != 0 {
    fail_bench(
      "partial benchmark recorded a damage fallback during measured frames",
    )
  }
}

///|
fn bench_frame_pixel_diff(
  left : @skia_renderer.SkiaPixelFrame,
  right : @skia_renderer.SkiaPixelFrame,
) -> (Int32, Int32, Int32) {
  let mut count = 0
  let mut max_delta = 0
  let mut first = -1
  for index in 0..<left.pixels().length() {
    let delta = (left.pixels()[index].to_int() - right.pixels()[index].to_int()).abs()
    if delta != 0 {
      if first < 0 {
        first = index
      }
      count += 1
      if delta > max_delta {
        max_delta = delta
      }
    }
  }
  (count, max_delta, first)
}

///|
fn main {
  if !@skia_renderer.skia_available() {
    fail_bench(
      "Skia is unavailable; configure real native Skia before running this benchmark",
    )
  }
  let frames = bench_env_int("MOUI_SKIA_CACHED_LAYER_BENCH_FRAMES", 120)
  let warmup = bench_env_int("MOUI_SKIA_CACHED_LAYER_BENCH_WARMUP", 20)
  let static_commands = bench_static_layer_commands()
  let spec = bench_layer_spec()
  let update_frame = bench_cached_update_frame(spec, static_commands)
  let cached_frames = bench_cached_hit_frames(spec, static_commands, frames)
  let cached_warmup = bench_cached_hit_frames(spec, static_commands, warmup)
  let full_frames = bench_full_repaint_frames(static_commands, frames)
  let full_warmup = bench_full_repaint_frames(static_commands, warmup)
  let cached_renderer = bench_renderer("skia-cached-layer-benchmark-cached")
  let update = bench_single_frame(cached_renderer, "cache-update", update_frame)
  if update.cache_update_count != 1 {
    // `cache_miss_count` also aggregates cold text-shaping cache fills, so the
    // update frame is validated on retained-layer creation alone.
    fail_bench(
      "expected benchmark cache update frame to create exactly one layer, got updates=\{update.cache_update_count} misses=\{update.cache_miss_count}",
    )
  }
  ignore(bench_run_frames(cached_renderer, "cached-warmup", cached_warmup))
  let cached = bench_run_frames(cached_renderer, "cached-hit", cached_frames)
  bench_validate_cached_result(cached)
  let full_renderer = bench_renderer("skia-cached-layer-benchmark-full")
  ignore(bench_run_frames(full_renderer, "full-warmup", full_warmup))
  let full = bench_run_frames(full_renderer, "full-repaint", full_frames)
  // Damage-limited overlay: the dashboard body is drawn once at full damage,
  // then each measured frame redraws only the union of the previous and current
  // overlay rect. The body commands have no scope commands, so the renderer can
  // honestly honour sub-rect damage and the final pixels must match a
  // full-frame reference.
  let partial_commands = bench_static_body_commands()
  let partial_renderer = bench_renderer(
    "skia-cached-layer-benchmark-subrect",
    surface_damage=@render.SubRect,
  )
  let baseline = bench_single_frame(
    partial_renderer,
    "partial-baseline",
    bench_partial_reference_frame(partial_commands, 0),
  )
  if baseline.effective_full_frames != 1 || baseline.effective_rect_frames != 0 {
    fail_bench("expected the partial baseline to draw a full frame")
  }
  ignore(
    bench_run_frames(
      partial_renderer,
      "partial-warmup",
      bench_partial_frames(partial_commands, 1, warmup),
    ),
  )
  let partial = bench_run_frames(
    partial_renderer,
    "partial-overlay",
    bench_partial_frames(partial_commands, warmup + 1, frames),
  )
  bench_validate_partial_result(partial)
  guard partial_renderer.last_frame() is Some(partial_last) else {
    fail_bench("partial repaint did not present a final frame")
  }
  // Re-render the same final command stream as a full frame on the same
  // renderer, so glyph/cache warm-up state cannot account for a difference.
  let reference = bench_single_frame(
    partial_renderer,
    "partial-reference",
    bench_partial_reference_frame(partial_commands, warmup + frames),
  )
  guard partial_renderer.last_frame() is Some(reference_frame) else {
    fail_bench("partial reference did not present a frame")
  }
  let (partial_pixel_diff_bytes, partial_pixel_diff_max_delta, _) = bench_frame_pixel_diff(
    partial_last, reference_frame,
  )
  // Replaying a static body through a damage clip can change Skia's
  // antialiasing path at the clip boundary by a few levels. Bound that seam
  // instead of demanding byte identity from a clipped redraw.
  let pixel_diff_limit = partial_last.pixels().length() / 1000 + 1
  if partial_pixel_diff_max_delta > 8 ||
    partial_pixel_diff_bytes > pixel_diff_limit {
    fail_bench(
      "partial repaint final frame diverged from the full-frame reference: differing_bytes=\{partial_pixel_diff_bytes} max_delta=\{partial_pixel_diff_max_delta}",
    )
  }
  println(
    "MoUI Skia cached layer benchmark frames=\{frames} warmup=\{warmup} static_commands=\{static_commands.length()} update_avg_ms=\{bench_avg_ms(update)} cached_avg_ms=\{bench_avg_ms(cached)} full_avg_ms=\{bench_avg_ms(full)} speedup=\{bench_speedup(full, cached)} partial_avg_ms=\{bench_avg_ms(partial)} partial_draw_ms=\{bench_avg_phase_ms(partial.draw_us, partial.frames)} partial_copy_ms=\{bench_avg_phase_ms(partial.copy_us, partial.frames)} partial_present_ms=\{bench_avg_phase_ms(partial.present_us, partial.frames)} partial_full_reference_draw_ms=\{bench_avg_phase_ms(reference.draw_us, reference.frames)} partial_full_reference_copy_ms=\{bench_avg_phase_ms(reference.copy_us, reference.frames)} partial_full_reference_present_ms=\{bench_avg_phase_ms(reference.present_us, reference.frames)} partial_pixel_diff_bytes=\{partial_pixel_diff_bytes} partial_pixel_diff_max_delta=\{partial_pixel_diff_max_delta} cache_hits=\{cached.cache_hit_count} cache_misses=\{cached.cache_miss_count}",
  )
  println(
    "{\"benchmark\":\"skia-cached-layer-static-boundary\",\"frames\":\{frames},\"warmup\":\{warmup},\"static_command_count\":\{static_commands.length()},\"partial_command_count\":\{partial_commands.length()},\"partial_pixel_diff_bytes\":\{partial_pixel_diff_bytes},\"partial_pixel_diff_max_delta\":\{partial_pixel_diff_max_delta},\"update\":\{bench_result_json(update)},\"cached_hit\":\{bench_result_json(cached)},\"full_repaint\":\{bench_result_json(full)},\"partial_overlay\":\{bench_result_json(partial)},\"partial_full_reference\":\{bench_result_json(reference)},\"speedup\":\{bench_speedup(full, cached)}}",
  )
}

///|
extern "c" fn bench_now_ms() -> Double = "moui_skia_cached_layer_benchmark_now_ms"

///|
struct BenchRunResult {
  label : String
  frames : Int
  elapsed_ms : Double
  cache_hit_count : Int
  cache_miss_count : Int
  cache_update_count : Int
  cache_evict_count : Int
  present_count : Int
}

///|
fn[T] fail_bench(message : String) -> T {
  println(message)
  abort("MoUI Skia cached layer benchmark failed")
}

///|
fn bench_parse_positive_int(value : String, fallback : Int) -> Int {
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
fn bench_env_int(name : String, fallback : Int) -> Int {
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
  a? : Double = 1.0,
) -> @core.Color {
  @core.Color::rgba(r~, g~, b~, a~)
}

///|
fn bench_font(size : Double, weight? : Int = 400) -> @core.FontSpec {
  @core.FontSpec::new(size~, weight~)
}

///|
fn bench_static_layer_commands() -> Array[@core.DrawCommand] {
  let commands : Array[@core.DrawCommand] = []
  let layer = bench_layer_frame()
  commands.push(
    @core.DrawCommand::FillRoundedRectBrush(
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
    @core.DrawCommand::StrokeRoundedRect(
      @core.RoundedRect::new(rect=layer, radius=16.0),
      bench_color(0.18, 0.24, 0.30, a=0.28),
      1.0,
    ),
  )
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="MoUI renderer cache benchmark",
        frame=@core.Rect::new(x=56.0, y=54.0, width=430.0, height=32.0),
        font=bench_font(22.0, weight=700),
        color=bench_color(0.05, 0.08, 0.12),
        align=@core.TextAlign::TextStart,
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
        @core.DrawCommand::DrawShadow(
          @core.ShadowSpec::new(
            rect=@core.RoundedRect::new(rect~, radius=8.0),
            color=bench_color(0.0, 0.0, 0.0, a=0.08),
            offset=@core.Point::new(x=0.0, y=2.0),
            blur_radius=6.0,
          ),
        ),
      )
      commands.push(
        @core.DrawCommand::FillRoundedRectBrush(
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
        @core.DrawCommand::StrokeRoundedRect(
          @core.RoundedRect::new(rect~, radius=8.0),
          bench_color(0.17, 0.20, 0.24, a=0.16),
          1.0,
        ),
      )
      commands.push(
        @core.DrawCommand::DrawText(
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
            align=@core.TextAlign::TextStart,
          ),
        ),
      )
    }
  }
  for index in 0..<24 {
    let x = 72.0 + (index % 12).to_double() * 56.0
    let y = 520.0 + (index / 12).to_double() * 18.0
    commands.push(
      @core.DrawCommand::DrawPath(
        @core.PathSpec::new(
          verbs=[
            @core.PathVerb::MoveTo(@core.Point::new(x~, y~)),
            @core.PathVerb::CubicTo(
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
  commands.push(
    @core.DrawCommand::PushLayer(
      @core.LayerSpec::new(
        opacity=0.64,
        mask=@core.LayerMask::RoundedMask(
          @core.RoundedRect::new(
            rect=@core.Rect::new(x=548.0, y=66.0, width=190.0, height=86.0),
            radius=14.0,
          ),
        ),
        offscreen=true,
      ),
    ),
  )
  commands.push(
    @core.DrawCommand::PushFilter(@core.FilterEffect::Saturate(1.35)),
  )
  commands.push(
    @core.DrawCommand::FillRoundedRectBrush(
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
  commands.push(@core.DrawCommand::PopFilter)
  commands.push(@core.DrawCommand::PopLayer)
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
fn bench_overlay_rect(frame_index : Int) -> @core.Rect {
  let x = 70.0 + (frame_index * 13 % 620).to_double()
  @core.Rect::new(x~, y=458.0, width=28.0, height=28.0)
}

///|
fn bench_append_overlay(
  commands : Array[@core.DrawCommand],
  frame_index : Int,
) -> Unit {
  let rect = bench_overlay_rect(frame_index)
  commands.push(
    @core.DrawCommand::FillRoundedRect(
      @core.RoundedRect::new(rect~, radius=7.0),
      bench_color(0.98, 0.18, 0.24, a=0.86),
    ),
  )
  commands.push(
    @core.DrawCommand::StrokeRoundedRect(
      @core.RoundedRect::new(rect~, radius=7.0),
      bench_color(0.10, 0.04, 0.05, a=0.62),
      1.0,
    ),
  )
}

///|
fn bench_overlay_damage(frame_index : Int) -> @core.DamageRegion {
  @core.DamageRegion::from_rects(
    [bench_overlay_rect(frame_index).inflate(2.0)],
    bench_surface_rect(),
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
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::BeginRetainedLayer(spec),
  ]
  bench_append_static(commands, static_commands)
  commands.push(@core.DrawCommand::EndRetainedLayer(spec.key))
  bench_append_overlay(commands, 0)
  bench_draw_frame(commands, @core.DamageRegion::full("benchmark cache update"))
}

///|
fn bench_cached_hit_frame(
  spec : @core.RetainedLayerSpec,
  static_commands : Array[@core.DrawCommand],
  frame_index : Int,
) -> @core.DrawFrame {
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::BeginRetainedLayer(spec),
  ]
  bench_append_static(commands, static_commands)
  commands.push(@core.DrawCommand::EndRetainedLayer(spec.key))
  bench_append_overlay(commands, frame_index)
  bench_draw_frame(commands, bench_overlay_damage(frame_index))
}

///|
fn bench_full_repaint_frame(
  static_commands : Array[@core.DrawCommand],
  frame_index : Int,
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
  frames : Int,
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
  frames : Int,
) -> Array[@core.DrawFrame] {
  let result : Array[@core.DrawFrame] = []
  for index in 0..<frames {
    result.push(bench_full_repaint_frame(static_commands, index + 1))
  }
  result
}

///|
fn bench_renderer(label : String) -> @skia_renderer.SkiaRasterRenderer {
  let target = @skia_renderer.SkiaPresentTarget::new(description=label, present=_frame => {
    true
  })
  @skia_renderer.create_with_present_target(bench_metrics(), target) catch {
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
  for frame in frames {
    let result = renderer.render_frame(frame)
    if !result.presented {
      fail_bench("\{label} produced an unpresented frame")
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
fn bench_result_json(result : BenchRunResult) -> String {
  "{\"label\":\"\{result.label}\",\"frames\":\{result.frames},\"elapsed_ms\":\{result.elapsed_ms},\"avg_ms\":\{bench_avg_ms(result)},\"cache_hit_count\":\{result.cache_hit_count},\"cache_miss_count\":\{result.cache_miss_count},\"cache_update_count\":\{result.cache_update_count},\"cache_evict_count\":\{result.cache_evict_count},\"present_count\":\{result.present_count}}"
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
  if update.cache_update_count != 1 || update.cache_miss_count != 1 {
    fail_bench(
      "expected benchmark cache update frame to create exactly one layer",
    )
  }
  ignore(bench_run_frames(cached_renderer, "cached-warmup", cached_warmup))
  let cached = bench_run_frames(cached_renderer, "cached-hit", cached_frames)
  bench_validate_cached_result(cached)
  let full_renderer = bench_renderer("skia-cached-layer-benchmark-full")
  ignore(bench_run_frames(full_renderer, "full-warmup", full_warmup))
  let full = bench_run_frames(full_renderer, "full-repaint", full_frames)
  println(
    "MoUI Skia cached layer benchmark frames=\{frames} warmup=\{warmup} static_commands=\{static_commands.length()} update_avg_ms=\{bench_avg_ms(update)} cached_avg_ms=\{bench_avg_ms(cached)} full_avg_ms=\{bench_avg_ms(full)} speedup=\{bench_speedup(full, cached)} cache_hits=\{cached.cache_hit_count} cache_misses=\{cached.cache_miss_count}",
  )
  println(
    "{\"benchmark\":\"skia-cached-layer-static-boundary\",\"frames\":\{frames},\"warmup\":\{warmup},\"static_command_count\":\{static_commands.length()},\"update\":\{bench_result_json(update)},\"cached_hit\":\{bench_result_json(cached)},\"full_repaint\":\{bench_result_json(full)},\"speedup\":\{bench_speedup(full, cached)}}",
  )
}

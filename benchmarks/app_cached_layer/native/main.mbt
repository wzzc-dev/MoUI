///|
extern "c" fn app_bench_now_ms() -> Double = "moui_app_cached_layer_benchmark_now_ms"

///|
struct AppBenchPipelineCounters {
  rebuild_pass_count : Int
  layout_pass_count : Int
  paint_pass_count : Int
  draw_command_build_count : Int
}

///|
struct CachedFrameSample {
  submitted_frames : Int
  elapsed_draw_ms : Double
  elapsed_render_ms : Double
  cache_hit_count : Int
  cache_miss_count : Int
  cache_update_count : Int
  cache_evict_count : Int
  present_count : Int
  followup_count : Int
  command_count_sum : Int
  command_count_max : Int
  damage_rect_count_sum : Int
  damage_rect_count_max : Int
  damage_full_count : Int
  damage_rect_frame_count : Int
  damage_empty_count : Int
  begin_cached_layer_count : Int
  draw_cached_layer_count : Int
  overlay_only_frame_count : Int
  rebuild_pass_count : Int
  layout_pass_count : Int
  paint_pass_count : Int
  draw_command_build_count : Int
  first_damage_full_reason : String
}

///|
struct CachedRunResult {
  label : String
  frames : Int
  submitted_frames : Int
  elapsed_draw_ms : Double
  elapsed_render_ms : Double
  cache_hit_count : Int
  cache_miss_count : Int
  cache_update_count : Int
  cache_evict_count : Int
  present_count : Int
  followup_count : Int
  command_count_sum : Int
  command_count_max : Int
  damage_rect_count_sum : Int
  damage_rect_count_max : Int
  damage_full_count : Int
  damage_rect_frame_count : Int
  damage_empty_count : Int
  begin_cached_layer_count : Int
  draw_cached_layer_count : Int
  overlay_only_frame_count : Int
  rebuild_pass_count : Int
  layout_pass_count : Int
  paint_pass_count : Int
  draw_command_build_count : Int
  initial_begin_cached_layer_count : Int
  initial_draw_cached_layer_count : Int
  initial_cache_update_count : Int
  warmup_begin_cached_layer_count : Int
  warmup_draw_cached_layer_count : Int
  warmup_cache_hit_count : Int
  warmup_cache_update_count : Int
  first_damage_full_reason : String
}

///|
struct FullFrameSample {
  elapsed_draw_ms : Double
  elapsed_render_ms : Double
  command_count : Int
  rebuild_pass_count : Int
  layout_pass_count : Int
  paint_pass_count : Int
  draw_command_build_count : Int
}

///|
struct FullRunResult {
  label : String
  frames : Int
  elapsed_draw_ms : Double
  elapsed_render_ms : Double
  present_count : Int
  command_count_sum : Int
  command_count_max : Int
  rebuild_pass_count : Int
  layout_pass_count : Int
  paint_pass_count : Int
  draw_command_build_count : Int
}

///|
fn[T] fail_bench(message : String) -> T {
  println(message)
  abort("MoUI real app cached layer benchmark failed")
}

///|
fn app_bench_parse_positive_int(value : String, fallback : Int) -> Int {
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
fn app_bench_env_int(name : String, fallback : Int) -> Int {
  match @env.get_env_var(name) {
    Some(value) => app_bench_parse_positive_int(value, fallback)
    None => fallback
  }
}

///|
fn app_bench_metrics(
  width : Double,
  height : Double,
) -> @render.RendererSurfaceMetrics {
  @render.RendererSurfaceMetrics::from_logical(
    size=@core.Size::new(width~, height~),
  )
}

///|
fn app_bench_renderer(
  label : String,
  width : Double,
  height : Double,
) -> @skia_renderer.SkiaRasterRenderer {
  let target = @skia_renderer.SkiaPresentTarget::new(description=label, present=_frame => {
    true
  })
  @skia_renderer.create_with_present_target(
    app_bench_metrics(width, height),
    target,
  ) catch {
    err => fail_bench("expected Skia renderer for \{label}: \{err.message()}")
  }
}

///|
fn app_bench_assert_renderer_supported(
  renderer : @skia_renderer.SkiaRasterRenderer,
  label : String,
) -> Unit {
  if renderer.unsupported_command_count() != 0 {
    let diagnostics = renderer.unsupported_command_diagnostics()
    if diagnostics.length() > 0 {
      fail_bench(
        "\{label} recorded unsupported Skia command: \{diagnostics[0].command} \{diagnostics[0].reason}",
      )
    }
    fail_bench("\{label} recorded unsupported Skia commands")
  }
}

///|
fn app_bench_pipeline_counters(
  runtime : @core.AppRuntime,
) -> AppBenchPipelineCounters {
  let snapshot = runtime.inspector_snapshot().runtime
  {
    rebuild_pass_count: snapshot.rebuild_pass_count,
    layout_pass_count: snapshot.layout_pass_count,
    paint_pass_count: snapshot.paint_pass_count,
    draw_command_build_count: snapshot.draw_command_build_count,
  }
}

///|
fn app_bench_pipeline_delta(
  before : AppBenchPipelineCounters,
  after : AppBenchPipelineCounters,
) -> AppBenchPipelineCounters {
  {
    rebuild_pass_count: after.rebuild_pass_count - before.rebuild_pass_count,
    layout_pass_count: after.layout_pass_count - before.layout_pass_count,
    paint_pass_count: after.paint_pass_count - before.paint_pass_count,
    draw_command_build_count: after.draw_command_build_count -
    before.draw_command_build_count,
  }
}

///|
fn app_bench_pipeline_plus(
  left : AppBenchPipelineCounters,
  right : AppBenchPipelineCounters,
) -> AppBenchPipelineCounters {
  {
    rebuild_pass_count: left.rebuild_pass_count + right.rebuild_pass_count,
    layout_pass_count: left.layout_pass_count + right.layout_pass_count,
    paint_pass_count: left.paint_pass_count + right.paint_pass_count,
    draw_command_build_count: left.draw_command_build_count +
    right.draw_command_build_count,
  }
}

///|
fn app_bench_damage_full_count(damage : @core.DamageRegion) -> Int {
  if damage.kind() == "full" {
    1
  } else {
    0
  }
}

///|
fn app_bench_damage_rect_frame_count(damage : @core.DamageRegion) -> Int {
  if damage.kind() == "rects" {
    1
  } else {
    0
  }
}

///|
fn app_bench_damage_empty_count(damage : @core.DamageRegion) -> Int {
  if damage.kind() == "empty" {
    1
  } else {
    0
  }
}

///|
fn app_bench_first_full_reason(
  current : String,
  damage : @core.DamageRegion,
) -> String {
  if current != "" {
    current
  } else {
    damage.full_reason()
  }
}

///|
fn app_bench_begin_cached_layer_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  let mut count = 0
  for command in commands {
    if command is @core.DrawCommand::BeginCachedLayer(_) {
      count = count + 1
    }
  }
  count
}

///|
fn app_bench_draw_cached_layer_count(
  commands : Array[@core.DrawCommand],
) -> Int {
  let mut count = 0
  for command in commands {
    if command is @core.DrawCommand::DrawCachedLayer(_) {
      count = count + 1
    }
  }
  count
}

///|
fn app_bench_cached_frame(
  renderer : @skia_renderer.SkiaRasterRenderer,
  runtime : @core.AppRuntime,
  label : String,
) -> CachedFrameSample {
  let pipeline_before = app_bench_pipeline_counters(runtime)
  let draw_start = app_bench_now_ms()
  let frame = runtime.draw_frame()
  let mut draw_ms = app_bench_now_ms() - draw_start
  let mut submitted_frames = 1
  let mut command_count_sum = frame.commands.length()
  let mut command_count_max = frame.commands.length()
  let mut damage_rect_count_sum = frame.damage.rect_count()
  let mut damage_rect_count_max = frame.damage.rect_count()
  let mut damage_full_count = app_bench_damage_full_count(frame.damage)
  let mut damage_rect_frame_count = app_bench_damage_rect_frame_count(
    frame.damage,
  )
  let mut damage_empty_count = app_bench_damage_empty_count(frame.damage)
  let mut begin_cached_layer_count = app_bench_begin_cached_layer_count(
    frame.commands,
  )
  let mut draw_cached_layer_count = app_bench_draw_cached_layer_count(
    frame.commands,
  )
  let mut first_damage_full_reason = app_bench_first_full_reason(
    "",
    frame.damage,
  )
  let render_start = app_bench_now_ms()
  let result = renderer.render_frame(frame)
  let mut render_ms = app_bench_now_ms() - render_start
  let mut cache_hit_count = result.cache_hit_count
  let mut cache_miss_count = result.cache_miss_count
  let mut cache_update_count = result.cache_update_count
  let mut cache_evict_count = result.cache_evict_count
  let mut present_count = if result.presented { 1 } else { 0 }
  let mut followup_count = 0
  let mut pipeline = app_bench_pipeline_delta(
    pipeline_before,
    app_bench_pipeline_counters(runtime),
  )
  let mut pending_result = result
  while !pending_result.presented && followup_count < 32 {
    if pending_result.cache_miss_count == 0 ||
      pending_result.missing_layer_keys.length() == 0 {
      fail_bench(
        "\{label} produced an unpresented frame without cache-miss keys",
      )
    }
    for key in pending_result.missing_layer_keys {
      runtime.invalidate_cached_layer_key(key)
    }
    followup_count = followup_count + 1
    submitted_frames = submitted_frames + 1
    let follow_pipeline_before = app_bench_pipeline_counters(runtime)
    let follow_draw_start = app_bench_now_ms()
    let follow_frame = runtime.draw_frame()
    draw_ms = draw_ms + app_bench_now_ms() - follow_draw_start
    command_count_sum = command_count_sum + follow_frame.commands.length()
    command_count_max = command_count_max.max(follow_frame.commands.length())
    damage_rect_count_sum = damage_rect_count_sum +
      follow_frame.damage.rect_count()
    damage_rect_count_max = damage_rect_count_max.max(
      follow_frame.damage.rect_count(),
    )
    damage_full_count = damage_full_count +
      app_bench_damage_full_count(follow_frame.damage)
    damage_rect_frame_count = damage_rect_frame_count +
      app_bench_damage_rect_frame_count(follow_frame.damage)
    damage_empty_count = damage_empty_count +
      app_bench_damage_empty_count(follow_frame.damage)
    begin_cached_layer_count = begin_cached_layer_count +
      app_bench_begin_cached_layer_count(follow_frame.commands)
    draw_cached_layer_count = draw_cached_layer_count +
      app_bench_draw_cached_layer_count(follow_frame.commands)
    first_damage_full_reason = app_bench_first_full_reason(
      first_damage_full_reason,
      follow_frame.damage,
    )
    let follow_render_start = app_bench_now_ms()
    let follow_result = renderer.render_frame(follow_frame)
    render_ms = render_ms + app_bench_now_ms() - follow_render_start
    cache_hit_count = cache_hit_count + follow_result.cache_hit_count
    cache_miss_count = cache_miss_count + follow_result.cache_miss_count
    cache_update_count = cache_update_count + follow_result.cache_update_count
    cache_evict_count = cache_evict_count + follow_result.cache_evict_count
    pipeline = app_bench_pipeline_plus(
      pipeline,
      app_bench_pipeline_delta(
        follow_pipeline_before,
        app_bench_pipeline_counters(runtime),
      ),
    )
    if follow_result.presented {
      present_count = present_count + 1
    }
    pending_result = follow_result
  }
  if !pending_result.presented {
    fail_bench("\{label} cache-miss follow-up frame was not presented")
  }
  let overlay_only_frame_count = if cache_update_count == 0 &&
    cache_evict_count == 0 &&
    cache_miss_count == 0 {
    1
  } else {
    0
  }
  {
    submitted_frames,
    elapsed_draw_ms: draw_ms,
    elapsed_render_ms: render_ms,
    cache_hit_count,
    cache_miss_count,
    cache_update_count,
    cache_evict_count,
    present_count,
    followup_count,
    command_count_sum,
    command_count_max,
    damage_rect_count_sum,
    damage_rect_count_max,
    damage_full_count,
    damage_rect_frame_count,
    damage_empty_count,
    begin_cached_layer_count,
    draw_cached_layer_count,
    overlay_only_frame_count,
    rebuild_pass_count: pipeline.rebuild_pass_count,
    layout_pass_count: pipeline.layout_pass_count,
    paint_pass_count: pipeline.paint_pass_count,
    draw_command_build_count: pipeline.draw_command_build_count,
    first_damage_full_reason,
  }
}

///|
fn app_bench_full_frame(
  renderer : @skia_renderer.SkiaRasterRenderer,
  runtime : @core.AppRuntime,
  label : String,
) -> FullFrameSample {
  let pipeline_before = app_bench_pipeline_counters(runtime)
  let draw_start = app_bench_now_ms()
  let commands = runtime.draw_commands()
  let draw_ms = app_bench_now_ms() - draw_start
  let render_start = app_bench_now_ms()
  renderer.render(commands) catch {
    err => fail_bench("\{label} full repaint render failed: \{err.message()}")
  }
  let render_ms = app_bench_now_ms() - render_start
  let pipeline = app_bench_pipeline_delta(
    pipeline_before,
    app_bench_pipeline_counters(runtime),
  )
  {
    elapsed_draw_ms: draw_ms,
    elapsed_render_ms: render_ms,
    command_count: commands.length(),
    rebuild_pass_count: pipeline.rebuild_pass_count,
    layout_pass_count: pipeline.layout_pass_count,
    paint_pass_count: pipeline.paint_pass_count,
    draw_command_build_count: pipeline.draw_command_build_count,
  }
}

///|
fn app_bench_showcase_runtime(
  width : Double,
  height : Double,
) -> @core.AppRuntime {
  @showcase.ShowcaseModel::new()
  .update(@showcase.ShowcaseMsg::SelectSection("runtime-renderer"))
  .runtime(width~, height~)
}

///|
fn app_bench_markdown_runtime(
  width : Double,
  height : Double,
) -> @core.AppRuntime {
  @markdown.MarkdownEditorApp::new().runtime(width~, height~)
}

///|
fn app_bench_no_prepare(_runtime : @core.AppRuntime) -> Unit {
  ()
}

///|
fn app_bench_prepare_markdown_input(runtime : @core.AppRuntime) -> Unit {
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
}

///|
fn app_bench_dispatch_showcase_scroll(
  runtime : @core.AppRuntime,
  index : Int,
) -> Unit {
  let direction = if index / 18 % 2 == 0 { -44.0 } else { 44.0 }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=470.0, y=260.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=direction),
      ),
    ),
  )
}

///|
fn app_bench_dispatch_showcase_sidebar_hover(
  runtime : @core.AppRuntime,
  index : Int,
) -> Unit {
  let y = if index % 2 == 0 { 208.0 } else { 250.0 }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=42.0, y~),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
}

///|
fn app_bench_markdown_token(index : Int) -> String {
  let tokens = ["M", "o", "U", "I", " ", "c", "a", "c", "h", "e", " "]
  tokens[index % tokens.length()]
}

///|
fn app_bench_dispatch_markdown_input(
  runtime : @core.AppRuntime,
  index : Int,
) -> Unit {
  runtime.dispatch_event(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::InsertText(app_bench_markdown_token(index)),
    ),
  )
}

///|
fn app_bench_dispatch_markdown_scroll(
  runtime : @core.AppRuntime,
  index : Int,
) -> Unit {
  let direction = if index / 18 % 2 == 0 { -42.0 } else { 42.0 }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=470.0, y=260.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=direction),
      ),
    ),
  )
}

///|
fn app_bench_dispatch_markdown_caret_overlay(
  runtime : @core.AppRuntime,
  index : Int,
) -> Unit {
  let key = if index % 2 == 0 { "ArrowRight" } else { "ArrowLeft" }
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key~)),
  )
}

///|
fn app_bench_run_cached(
  label : String,
  width : Double,
  height : Double,
  make_runtime : (Double, Double) -> @core.AppRuntime,
  prepare : (@core.AppRuntime) -> Unit,
  drive : (@core.AppRuntime, Int) -> Unit,
  frames : Int,
  warmup : Int,
) -> CachedRunResult {
  let runtime = make_runtime(width, height)
  prepare(runtime)
  let renderer = app_bench_renderer("\{label}-cached", width, height)
  let initial_sample = app_bench_cached_frame(
    renderer,
    runtime,
    "\{label} initial",
  )
  let mut warmup_begin_cached_layer_count = 0
  let mut warmup_draw_cached_layer_count = 0
  let mut warmup_cache_hit_count = 0
  let mut warmup_cache_update_count = 0
  for index in 0..<warmup {
    drive(runtime, index)
    let warmup_sample = app_bench_cached_frame(
      renderer,
      runtime,
      "\{label} warmup",
    )
    warmup_begin_cached_layer_count = warmup_begin_cached_layer_count +
      warmup_sample.begin_cached_layer_count
    warmup_draw_cached_layer_count = warmup_draw_cached_layer_count +
      warmup_sample.draw_cached_layer_count
    warmup_cache_hit_count = warmup_cache_hit_count +
      warmup_sample.cache_hit_count
    warmup_cache_update_count = warmup_cache_update_count +
      warmup_sample.cache_update_count
  }
  let mut submitted_frames = 0
  let mut elapsed_draw_ms = 0.0
  let mut elapsed_render_ms = 0.0
  let mut cache_hit_count = 0
  let mut cache_miss_count = 0
  let mut cache_update_count = 0
  let mut cache_evict_count = 0
  let mut present_count = 0
  let mut followup_count = 0
  let mut command_count_sum = 0
  let mut command_count_max = 0
  let mut damage_rect_count_sum = 0
  let mut damage_rect_count_max = 0
  let mut damage_full_count = 0
  let mut damage_rect_frame_count = 0
  let mut damage_empty_count = 0
  let mut begin_cached_layer_count = 0
  let mut draw_cached_layer_count = 0
  let mut overlay_only_frame_count = 0
  let mut rebuild_pass_count = 0
  let mut layout_pass_count = 0
  let mut paint_pass_count = 0
  let mut draw_command_build_count = 0
  let mut first_damage_full_reason = ""
  for index in 0..<frames {
    drive(runtime, warmup + index)
    let sample = app_bench_cached_frame(renderer, runtime, "\{label} measured")
    submitted_frames = submitted_frames + sample.submitted_frames
    elapsed_draw_ms = elapsed_draw_ms + sample.elapsed_draw_ms
    elapsed_render_ms = elapsed_render_ms + sample.elapsed_render_ms
    cache_hit_count = cache_hit_count + sample.cache_hit_count
    cache_miss_count = cache_miss_count + sample.cache_miss_count
    cache_update_count = cache_update_count + sample.cache_update_count
    cache_evict_count = cache_evict_count + sample.cache_evict_count
    present_count = present_count + sample.present_count
    followup_count = followup_count + sample.followup_count
    command_count_sum = command_count_sum + sample.command_count_sum
    command_count_max = command_count_max.max(sample.command_count_max)
    damage_rect_count_sum = damage_rect_count_sum + sample.damage_rect_count_sum
    damage_rect_count_max = damage_rect_count_max.max(
      sample.damage_rect_count_max,
    )
    damage_full_count = damage_full_count + sample.damage_full_count
    damage_rect_frame_count = damage_rect_frame_count +
      sample.damage_rect_frame_count
    damage_empty_count = damage_empty_count + sample.damage_empty_count
    begin_cached_layer_count = begin_cached_layer_count +
      sample.begin_cached_layer_count
    draw_cached_layer_count = draw_cached_layer_count +
      sample.draw_cached_layer_count
    overlay_only_frame_count = overlay_only_frame_count +
      sample.overlay_only_frame_count
    rebuild_pass_count = rebuild_pass_count + sample.rebuild_pass_count
    layout_pass_count = layout_pass_count + sample.layout_pass_count
    paint_pass_count = paint_pass_count + sample.paint_pass_count
    draw_command_build_count = draw_command_build_count +
      sample.draw_command_build_count
    if first_damage_full_reason == "" {
      first_damage_full_reason = sample.first_damage_full_reason
    }
  }
  app_bench_assert_renderer_supported(renderer, label)
  if present_count != frames {
    fail_bench(
      "\{label} presented \{present_count} frames for \{frames} app frames",
    )
  }
  {
    label,
    frames,
    submitted_frames,
    elapsed_draw_ms,
    elapsed_render_ms,
    cache_hit_count,
    cache_miss_count,
    cache_update_count,
    cache_evict_count,
    present_count,
    followup_count,
    command_count_sum,
    command_count_max,
    damage_rect_count_sum,
    damage_rect_count_max,
    damage_full_count,
    damage_rect_frame_count,
    damage_empty_count,
    begin_cached_layer_count,
    draw_cached_layer_count,
    overlay_only_frame_count,
    rebuild_pass_count,
    layout_pass_count,
    paint_pass_count,
    draw_command_build_count,
    initial_begin_cached_layer_count: initial_sample.begin_cached_layer_count,
    initial_draw_cached_layer_count: initial_sample.draw_cached_layer_count,
    initial_cache_update_count: initial_sample.cache_update_count,
    warmup_begin_cached_layer_count,
    warmup_draw_cached_layer_count,
    warmup_cache_hit_count,
    warmup_cache_update_count,
    first_damage_full_reason,
  }
}

///|
fn app_bench_run_full(
  label : String,
  width : Double,
  height : Double,
  make_runtime : (Double, Double) -> @core.AppRuntime,
  prepare : (@core.AppRuntime) -> Unit,
  drive : (@core.AppRuntime, Int) -> Unit,
  frames : Int,
  warmup : Int,
) -> FullRunResult {
  let runtime = make_runtime(width, height)
  prepare(runtime)
  let renderer = app_bench_renderer("\{label}-full", width, height)
  ignore(app_bench_full_frame(renderer, runtime, "\{label} initial"))
  for index in 0..<warmup {
    drive(runtime, index)
    ignore(app_bench_full_frame(renderer, runtime, "\{label} warmup"))
  }
  let before_present = renderer.present_count()
  let mut elapsed_draw_ms = 0.0
  let mut elapsed_render_ms = 0.0
  let mut command_count_sum = 0
  let mut command_count_max = 0
  let mut rebuild_pass_count = 0
  let mut layout_pass_count = 0
  let mut paint_pass_count = 0
  let mut draw_command_build_count = 0
  for index in 0..<frames {
    drive(runtime, warmup + index)
    let sample = app_bench_full_frame(renderer, runtime, "\{label} measured")
    elapsed_draw_ms = elapsed_draw_ms + sample.elapsed_draw_ms
    elapsed_render_ms = elapsed_render_ms + sample.elapsed_render_ms
    command_count_sum = command_count_sum + sample.command_count
    command_count_max = command_count_max.max(sample.command_count)
    rebuild_pass_count = rebuild_pass_count + sample.rebuild_pass_count
    layout_pass_count = layout_pass_count + sample.layout_pass_count
    paint_pass_count = paint_pass_count + sample.paint_pass_count
    draw_command_build_count = draw_command_build_count +
      sample.draw_command_build_count
  }
  app_bench_assert_renderer_supported(renderer, label)
  {
    label,
    frames,
    elapsed_draw_ms,
    elapsed_render_ms,
    present_count: renderer.present_count() - before_present,
    command_count_sum,
    command_count_max,
    rebuild_pass_count,
    layout_pass_count,
    paint_pass_count,
    draw_command_build_count,
  }
}

///|
fn app_bench_avg(total : Double, frames : Int) -> Double {
  if frames == 0 {
    0.0
  } else {
    total / frames.to_double()
  }
}

///|
fn app_bench_avg_int(total : Int, frames : Int) -> Double {
  if frames == 0 {
    0.0
  } else {
    total.to_double() / frames.to_double()
  }
}

///|
fn CachedRunResult::total_ms(self : CachedRunResult) -> Double {
  self.elapsed_draw_ms + self.elapsed_render_ms
}

///|
fn FullRunResult::total_ms(self : FullRunResult) -> Double {
  self.elapsed_draw_ms + self.elapsed_render_ms
}

///|
fn app_bench_speedup(full : FullRunResult, cached : CachedRunResult) -> Double {
  let cached_avg = app_bench_avg(cached.total_ms(), cached.frames)
  if cached_avg <= 0.0 {
    0.0
  } else {
    app_bench_avg(full.total_ms(), full.frames) / cached_avg
  }
}

///|
fn app_bench_cached_json(result : CachedRunResult) -> String {
  "{\"label\":\"\{result.label}\",\"frames\":\{result.frames},\"submitted_frames\":\{result.submitted_frames},\"avg_draw_ms\":\{app_bench_avg(result.elapsed_draw_ms, result.frames)},\"avg_render_ms\":\{app_bench_avg(result.elapsed_render_ms, result.frames)},\"avg_total_ms\":\{app_bench_avg(result.total_ms(), result.frames)},\"cache_hit_count\":\{result.cache_hit_count},\"cache_miss_count\":\{result.cache_miss_count},\"cache_update_count\":\{result.cache_update_count},\"cache_evict_count\":\{result.cache_evict_count},\"present_count\":\{result.present_count},\"followup_count\":\{result.followup_count},\"overlay_only_frames\":\{result.overlay_only_frame_count},\"avg_command_count\":\{app_bench_avg_int(result.command_count_sum, result.frames)},\"max_command_count\":\{result.command_count_max},\"rebuild_pass_count\":\{result.rebuild_pass_count},\"layout_pass_count\":\{result.layout_pass_count},\"paint_pass_count\":\{result.paint_pass_count},\"draw_command_build_count\":\{result.draw_command_build_count},\"avg_rebuild_pass_count\":\{app_bench_avg_int(result.rebuild_pass_count, result.frames)},\"avg_layout_pass_count\":\{app_bench_avg_int(result.layout_pass_count, result.frames)},\"avg_paint_pass_count\":\{app_bench_avg_int(result.paint_pass_count, result.frames)},\"avg_draw_command_build_count\":\{app_bench_avg_int(result.draw_command_build_count, result.frames)},\"avg_damage_rect_count\":\{app_bench_avg_int(result.damage_rect_count_sum, result.frames)},\"max_damage_rect_count\":\{result.damage_rect_count_max},\"damage_full_count\":\{result.damage_full_count},\"damage_rect_frame_count\":\{result.damage_rect_frame_count},\"damage_empty_count\":\{result.damage_empty_count},\"begin_cached_layer_count\":\{result.begin_cached_layer_count},\"draw_cached_layer_count\":\{result.draw_cached_layer_count},\"initial_begin_cached_layer_count\":\{result.initial_begin_cached_layer_count},\"initial_draw_cached_layer_count\":\{result.initial_draw_cached_layer_count},\"initial_cache_update_count\":\{result.initial_cache_update_count},\"warmup_begin_cached_layer_count\":\{result.warmup_begin_cached_layer_count},\"warmup_draw_cached_layer_count\":\{result.warmup_draw_cached_layer_count},\"warmup_cache_hit_count\":\{result.warmup_cache_hit_count},\"warmup_cache_update_count\":\{result.warmup_cache_update_count},\"first_damage_full_reason\":\"\{result.first_damage_full_reason}\"}"
}

///|
fn app_bench_full_json(result : FullRunResult) -> String {
  "{\"label\":\"\{result.label}\",\"frames\":\{result.frames},\"avg_draw_ms\":\{app_bench_avg(result.elapsed_draw_ms, result.frames)},\"avg_render_ms\":\{app_bench_avg(result.elapsed_render_ms, result.frames)},\"avg_total_ms\":\{app_bench_avg(result.total_ms(), result.frames)},\"present_count\":\{result.present_count},\"avg_command_count\":\{app_bench_avg_int(result.command_count_sum, result.frames)},\"max_command_count\":\{result.command_count_max},\"rebuild_pass_count\":\{result.rebuild_pass_count},\"layout_pass_count\":\{result.layout_pass_count},\"paint_pass_count\":\{result.paint_pass_count},\"draw_command_build_count\":\{result.draw_command_build_count},\"avg_rebuild_pass_count\":\{app_bench_avg_int(result.rebuild_pass_count, result.frames)},\"avg_layout_pass_count\":\{app_bench_avg_int(result.layout_pass_count, result.frames)},\"avg_paint_pass_count\":\{app_bench_avg_int(result.paint_pass_count, result.frames)},\"avg_draw_command_build_count\":\{app_bench_avg_int(result.draw_command_build_count, result.frames)}}"
}

///|
fn app_bench_print_scenario(
  label : String,
  cached : CachedRunResult,
  full : FullRunResult,
) -> Unit {
  println(
    "MoUI real app cached layer benchmark scenario=\{label} frames=\{cached.frames} cached_avg_ms=\{app_bench_avg(cached.total_ms(), cached.frames)} full_avg_ms=\{app_bench_avg(full.total_ms(), full.frames)} speedup=\{app_bench_speedup(full, cached)} cache_hits=\{cached.cache_hit_count} cache_misses=\{cached.cache_miss_count} cache_updates=\{cached.cache_update_count} begin_layers=\{cached.begin_cached_layer_count} draw_layers=\{cached.draw_cached_layer_count} overlay_only_frames=\{cached.overlay_only_frame_count} initial_begin_layers=\{cached.initial_begin_cached_layer_count} warmup_draw_layers=\{cached.warmup_draw_cached_layer_count} avg_cached_commands=\{app_bench_avg_int(cached.command_count_sum, cached.frames)} avg_full_commands=\{app_bench_avg_int(full.command_count_sum, full.frames)} avg_cached_rebuilds=\{app_bench_avg_int(cached.rebuild_pass_count, cached.frames)} avg_full_rebuilds=\{app_bench_avg_int(full.rebuild_pass_count, full.frames)} avg_cached_layouts=\{app_bench_avg_int(cached.layout_pass_count, cached.frames)} avg_full_layouts=\{app_bench_avg_int(full.layout_pass_count, full.frames)} avg_cached_paints=\{app_bench_avg_int(cached.paint_pass_count, cached.frames)} avg_full_paints=\{app_bench_avg_int(full.paint_pass_count, full.frames)} avg_cached_draw_builds=\{app_bench_avg_int(cached.draw_command_build_count, cached.frames)} avg_full_draw_builds=\{app_bench_avg_int(full.draw_command_build_count, full.frames)} avg_damage_rects=\{app_bench_avg_int(cached.damage_rect_count_sum, cached.frames)} damage_full_frames=\{cached.damage_full_count} first_full_reason=\{cached.first_damage_full_reason}",
  )
  println(
    "{\"benchmark\":\"moui-real-app-cached-layer\",\"scenario\":\"\{label}\",\"cached\":\{app_bench_cached_json(cached)},\"full_repaint\":\{app_bench_full_json(full)},\"speedup\":\{app_bench_speedup(full, cached)}}",
  )
}

///|
fn app_bench_run_scenario(
  label : String,
  width : Double,
  height : Double,
  make_runtime : (Double, Double) -> @core.AppRuntime,
  prepare : (@core.AppRuntime) -> Unit,
  drive : (@core.AppRuntime, Int) -> Unit,
  frames : Int,
  warmup : Int,
) -> Unit {
  let cached = app_bench_run_cached(
    label, width, height, make_runtime, prepare, drive, frames, warmup,
  )
  let full = app_bench_run_full(
    label, width, height, make_runtime, prepare, drive, frames, warmup,
  )
  app_bench_print_scenario(label, cached, full)
}

///|
fn main {
  if !@skia_renderer.skia_available() {
    fail_bench(
      "Skia is unavailable; configure real native Skia before running this benchmark",
    )
  }
  let frames = app_bench_env_int("MOUI_APP_CACHED_LAYER_BENCH_FRAMES", 90)
  let warmup = app_bench_env_int("MOUI_APP_CACHED_LAYER_BENCH_WARMUP", 12)
  println(
    "MoUI real app cached layer benchmark frames=\{frames} warmup=\{warmup}",
  )
  app_bench_run_scenario(
    "showcase-runtime-scroll", 1280.0, 720.0, app_bench_showcase_runtime, app_bench_no_prepare,
    app_bench_dispatch_showcase_scroll, frames, warmup,
  )
  app_bench_run_scenario(
    "showcase-sidebar-hover", 1280.0, 720.0, app_bench_showcase_runtime, app_bench_no_prepare,
    app_bench_dispatch_showcase_sidebar_hover, frames, warmup,
  )
  app_bench_run_scenario(
    "markdown-editor-text-input", 980.0, 640.0, app_bench_markdown_runtime, app_bench_prepare_markdown_input,
    app_bench_dispatch_markdown_input, frames, warmup,
  )
  app_bench_run_scenario(
    "markdown-editor-scroll", 980.0, 640.0, app_bench_markdown_runtime, app_bench_no_prepare,
    app_bench_dispatch_markdown_scroll, frames, warmup,
  )
  app_bench_run_scenario(
    "markdown-editor-caret-overlay", 980.0, 640.0, app_bench_markdown_runtime, app_bench_prepare_markdown_input,
    app_bench_dispatch_markdown_caret_overlay, frames, warmup,
  )
}

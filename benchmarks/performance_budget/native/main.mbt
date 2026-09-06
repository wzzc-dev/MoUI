///|
extern "c" fn perf_now_ms() -> Double = "moui_performance_budget_now_ms"

///|
extern "c" fn perf_peak_rss_bytes() -> Double = "moui_performance_budget_peak_rss_bytes"

///|
extern "c" fn perf_allocation_count() -> Double = "moui_performance_budget_allocation_count"

///|
extern "c" fn perf_package_bytes() -> Double = "moui_performance_budget_package_bytes"

///|
struct TimingSamples {
  build_ms : Array[Double]
  layout_ms : Array[Double]
  paint_ms : Array[Double]
  present_ms : Array[Double]
  frame_ms : Array[Double]
}

///|
struct ResourceSamples {
  peak_rss_bytes : Double
  allocation_count : Double
  cache_hit_rate : Double
  startup_ms : Double
  package_bytes : Double
}

///|
struct ScenarioResult {
  samples : TimingSamples
  resources : ResourceSamples
}

///|
struct RuntimeCacheCounters {
  hits : Int
  misses : Int
}

///|
fn[T] perf_fail(message : String) -> T {
  println(message)
  abort("MoUI performance budget benchmark failed")
}

///|
fn perf_parse_positive_int(value : String, fallback : Int) -> Int {
  let chars = value.trim().to_array()
  if chars.is_empty() {
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
fn perf_env_int(name : String, fallback : Int) -> Int {
  match @env.get_env_var(name) {
    Some(value) => perf_parse_positive_int(value, fallback)
    None => fallback
  }
}

///|
fn perf_renderer(
  label : String,
  width : Double,
  height : Double,
) -> @skia_renderer.SkiaRasterRenderer {
  let target = @skia_renderer.SkiaPresentTarget::new(description=label, present=_frame => {
    true
  })
  @skia_renderer.create_with_present_target(
    @core.SurfaceMetrics::from_logical(size=@core.Size::new(width~, height~)),
    target,
  ) catch {
    error =>
      perf_fail(
        "expected Skia Raster renderer for \{label}: \{error.message()}",
      )
  }
}

///|
fn perf_showcase_runtimes(
  width : Double,
  height : Double,
) -> Array[@runtime.AppRuntime] {
  let model = @showcase.ShowcaseModel::new().update(
    @showcase.ShowcaseMsg::Navigate("diagnostics/advanced-rendering"),
  )
  [
    @runtime.new_program_with_dimensions(
      program=model.program(),
      width~,
      height~,
    ),
  ]
}

///|
fn perf_markdown_runtimes(
  width : Double,
  height : Double,
) -> Array[@runtime.AppRuntime] {
  let app = @markdown.MarkdownEditorApp::new()
  [@runtime.new_program_with_dimensions(program=app.program(), width~, height~)]
}

///|
fn perf_excel_runtimes(
  width : Double,
  height : Double,
) -> Array[@runtime.AppRuntime] {
  [
    @runtime.AppRuntime::new_program(
      program=@excel.program(),
      size=@core.Size::new(width~, height~),
    ),
  ]
}

///|
fn perf_virtual_list_runtimes(
  width : Double,
  height : Double,
) -> Array[@runtime.AppRuntime] {
  let items : Array[Int] = []
  for index in 0..<100000 {
    items.push(index)
  }
  let program = @core.Program::simple(
    init=@core.Point::new(x=0.0, y=0.0),
    update=fn(_model, offset) { offset },
    view=fn(offset) {
      @views.virtual_list(
        items,
        value => value.to_string(),
        value => @views.text("Row \{value}", width=760.0, height=24.0),
        item_height=24.0,
        viewport_height=height,
        spacing=1.0,
        overscan=4,
        offset~,
        on_scroll=offset => offset,
      )
    },
  )
  [
    @runtime.AppRuntime::new_program(
      program~,
      size=@core.Size::new(width~, height~),
    ),
  ]
}

///|
fn perf_deep_tree_node(
  depth : Int,
  width : Int,
  msg_base : Int,
) -> @core.View[Int] {
  if depth <= 0 {
    @views.button("x", on_click=msg_base)
  } else {
    let children : Array[@core.View[Int]] = []
    for col in 0..<width {
      children.push(perf_deep_tree_node(depth - 1, width, msg_base + col * 100))
    }
    @views.column(children)
  }
}

///|
fn perf_deep_tree_runtimes(
  width : Double,
  height : Double,
) -> Array[@runtime.AppRuntime] {
  // 511-node deep tree (depth 8, width 2) — the same shape as the
  // full_cycle F/G scenarios, which isolate rebuild/layout/paint plus
  // dirty-queue and damage-region bookkeeping on a deep tree.
  let program = @core.Program::simple(init=0, update=fn(_model, msg) { msg }, view=fn(
    model,
  ) {
    perf_deep_tree_node(8, 2, model + 1000)
  })
  [
    @runtime.AppRuntime::new_program(
      program~,
      size=@core.Size::new(width~, height~),
    ),
  ]
}

///|
fn perf_drive_deep_tree(
  runtimes : Array[@runtime.AppRuntime],
  index : Int,
) -> Unit {
  // Environment toggle forces mark_component_tree_build_dirty → rebuild on
  // every frame, mirroring full_cycle's F-deep-click scenario.
  let scale = 1.0 + (index % 10).to_double() * 0.01
  runtimes[0].set_environment(
    @core.Environment::neutral().with_text_scale(scale),
  )
}

///|
fn perf_multi_window_runtimes(
  width : Double,
  height : Double,
) -> Array[@runtime.AppRuntime] {
  let runtimes : Array[@runtime.AppRuntime] = []
  for index in 0..<4 {
    runtimes.push(
      @runtime.AppRuntime::new_view(
        root=@views.column([
          @views.text("Window \{index}", width~, height=36.0),
          @views.virtual_list(
            [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
            value => "\{index}-\{value}",
            value => @views.text("Item \{value}", width~, height=30.0),
            item_height=30.0,
            viewport_height=height - 36.0,
            offset=@core.Point::new(x=0.0, y=0.0),
            on_scroll=offset => offset,
          ),
        ]),
        size=@core.Size::new(width~, height~),
      ),
    )
  }
  runtimes
}

///|
fn perf_prepare_markdown(runtimes : Array[@runtime.AppRuntime]) -> Unit {
  runtimes[0].dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
}

///|
fn perf_no_prepare(_runtimes : Array[@runtime.AppRuntime]) -> Unit {
  ()
}

///|
fn perf_drive_showcase(
  runtimes : Array[@runtime.AppRuntime],
  index : Int,
) -> Unit {
  let direction = if index / 18 % 2 == 0 { -44.0 } else { 44.0 }
  runtimes[0].dispatch_event(
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
fn perf_drive_markdown(
  runtimes : Array[@runtime.AppRuntime],
  index : Int,
) -> Unit {
  let tokens = ["M", "o", "U", "I", " ", "p", "e", "r", "f", " "]
  runtimes[0].dispatch_event(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::InsertText(tokens[index % tokens.length()]),
    ),
  )
}

///|
fn perf_drive_excel(runtimes : Array[@runtime.AppRuntime], index : Int) -> Unit {
  let x = 92.0 + (index % 6).to_double() * 110.0
  let y = 172.0 + (index / 6 % 8).to_double() * 28.0
  runtimes[0].dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x~, y~),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
}

///|
fn perf_drive_virtual_list(
  runtimes : Array[@runtime.AppRuntime],
  index : Int,
) -> Unit {
  let direction = if index / 20 % 2 == 0 { -120.0 } else { 120.0 }
  runtimes[0].dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=400.0, y=300.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=direction),
      ),
    ),
  )
}

///|
fn perf_drive_multi_window(
  runtimes : Array[@runtime.AppRuntime],
  index : Int,
) -> Unit {
  for window, runtime in runtimes {
    runtime.set_environment(
      @core.Environment::neutral().with_text_scale(
        1.0 + ((index + window) % 4).to_double() * 0.02,
      ),
    )
  }
}

///|
fn perf_cache_counters(
  runtimes : Array[@runtime.AppRuntime],
) -> RuntimeCacheCounters {
  let mut hits = 0
  let mut misses = 0
  for runtime in runtimes {
    let snapshot = runtime.inspector_snapshot().runtime()
    hits = hits +
      snapshot.layout_cache_hit_count() +
      snapshot.render_cache_hit_count()
    misses = misses +
      snapshot.layout_cache_miss_count() +
      snapshot.render_cache_miss_count()
  }
  { hits, misses }
}

///|
fn perf_cache_hit_rate(
  before : RuntimeCacheCounters,
  after : RuntimeCacheCounters,
) -> Double {
  let hits = (after.hits - before.hits).max(0)
  let misses = (after.misses - before.misses).max(0)
  let total = hits + misses
  if total == 0 {
    1.0
  } else {
    hits.to_double() / total.to_double()
  }
}

///|
fn perf_empty_samples() -> TimingSamples {
  { build_ms: [], layout_ms: [], paint_ms: [], present_ms: [], frame_ms: [] }
}

///|
fn perf_measure_iteration(
  runtimes : Array[@runtime.AppRuntime],
  renderers : Array[@skia_renderer.SkiaRasterRenderer],
  samples : TimingSamples,
) -> Unit {
  let mut build_ms = 0.0
  let mut layout_ms = 0.0
  let mut paint_ms = 0.0
  let mut draw_ms = 0.0
  let mut present_ms = 0.0
  for index, runtime in runtimes {
    let profiled = runtime.profile_draw_frame(perf_now_ms)
    let timing = profiled.timing()
    build_ms = build_ms + timing.build_ms()
    layout_ms = layout_ms + timing.layout_ms()
    paint_ms = paint_ms + timing.paint_ms()
    draw_ms = draw_ms + timing.draw_ms()
    let present_start = perf_now_ms()
    let result = renderers[index].render_frame(profiled.frame())
    present_ms = present_ms + (perf_now_ms() - present_start).max(0.0)
    if !result.presented {
      perf_fail("Skia renderer did not present performance frame")
    }
  }
  samples.build_ms.push(build_ms)
  samples.layout_ms.push(layout_ms)
  samples.paint_ms.push(paint_ms)
  samples.present_ms.push(present_ms)
  samples.frame_ms.push(build_ms + layout_ms + paint_ms + draw_ms + present_ms)
}

///|
fn perf_run_scenario(
  label : String,
  width : Double,
  height : Double,
  make_runtimes : (Double, Double) -> Array[@runtime.AppRuntime],
  prepare : (Array[@runtime.AppRuntime]) -> Unit,
  drive : (Array[@runtime.AppRuntime], Int) -> Unit,
  frames : Int,
  warmup : Int,
) -> ScenarioResult {
  let startup_start = perf_now_ms()
  let runtimes = make_runtimes(width, height)
  prepare(runtimes)
  let renderers : Array[@skia_renderer.SkiaRasterRenderer] = []
  for index in 0..<runtimes.length() {
    renderers.push(perf_renderer("\{label}-\{index}", width, height))
  }
  let warmup_samples = perf_empty_samples()
  for index in 0..<warmup {
    drive(runtimes, index)
    perf_measure_iteration(runtimes, renderers, warmup_samples)
  }
  let startup_ms = perf_now_ms() - startup_start
  let before_cache = perf_cache_counters(runtimes)
  let samples = perf_empty_samples()
  for index in 0..<frames {
    drive(runtimes, warmup + index)
    perf_measure_iteration(runtimes, renderers, samples)
  }
  let after_cache = perf_cache_counters(runtimes)
  for renderer in renderers {
    if renderer.unsupported_command_count() != 0 {
      perf_fail("\{label} emitted unsupported Skia commands")
    }
  }
  {
    samples,
    resources: {
      peak_rss_bytes: perf_peak_rss_bytes(),
      allocation_count: perf_allocation_count(),
      cache_hit_rate: perf_cache_hit_rate(before_cache, after_cache),
      startup_ms,
      package_bytes: perf_package_bytes(),
    },
  }
}

///|
fn perf_scenario_json(result : ScenarioResult) -> Json {
  {
    "samples": {
      "buildMs": result.samples.build_ms,
      "layoutMs": result.samples.layout_ms,
      "paintMs": result.samples.paint_ms,
      "presentMs": result.samples.present_ms,
      "frameMs": result.samples.frame_ms,
    },
    "resources": {
      "peakRssBytes": result.resources.peak_rss_bytes,
      "allocationCount": result.resources.allocation_count,
      "cacheHitRate": result.resources.cache_hit_rate,
      "startupMs": result.resources.startup_ms,
      "packageBytes": result.resources.package_bytes,
    },
  }
}

///|
fn main {
  if !@skia_renderer.skia_available() {
    perf_fail(
      "Skia is unavailable; configure the locked real Skia provider before running performance budgets",
    )
  }
  let frames = perf_env_int("MOUI_PERFORMANCE_FRAMES", 60)
  let warmup = perf_env_int("MOUI_PERFORMANCE_WARMUP", 12)
  let scenarios : Map[String, Json] = Map([])
  scenarios["showcase-runtime-scroll"] = perf_scenario_json(
    perf_run_scenario(
      "showcase-runtime-scroll", 1280.0, 720.0, perf_showcase_runtimes, perf_no_prepare,
      perf_drive_showcase, frames, warmup,
    ),
  )
  scenarios["markdown-editor-text-input"] = perf_scenario_json(
    perf_run_scenario(
      "markdown-editor-text-input", 980.0, 640.0, perf_markdown_runtimes, perf_prepare_markdown,
      perf_drive_markdown, frames, warmup,
    ),
  )
  scenarios["excel-grid-navigation"] = perf_scenario_json(
    perf_run_scenario(
      "excel-grid-navigation", 1280.0, 800.0, perf_excel_runtimes, perf_no_prepare,
      perf_drive_excel, frames, warmup,
    ),
  )
  scenarios["virtual-list-100k"] = perf_scenario_json(
    perf_run_scenario(
      "virtual-list-100k", 800.0, 600.0, perf_virtual_list_runtimes, perf_no_prepare,
      perf_drive_virtual_list, frames, warmup,
    ),
  )
  scenarios["multi-window-4"] = perf_scenario_json(
    perf_run_scenario(
      "multi-window-4", 480.0, 360.0, perf_multi_window_runtimes, perf_no_prepare,
      perf_drive_multi_window, frames, warmup,
    ),
  )
  scenarios["deep-tree-env-toggle"] = perf_scenario_json(
    perf_run_scenario(
      "deep-tree-env-toggle", 800.0, 600.0, perf_deep_tree_runtimes, perf_no_prepare,
      perf_drive_deep_tree, frames, warmup,
    ),
  )
  let report : Json = {
    "schemaVersion": 1,
    "runner": "native-skia-raster",
    "scenarios": scenarios,
  }
  println("MOUI_PERFORMANCE_RESULT=" + report.stringify(indent=0))
}

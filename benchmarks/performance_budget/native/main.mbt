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
  draw_ms : Array[Double]
  present_ms : Array[Double]
  frame_ms : Array[Double]
  total_ms : Array[Double]
}

///|
struct ResourceSamples {
  peak_rss_bytes : Double
  allocation_count : Double
  cache_hit_rate : Double
  layout_cache_hits : Int32
  layout_cache_misses : Int32
  render_cache_hits : Int32
  render_cache_misses : Int32
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
  hits : Int32
  misses : Int32
}

///|
struct LeafMemoCounters {
  builds : Int32
  hits : Int32
  misses : Int32
}

///|
priv enum LeafConstructionMode {
  Direct
  Memo
  BuilderCache
} derive(Eq)

///|
fn LeafConstructionMode::label(self : LeafConstructionMode) -> String {
  match self {
    Direct => "direct"
    Memo => "memo"
    BuilderCache => "builder-cache"
  }
}

///|
fn LeafConstructionMode::memoized(self : LeafConstructionMode) -> Bool {
  match self {
    Direct => false
    Memo | BuilderCache => true
  }
}

///|
struct LeafUpdateModel {
  value : Int32
}

///|
struct LeafUpdateSamples {
  update_ms : Array[Double]
  runtime_ms : Array[Double]
  present_ms : Array[Double]
  frame_ms : Array[Double]
}

///|
struct LeafUpdateResult {
  nodes : Int32
  frames : Int32
  map_layers : Int32
  construction_mode : LeafConstructionMode
  root_builder_calls : Int32
  node_builds : Int32
  assembled_nodes : Int32
  map_adapter_copies : Int32
  memo_build_count : Int32
  memo_hit_count : Int32
  memo_miss_count : Int32
  builder_cache_build_count : Int32
  builder_cache_hit_count : Int32
  builder_cache_miss_count : Int32
  builder_cache_entry_count : Int32
  rebuild_pass_count : Int32
  layout_cache_hits : Int32
  layout_cache_misses : Int32
  render_cache_hits : Int32
  render_cache_misses : Int32
  damage_empty_frames : Int32
  damage_rect_frames : Int32
  damage_full_frames : Int32
  damage_coverage : Double
  samples : LeafUpdateSamples
}

///|
fn[T] perf_fail(message : String) -> T {
  println(message)
  abort("MoUI performance budget benchmark failed")
}

///|
fn perf_parse_positive_int(value : String, fallback : Int32) -> Int32 {
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
fn perf_env_int(name : String, fallback : Int32) -> Int32 {
  match @env.get_env_var(name) {
    Some(value) => perf_parse_positive_int(value, fallback)
    None => fallback
  }
}

///|
fn perf_env_string(name : String, fallback : String) -> String {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed.is_empty() {
        fallback
      } else {
        trimmed
      }
    }
    None => fallback
  }
}

///|
/// `MOUI_PERFORMANCE_SURFACE_ROUTE` selects which real present path the harness
/// renders through. The default stays on the gated CPU raster route.
///
/// - `raster`: CPU raster surface, presented as a `SkiaPixelFrame`.
/// - `metal-gpu`: Skia's Metal GPU surface route, still presented as a CPU
///   pixel frame. This pays the GPU→CPU `read_pixels` copy, so it prices the
///   GPU *engine*, not the path the product ships.
/// - `metal-gpu-host`: the path macOS/iOS ship — a `HostGpuPresentTarget`, so
///   `render_frame` never calls `read_frame` and no CPU copy happens. The
///   stand-in drawable is an offscreen GPU surface and `present_gpu` is a
///   no-op, so this still excludes `CAMetalLayer` acquisition and the
///   vsync-blocked present.
/// - `metal-gpu-host-rotating`: the same host target, but `present_gpu` returns
///   a freshly allocated surface as `next_surface` every frame. Metal drawables
///   rotate, so this is the only mode that pays per-frame surface acquisition on
///   the measured path. It still excludes `CAMetalLayer` and vsync.
fn perf_present_mode() -> String {
  let mode = perf_env_string("MOUI_PERFORMANCE_SURFACE_ROUTE", "raster")
  match mode {
    "raster" | "metal-gpu" | "metal-gpu-host" | "metal-gpu-host-rotating" =>
      mode
    other => perf_fail("unknown MOUI_PERFORMANCE_SURFACE_ROUTE: \{other}")
  }
}

///|
fn perf_surface_route(mode : String) -> @skia_renderer.SkiaSurfaceRoute {
  match mode {
    "metal-gpu" | "metal-gpu-host" | "metal-gpu-host-rotating" =>
      MetalGpuSurfaceRoute
    _ => RasterSurfaceRoute
  }
}

///|
fn perf_route_is_gpu(mode : String) -> Bool {
  mode != "raster"
}

///|
fn perf_uses_host_gpu_target(mode : String) -> Bool {
  mode == "metal-gpu-host" || mode == "metal-gpu-host-rotating"
}

///|
fn perf_rotates_host_surface(mode : String) -> Bool {
  mode == "metal-gpu-host-rotating"
}

///|
/// One runner-identity rule for every provider: the label names the engine and
/// the present path, and nothing else may claim that label. The four Skia
/// concrete labels are unchanged, so the committed budgets keep addressing the
/// runner they were measured on.
fn perf_runner_label(provider : String, mode : String) -> String {
  match provider {
    "sun" => "native-sun-raster"
    "skia-neutral" => "native-skia-raster-via-provider"
    _ =>
      match mode {
        "raster" => "native-skia-raster"
        "metal-gpu" => "native-skia-metal-gpu-cpu-frame"
        "metal-gpu-host" => "native-skia-metal-gpu-host-surface"
        _ => "native-skia-metal-gpu-host-surface-rotating"
      }
  }
}

///|
/// The frame pump the scenario loop drives. It is a pair of closures rather
/// than a concrete renderer type because a harness typed to
/// `@skia_renderer.SkiaRasterRenderer` can only ever produce Skia numbers, and
/// the L0 kill gate's first branch asks whether a *non*-Skia route meets the
/// frame budgets. `assert_clean` is where each route states the post-scenario
/// condition it can actually prove: Skia can count its unsupported commands, a
/// neutral session can only prove every pumped frame was presented.
struct PerfFramePump {
  render : (Int32, @core.DrawFrame) -> Bool
  assert_clean : (String, Int32) -> Unit
}

///|
/// `MOUI_PERFORMANCE_PROVIDER` selects which renderer owns the frame pump.
///
/// - `skia` (default): the concrete `SkiaRasterRenderer` the committed budgets
///   were measured through, including the three `metal-gpu` present modes below.
/// - `skia-neutral`: the same Skia raster engine driven through the
///   renderer-neutral `RendererProvider` → `RendererSession` contract, emitted
///   under its own runner identity. It is deliberately not the gated runner: the
///   provider builds with `async_image_loading=true`
///   (`moui_skia_renderer/binding_factory.mbt:26`) while the gated concrete path
///   leaves it `false`, so adopting it would re-baseline every committed number
///   as a side effect of switching construction paths.
/// - `sun`: the Sun CPU raster provider through that same neutral contract. ADR
///   0023 declares Sun experimental, so its numbers are evidence for the kill
///   gate, not a gate of their own.
fn perf_provider_choice() -> String {
  let provider = perf_env_string("MOUI_PERFORMANCE_PROVIDER", "skia")
  match provider {
    "skia" | "skia-neutral" | "sun" => provider
    other => perf_fail("unknown MOUI_PERFORMANCE_PROVIDER: \{other}")
  }
}

///|
/// The `metal-gpu` modes exist only as arguments to Skia's own constructor
/// (`create_with_present_target_and_route` plus a `HostGpuPresentTarget`
/// stand-in); no provider expression reaches them, and `moui_skia_renderer`'s
/// `gpu()` provider rejects a surface with no native handle. Refusing here is
/// the difference between a control number and a mislabelled one.
fn perf_assert_provider_mode(provider : String, mode : String) -> Unit {
  if provider != "skia" && mode != "raster" {
    perf_fail(
      "\{provider} has no \{mode} present mode: the metal-gpu routes are Skia-concrete, so run them with MOUI_PERFORMANCE_PROVIDER=skia",
    )
  }
}

///|
/// A stand-in for the host drawable: an offscreen GPU surface at exactly the
/// renderer's physical size, presented by a no-op. The size must match the
/// renderer's backing surface, because `Surface::copy_from` refuses mismatched
/// sizes and the renderer would silently fall back to a direct full redraw —
/// a different measurement under the same runner label.
fn perf_host_gpu_target(
  label : String,
  rotate~ : Bool = false,
) -> @skia_renderer.HostGpuPresentTarget {
  @skia_renderer.HostGpuPresentTarget::new(
    description=label,
    create_window_surface=(context, metrics) => {
      match context {
        None => None
        Some(context) =>
          @skia_native.Surface::gpu_n32_premul(
            context,
            @moui_skia.SurfaceDescriptor::gpu_n32_premul(
              @moui_skia.ISize::new(
                metrics.physical_size.width.ceil().max(1.0).to_int(),
                metrics.physical_size.height.ceil().max(1.0).to_int(),
              ),
            ),
          )
      }
    },
    present_gpu=(context, surface) => {
      if rotate {
        // Reuse the outgoing descriptor so the replacement is the same size and
        // format; a mismatch makes Surface::copy_from fail and silently moves the
        // renderer off the backing-blit path it is supposed to be measuring.
        let next_surface = match context {
          None => None
          Some(context) =>
            @skia_native.Surface::gpu_n32_premul(context, surface.descriptor())
        }
        @skia_renderer.HostGpuPresentOutcome::new(succeeded=true, next_surface~)
      } else {
        @skia_renderer.HostGpuPresentOutcome::new(succeeded=true)
      }
    },
  )
}

///|
fn perf_renderer(
  label : String,
  width : Double,
  height : Double,
) -> @skia_renderer.SkiaRasterRenderer {
  let mode = perf_present_mode()
  let route = perf_surface_route(mode)
  let target = @skia_renderer.SkiaPresentTarget::new(description=label, present=_frame => {
    true
  })
  let gpu_target = if perf_uses_host_gpu_target(mode) {
    Some(perf_host_gpu_target(label, rotate=perf_rotates_host_surface(mode)))
  } else {
    None
  }
  let renderer = @skia_renderer.create_with_present_target_and_route(
    @core.SurfaceMetrics::from_logical(size=@core.Size::new(width~, height~)),
    target,
    surface_route=route,
    gpu_target~,
  ) catch {
    error =>
      perf_fail("expected Skia renderer for \{label}: \{error.message()}")
  }
  // The emitted runner identity is only honest if the surface underneath is
  // really the requested route. A GPU route that silently degraded to a raster
  // surface would otherwise produce a control number that means nothing.
  if renderer.surface_is_gpu() != perf_route_is_gpu(mode) {
    perf_fail(
      "\{label}: requested route \{perf_surface_route_label(route)} but the renderer surface is_gpu=\{renderer.surface_is_gpu()}",
    )
  }
  // The readback-free claim is the whole point of the host-surface control, so
  // the present kind is asserted too rather than inferred from the label.
  let uses_host_surface = renderer.target_kind()
    is @skia_renderer.HostGpuSurface
  if uses_host_surface != perf_uses_host_gpu_target(mode) {
    perf_fail(
      "\{label}: requested \{mode} but the renderer present kind is \{perf_present_kind_label(renderer.target_kind())}",
    )
  }
  renderer
}

///|
fn perf_concrete_skia_pump(
  label : String,
  width : Double,
  height : Double,
) -> PerfFramePump {
  let renderer = perf_renderer(label, width, height)
  PerfFramePump::{
    render: (_sequence, frame) => renderer.render_frame(frame).presented,
    assert_clean: (scenario_label, _pumped) => {
      if renderer.unsupported_command_count() != 0 {
        perf_fail("\{scenario_label} emitted unsupported Skia commands")
      }
    },
  }
}

///|
/// Drive one provider through the renderer-neutral session contract. This is
/// the path a non-Skia route can actually be measured on, so its identity rules
/// are the ones the L0 gate has to trust.
fn perf_neutral_pump(
  label : String,
  width : Double,
  height : Double,
  provider_id~ : String,
  provider~ : @render.RendererProvider,
) -> PerfFramePump {
  if provider.id() != provider_id {
    perf_fail(
      "\{label}: expected provider id \{provider_id}, got \{provider.id()}",
    )
  }
  // The descriptor's presentation model is the only identity claim a neutral
  // session can make about itself: `surface_is_gpu()` and `target_kind()` are
  // Skia-renderer methods with no session equivalent, so a `CpuPixelFrame`
  // descriptor is what licenses the `-raster` in the runner label.
  let descriptor = provider.descriptor()
  if descriptor.presentation != @render.CpuPixelFrame {
    perf_fail(
      "\{label}: \{provider_id} presents \{descriptor.presentation.to_repr()}, not a CPU pixel frame",
    )
  }
  let surface = @render.HostSurface::new(
    surface_id=label,
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width~, height~),
    ),
    cpu_present=Some(
      @render.PresentTarget::new(description=label, present=_frame => true),
    ),
  )
  let session = match provider.bind_surface(surface) {
    @render.Bound(session) => session
    @render.Rejected(message) =>
      perf_fail(
        "\{label}: \{provider_id} rejected the headless surface: \{message}",
      )
  }
  PerfFramePump::{
    render: (sequence, frame) => {
      session.render_frame(
        @render.RenderFrameSubmission::new(
          token=@render.FrameToken::new(surface_generation=0, sequence~),
          frame~,
        ),
      ).presented
    },
    // Every pumped frame must have reached the presenter. A provider that
    // silently dropped frames would otherwise report a frame cost it never
    // paid.
    assert_clean: (scenario_label, pumped) => {
      let presented = session.present_count()
      if presented != pumped {
        perf_fail(
          "\{scenario_label}: \{provider_id} presented \{presented} of \{pumped} pumped frames",
        )
      }
    },
  }
}

///|
fn perf_pump(label : String, width : Double, height : Double) -> PerfFramePump {
  match perf_provider_choice() {
    "skia" => perf_concrete_skia_pump(label, width, height)
    "skia-neutral" =>
      perf_neutral_pump(
        label,
        width,
        height,
        provider_id="skia-raster",
        provider=@skia_renderer.raster(),
      )
    _ =>
      perf_neutral_pump(
        label,
        width,
        height,
        provider_id="sun-raster",
        provider=@render_sun.raster(),
      )
  }
}

///|
fn perf_present_kind_label(kind : @skia_renderer.SkiaPresentKind) -> String {
  match kind {
    @skia_renderer.CpuPixelFrame => "cpu-pixel-frame"
    @skia_renderer.HostGpuSurface => "host-gpu-surface"
  }
}

///|
fn perf_surface_route_label(route : @skia_renderer.SkiaSurfaceRoute) -> String {
  match route {
    RasterSurfaceRoute => "raster"
    MetalGpuSurfaceRoute => "metal-gpu"
    _ => "other-gpu"
  }
}

///|
fn perf_showcase_runtimes(
  width : Double,
  height : Double,
) -> Array[@runtime.AppRuntime] {
  let model = @showcase.ShowcaseModel::new().update(
    Navigate("diagnostics/advanced-rendering"),
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
  let items : Array[Int32] = []
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
  depth : Int32,
  width : Int32,
  msg_base : Int32,
) -> @core.View[Int32] {
  if depth <= 0 {
    @views.button("x", on_click=msg_base)
  } else {
    let children : Array[@core.View[Int32]] = []
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
  index : Int32,
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
fn perf_no_prepare(_runtimes : Array[@runtime.AppRuntime]) -> Unit {
  ()
}

///|
fn perf_drive_showcase(
  runtimes : Array[@runtime.AppRuntime],
  index : Int32,
) -> Unit {
  let direction = if index / 18 % 2 == 0 { -44.0 } else { 44.0 }
  runtimes[0].dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=470.0, y=260.0),
        phase=Move,
        wheel_delta=@core.Point::new(x=0.0, y=direction),
      ),
    ),
  )
}

///|
fn perf_drive_excel(
  runtimes : Array[@runtime.AppRuntime],
  index : Int32,
) -> Unit {
  let x = 92.0 + (index % 6).to_double() * 110.0
  let y = 172.0 + (index / 6 % 8).to_double() * 28.0
  runtimes[0].dispatch_event(
    Pointer(
      @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Down),
    ),
  )
}

///|
fn perf_drive_virtual_list(
  runtimes : Array[@runtime.AppRuntime],
  index : Int32,
) -> Unit {
  let direction = if index / 20 % 2 == 0 { -120.0 } else { 120.0 }
  runtimes[0].dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=400.0, y=300.0),
        phase=Move,
        wheel_delta=@core.Point::new(x=0.0, y=direction),
      ),
    ),
  )
}

///|
fn perf_drive_multi_window(
  runtimes : Array[@runtime.AppRuntime],
  index : Int32,
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
  { hits, misses, }
}

///|
fn perf_detailed_cache_counters(
  runtimes : Array[@runtime.AppRuntime],
) -> CacheCounterSnapshot {
  let mut layout_hits = 0
  let mut layout_misses = 0
  let mut render_hits = 0
  let mut render_misses = 0
  for runtime in runtimes {
    let snapshot = runtime.inspector_snapshot().runtime()
    layout_hits = layout_hits + snapshot.layout_cache_hit_count()
    layout_misses = layout_misses + snapshot.layout_cache_miss_count()
    render_hits = render_hits + snapshot.render_cache_hit_count()
    render_misses = render_misses + snapshot.render_cache_miss_count()
  }
  { layout_hits, layout_misses, render_hits, render_misses, }
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
/// Inspector cache counters are stored per element. A structural remount can
/// discard the counters of nodes that left the tree, so a measured delta is
/// clamped at zero rather than reporting a negative hit/miss count. Scenarios
/// that frequently replace their whole tree therefore use these counters as a
/// lower bound; they still distinguish layout hits from render hits.
fn perf_counter_delta(after : Int32, before : Int32) -> Int32 {
  (after - before).max(0)
}

///|
struct CacheCounterSnapshot {
  layout_hits : Int32
  layout_misses : Int32
  render_hits : Int32
  render_misses : Int32
}

///|
fn perf_leaf_cache_counters(
  runtime : @runtime.AppRuntime,
) -> CacheCounterSnapshot {
  let snapshot = runtime.inspector_snapshot().runtime()
  {
    layout_hits: snapshot.layout_cache_hit_count(),
    layout_misses: snapshot.layout_cache_miss_count(),
    render_hits: snapshot.render_cache_hit_count(),
    render_misses: snapshot.render_cache_miss_count(),
  }
}

///|
fn perf_leaf_percentile(samples : Array[Double], percent : Double) -> Double {
  if samples.is_empty() {
    return 0.0
  }
  let sorted = samples.copy()
  sorted.sort()
  let rank = (percent / 100.0 * sorted.length().to_double()).ceil().to_int()
  sorted[rank.clamp(min=1, max=sorted.length()) - 1]
}

///|
fn perf_leaf_ratio(hits : Int32, misses : Int32) -> Double {
  let total = hits + misses
  if total == 0 {
    1.0
  } else {
    hits.to_double() / total.to_double()
  }
}

///|
fn perf_leaf_empty_samples() -> LeafUpdateSamples {
  { update_ms: [], runtime_ms: [], present_ms: [], frame_ms: [], }
}

///|
fn perf_leaf_damage_coverage(
  damage : @core.DamageRegion,
  surface : @core.Rect,
) -> Double {
  match damage {
    Empty => 0.0
    FullSurface(_) => 1.0
    Rects(rects) =>
      if rects.is_empty() || surface.area() <= 0.0 {
        0.0
      } else {
        let mut bounds = rects[0]
        for index in 1..<rects.length() {
          bounds = bounds.union(rects[index])
        }
        (bounds.area() / surface.area()).clamp(min=0.0, max=1.0)
      }
  }
}

///|
fn perf_leaf_pointer_event(phase : @core.PointerPhase) -> @core.AppEvent {
  Pointer(
    @core.PointerEvent::new(position=@core.Point::new(x=10.0, y=10.0), phase~),
  )
}

///|
fn perf_leaf_memo_counters(
  memos : Array[@core.ViewMemo[Int32]],
) -> LeafMemoCounters {
  let mut counters : LeafMemoCounters = { builds: 0, hits: 0, misses: 0, }
  for memo in memos {
    let stats = memo.stats()
    counters = {
      builds: counters.builds + stats.build_count(),
      hits: counters.hits + stats.hit_count(),
      misses: counters.misses + stats.miss_count(),
    }
  }
  counters
}

///|
fn perf_leaf_content_key(
  leaf_index : Int32,
  value : Int32,
) -> @core.DeclarationKey {
  if leaf_index == 0 {
    @core.DeclarationKey::record(type_tag="leaf-update.content", fields=[
      ("value", @core.DeclarationKey::int(value)),
    ])
  } else {
    @core.DeclarationKey::string("leaf-update.static")
  }
}

///|
fn perf_leaf_update_scenario(
  label : String,
  leaf_count : Int32,
  width : Double,
  height : Double,
  frames : Int32,
  warmup : Int32,
  construction_mode~ : LeafConstructionMode,
  map_layers~ : Int32 = 1,
) -> LeafUpdateResult {
  let root_builder_calls = Ref(0)
  let node_builds = Ref(0)
  let assembled_nodes = Ref(0)
  let memos : Array[@core.ViewMemo[Int32]] = []
  if construction_mode == Memo {
    for _index in 0..<leaf_count {
      memos.push(@core.ViewMemo::new())
    }
  }
  let builder_keys : Array[@core.DeclarationKey] = []
  if construction_mode == BuilderCache {
    for index in 0..<leaf_count {
      builder_keys.push(
        @core.DeclarationKey::record(type_tag="leaf-update.builder", fields=[
          ("index", @core.DeclarationKey::int(index)),
        ]),
      )
    }
  }
  let builder_cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let program = @core.Program::simple(
    init={ value: 0, },
    update=fn(model, _message) { { value: model.value + 1, } },
    view=fn(model) {
      root_builder_calls.val = root_builder_calls.val + 1
      let children : Array[@core.View[Int32]] = []
      for index in 0..<leaf_count {
        let leaf_index = index
        let build_leaf = () => {
          node_builds.val = node_builds.val + 1
          if leaf_index == 0 {
            @views.text(
              "Leaf 0: \{model.value}",
              width=width - 40.0,
              height=20.0,
            ).on_tap(1)
          } else {
            @views.text("Leaf \{leaf_index}", width=width - 40.0, height=20.0)
          }
        }
        let child = match construction_mode {
          Direct => build_leaf()
          Memo => {
            let content_key = perf_leaf_content_key(leaf_index, model.value)
            memos[leaf_index].view(key=content_key, build=build_leaf)
          }
          BuilderCache => {
            let content_key = perf_leaf_content_key(leaf_index, model.value)
            builder_cache.view(
              builder_key=builder_keys[leaf_index],
              content_key~,
              build=build_leaf,
            )
          }
        }
        assembled_nodes.val = assembled_nodes.val + 1
        children.push(child)
      }
      let column = @views.column(children)
      assembled_nodes.val = assembled_nodes.val + 1
      node_builds.val = node_builds.val + 1
      let mut view = column
      for _layer in 0..<map_layers {
        view = view.map(message => message)
      }
      view
    },
  )
  let runtime = @runtime.AppRuntime::new_program(
    program~,
    size=@core.Size::new(width~, height~),
  )
  let pump = perf_pump(label, width, height)
  for _index in 0..<warmup {
    runtime.advance_time(16.0)
    runtime.dispatch_event(perf_leaf_pointer_event(Down))
    runtime.dispatch_event(perf_leaf_pointer_event(Up))
    let frame = runtime.draw_frame()
    if !(pump.render)(0, frame) {
      perf_fail("\{label}: renderer did not present warmup frame")
    }
  }
  let builders_before = root_builder_calls.val
  let nodes_before = node_builds.val
  let assembled_before = assembled_nodes.val
  let cache_before = perf_leaf_cache_counters(runtime)
  let memo_before = perf_leaf_memo_counters(memos)
  let builder_cache_before = builder_cache.stats()
  let rebuild_before = runtime
    .inspector_snapshot()
    .runtime()
    .rebuild_pass_count()
  let samples = perf_leaf_empty_samples()
  let surface = @core.Rect::new(x=0.0, y=0.0, width~, height~)
  let mut damage_empty_frames = 0
  let mut damage_rect_frames = 0
  let mut damage_full_frames = 0
  let mut damage_coverage = 0.0
  for index in 0..<frames {
    let frame_start = perf_now_ms()
    let update_start = perf_now_ms()
    runtime.advance_time(16.0)
    runtime.dispatch_event(perf_leaf_pointer_event(Down))
    runtime.dispatch_event(perf_leaf_pointer_event(Up))
    let update_ms = (perf_now_ms() - update_start).max(0.0)
    let profiled = runtime.profile_draw_frame(perf_now_ms)
    let timing = profiled.timing()
    let present_start = perf_now_ms()
    let presented = (pump.render)(warmup + index, profiled.frame())
    let present_ms = (perf_now_ms() - present_start).max(0.0)
    let frame_ms = (perf_now_ms() - frame_start).max(0.0)
    if !presented {
      perf_fail("\{label}: renderer did not present measured frame")
    }
    samples.update_ms.push(update_ms)
    samples.runtime_ms.push(timing.total_ms())
    samples.present_ms.push(present_ms)
    samples.frame_ms.push(frame_ms)
    match profiled.frame().damage {
      Empty => damage_empty_frames = damage_empty_frames + 1
      FullSurface(_) => damage_full_frames = damage_full_frames + 1
      Rects(_) => damage_rect_frames = damage_rect_frames + 1
    }
    damage_coverage = damage_coverage +
      perf_leaf_damage_coverage(profiled.frame().damage, surface)
  }
  (pump.assert_clean)(label, warmup + frames)
  let cache_after = perf_leaf_cache_counters(runtime)
  let memo_after = perf_leaf_memo_counters(memos)
  let builder_cache_after = builder_cache.stats()
  let rebuild_after = runtime
    .inspector_snapshot()
    .runtime()
    .rebuild_pass_count()
  let measured_node_builds = node_builds.val - nodes_before
  let measured_assembled_nodes = assembled_nodes.val - assembled_before
  let measured_builder_cache_builds = perf_counter_delta(
    builder_cache_after.build_count(),
    builder_cache_before.build_count(),
  )
  let measured_builder_cache_hits = perf_counter_delta(
    builder_cache_after.hit_count(),
    builder_cache_before.hit_count(),
  )
  let measured_builder_cache_misses = perf_counter_delta(
    builder_cache_after.miss_count(),
    builder_cache_before.miss_count(),
  )
  if construction_mode == BuilderCache {
    if measured_node_builds != frames * 2 {
      perf_fail(
        "\{label}: expected the changed leaf plus container to be built (\{frames * 2}), measured \{measured_node_builds}",
      )
    }
    if measured_builder_cache_builds != frames ||
      measured_builder_cache_hits != frames * (leaf_count - 1) ||
      measured_builder_cache_misses != frames ||
      builder_cache_after.entry_count() != leaf_count {
      perf_fail(
        "\{label}: builder-cache structural counters do not match one changed leaf per frame",
      )
    }
  }
  {
    nodes: leaf_count + 1,
    frames,
    map_layers,
    construction_mode,
    root_builder_calls: root_builder_calls.val - builders_before,
    node_builds: measured_node_builds,
    assembled_nodes: measured_assembled_nodes,
    // Each leaf is one adapter; leaf zero also carries the OnTap modifier
    // wrapper, and the column is one adapter. Recursive `ViewAdapter::map`
    // copies that whole adapter tree once per map layer.
    map_adapter_copies: (measured_assembled_nodes + frames) * map_layers,
    memo_build_count: perf_counter_delta(memo_after.builds, memo_before.builds),
    memo_hit_count: perf_counter_delta(memo_after.hits, memo_before.hits),
    memo_miss_count: perf_counter_delta(memo_after.misses, memo_before.misses),
    builder_cache_build_count: measured_builder_cache_builds,
    builder_cache_hit_count: measured_builder_cache_hits,
    builder_cache_miss_count: measured_builder_cache_misses,
    builder_cache_entry_count: builder_cache_after.entry_count(),
    rebuild_pass_count: rebuild_after - rebuild_before,
    layout_cache_hits: perf_counter_delta(
      cache_after.layout_hits,
      cache_before.layout_hits,
    ),
    layout_cache_misses: perf_counter_delta(
      cache_after.layout_misses,
      cache_before.layout_misses,
    ),
    render_cache_hits: perf_counter_delta(
      cache_after.render_hits,
      cache_before.render_hits,
    ),
    render_cache_misses: perf_counter_delta(
      cache_after.render_misses,
      cache_before.render_misses,
    ),
    damage_empty_frames,
    damage_rect_frames,
    damage_full_frames,
    damage_coverage: if frames > 0 {
      damage_coverage / frames.to_double()
    } else {
      0.0
    },
    samples,
  }
}

///|
fn perf_leaf_timing_json(samples : Array[Double]) -> Json {
  {
    "p50": perf_leaf_percentile(samples, 50.0),
    "p95": perf_leaf_percentile(samples, 95.0),
  }
}

///|
fn perf_leaf_update_json(result : LeafUpdateResult) -> Json {
  {
    "nodes": result.nodes,
    "frames": result.frames,
    "mapLayers": result.map_layers,
    "constructionMode": result.construction_mode.label(),
    "memoized": result.construction_mode.memoized(),
    "build": {
      "rootBuilderCalls": result.root_builder_calls,
      "nodeBuilds": result.node_builds,
      "assembledNodes": result.assembled_nodes,
      "mapAdapterCopies": result.map_adapter_copies,
    },
    "memo": {
      "buildCount": result.memo_build_count,
      "hitCount": result.memo_hit_count,
      "missCount": result.memo_miss_count,
    },
    "builderCache": {
      "buildCount": result.builder_cache_build_count,
      "hitCount": result.builder_cache_hit_count,
      "missCount": result.builder_cache_miss_count,
      "entryCount": result.builder_cache_entry_count,
    },
    "rebuildPassCount": result.rebuild_pass_count,
    "cache": {
      "layoutHits": result.layout_cache_hits,
      "layoutMisses": result.layout_cache_misses,
      "layoutHitRate": perf_leaf_ratio(
        result.layout_cache_hits,
        result.layout_cache_misses,
      ),
      "renderHits": result.render_cache_hits,
      "renderMisses": result.render_cache_misses,
      "renderHitRate": perf_leaf_ratio(
        result.render_cache_hits,
        result.render_cache_misses,
      ),
    },
    "damage": {
      "emptyFrames": result.damage_empty_frames,
      "rectFrames": result.damage_rect_frames,
      "fullFrames": result.damage_full_frames,
      "averageCoverage": result.damage_coverage,
    },
    "timings": {
      // Pointer delivery performs the synchronous TEA reconcile, so `updateMs`
      // owns the build cost. `runtimeMs` is the remaining profile_draw_frame
      // pipeline (normally layout/paint/draw after the message).
      "updateMs": perf_leaf_timing_json(result.samples.update_ms),
      "runtimeMs": perf_leaf_timing_json(result.samples.runtime_ms),
      "presentMs": perf_leaf_timing_json(result.samples.present_ms),
      "frameMs": perf_leaf_timing_json(result.samples.frame_ms),
    },
  }
}

///|
fn perf_empty_samples() -> TimingSamples {
  {
    build_ms: [],
    layout_ms: [],
    paint_ms: [],
    draw_ms: [],
    present_ms: [],
    frame_ms: [],
    total_ms: [],
  }
}

///|
fn perf_measure_iteration(
  runtimes : Array[@runtime.AppRuntime],
  pumps : Array[PerfFramePump],
  sequence : Int32,
  samples : TimingSamples,
) -> Unit {
  let mut build_ms = 0.0
  let mut layout_ms = 0.0
  let mut paint_ms = 0.0
  let mut draw_ms = 0.0
  let mut total_ms = 0.0
  let mut present_ms = 0.0
  for index, runtime in runtimes {
    let profiled = runtime.profile_draw_frame(perf_now_ms)
    let timing = profiled.timing()
    build_ms = build_ms + timing.build_ms()
    layout_ms = layout_ms + timing.layout_ms()
    paint_ms = paint_ms + timing.paint_ms()
    draw_ms = draw_ms + timing.draw_ms()
    total_ms = total_ms + timing.total_ms()
    let present_start = perf_now_ms()
    let presented = (pumps[index].render)(sequence, profiled.frame())
    present_ms = present_ms + (perf_now_ms() - present_start).max(0.0)
    if !presented {
      perf_fail("renderer did not present performance frame")
    }
  }
  samples.build_ms.push(build_ms)
  samples.layout_ms.push(layout_ms)
  samples.paint_ms.push(paint_ms)
  samples.draw_ms.push(draw_ms)
  samples.present_ms.push(present_ms)
  samples.frame_ms.push(build_ms + layout_ms + paint_ms + draw_ms + present_ms)
  samples.total_ms.push(total_ms)
}

///|
fn perf_run_scenario(
  label : String,
  width : Double,
  height : Double,
  make_runtimes : (Double, Double) -> Array[@runtime.AppRuntime],
  prepare : (Array[@runtime.AppRuntime]) -> Unit,
  drive : (Array[@runtime.AppRuntime], Int32) -> Unit,
  frames : Int32,
  warmup : Int32,
) -> ScenarioResult {
  let startup_start = perf_now_ms()
  let runtimes = make_runtimes(width, height)
  prepare(runtimes)
  let pumps : Array[PerfFramePump] = []
  for index in 0..<runtimes.length() {
    pumps.push(perf_pump("\{label}-\{index}", width, height))
  }
  let warmup_samples = perf_empty_samples()
  for index in 0..<warmup {
    drive(runtimes, index)
    perf_measure_iteration(runtimes, pumps, index, warmup_samples)
  }
  let startup_ms = perf_now_ms() - startup_start
  let before_cache = perf_cache_counters(runtimes)
  let before_detailed_cache = perf_detailed_cache_counters(runtimes)
  let samples = perf_empty_samples()
  for index in 0..<frames {
    let sequence = warmup + index
    drive(runtimes, sequence)
    perf_measure_iteration(runtimes, pumps, sequence, samples)
  }
  let after_cache = perf_cache_counters(runtimes)
  let after_detailed_cache = perf_detailed_cache_counters(runtimes)
  let pumped = warmup + frames
  for pump in pumps {
    (pump.assert_clean)(label, pumped)
  }
  {
    samples,
    resources: {
      peak_rss_bytes: perf_peak_rss_bytes(),
      allocation_count: perf_allocation_count(),
      cache_hit_rate: perf_cache_hit_rate(before_cache, after_cache),
      layout_cache_hits: perf_counter_delta(
        after_detailed_cache.layout_hits,
        before_detailed_cache.layout_hits,
      ),
      layout_cache_misses: perf_counter_delta(
        after_detailed_cache.layout_misses,
        before_detailed_cache.layout_misses,
      ),
      render_cache_hits: perf_counter_delta(
        after_detailed_cache.render_hits,
        before_detailed_cache.render_hits,
      ),
      render_cache_misses: perf_counter_delta(
        after_detailed_cache.render_misses,
        before_detailed_cache.render_misses,
      ),
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
      "drawMs": result.samples.draw_ms,
      "presentMs": result.samples.present_ms,
      "frameMs": result.samples.frame_ms,
      "totalMs": result.samples.total_ms,
    },
    "cache": {
      "layoutHits": result.resources.layout_cache_hits,
      "layoutMisses": result.resources.layout_cache_misses,
      "layoutHitRate": perf_leaf_ratio(
        result.resources.layout_cache_hits,
        result.resources.layout_cache_misses,
      ),
      "renderHits": result.resources.render_cache_hits,
      "renderMisses": result.resources.render_cache_misses,
      "renderHitRate": perf_leaf_ratio(
        result.resources.render_cache_hits,
        result.resources.render_cache_misses,
      ),
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
  let provider = perf_provider_choice()
  let mode = perf_present_mode()
  perf_assert_provider_mode(provider, mode)
  // The Sun provider links no Skia at all, so requiring the locked Skia
  // artifact here would make a non-Skia number impossible to produce on a
  // machine that has never downloaded one — which is the dependency this
  // harness is supposed to be able to drop.
  if provider != "sun" && !@skia_renderer.skia_available() {
    perf_fail(
      "Skia is unavailable; configure the locked real Skia provider before running performance budgets",
    )
  }
  let frames = perf_env_int("MOUI_PERFORMANCE_FRAMES", 60)
  let warmup = perf_env_int("MOUI_PERFORMANCE_WARMUP", 12)
  let leaf_frames = perf_env_int("MOUI_PERFORMANCE_LEAF_FRAMES", 30)
  let leaf_warmup = perf_env_int("MOUI_PERFORMANCE_LEAF_WARMUP", 6)
  let scenarios : Map[String, Json] = Map([])
  scenarios["showcase-runtime-scroll"] = perf_scenario_json(
    perf_run_scenario(
      "showcase-runtime-scroll", 1280.0, 720.0, perf_showcase_runtimes, perf_no_prepare,
      perf_drive_showcase, frames, warmup,
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
  // W0.1 diagnostic block: one leaf changes per frame, on both sides of a
  // 1k/10k-node scale boundary. This is intentionally outside the five
  // budgeted scenarios until W0.3 ratifies a stable update budget.
  let leaf_scenarios : Map[String, Json] = Map([])
  leaf_scenarios["leaf-update-1k"] = perf_leaf_update_json(
    perf_leaf_update_scenario(
      "leaf-update-1k",
      1000,
      800.0,
      600.0,
      leaf_frames,
      leaf_warmup,
      construction_mode=Direct,
    ),
  )
  leaf_scenarios["leaf-update-10k"] = perf_leaf_update_json(
    perf_leaf_update_scenario(
      "leaf-update-10k",
      10000,
      800.0,
      600.0,
      leaf_frames,
      leaf_warmup,
      construction_mode=Direct,
    ),
  )
  leaf_scenarios["leaf-update-1k-memo"] = perf_leaf_update_json(
    perf_leaf_update_scenario(
      "leaf-update-1k-memo",
      1000,
      800.0,
      600.0,
      leaf_frames,
      leaf_warmup,
      construction_mode=Memo,
    ),
  )
  leaf_scenarios["leaf-update-10k-memo"] = perf_leaf_update_json(
    perf_leaf_update_scenario(
      "leaf-update-10k-memo",
      10000,
      800.0,
      600.0,
      leaf_frames,
      leaf_warmup,
      construction_mode=Memo,
    ),
  )
  leaf_scenarios["leaf-update-1k-builder-cache"] = perf_leaf_update_json(
    perf_leaf_update_scenario(
      "leaf-update-1k-builder-cache",
      1000,
      800.0,
      600.0,
      leaf_frames,
      leaf_warmup,
      construction_mode=BuilderCache,
    ),
  )
  leaf_scenarios["leaf-update-10k-builder-cache"] = perf_leaf_update_json(
    perf_leaf_update_scenario(
      "leaf-update-10k-builder-cache",
      10000,
      800.0,
      600.0,
      leaf_frames,
      leaf_warmup,
      construction_mode=BuilderCache,
    ),
  )
  // N2 structural comparison: the same construction modes with two map
  // layers. Adapter-copy counts must scale with layers even when node builds
  // are served by the builder cache.
  leaf_scenarios["leaf-update-1k-map2"] = perf_leaf_update_json(
    perf_leaf_update_scenario(
      "leaf-update-1k-map2",
      1000,
      800.0,
      600.0,
      leaf_frames,
      leaf_warmup,
      construction_mode=Direct,
      map_layers=2,
    ),
  )
  leaf_scenarios["leaf-update-1k-builder-cache-map2"] = perf_leaf_update_json(
    perf_leaf_update_scenario(
      "leaf-update-1k-builder-cache-map2",
      1000,
      800.0,
      600.0,
      leaf_frames,
      leaf_warmup,
      construction_mode=BuilderCache,
      map_layers=2,
    ),
  )
  leaf_scenarios["leaf-update-10k-map2"] = perf_leaf_update_json(
    perf_leaf_update_scenario(
      "leaf-update-10k-map2",
      10000,
      800.0,
      600.0,
      leaf_frames,
      leaf_warmup,
      construction_mode=Direct,
      map_layers=2,
    ),
  )
  leaf_scenarios["leaf-update-10k-builder-cache-map2"] = perf_leaf_update_json(
    perf_leaf_update_scenario(
      "leaf-update-10k-builder-cache-map2",
      10000,
      800.0,
      600.0,
      leaf_frames,
      leaf_warmup,
      construction_mode=BuilderCache,
      map_layers=2,
    ),
  )
  let report : Json = {
    "schemaVersion": 1,
    "runner": perf_runner_label(provider, mode),
    "config": {
      "frames": frames,
      "warmup": warmup,
      "leafFrames": leaf_frames,
      "leafWarmup": leaf_warmup,
      "provider": provider,
      "surfaceRoute": mode,
    },
    "scenarios": scenarios,
    "leafUpdate": { "schemaVersion": 2, "scenarios": leaf_scenarios },
  }
  println("MOUI_PERFORMANCE_RESULT=" + report.stringify(indent=0))
}

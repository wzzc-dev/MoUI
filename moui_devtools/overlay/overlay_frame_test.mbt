///|
fn frame_test_trace(
  build_ms~ : Double,
  layout_ms~ : Double,
  paint_ms~ : Double,
  draw_ms~ : Double,
  timed~ : Bool = true,
) -> @devtools.DevtoolsFrameTrace {
  {
    timed,
    rebuild_passes: 1,
    layout_passes: 1,
    paint_passes: 1,
    draw_builds: 1,
    build_ms,
    layout_ms,
    paint_ms,
    draw_ms,
    total_ms: build_ms + layout_ms + paint_ms + draw_ms,
    damage_kind: "partial",
    damage_rect_count: 1,
  }
}

///|
test "frame phase spans report the four timed phases in paint order" {
  let trace = frame_test_trace(
    build_ms=1.0,
    layout_ms=2.0,
    paint_ms=3.0,
    draw_ms=4.0,
  )
  let spans = @overlay.frame_phase_spans(trace)
  inspect(spans.length(), content="4")
  inspect(spans[0].phase, content="build")
  inspect(spans[3].phase, content="draw")
  inspect(spans[3].ms, content="4")
}

///|
test "sparkline segment heights scale to the budget and cap past it" {
  // Half the budget fills half the column.
  let half = @overlay.frame_sparkline_segment_heights(
    frame_test_trace(build_ms=5.0, layout_ms=0.0, paint_ms=0.0, draw_ms=0.0),
    budget_ms=10.0,
    max_height=48.0,
  )
  inspect(half[0], content="24")
  // Past the budget every segment caps at the column height.
  let over = @overlay.frame_sparkline_segment_heights(
    frame_test_trace(build_ms=80.0, layout_ms=0.0, paint_ms=0.0, draw_ms=0.0),
    budget_ms=10.0,
    max_height=48.0,
  )
  inspect(over[0], content="48")
  // An untimed frame draws nothing rather than inventing timings.
  let untimed = @overlay.frame_sparkline_segment_heights(
    frame_test_trace(
      build_ms=0.0,
      layout_ms=0.0,
      paint_ms=0.0,
      draw_ms=0.0,
      timed=false,
    ),
    budget_ms=10.0,
    max_height=48.0,
  )
  inspect(untimed.length(), content="4")
  inspect(untimed[0] + untimed[1] + untimed[2] + untimed[3], content="0")
}

///|
test "frame trace p95 is the nearest-rank percentile of total time" {
  let empty : Array[@devtools.DevtoolsFrameTrace] = []
  inspect(@overlay.frame_trace_p95(empty), content="0")
  // 20 frames of 1..20ms total: nearest-rank p95 of 20 samples is the 19th.
  let traces : Array[@devtools.DevtoolsFrameTrace] = []
  for index in 1..<21 {
    let ms = index.to_double()
    traces.push(
      frame_test_trace(build_ms=ms, layout_ms=0.0, paint_ms=0.0, draw_ms=0.0),
    )
  }
  inspect(@overlay.frame_trace_p95(traces), content="19")
}

///|
test "stats line summarizes count, last, p95, and over-budget frames" {
  let empty : Array[@devtools.DevtoolsFrameTrace] = []
  inspect(
    @overlay.frame_trace_stats_line(empty, budget_ms=16.7),
    content="no frames recorded",
  )
  let traces = [
    frame_test_trace(build_ms=5.0, layout_ms=0.0, paint_ms=0.0, draw_ms=0.0),
    frame_test_trace(build_ms=20.0, layout_ms=0.0, paint_ms=0.0, draw_ms=0.0),
  ]
  inspect(
    @overlay.frame_trace_stats_line(traces, budget_ms=16.7),
    content="frames 2 · last 20ms · p95 20ms · over budget 1",
  )
}

///|
test "the overlay view assembles from recorded trace entries" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.text("probe") : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=40.0),
  )
  ignore(runtime.draw_frame())
  let trace = @devtools.DevtoolsTrace::new(capacity=8)
  let clock = Ref(0.0)
  for _pass in 0..<2 {
    let profiled = runtime.profile_draw_frame(() => {
      clock.val = clock.val + 1.0
      clock.val
    })
    ignore(
      trace.record_frame(runtime.inspector_snapshot(), timing=profiled.timing()),
    )
  }
  let traces = @overlay.frame_trace_entries(trace)
  inspect(traces.length(), content="2")
  let view = @overlay.frame_trace_overlay(traces)
  let _ = view
  // An empty trace renders the honest placeholder instead of an empty chart.
  let empty_trace : Array[@devtools.DevtoolsFrameTrace] = []
  let stats = @overlay.frame_trace_stats_line(empty_trace, budget_ms=16.7)
  inspect(stats, content="no frames recorded")
  let placeholder = @overlay.frame_trace_overlay(empty_trace)
  let _ = placeholder
}

///|
/// Visual frame-performance surface over the data `DevtoolsTrace` already
/// records: the most recent frames as a phase-stacked sparkline scaled against
/// the frame budget, with a one-line summary (frames, last, p95, over-budget
/// count). The app owns retention — pass it the trace it keeps, or
/// `frame_trace_entries` over a `DevtoolsTrace`.

///|
/// One timed phase of a frame, in paint order.
pub struct FramePhaseSpan {
  phase : String
  ms : Double
}

///|
/// Extract the frame trace of every recorded entry, oldest first.
pub fn frame_trace_entries(
  trace : @devtools.DevtoolsTrace,
) -> Array[@devtools.DevtoolsFrameTrace] {
  trace.entries().map(entry => entry.frame)
}

///|
/// The four timed phases of a frame trace, in paint order.
pub fn frame_phase_spans(
  trace : @devtools.DevtoolsFrameTrace,
) -> Array[FramePhaseSpan] {
  [
    { phase: "build", ms: trace.build_ms, },
    { phase: "layout", ms: trace.layout_ms, },
    { phase: "paint", ms: trace.paint_ms, },
    { phase: "draw", ms: trace.draw_ms, },
  ]
}

///|
/// Phase color over the ambient theme palette: build=primary, layout=tertiary,
/// paint=secondary, draw=error, anything else=outline.
pub fn frame_phase_color(phase~ : String, theme~ : @core.Theme) -> @core.Color {
  let palette = theme.palette
  match phase {
    "build" => palette.primary
    "layout" => palette.tertiary
    "paint" => palette.secondary
    "draw" => palette.error
    _ => palette.outline
  }
}

///|
/// Per-phase segment heights for one sparkline column: the frame budget fills
/// the column, phases beyond it cap there, and untimed frames draw nothing.
pub fn frame_sparkline_segment_heights(
  trace : @devtools.DevtoolsFrameTrace,
  budget_ms~ : Double,
  max_height~ : Double,
) -> Array[Double] {
  if !trace.timed {
    return [0.0, 0.0, 0.0, 0.0]
  }
  frame_phase_spans(trace).map(span => {
    if span.ms <= 0.0 || budget_ms <= 0.0 {
      0.0
    } else {
      (span.ms / budget_ms * max_height).clamp(min=0.0, max=max_height)
    }
  })
}

///|
/// Nearest-rank p95 of the frames' total time: the `ceil(0.95 · N)`-th sample
/// of the sorted totals. An empty trace is 0.0.
pub fn frame_trace_p95(traces : Array[@devtools.DevtoolsFrameTrace]) -> Double {
  if traces.length() == 0 {
    return 0.0
  }
  let totals = traces.map(trace => trace.total_ms)
  totals.sort()
  let mut index = (totals.length().to_double() * 0.95).ceil().to_int() - 1
  if index < 0 {
    index = 0
  }
  if index > totals.length() - 1 {
    index = totals.length() - 1
  }
  totals[index]
}

///|
fn frame_trace_ms_text(value : Double) -> String {
  ((value * 100.0).round() / 100.0).to_string()
}

///|
/// One-line summary under the sparkline.
pub fn frame_trace_stats_line(
  traces : Array[@devtools.DevtoolsFrameTrace],
  budget_ms~ : Double,
) -> String {
  if traces.length() == 0 {
    return "no frames recorded"
  }
  let last = traces[traces.length() - 1].total_ms
  let mut over = 0
  for trace in traces {
    if trace.timed && trace.total_ms > budget_ms {
      over = over + 1
    }
  }
  "frames \{traces.length()} · last \{frame_trace_ms_text(last)}ms · p95 \{frame_trace_ms_text(frame_trace_p95(traces))}ms · over budget \{over}"
}

///|
/// The frame-performance overlay: a phase-stacked sparkline of the most
/// recent frames (bottom-aligned, budget line across the top) plus the stats
/// caption. Untimed frames draw an empty column so gaps stay honest.
pub fn frame_trace_overlay(
  traces : Array[@devtools.DevtoolsFrameTrace],
  theme~ : @core.Theme = @views.default_theme(),
  budget_ms~ : Double = 16.7,
  sparkline_height~ : Double = 48.0,
  bar_width~ : Double = 6.0,
  bar_gap~ : Double = 2.0,
  width~ : Double = 744.0,
  max_bars~ : Int32 = 48,
) -> @core.View[Unit] {
  let visible = if traces.length() > max_bars {
    let keep : Array[@devtools.DevtoolsFrameTrace] = []
    let start = traces.length() - max_bars
    for index in start..<traces.length() {
      keep.push(traces[index])
    }
    keep
  } else {
    traces
  }
  let bar_count = visible.length().to_double()
  let sparkline_width = (bar_count * bar_width +
  (bar_count - 1.0).max(0.0) * bar_gap).max(1.0)
  let sparkline = @views.canvas(
    measure=_ => @core.Size::new(width=sparkline_width, height=sparkline_height),
    draw=(ctx, frame) => {
      // The budget ceiling, drawn as a hairline across the top.
      @views.fill_rect(
        ctx,
        @core.Rect::new(
          x=frame.origin.x,
          y=frame.origin.y,
          width=frame.size.width,
          height=1.0,
        ),
        theme.palette.outline_variant,
      )
      let bottom = frame.origin.y + frame.size.height
      for index, trace in visible {
        let spans = frame_phase_spans(trace)
        let heights = frame_sparkline_segment_heights(
          trace,
          budget_ms~,
          max_height=sparkline_height - 1.0,
        )
        let x = frame.origin.x + index.to_double() * (bar_width + bar_gap)
        let mut y = bottom
        for phase_index, span in spans {
          let height = heights[phase_index]
          if height > 0.0 {
            y = y - height
            @views.fill_rect(
              ctx,
              @core.Rect::new(x~, y~, width=bar_width, height~),
              frame_phase_color(phase=span.phase, theme~),
            )
          }
        }
      }
    },
    semantics_label="frame timing sparkline",
  )
  @views.padding(
    @views.column(
      [
        sparkline,
        @views.text(
          frame_trace_stats_line(visible, budget_ms~),
          role=Caption,
          theme~,
          width~,
        ),
      ],
      spacing=4.0,
    ),
    12.0,
  )
}

///|
priv enum DevtoolsTraceProbeMsg {
  DevtoolsTraceToggle
}

///|
fn devtools_trace_probe_program() -> @core.Program[Bool, DevtoolsTraceProbeMsg] {
  @core.Program::new(
    init=() => (false, @core.Effect::none()),
    update=(model, message) => {
      match message {
        DevtoolsTraceToggle => (!model, @core.Effect::none())
      }
    },
    view=model => {
      let label = if model { "On" } else { "Off" }
      @views.column(
        [
          @views.button(
            label,
            on_click=DevtoolsTraceToggle,
            width=100.0,
            height=40.0,
          ),
          @views.button(
            label,
            on_click=DevtoolsTraceToggle,
            width=100.0,
            height=40.0,
          ),
          @views.button(
            label,
            on_click=DevtoolsTraceToggle,
            width=100.0,
            height=40.0,
          ),
        ],
        spacing=0.0,
      )
    },
  )
}

///|
fn devtools_trace_dispatch_click(
  runtime : @runtime.AppRuntime,
  x~ : Double,
  y~ : Double,
) -> Unit {
  runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Down),
  )
  |> ignore
  runtime.dispatch_pointer_input(
    @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase=Up),
  )
  |> ignore
}

///|
test "trace records one interaction with frame, message, cache, and semantics deltas" {
  let runtime = @runtime.AppRuntime::new_program(
    program=devtools_trace_probe_program(),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  ignore(runtime.draw_frame())
  let trace = DevtoolsTrace::new(capacity=2, semantics_diff_limit=1)
  let baseline = trace.record(runtime.inspector_snapshot())
  assert_true(baseline.semantics.baseline)
  devtools_trace_dispatch_click(runtime, x=10.0, y=10.0)
  let clock = Ref(0.0)
  let profiled = runtime.profile_draw_frame(() => {
    clock.val = clock.val + 1.0
    clock.val
  })
  let entry = trace.record_frame(
    runtime.inspector_snapshot(),
    timing=profiled.timing(),
  )
  assert_true(entry.messages.updated_delta > 0)
  assert_true(entry.effects.planned_delta > 0)
  assert_true(entry.frame.timed)
  assert_true(entry.frame.layout_passes > 0)
  assert_true(entry.frame.paint_passes > 0)
  assert_true(entry.frame.draw_builds > 0)
  assert_true(entry.frame.total_ms > 0.0)
  assert_true(entry.semantics.changed_count >= 3)
  assert_true(entry.semantics.dropped_count > 0)
  assert_eq(entry.semantics.entries.length(), 1)
  let change = entry.semantics.entries[0]
  assert_true(change.kind == SemanticsTreeChanged)
  assert_true(change.changed_fields.contains(SemanticsTreeFieldLabel))
  let report = trace_report_text(trace)
  assert_true(report.contains("[trace]"))
  assert_true(report.contains("semantics=+/-/~="))
  assert_true(report.contains("timing="))
  assert_true(trace_report_json(trace).contains("\"entries\""))
}

///|
test "trace retention is bounded and clear starts a new baseline" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.text("Bounded trace") : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=40.0),
  )
  ignore(runtime.draw_frame())
  let trace = DevtoolsTrace::new(capacity=2, semantics_diff_limit=8)
  ignore(trace.record(runtime.inspector_snapshot()))
  ignore(trace.record(runtime.inspector_snapshot()))
  ignore(trace.record(runtime.inspector_snapshot()))
  assert_eq(trace.length(), 2)
  let entries = trace.entries()
  assert_eq(entries[0].sequence, 1)
  assert_eq(entries[1].sequence, 2)
  trace.clear()
  assert_true(trace.is_empty())
  let baseline = trace.record(runtime.inspector_snapshot())
  assert_true(baseline.semantics.baseline)
  assert_eq(baseline.sequence, 3)
}

///|
test "trace consumes caller-owned ViewMemo counters without registering them" {
  let memo : @core.ViewMemo[Unit] = @core.ViewMemo::new()
  ignore(
    memo.view(key=@core.DeclarationKey::string("memo-probe"), build=() => {
      @views.text("Memo")
    }),
  )
  ignore(
    memo.view(key=@core.DeclarationKey::string("memo-probe"), build=() => {
      @views.text("Stale")
    }),
  )
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.empty() : @core.View[Unit]),
    size=@core.Size::new(width=32.0, height=32.0),
  )
  let trace = DevtoolsTrace::new(capacity=2)
  let entry = trace.record(
    runtime.inspector_snapshot(),
    memo_stats=memo.stats(),
  )
  assert_true(entry.memo.available)
  assert_eq(entry.memo.builds_after, 1)
  assert_eq(entry.memo.hits_after, 1)
  assert_eq(entry.memo.misses_after, 1)
  assert_eq(entry.memo.builds_delta, 1)
  assert_eq(entry.memo.hits_delta, 1)
  assert_eq(entry.memo.misses_delta, 1)
  let second = trace.record(runtime.inspector_snapshot())
  assert_false(second.memo.available)
}

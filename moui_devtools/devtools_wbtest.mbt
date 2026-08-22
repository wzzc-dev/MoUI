///|
test "devtools summarizes inspector snapshots" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.empty() : @core.View[Unit]),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  ignore(runtime.draw_commands())
  let snapshot = runtime.inspector_snapshot()
  let summary = snapshot_summary(snapshot)
  inspect(summary.width, content="320")
  inspect(summary.height, content="240")
  assert_true(snapshot_debug_text(snapshot).contains("commands="))
  assert_true(snapshot_json(snapshot).contains("\"runtime\""))
  let report = inspector_report(snapshot)
  inspect(report.view_tree().node_count(), content="1")
  inspect(report.layout().bounds().length(), content="1")
  let report_text = inspector_report_text(snapshot)
  assert_true(report_text.contains("[view]"))
  assert_true(report_text.contains("[layout]"))
  assert_true(report_text.contains("[render]"))
  assert_true(report_text.contains("[semantics]"))
  assert_true(report_text.contains("[effects]"))
  assert_true(report_text.contains("[subscriptions]"))
  assert_true(report_text.contains("[cache]"))
  assert_true(report_text.contains("[event]"))
  assert_true(snapshot_report_json(snapshot).contains("\"view_tree\""))
  let history = SnapshotHistory::new()
  history.push(snapshot)
  inspect(history.length(), content="1")
  assert_true(history.debug_text().contains("#0: size=320"))
}

///|
test "devtools reports pointer hit path and cache counters" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.padding(@views.text("Hit"), 8.0) : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=80.0),
  )
  ignore(runtime.draw_commands())
  runtime.dispatch_pointer_input(
    @core.PointerEvent::new(
      position=@core.Point::new(x=12.0, y=12.0),
      phase=Move,
    ),
  )
  |> ignore
  let report = inspector_report(runtime.inspector_snapshot())
  assert_true(report.runtime().layout_cache_miss_count() > 0)
  assert_true(report.runtime().render_cache_miss_count() > 0)
  assert_true(report.runtime().last_event_hit_path().length() > 0)
  assert_true(report.view_tree().nodes().any(node => node.depth() > 0))
  assert_true(
    report.layout().bounds().any(entry => entry.constraints().max.width > 0.0),
  )
  assert_true(report.render().nodes().length() > 0)
  assert_true(report.semantics().nodes().length() > 0)
}

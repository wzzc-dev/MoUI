///|
test "devtools summarizes inspector snapshots" {
  let runtime = @runtime.AppRuntime::new_view(
    root=(@core.View::empty() : @core.View[Unit]),
    size=@core.Size::new(width=320.0, height=240.0),
  )
  ignore(runtime.draw_commands())
  let snapshot = runtime.inspector_snapshot()
  let summary = snapshot_summary(snapshot)
  inspect(summary.width, content="320")
  inspect(summary.height, content="240")
  assert_true(snapshot_debug_text(snapshot).contains("commands="))
  assert_true(snapshot_json(snapshot).contains("\"runtime\""))
  let history = SnapshotHistory::new()
  history.push(snapshot)
  inspect(history.length(), content="1")
  assert_true(history.debug_text().contains("#0: size=320"))
}

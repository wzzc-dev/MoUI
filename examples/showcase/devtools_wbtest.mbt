///|
test "diagnostics landing carries a populated devtools inspector report" {
  let runtime = runtime(
    host_summary=@host.HostCapabilitySummary::new(
      backend=@host.HostBackendKind::Test,
    ),
    route="diagnostics",
  )
  ignore(runtime.draw_commands())
  let report = @moui_devtools.inspector_report(runtime.inspector_snapshot())
  assert_true(report.view_tree().node_count() > 10)
  assert_true(
    @moui_devtools.inspector_report_text(runtime.inspector_snapshot()).contains(
      "[semantics]",
    ),
  )
}

///|
test "diagnostics landing semantics include the devtools inspector card" {
  let runtime = runtime(
    host_summary=@host.HostCapabilitySummary::new(
      backend=@host.HostBackendKind::Test,
    ),
    route="diagnostics",
  )
  ignore(runtime.draw_commands())
  let mut found = false
  match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(snapshot)) =>
      for node in snapshot.nodes() {
        if node.label.contains("DevTools Inspector") ||
          node.value.contains("DevTools Inspector") {
          found = true
        }
      }
    _ => ()
  }
  assert_true(found)
}

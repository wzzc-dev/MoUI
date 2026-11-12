///|
test "runtime diagnostics sink keeps and drains render events" {
  let root : @core.View[Unit] = @views.text("diag")
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=120.0, height=40.0),
  )
  runtime.push_diagnostics([
    @diagnostics.DiagnosticEvent::new(
      code="render.test",
      severity=@diagnostics.DiagnosticSeverity::Warning,
      domain=@diagnostics.DiagnosticDomain::Render,
      message="unsupported command",
    ),
  ])
  inspect(runtime.diagnostics_sink().length(), content="1")
  let drained = runtime.drain_diagnostics()
  inspect(drained.length(), content="1")
  inspect(drained[0].code, content="render.test")
  inspect(runtime.diagnostics_sink().length(), content="0")
}

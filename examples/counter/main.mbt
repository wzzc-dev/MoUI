///|
fn main {
  let app = @counter_app.CounterApp::new()
  let runtime = app.runtime(width=800.0, height=600.0)
  runtime.dispatch_event(@core.Redraw(@core.Initial))
  app.sync_runtime(runtime)
  @windows.run_app("MoUI Counter", runtime)
}

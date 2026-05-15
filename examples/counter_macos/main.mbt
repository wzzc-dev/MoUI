///|
fn main {
  let app = @counter_app.CounterApp::new()
  let runtime = app.runtime(width=800.0, height=600.0)
  @macos.run_app("MoUI Counter", runtime)
}

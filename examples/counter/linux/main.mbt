///|
fn main {
  let app = @counter_app.CounterApp::new()
  let runtime = app.runtime()
  @linux_backend.run_app("MoUI Counter", runtime)
}

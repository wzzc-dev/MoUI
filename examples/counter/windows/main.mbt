///|
fn main {
  let app = @counter_app.CounterApp::new()
  let runtime = app.runtime()
  @windows_backend.run_app("MoUI Counter", runtime)
}

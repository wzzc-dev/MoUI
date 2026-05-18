///|
fn main {
  let app = @app.TodoApp::new()
  let runtime = app.runtime(width=800.0, height=600.0)
  @macos_backend.run_app("MoUI Todo", runtime)
}

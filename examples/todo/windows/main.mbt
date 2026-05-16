///|
fn main {
  let app = @todo_app.TodoApp::new()
  app.add("Try MoUI")
  let runtime = app.runtime(width=800.0, height=600.0)
  @windows_backend.run_app("MoUI Todo", runtime)
}

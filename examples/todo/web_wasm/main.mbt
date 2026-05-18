///|
fn main {
  let app = @todo_app.TodoApp::new()
  let runtime = app.runtime(width=800.0, height=600.0)
  @web.run_app("MoUI Todo Wasm Host", runtime)
}

///|
pub fn web_dispatch_event(
  kind : Int,
  raw_id : Int,
  arg0 : Int,
  arg1 : Int,
  argd : Double,
  text_id : Int,
) -> Unit {
  @web.web_dispatch_event(kind, raw_id, arg0, arg1, argd, text_id)
}

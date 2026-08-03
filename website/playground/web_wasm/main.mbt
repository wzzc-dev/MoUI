///|
fn main {
  let runtime = @runtime.new_program_with_dimensions(
    program=@playground_app.program(),
    width=1280.0,
    height=820.0,
  )
  @moui.run_app("MoUI Playground", runtime)
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
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

///|
pub fn web_dispatch_pointer_input(
  raw_id : Int,
  kind : Int,
  x_px : Double,
  y_px : Double,
  delta_x_px : Double,
  delta_y_px : Double,
  button : Int,
  modifiers : Int,
) -> Int {
  @web.web_dispatch_pointer_input(
    raw_id, kind, x_px, y_px, delta_x_px, delta_y_px, button, modifiers,
  )
}

///|
pub fn web_dispatch_route(source_code : Int, text_id : Int) -> Unit {
  @web.web_dispatch_route(source_code, text_id)
}

///|
pub fn web_dispatch_semantics_action(
  raw_id : Int,
  node_id_text_id : Int,
  generation_text_id : Int,
  action_code : Int,
  value_id : Int,
  direction_code : Int,
) -> Unit {
  @web.web_dispatch_semantics_action(
    raw_id, node_id_text_id, generation_text_id, action_code, value_id, direction_code,
  )
}

///|
pub fn web_complete_async_clipboard_read(
  id : Int,
  ok : Bool,
  text_id : Int,
) -> Unit {
  @web.web_complete_async_clipboard_read(id, ok, text_id)
}

///|
pub fn playground_begin_compile_result() -> Unit {
  @playground_bridge.begin_compile_result()
}

///|
pub fn playground_append_compile_result_char(character : Char) -> Unit {
  @playground_bridge.append_compile_result_char(character)
}

///|
pub fn playground_finish_compile_result() -> Unit {
  @playground_bridge.finish_compile_result()
}

///|
pub fn playground_begin_project_load() -> Unit {
  @playground_bridge.begin_project_load()
}

///|
pub fn playground_append_project_load_char(character : Char) -> Unit {
  @playground_bridge.append_project_load_char(character)
}

///|
pub fn playground_finish_project_load() -> Unit {
  @playground_bridge.finish_project_load()
}
